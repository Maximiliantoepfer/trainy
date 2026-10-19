import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/cardio.dart';
import '../models/training_program.dart';
import '../services/cardio_training.dart';
import '../services/database_service.dart';
import '../services/training_program_schema.dart';
import '../utils/uuid_v4.dart';

class TrainingProgramRepository {
  TrainingProgramRepository({DatabaseService? database})
    : db = database ?? DatabaseService();
  final DatabaseService db;
  Future<void> initialize() => db.transaction(TrainingProgramSchema.migrate);
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
    bool activate = true,
  }) async {
    program.validate();
    await db.transaction((txn) async {
      final todayDate = DateTime.now();
      final today = DateTime(todayDate.year, todayDate.month, todayDate.day);
      final existing = await txn.query(
        'training_programs',
        where: 'id=?',
        whereArgs: [program.id],
      );
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
              next.cycleWeek != previous.cycleWeek;
          if (!changed) continue;
          if (index >= 0) slots.removeAt(index);
          slots.add(
            previous.until != null && previous.until!.isBefore(today)
                ? previous
                : previous.copyWith(
                  until: DateTime(today.year, today.month, today.day - 1),
                ),
          );
          if (next != null) {
            final newId = UuidV4.generate();
            slots.add(
              ProgramSlot(
                id: newId,
                weekday: next.weekday,
                label: next.label,
                workoutId: next.workoutId,
                kind: next.kind,
                cycleWeek: next.cycleWeek,
                from: today,
                until: next.until,
              ),
            );
            await txn.update(
              'plan_slot_overrides',
              {'slot_id': newId},
              where: 'plan_id=? AND slot_id=? AND original_date>=?',
              whereArgs: [program.id, previous.id, dateKey(today)],
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
        },
        where: 'id=?',
        whereArgs: [program.id],
      );
      await txn.insert('training_programs', {
        'id': program.id,
        'program_json': jsonEncode(program.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
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

  Future<void> activate(String id) =>
      db.transaction((txn) => _activate(txn, id));
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
    final result = <ProgramEntry>[];
    final overrides = await db.query(
      'plan_slot_overrides',
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
        date.weekday == s.weekday &&
        (s.from == null || !date.isBefore(s.from!)) &&
        (s.until == null || !date.isAfter(s.until!)) &&
        (s.cycleWeek == 0 ||
            (calendarDays(date, monday) ~/ 7) % 2 + 1 == s.cycleWeek);
    final consumedSessions = <Object?>{};
    ProgramEntry strength(ProgramSlot slot, DateTime original, DateTime date) {
      final match =
          sessions
              .where(
                (r) =>
                    !consumedSessions.contains(r['id']) &&
                    slot.workoutId != null &&
                    r['workout_id'] == slot.workoutId &&
                    dateKey(
                          DateTime.fromMillisecondsSinceEpoch(
                            r['started_at_utc'] as int,
                          ),
                        ) ==
                        dateKey(date),
              )
              .firstOrNull;
      if (match != null) consumedSessions.add(match['id']);
      return ProgramEntry(
        id: '${slot.id}:${dateKey(original)}',
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
        completed: match != null,
      );
    }

    for (
      var date = from;
      date.isBefore(to);
      date = DateTime(date.year, date.month, date.day + 1)
    ) {
      for (final slot in p.slots.where((s) => occurs(s, date))) {
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
      if (slot != null && !date.isBefore(from) && date.isBefore(to)) {
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
      result.add(
        ProgramEntry(
          id: o.id,
          planId: p.id,
          date: o.date,
          name: o.workout.name,
          kind: 'running',
          cardio: o,
          completed: o.status == 'completed',
        ),
      );
    }
    result.sort((a, b) {
      final d = a.date.compareTo(b.date);
      return d == 0 ? a.id.compareTo(b.id) : d;
    });
    return result;
  }

  Future<void> moveStrength(
    TrainingProgram p,
    ProgramEntry entry,
    DateTime date, {
    required bool future,
  }) async {
    if (entry.completed || entry.slotId == null) {
      throw StateError('Completed or invalid entry');
    }
    final original = entry.originalDate!;
    await db.transaction((txn) async {
      if (future) {
        final old = p.slots.firstWhere((s) => s.id == entry.slotId);
        // Split the recurrence instead of retroactively moving historical sessions.
        final slots = [
          for (final s in p.slots)
            s.id == old.id
                ? s.copyWith(
                  until: DateTime(
                    original.year,
                    original.month,
                    original.day - 1,
                  ),
                )
                : s,
          ProgramSlot(
            weekday: date.weekday,
            label: old.label,
            workoutId: old.workoutId,
            kind: old.kind,
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
      } else {
        await txn.insert('plan_slot_overrides', {
          'plan_id': p.id,
          'slot_id': entry.slotId,
          'original_date': dateKey(original),
          'local_date': dateKey(date),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
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
