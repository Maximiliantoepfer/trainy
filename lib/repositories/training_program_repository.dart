import '../models/training_profile.dart';
import 'dart:convert';
import '../models/strength_plan.dart';
import '../services/catalog_repository.dart';
import 'workout_planning_repository.dart';
import 'package:sqflite/sqflite.dart';
import '../models/cardio.dart';
import '../models/training_program.dart';
import '../services/cardio_training.dart';
import '../services/database_service.dart';
import '../services/training_program_schema.dart';
import '../services/profile_readiness.dart';
import '../utils/uuid_v4.dart';

class TrainingProgramRepository {
  TrainingProgramRepository({DatabaseService? database})
    : db = database ?? DatabaseService();
  final DatabaseService db;
  Future<void> initialize() => db.transaction((txn) async {
    await TrainingProgramSchema.migrate(txn);
    final rows = await txn.query('user_training_profile');
    final user =
        rows.isEmpty
            ? const UserTrainingProfile()
            : UserTrainingProfile.fromJson(_json(rows.single['profile_json']));
    if (user.interestsVersion >= 1) return;
    final interests = {...user.interests};
    for (final row in await txn.rawQuery(
      "SELECT p.program_json FROM training_programs p JOIN training_plans t ON t.id=p.id WHERE t.status='active'",
    )) {
      final plan = TrainingProgram.fromJson(_json(row['program_json']));
      interests.addAll(plan.currentSlots.map((s) => s.kind));
      if (plan.hasRunning) interests.add('running');
    }
    await txn.insert('user_training_profile', {
      'id': 0,
      'profile_json': jsonEncode({
        ...user.toJson(),
        'interests': interests.toList(),
        'interestsVersion': 1,
      }),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });
  Future<UserTrainingProfile> userProfile() async {
    final rows = await db.query('user_training_profile');
    return rows.isEmpty
        ? const UserTrainingProfile()
        : UserTrainingProfile.fromJson(_json(rows.single['profile_json']));
  }

  Future<void> saveUserProfile(UserTrainingProfile p) =>
      db.transaction((txn) async {
        await txn.insert('user_training_profile', {
          'id': 0,
          'profile_json': jsonEncode(p.toJson()),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
  Future<Map<String, dynamic>?> draft(String id) async {
    final rows = await db.query('setup_drafts', where: 'id=?', whereArgs: [id]);
    return rows.isEmpty ? null : _json(rows.single['payload_json']);
  }

  Future<void> saveDraft(String id, Map<String, dynamic> data) async {
    await db.insert('setup_drafts', {
      'id': id,
      'payload_json': jsonEncode(data),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearDraft(String id) async {
    await db.delete('setup_drafts', where: 'id=?', whereArgs: [id]);
  }

  Future<List<TrainingProgram>> plans() async => [
    for (final row in await db.rawQuery(
      '''
    SELECT p.program_json,t.name,t.status FROM training_programs p JOIN training_plans t ON t.id=p.id
    ORDER BY t.updated_at_utc DESC''',
    ))
      TrainingProgram.fromJson({
        ..._json(row['program_json']),
        'name': row['name'],
        'status': row['status'],
      }),
  ];
  Future<String?> activeId() async =>
      (await db.query('active_training_plan')).firstOrNull?['plan_id']
          as String?;

  Future<void> save(
    TrainingProgram program, {
    RunningPlanProposal? running,
    StrengthPlanProposal? strength,
    String locale = 'en',
    Map<String, String> strengthMoves = const {},
    bool activate = true,
  }) async {
    program.validate();
    if (strength != null && !await CatalogRepository.instance.load()) {
      throw StateError('Catalog unavailable');
    }
    await db.transaction((txn) async {
      final todayDate = DateTime.now();
      final today = DateTime(todayDate.year, todayDate.month, todayDate.day);
      final existing = await txn.query(
        'training_programs',
        where: 'id=?',
        whereArgs: [program.id],
      );
      final old =
          existing.isEmpty
              ? null
              : TrainingProgram.fromJson(
                _json(existing.single['program_json']),
              );
      final active = await txn.query('active_training_plan', where: 'id=0');
      final newlyActivating =
          activate &&
          (active.isEmpty || active.single['plan_id'] != program.id);
      await _requireProfiles(
        txn,
        strength:
            program.currentSlots.any((s) => s.kind == 'strength') &&
            (newlyActivating ||
                old == null ||
                !old.currentSlots.any((s) => s.kind == 'strength')),
        running:
            program.hasRunning &&
            (newlyActivating ||
                old == null ||
                !old.hasRunning ||
                running != null),
      );
      if (strength != null) {
        final rows = await txn.query('user_training_profile');
        final user = UserTrainingProfile.fromJson(
          rows.isEmpty ? {} : _json(rows.single['profile_json']),
        );
        final places = [
          for (final r in await txn.query(
            'training_profiles_v2',
            where: 'is_archived=0',
          ))
            TrainingProfileRecord(
              id: r['id'] as String,
              name: r['name'] as String,
              equipmentCodes: const {},
              createdAtUtc: today,
              updatedAtUtc: today,
            ),
        ];
        final missing = ProfileReadiness.strengthForGeneration(user, places);
        if (missing.isNotEmpty) throw ProfileIncomplete('strength', missing);
        if (strength.workouts.map((w) => w.slotId).toSet().length !=
                strength.workouts.length ||
            strength.workouts.any(
              (w) =>
                  !program.slots.any(
                    (s) =>
                        s.id == w.slotId &&
                        s.kind == 'strength' &&
                        (s.workoutId == null || s.workoutId == w.id),
                  ),
            ) ||
            strength.workouts.any(
              (w) =>
                  w.variants.map((v) => v.profileId).toSet().length !=
                      user.strengthPlaces.length ||
                  !w.variants
                      .map((v) => v.profileId)
                      .toSet()
                      .containsAll(user.strengthPlaces),
            )) {
          throw StateError('Proposal does not match plan and places');
        }
        program = program.copyWith(
          strengthSettings: {
            ...program.strengthSettings,
            'proposal': strength.toJson(),
          },
        );
        await WorkoutPlanningRepository.writeGenerated(
          txn,
          strength,
          CatalogRepository.instance,
          locale,
        );
        program = program.copyWith(
          slots: [
            for (final s in program.slots)
              if (s.workoutId == null &&
                  strength.workouts.any((w) => w.slotId == s.id))
                s.copyWith(
                  workoutId:
                      strength.workouts.firstWhere((w) => w.slotId == s.id).id,
                )
              else
                s,
          ],
        );
      }
      final replacedSlotIds = <String, String>{};
      final existingWorkouts =
          existing.isEmpty
              ? <String?>{}
              : TrainingProgram.fromJson(
                _json(existing.single['program_json']),
              ).slots.map((s) => s.workoutId).toSet();
      if (existing.isNotEmpty) {
        final old = TrainingProgram.fromJson(
          _json(existing.single['program_json']),
        );
        final slots = [...program.slots];
        for (final previous in old.slots) {
          final index = slots.indexWhere((s) => s.id == previous.id);
          final next = index < 0 ? null : slots[index];
          final changed =
              next == null ||
              next.workoutId != previous.workoutId ||
              next.weekday != previous.weekday ||
              next.label != previous.label ||
              next.focus
                  .toSet()
                  .difference(previous.focus.toSet())
                  .isNotEmpty ||
              previous.focus
                  .toSet()
                  .difference(next.focus.toSet())
                  .isNotEmpty ||
              next.cycleWeek != previous.cycleWeek;
          if (!changed) continue;
          var effectiveFrom = today;
          final protected = await txn.rawQuery(
            '''SELECT l.occurrence_id FROM strength_session_links l
            JOIN activity_sessions s ON s.id=l.session_id WHERE l.plan_id=? AND l.occurrence_id LIKE ? AND s.status!='discarded' ''',
            [program.id, '${previous.id}:%'],
          );
          for (final link in protected) {
            final occurrence = link['occurrence_id'] as String;
            final date = DateTime.tryParse(
              occurrence.substring(previous.id.length + 1),
            );
            if (date != null && !date.isBefore(effectiveFrom)) {
              effectiveFrom = DateTime(date.year, date.month, date.day + 1);
            }
          }
          if (index >= 0) slots.removeAt(index);
          slots.add(
            previous.until != null && previous.until!.isBefore(today)
                ? previous
                : previous.copyWith(
                  until: DateTime(
                    effectiveFrom.year,
                    effectiveFrom.month,
                    effectiveFrom.day - 1,
                  ),
                ),
          );
          if (next != null) {
            final newId = UuidV4.generate();
            replacedSlotIds[previous.id] = newId;
            slots.add(
              ProgramSlot(
                id: newId,
                weekday: next.weekday,
                label: next.label,
                workoutId: next.workoutId,
                kind: next.kind,
                focus: next.focus,
                cycleWeek: next.cycleWeek,
                from: effectiveFrom,
                until: next.until,
              ),
            );
            await txn.update(
              'plan_slot_overrides',
              {'slot_id': newId},
              where: 'plan_id=? AND slot_id=? AND original_date>=?',
              whereArgs: [program.id, previous.id, dateKey(effectiveFrom)],
            );
            await txn.rawUpdate(
              '''UPDATE strength_occurrence_parts SET slot_id=?, source_occurrence_id=? || substr(source_occurrence_id,?)
              WHERE plan_id=? AND slot_id=? AND original_date>=?''',
              [
                newId,
                newId,
                previous.id.length + 1,
                program.id,
                previous.id,
                dateKey(effectiveFrom),
              ],
            );
          }
        }
        program = program.copyWith(slots: slots);
      }
      for (final slot in program.currentSlots.where(
        (s) => s.workoutId != null,
      )) {
        if ((await txn.query(
              'workout_templates',
              where: 'id=? AND is_archived=0',
              whereArgs: [slot.workoutId],
            )).isEmpty &&
            !existingWorkouts.contains(slot.workoutId)) {
          throw StateError('workoutUnavailable');
        }
      }
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await txn.insert('training_plans', {
        'id': program.id,
        'name': program.name.trim(),
        'source_type': 'manual',
        'status': 'draft',
        'created_at_utc': now,
        'updated_at_utc': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.update(
        'training_plans',
        {
          'name': program.name.trim(),
          'updated_at_utc': now,
          'starts_at_utc': program.start.toUtc().millisecondsSinceEpoch,
          'ends_at_utc': program.endDate?.toUtc().millisecondsSinceEpoch,
        },
        where: 'id=?',
        whereArgs: [program.id],
      );
      await txn.insert('training_programs', {
        'id': program.id,
        'program_json': jsonEncode(program.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final move in strengthMoves.entries) {
        final separator = move.key.lastIndexOf(':');
        if (separator < 0) throw StateError('Invalid occurrence move');
        final originalSlotId = move.key.substring(0, separator);
        final slotId = replacedSlotIds[originalSlotId] ?? originalSlotId;
        final originalDate = move.key.substring(separator + 1);
        await _requireUnstarted(txn, '$originalSlotId:$originalDate');
        if (!program.slots.any((s) => s.id == slotId)) continue;
        final target = DateTime.parse(move.value);
        if (target.isBefore(
              DateTime(
                program.start.year,
                program.start.month,
                program.start.day,
              ),
            ) ||
            (program.endDate != null && target.isAfter(program.endDate!))) {
          throw StateError('Date outside plan');
        }
        await _writeOverride(txn, {
          'plan_id': program.id,
          'slot_id': slotId,
          'original_date': originalDate,
          'local_date': move.value,
        });
      }
      if (activate) {
        final rows = await txn.query('user_training_profile');
        final user =
            rows.isEmpty
                ? const UserTrainingProfile()
                : UserTrainingProfile.fromJson(
                  _json(rows.single['profile_json']),
                );
        final interests = {
          ...user.interests,
          ...program.currentSlots.map((s) => s.kind),
          if (program.hasRunning) 'running',
        };
        await txn.insert('user_training_profile', {
          'id': 0,
          'profile_json': jsonEncode({
            ...user.toJson(),
            'interests': interests.toList(),
            'interestsVersion': 1,
          }),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (running != null) {
        await txn.insert('cardio_plans', {
          'id': program.id,
          'request_json': jsonEncode(running.request.toJson()),
          'version': 2,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await txn.update(
          'cardio_plans',
          {'request_json': jsonEncode(running.request.toJson()), 'version': 2},
          where: 'id=?',
          whereArgs: [program.id],
        );
        // Preserve history, in-progress sessions and every explicitly edited/moved occurrence.
        final today = dateKey(DateTime.now());
        final preserved = await txn.query(
          'cardio_occurrences',
          where:
              "plan_id=? AND (status!='planned' OR locked=1 OR session_id IS NOT NULL OR local_date<?)",
          whereArgs: [program.id, today],
        );
        final dates = preserved.map((r) => r['local_date']).toSet();
        for (final row in preserved) {
          final origins = await txn.query(
            'cardio_occurrence_origins',
            where: 'occurrence_id=?',
            whereArgs: [row['id']],
          );
          dates.addAll(origins.map((r) => r['original_date']));
        }
        await txn.delete(
          'cardio_occurrences',
          where:
              "plan_id=? AND status='planned' AND locked=0 AND session_id IS NULL AND local_date>=?",
          whereArgs: [program.id, today],
        );
        for (final o in running.occurrences.where(
          (o) =>
              (program.endDate == null || !o.date.isAfter(program.endDate!)) &&
              !dates.contains(dateKey(o.date)) &&
              dateKey(o.date).compareTo(today) >= 0,
        )) {
          await txn.insert('cardio_occurrences', {
            'id': o.id,
            'plan_id': program.id,
            'local_date': dateKey(o.date),
            'workout_json': jsonEncode(o.workout.toJson()),
            'locked': o.locked ? 1 : 0,
          });
          await txn.insert('cardio_occurrence_origins', {
            'occurrence_id': o.id,
            'original_date': dateKey(o.date),
          });
        }
      } else if (!program.hasRunning) {
        await txn.delete(
          'cardio_occurrences',
          where:
              "plan_id=? AND status='planned' AND locked=0 AND session_id IS NULL AND local_date>=?",
          whereArgs: [program.id, dateKey(today)],
        );
      }
      if (activate) await _activate(txn, program.id);
      await txn.delete(
        'setup_drafts',
        where: 'id=?',
        whereArgs: ['plan:${program.id}'],
      );
      if (existing.isEmpty) {
        await txn.delete(
          'setup_drafts',
          where: 'id=?',
          whereArgs: ['plan:new'],
        );
      }
    });
  }

  Future<void> activate(String id) => db.transaction((txn) async {
    final rows = await txn.query(
      'training_programs',
      where: 'id=?',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw StateError('Plan not found');
    final p = TrainingProgram.fromJson(_json(rows.single['program_json']));
    await _requireProfiles(
      txn,
      strength: p.currentSlots.any((s) => s.kind == 'strength'),
      running: p.hasRunning,
    );
    await _activate(txn, id);
  });

  Future<void> addCardioOccurrence(
    TrainingProgram program,
    DateTime date,
    CardioWorkout workout,
  ) async {
    workout.validate();
    if (date.isBefore(
          DateTime(program.start.year, program.start.month, program.start.day),
        ) ||
        (program.endDate != null && date.isAfter(program.endDate!))) {
      throw const FormatException('Date outside plan');
    }
    await db.transaction((txn) async {
      await _requireProfiles(txn, strength: false, running: true);
      final rows = await txn.query(
        'training_programs',
        where: 'id=?',
        whereArgs: [program.id],
      );
      if (rows.isEmpty) throw StateError('Plan not found');
      final current = TrainingProgram.fromJson(
        _json(rows.single['program_json']),
      );
      final next = current.copyWith(
        runningDays: {...current.runningDays, date.weekday}.toList()..sort(),
      );
      await txn.update(
        'training_programs',
        {'program_json': jsonEncode(next.toJson())},
        where: 'id=?',
        whereArgs: [program.id],
      );
      await txn.insert('cardio_plans', {
        'id': program.id,
        'request_json': jsonEncode(
          RunningPlanRequest(
            targetMeters: next.targetMeters,
            startDate: next.start,
          ).toJson(),
        ),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.insert('cardio_occurrences', {
        'id': UuidV4.generate(),
        'plan_id': program.id,
        'local_date': dateKey(date),
        'workout_json': jsonEncode(workout.toJson()),
        'locked': 1,
      });
    });
  }

  Future<void> _requireProfiles(
    Transaction txn, {
    required bool strength,
    required bool running,
  }) async {
    if (running) {
      final rows = await txn.query('cardio_preferences');
      ProfileReadiness.requireRunning(
        AthleteRunningProfile.fromJson(
          rows.isEmpty ? {} : _json(rows.single['profile_json']),
        ),
      );
    }
    if (strength) {
      final rows = await txn.query('user_training_profile');
      final p = UserTrainingProfile.fromJson(
        rows.isEmpty ? {} : _json(rows.single['profile_json']),
      );
      final places = await txn.query(
        'training_profiles_v2',
        where: 'id=? AND is_archived=0',
        whereArgs: [p.strengthProfileId ?? ''],
      );
      final missing = ProfileReadiness.strengthStatus(
        p,
        hasPlace: places.isNotEmpty,
      );
      if (missing.isNotEmpty) {
        throw ProfileIncomplete('strength', missing);
      }
    }
  }

  Future<void> _activate(Transaction txn, String id) async {
    if ((await txn.query(
      'training_programs',
      where: 'id=?',
      whereArgs: [id],
    )).isEmpty) {
      throw StateError('Plan not found');
    }
    await txn.update(
      'training_plans',
      {'status': 'archived'},
      where: "status='active' AND id!=?",
      whereArgs: [id],
    );
    await txn.update(
      'training_plans',
      {'status': 'active'},
      where: 'id=?',
      whereArgs: [id],
    );
    await txn.insert('active_training_plan', {
      'id': 0,
      'plan_id': id,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ProgramEntry>> entries(
    TrainingProgram p,
    DateTime from,
    DateTime to,
  ) async {
    // Calendar bounds are local civil dates, including UTC dates restored from drafts.
    from = DateTime(from.year, from.month, from.day);
    to = DateTime(to.year, to.month, to.day);
    final result = <ProgramEntry>[];
    final overrides = await db.query(
      'plan_slot_overrides',
      where: 'plan_id=?',
      whereArgs: [p.id],
    );
    final links = await db.rawQuery(
      '''SELECT l.occurrence_id,s.* FROM strength_session_links l
      JOIN activity_sessions s ON s.id=l.session_id WHERE l.plan_id=? AND s.status!='discarded' ''',
      [p.id],
    );
    final parts = await db.query(
      'strength_occurrence_parts',
      where: 'plan_id=?',
      whereArgs: [p.id],
    );
    final sessions = await db.query(
      'activity_sessions',
      where: "status='completed' AND started_at_utc>=? AND started_at_utc<?",
      whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    final names = {
      for (final w in await db.query(
        'workout_templates',
        where: 'is_archived=0',
      ))
        w['id']: w['name'],
    };
    final monday = DateTime(
      p.start.year,
      p.start.month,
      p.start.day - p.start.weekday + 1,
    );
    bool occurs(ProgramSlot s, DateTime date) =>
        !date.isBefore(DateTime(p.start.year, p.start.month, p.start.day)) &&
        (p.endDate == null || !date.isAfter(p.endDate!)) &&
        date.weekday == s.weekday &&
        (s.from == null || !date.isBefore(s.from!)) &&
        (s.until == null || !date.isAfter(s.until!)) &&
        (s.cycleWeek == 0 ||
            (calendarDays(date, monday) ~/ 7) % 2 + 1 == s.cycleWeek);
    final consumedSessions = <Object?>{};
    ProgramEntry strength(
      ProgramSlot slot,
      DateTime original,
      DateTime date, {
      String? partId,
      String? splitSourceId,
    }) {
      final id = partId ?? '${slot.id}:${dateKey(original)}';
      final linked = links.where((r) => r['occurrence_id'] == id).firstOrNull;
      final candidates =
          sessions
              .where(
                (r) =>
                    !consumedSessions.contains(r['id']) &&
                    !links.any((l) => l['id'] == r['id']) &&
                    slot.workoutId != null &&
                    r['workout_id'] == slot.workoutId &&
                    dateKey(
                          DateTime.fromMillisecondsSinceEpoch(
                            r['started_at_utc'] as int,
                          ),
                        ) ==
                        dateKey(date),
              )
              .toList();
      // Never assign one of several identical same-day workouts by arbitrary order.
      final sameDaySlots =
          p.slots
              .where((s) => s.workoutId == slot.workoutId && occurs(s, date))
              .length;
      final match =
          linked ??
          (candidates.length == 1 && sameDaySlots <= 1
              ? candidates.single
              : null);
      if (match != null) consumedSessions.add(match['id']);
      return ProgramEntry(
        id: id,
        planId: p.id,
        date: date,
        originalDate: original,
        slotId: slot.id,
        name:
            match?['name_snapshot'] as String? ??
            names[slot.workoutId] as String? ??
            slot.label,
        kind: slot.kind,
        workoutId:
            match != null || names.containsKey(slot.workoutId)
                ? slot.workoutId
                : null,
        completed: match?['status'] == 'completed',
        sessionId: match?['id'] as String?,
        splitSourceId: splitSourceId,
      );
    }

    for (
      var date = from;
      date.isBefore(to);
      date = DateTime(date.year, date.month, date.day + 1)
    ) {
      for (final slot in p.slots.where((s) => occurs(s, date))) {
        if (parts.any(
          (r) => r['source_occurrence_id'] == '${slot.id}:${dateKey(date)}',
        )) {
          continue;
        }
        if (!overrides.any(
          (o) => o['slot_id'] == slot.id && o['original_date'] == dateKey(date),
        )) {
          result.add(strength(slot, date, date));
        }
      }
    }
    for (final o in overrides) {
      final date = DateTime.parse(o['local_date'] as String),
          original = DateTime.parse(o['original_date'] as String);
      final slot = p.slots.where((s) => s.id == o['slot_id']).firstOrNull;
      if (parts.any(
        (r) =>
            r['source_occurrence_id'] ==
            '${o['slot_id']}:${o['original_date']}',
      )) {
        continue;
      }
      if (slot != null && !date.isBefore(from) && date.isBefore(to)) {
        final entry = strength(
          o['workout_id'] == null
              ? slot
              : slot.copyWith(workoutId: o['workout_id'] as String),
          original,
          date,
        );
        if (p.endDate == null ||
            !date.isAfter(p.endDate!) ||
            entry.sessionId != null) {
          result.add(entry);
        }
      }
    }
    for (final part in parts) {
      final date = DateTime.parse(part['local_date'] as String);
      if (date.isBefore(from) || !date.isBefore(to)) continue;
      final slot = p.slots.where((s) => s.id == part['slot_id']).firstOrNull;
      if (slot == null) continue;
      final entry = strength(
        slot.copyWith(workoutId: part['workout_id'] as String),
        DateTime.parse(part['original_date'] as String),
        date,
        partId: part['id'] as String,
        splitSourceId: part['source_occurrence_id'] as String,
      );
      if (p.endDate == null ||
          !date.isAfter(p.endDate!) ||
          entry.sessionId != null) {
        result.add(entry);
      }
    }
    // A shortened plan never hides a session that was already started.
    for (final link in links) {
      final id = link['occurrence_id'] as String;
      if (result.any((e) => e.id == id)) continue;
      final slot = p.slots.where((s) => id.startsWith('${s.id}:')).firstOrNull;
      if (slot == null) continue;
      final original = DateTime.tryParse(id.substring(slot.id.length + 1));
      if (original == null) continue;
      final moved =
          overrides
              .where(
                (o) =>
                    o['slot_id'] == slot.id &&
                    o['original_date'] == dateKey(original),
              )
              .firstOrNull;
      final date =
          moved == null
              ? original
              : DateTime.parse(moved['local_date'] as String);
      if (!date.isBefore(from) && date.isBefore(to)) {
        result.add(strength(slot, original, date));
      }
    }
    for (final r in await db.query(
      'cardio_occurrences',
      where: 'plan_id=? AND local_date>=? AND local_date<?',
      whereArgs: [p.id, dateKey(from), dateKey(to)],
      orderBy: 'local_date,id',
    )) {
      final o = ScheduledCardioWorkout(
        id: r['id'] as String,
        planId: p.id,
        date: DateTime.parse(r['local_date'] as String),
        workout: CardioWorkout.fromJson(_json(r['workout_json'])),
        status: r['status'] as String,
        locked: r['locked'] == 1,
        sessionId: r['session_id'] as String?,
      );
      if (p.endDate != null &&
          o.date.isAfter(p.endDate!) &&
          o.status == 'planned' &&
          o.sessionId == null) {
        continue;
      }
      result.add(
        ProgramEntry(
          id: o.id,
          planId: p.id,
          date: o.date,
          name: o.workout.name,
          kind: 'running',
          cardio: o,
          completed: o.status == 'completed',
          sessionId: o.sessionId,
        ),
      );
    }
    result.sort((a, b) {
      final d = a.date.compareTo(b.date);
      return d == 0 ? a.id.compareTo(b.id) : d;
    });
    return result;
  }

  static Future<void> _writeOverride(
    DatabaseExecutor txn,
    Map<String, Object?> values,
  ) async {
    final keys = values.keys.toList();
    await txn.rawInsert(
      'INSERT INTO plan_slot_overrides (${keys.join(',')}) VALUES (${List.filled(keys.length, '?').join(',')}) '
      'ON CONFLICT(plan_id,slot_id,original_date) DO UPDATE SET local_date=excluded.local_date'
      '${values.containsKey('workout_id') ? ', workout_id=excluded.workout_id' : ''}',
      keys.map((k) => values[k]).toList(),
    );
  }

  Future<void> replaceStrengthOccurrence(
    TrainingProgram p,
    ProgramEntry e,
    String workoutId,
  ) async {
    if (e.completed ||
        e.sessionId != null ||
        e.slotId == null ||
        e.originalDate == null) {
      throw StateError('Protected occurrence');
    }
    await db.transaction((txn) async {
      await _requireUnstarted(txn, e.id);
      if ((await txn.query(
        'workout_templates',
        where: 'id=? AND is_archived=0',
        whereArgs: [workoutId],
      )).isEmpty) {
        throw StateError('Workout unavailable');
      }
      if (e.splitSourceId != null) {
        await txn.update(
          'strength_occurrence_parts',
          {'workout_id': workoutId},
          where: 'id=?',
          whereArgs: [e.id],
        );
      } else {
        await _writeOverride(txn, {
          'plan_id': p.id,
          'slot_id': e.slotId,
          'original_date': dateKey(e.originalDate!),
          'local_date': dateKey(e.date),
          'workout_id': workoutId,
        });
      }
    });
  }

  Future<void> moveStrength(
    TrainingProgram p,
    ProgramEntry entry,
    DateTime date, {
    required bool future,
  }) async {
    if (entry.completed || entry.sessionId != null || entry.slotId == null) {
      throw StateError('Completed or invalid entry');
    }
    final original = entry.originalDate!;
    if (p.endDate != null && date.isAfter(p.endDate!)) {
      throw StateError('Date is after plan end');
    }
    if (dateKey(date).compareTo(dateKey(p.start)) < 0) {
      throw StateError('Date is before plan start');
    }
    await db.transaction((txn) async {
      await _requireUnstarted(txn, entry.id);
      if (entry.splitSourceId != null) {
        if (future) throw StateError('A split only applies to this week');
        await txn.update(
          'strength_occurrence_parts',
          {'local_date': dateKey(date)},
          where: 'id=?',
          whereArgs: [entry.id],
        );
        return;
      }
      if (future) {
        final old = p.slots.firstWhere((s) => s.id == entry.slotId);
        final linked = await txn.rawQuery(
          '''SELECT l.occurrence_id FROM strength_session_links l
          JOIN activity_sessions a ON a.id=l.session_id
          LEFT JOIN strength_occurrence_parts part ON part.id=l.occurrence_id
          WHERE l.plan_id=? AND a.status!='discarded' AND
          ((l.occurrence_id LIKE ? AND substr(l.occurrence_id,?)>=?) OR
           (part.slot_id=? AND part.original_date>=?))''',
          [
            p.id,
            '${old.id}:%',
            old.id.length + 2,
            dateKey(original),
            old.id,
            dateKey(original),
          ],
        );
        if (linked.isNotEmpty) {
          throw StateError(
            'Future sessions already started; move only this occurrence',
          );
        }
        final newId = UuidV4.generate();
        final boundary = date.isBefore(original) ? date : original;
        // Split the recurrence instead of retroactively moving historical sessions.
        final slots = [
          for (final s in p.slots)
            s.id == old.id
                ? s.copyWith(
                  until: DateTime(
                    boundary.year,
                    boundary.month,
                    boundary.day - 1,
                  ),
                )
                : s,
          ProgramSlot(
            id: newId,
            weekday: date.weekday,
            label: old.label,
            workoutId: old.workoutId,
            kind: old.kind,
            focus: old.focus,
            cycleWeek:
                old.cycleWeek == 0
                    ? 0
                    : (calendarDays(
                                  date,
                                  DateTime(
                                    p.start.year,
                                    p.start.month,
                                    p.start.day - p.start.weekday + 1,
                                  ),
                                ) ~/
                                7) %
                            2 +
                        1,
            from: date,
          ),
        ];
        await txn.update(
          'training_programs',
          {'program_json': jsonEncode(p.copyWith(slots: slots).toJson())},
          where: 'id=?',
          whereArgs: [p.id],
        );
        await txn.delete(
          'plan_slot_overrides',
          where: 'plan_id=? AND slot_id=? AND original_date=?',
          whereArgs: [p.id, old.id, dateKey(original)],
        );
        final shift = '${calendarDays(date, original)} days';
        await txn.rawUpdate(
          '''UPDATE plan_slot_overrides SET slot_id=?, original_date=date(original_date,?)
          WHERE plan_id=? AND slot_id=? AND original_date>=?''',
          [newId, shift, p.id, old.id, dateKey(original)],
        );
        await txn.rawUpdate(
          '''UPDATE strength_occurrence_parts SET slot_id=?,
          source_occurrence_id=? || ':' || date(original_date,?), original_date=date(original_date,?)
          WHERE plan_id=? AND slot_id=? AND original_date>=?''',
          [newId, newId, shift, shift, p.id, old.id, dateKey(original)],
        );
      } else {
        await _writeOverride(txn, {
          'plan_id': p.id,
          'slot_id': entry.slotId,
          'original_date': dateKey(original),
          'local_date': dateKey(date),
        });
      }
    });
  }

  static Future<void> _requireUnstarted(DatabaseExecutor txn, String id) async {
    final rows = await txn.rawQuery(
      '''SELECT s.id FROM strength_session_links l JOIN activity_sessions s
      ON s.id=l.session_id WHERE l.occurrence_id=? AND s.status!='discarded' ''',
      [id],
    );
    if (rows.isNotEmpty) throw StateError('Started sessions cannot be changed');
  }

  /// Swaps dated placements atomically, never changes the recurring program.
  Future<void> swapEntries(ProgramEntry a, ProgramEntry b) async {
    if (a.planId != b.planId ||
        a.id == b.id ||
        a.completed ||
        b.completed ||
        a.sessionId != null ||
        b.sessionId != null) {
      throw StateError('Invalid swap');
    }
    await db.transaction((txn) async {
      for (final pair in [(a, b.date), (b, a.date)]) {
        final e = pair.$1, date = pair.$2;
        await _requireUnstarted(txn, e.id);
        if (e.cardio != null) {
          final changed = await txn.update(
            'cardio_occurrences',
            {'local_date': dateKey(date), 'locked': 1},
            where: "id=? AND status='planned' AND session_id IS NULL",
            whereArgs: [e.id],
          );
          if (changed != 1) throw StateError('Occurrence already started');
          await txn.insert(
            'cardio_occurrence_origins',
            {'occurrence_id': e.id, 'original_date': dateKey(e.date)},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        } else if (e.splitSourceId != null) {
          await txn.update(
            'strength_occurrence_parts',
            {'local_date': dateKey(date)},
            where: 'id=?',
            whereArgs: [e.id],
          );
        } else {
          await _writeOverride(txn, {
            'plan_id': e.planId,
            'slot_id': e.slotId,
            'original_date': dateKey(e.originalDate!),
            'local_date': dateKey(date),
          });
        }
      }
    });
  }

  Future<void> splitStrength(
    ProgramEntry entry,
    Set<String> firstSlotIds,
    DateTime secondDate,
  ) async {
    if (entry.completed ||
        entry.sessionId != null ||
        entry.workoutId == null ||
        entry.cardio != null ||
        entry.splitSourceId != null) {
      throw StateError('Invalid split');
    }
    final monday = DateTime(
      entry.date.year,
      entry.date.month,
      entry.date.day - entry.date.weekday + 1,
    );
    if (calendarDays(secondDate, monday) < 0 ||
        calendarDays(secondDate, monday) > 6 ||
        dateKey(entry.date) == dateKey(secondDate)) {
      throw StateError('Choose another day in this week');
    }
    await db.transaction((txn) async {
      await _requireUnstarted(txn, entry.id);
      final storedPlan = await txn.query(
        'training_programs',
        where: 'id=?',
        whereArgs: [entry.planId],
      );
      if (storedPlan.isEmpty) throw StateError('Plan unavailable');
      final plan = TrainingProgram.fromJson(
        _json(storedPlan.single['program_json']),
      );
      if (dateKey(secondDate).compareTo(dateKey(plan.start)) < 0 ||
          (plan.endDate != null &&
              dateKey(secondDate).compareTo(dateKey(plan.endDate!)) > 0)) {
        throw StateError('Date is outside plan');
      }
      if ((await txn.query(
        'strength_occurrence_parts',
        where: 'source_occurrence_id=?',
        whereArgs: [entry.id],
      )).isNotEmpty) {
        throw StateError('Already split');
      }
      final setups = await txn.query(
        'workout_variants_v2',
        where: 'workout_id=?',
        whereArgs: [entry.workoutId],
        orderBy: 'is_default DESC,sort_order,id',
        limit: 1,
      );
      if (setups.isEmpty) throw StateError('No workout setup');
      final setup = setups.single;
      final slots = await txn.rawQuery(
        '''SELECT s.* FROM workout_slots_v2 s JOIN workout_variant_group_selections_v2 v
        ON s.group_variant_id=v.group_variant_id WHERE v.workout_variant_id=? ORDER BY s.sort_order,s.id''',
        [setup['id']],
      );
      final all = slots.map((s) => s['id'] as String).toSet();
      if (firstSlotIds.isEmpty ||
          firstSlotIds.length == all.length ||
          !all.containsAll(firstSlotIds)) {
        throw StateError('Both parts need exercises');
      }
      for (final part
          in [
            (firstSlotIds, entry.date),
            (all.difference(firstSlotIds), secondDate),
          ].indexed) {
        final workoutId = await _cloneStrengthPart(
          txn,
          entry.workoutId!,
          setup,
          part.$2.$1,
          part.$1 + 1,
        );
        await txn.insert('strength_occurrence_parts', {
          'id': UuidV4.generate(),
          'plan_id': entry.planId,
          'source_occurrence_id': entry.id,
          'slot_id': entry.slotId,
          'original_date': dateKey(entry.originalDate!),
          'local_date': dateKey(part.$2.$2),
          'workout_id': workoutId,
        });
      }
    });
  }

  static Future<String> _cloneStrengthPart(
    DatabaseExecutor txn,
    String sourceId,
    Map<String, Object?> setup,
    Set<String> slotIds,
    int part,
  ) async {
    final original =
        (await txn.query(
          'workout_templates',
          where: 'id=?',
          whereArgs: [sourceId],
        )).single;
    final id = UuidV4.generate(),
        setupId = UuidV4.generate(),
        localId = DateTime.now().microsecondsSinceEpoch;
    final name = '${original['name']} · $part';
    await txn.insert('workout_templates', {
      ...original,
      'id': id,
      'legacy_local_id': localId,
      'name': name,
    });
    for (final tag in await txn.query(
      'workout_tags',
      where: 'workout_id=?',
      whereArgs: [sourceId],
    )) {
      await txn.insert('workout_tags', {...tag, 'workout_id': id});
    }
    await txn.insert('workouts', {
      'id': localId,
      'name': name,
      'description': original['description'] ?? '',
      'goalCodes': jsonEncode([original['primary_goal_code'] ?? 'strength']),
    });
    await txn.insert('workout_variants_v2', {
      ...setup,
      'id': setupId,
      'workout_id': id,
      'is_default': 1,
      'sort_order': 0,
    });
    final selections = await txn.query(
      'workout_variant_group_selections_v2',
      where: 'workout_variant_id=?',
      whereArgs: [setup['id']],
    );
    var order = 0;
    for (final selection in selections) {
      final sourceSlots = await txn.query(
        'workout_slots_v2',
        where: 'group_variant_id=?',
        whereArgs: [selection['group_variant_id']],
        orderBy: 'sort_order,id',
      );
      final selected =
          sourceSlots.where((s) => slotIds.contains(s['id'])).toList();
      if (selected.isEmpty) continue;
      final group =
          (await txn.query(
            'workout_groups_v2',
            where: 'id=?',
            whereArgs: [selection['workout_group_id']],
          )).single;
      final variant =
          (await txn.query(
            'workout_group_variants_v2',
            where: 'id=?',
            whereArgs: [selection['group_variant_id']],
          )).single;
      final groupId = UuidV4.generate(), variantId = UuidV4.generate();
      await txn.insert('workout_groups_v2', {
        ...group,
        'id': groupId,
        'workout_id': id,
      });
      await txn.insert('workout_group_variants_v2', {
        ...variant,
        'id': variantId,
        'workout_group_id': groupId,
        'owner_setup_id': setupId,
      });
      await txn.insert('workout_variant_group_selections_v2', {
        'workout_variant_id': setupId,
        'workout_group_id': groupId,
        'group_variant_id': variantId,
      });
      for (final slot in selected) {
        final slotId = UuidV4.generate();
        await txn.insert('workout_slots_v2', {
          ...slot,
          'id': slotId,
          'group_variant_id': variantId,
        });
        for (final p in await txn.query(
          'workout_slot_prescriptions',
          where: 'slot_id=?',
          whereArgs: [slot['id']],
        )) {
          await txn.insert('workout_slot_prescriptions', {
            ...p,
            'slot_id': slotId,
          });
        }
        for (final alt in await txn.query(
          'workout_slot_alternatives_v2',
          where: 'workout_slot_id=?',
          whereArgs: [slot['id']],
        )) {
          await txn.insert('workout_slot_alternatives_v2', {
            ...alt,
            'id': UuidV4.generate(),
            'workout_slot_id': slotId,
          });
        }
        final exercise =
            (await txn.query(
              'exercise_items',
              where: 'id=?',
              whereArgs: [slot['exercise_id']],
            )).single;
        await txn.insert('exercises_in_workouts', {
          'id': localId + ++order,
          'workoutId': localId,
          'exerciseId': exercise['legacy_local_id'],
          'sort': order,
        });
      }
    }
    return id;
  }

  Future<void> undoSplit(String sourceId) async => db.transaction((txn) async {
    final parts = await txn.query(
      'strength_occurrence_parts',
      where: 'source_occurrence_id=?',
      whereArgs: [sourceId],
    );
    for (final part in parts) {
      await _requireUnstarted(txn, part['id'] as String);
    }
    await txn.delete(
      'strength_occurrence_parts',
      where: 'source_occurrence_id=?',
      whereArgs: [sourceId],
    );
    for (final part in parts) {
      final w = await txn.query(
        'workout_templates',
        where: 'id=?',
        whereArgs: [part['workout_id']],
      );
      if (w.isEmpty) continue;
      await txn.delete(
        'exercises_in_workouts',
        where: 'workoutId=?',
        whereArgs: [w.single['legacy_local_id']],
      );
      await txn.delete(
        'workouts',
        where: 'id=?',
        whereArgs: [w.single['legacy_local_id']],
      );
      await txn.delete(
        'workout_templates',
        where: 'id=?',
        whereArgs: [part['workout_id']],
      );
    }
  });

  Future<List<ProgramEntry>> weekEntries(
    TrainingProgram? p,
    DateTime from,
    DateTime to,
  ) async {
    final result = p == null ? <ProgramEntry>[] : await entries(p, from, to);
    final rows = await db.query(
      'activity_sessions',
      where: "status='completed' AND started_at_utc>=? AND started_at_utc<?",
      whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    for (final row in rows) {
      if (result.any((e) => e.sessionId == row['id'])) continue;
      result.add(
        ProgramEntry(
          id: row['id'] as String,
          sessionId: row['id'] as String,
          planId: p?.id ?? '',
          date: DateTime.fromMillisecondsSinceEpoch(
            row['started_at_utc'] as int,
          ),
          name: row['name_snapshot'] as String,
          kind:
              row['activity_type'] == 'strength'
                  ? 'strength'
                  : row['activity_type'] == 'mobility'
                  ? 'mobility'
                  : 'running',
          workoutId: row['workout_id'] as String?,
          completed: true,
        ),
      );
    }
    return result;
  }

  Future<AthleteRunningProfile> withRecentLoad(
    AthleteRunningProfile p,
    DateTime now,
  ) async {
    final from = DateTime(now.year, now.month, now.day - 28);
    final rows = await db.rawQuery(
      '''SELECT s.started_at_utc,s.ended_at_utc,d.snapshot_json,d.runtime_json FROM activity_sessions s
      JOIN cardio_session_details d ON d.session_id=s.id WHERE s.status='completed' AND s.activity_type='running' AND s.started_at_utc>=? AND s.started_at_utc<=?''',
      [from.millisecondsSinceEpoch, now.millisecondsSinceEpoch],
    );
    if (rows.isEmpty) return p;
    final weeks =
        rows
            .map(
              (r) =>
                  calendarDays(
                    DateTime.fromMillisecondsSinceEpoch(
                      r['started_at_utc'] as int,
                    ),
                    from,
                  ) ~/
                  7,
            )
            .toSet();
    // An incomplete import is not evidence of a whole month's training volume.
    if (weeks.length < 3) return p;
    final json = p.toJson();
    json['recentRunsPerWeek'] ??= (rows.length / 4).round().clamp(0, 7);
    final distances =
        rows
            .map((r) {
              final runtime =
                  r['runtime_json'] == null
                      ? <String, dynamic>{}
                      : _json(r['runtime_json']);
              return (runtime['distanceMeters'] as num?)?.toDouble() ?? 0;
            })
            .where((d) => d.isFinite && d > 0)
            .toList();
    if (distances.length == rows.length) {
      json['weeklyMeters'] = distances.fold<double>(0, (a, b) => a + b) / 4;
      if (p.longestMeters == 0) {
        json['longestMeters'] = distances.reduce((a, b) => a > b ? a : b);
      }
    }
    return AthleteRunningProfile.fromJson(json);
  }

  static Map<String, dynamic> _json(Object? value) =>
      Map<String, dynamic>.from(jsonDecode(value as String) as Map);
}
