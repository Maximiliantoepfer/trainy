import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../services/running_fitness.dart';
import '../services/running_forecast.dart';
import '../services/running_rules.dart';
import 'package:sqflite/sqflite.dart';
import '../models/cardio.dart';
import '../models/cardio_recording.dart';
import '../services/cardio_training.dart';
import '../services/database_service.dart';
import '../services/profile_readiness.dart';
import '../utils/uuid_v4.dart';

class CardioRepository {
  CardioRepository({DatabaseService? database})
    : db = database ?? DatabaseService();
  final DatabaseService db;
  Future<AthleteRunningProfile> profile() async {
    final rows = await db.query('cardio_preferences');
    final user = await db.query('user_training_profile');
    return AthleteRunningProfile.fromJson({
      if (rows.isNotEmpty)
        ...Map<String, dynamic>.from(
          jsonDecode(rows.single['profile_json'] as String) as Map,
        ),
      if (user.isNotEmpty)
        ...Map<String, dynamic>.from(
          jsonDecode(user.single['profile_json'] as String) as Map,
        ),
    });
  }

  Future<void> saveProfile(AthleteRunningProfile profile) async {
    profile.validate();
    await db.transaction((txn) async {
      final json = profile.toJson();
      final rows = await txn.query('user_training_profile');
      final user =
          rows.isEmpty
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(
                jsonDecode(rows.single['profile_json'] as String) as Map,
              );
      for (final key in [
        'units',
        'interests',
        'backupSensorData',
        'healthEnabled',
      ]) {
        user[key] = json.remove(key);
      }
      await txn.insert('user_training_profile', {
        'id': 0,
        'profile_json': jsonEncode(user),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('cardio_preferences', {
        'id': 0,
        'profile_json': jsonEncode(json),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<CardioWorkout>> workouts() async =>
      (await db.query('cardio_workouts', orderBy: 'updated_at_utc DESC'))
          .map(
            (r) => CardioWorkout.fromJson(
              jsonDecode(r['workout_json'] as String) as Map<String, dynamic>,
            ),
          )
          .toList();
  Future<void> saveWorkout(CardioWorkout workout) async {
    workout.validate();
    await db.transaction((txn) async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      if ((await txn.query(
        'workout_templates',
        where: 'id = ?',
        whereArgs: [workout.id],
      )).isEmpty) {
        await txn.insert('workout_templates', {
          'id': workout.id,
          'name': workout.name,
          'primary_goal_code': 'cardio',
          'created_at_utc': now,
          'updated_at_utc': now,
        });
        await txn.insert('workout_tags', {
          'workout_id': workout.id,
          'tag_code': 'cardio',
          'position': 0,
        });
      } else {
        await txn.update(
          'workout_templates',
          {'name': workout.name, 'updated_at_utc': now},
          where: 'id = ?',
          whereArgs: [workout.id],
        );
      }
      await txn.insert('cardio_workouts', {
        'id': workout.id,
        'workout_json': jsonEncode(workout.toJson()),
        'updated_at_utc': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> deleteWorkout(String id) async {
    await db.delete('cardio_workouts', where: 'id = ?', whereArgs: [id]);
    await db.update(
      'workout_templates',
      {'is_archived': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> savePlan(RunningPlanProposal proposal, String name) async =>
      db.transaction((txn) async {
        final profiles = await txn.query('cardio_preferences');
        ProfileReadiness.requireRunning(
          AthleteRunningProfile.fromJson(
            profiles.isEmpty
                ? {}
                : Map<String, dynamic>.from(
                  jsonDecode(profiles.single['profile_json'] as String) as Map,
                ),
          ),
        );
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        await txn.insert('training_plans', {
          'id': proposal.id,
          'name': name,
          'source_type': 'generated',
          'status': 'active',
          'starts_at_utc':
              proposal.request.startDate.toUtc().millisecondsSinceEpoch,
          'created_at_utc': now,
          'updated_at_utc': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await txn.insert('cardio_plans', {
          'id': proposal.id,
          'request_json': jsonEncode(proposal.request.toJson()),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        for (final o in proposal.occurrences) {
          await txn.insert('cardio_occurrences', {
            'id': o.id,
            'plan_id': o.planId,
            'local_date': dateKey(o.date),
            'workout_json': jsonEncode(o.workout.toJson()),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      });
  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static Future<Map<String, String>> _startedOccurrences(
    DatabaseExecutor txn,
  ) async {
    final started = <String, String>{};
    for (final row in await txn.rawQuery('''SELECT d.session_id, d.snapshot_json
      FROM cardio_session_details d JOIN activity_sessions s ON s.id=d.session_id
      WHERE s.status='active' ''')) {
      final id =
          (jsonDecode(row['snapshot_json'] as String) as Map)['occurrenceId'];
      if (id is String) started[id] = row['session_id'] as String;
    }
    return started;
  }

  Future<List<ScheduledCardioWorkout>> occurrences() => db.transaction((
    txn,
  ) async {
    // Older active sessions did not set the occurrence link until completion.
    final started = await _startedOccurrences(txn);
    return (await txn.query('cardio_occurrences', orderBy: 'local_date, id'))
        .map(
          (r) => ScheduledCardioWorkout(
            id: r['id'] as String,
            planId: r['plan_id'] as String,
            date: DateTime.parse(r['local_date'] as String),
            workout: CardioWorkout.fromJson(
              jsonDecode(r['workout_json'] as String) as Map<String, dynamic>,
            ),
            status: r['status'] as String,
            locked: r['locked'] == 1,
            sessionId: r['session_id'] as String? ?? started[r['id']],
          ),
        )
        .toList();
  });
  Future<void> move(
    ScheduledCardioWorkout occurrence,
    DateTime date, {
    bool future = false,
  }) async {
    final offset =
        DateTime.utc(date.year, date.month, date.day)
            .difference(
              DateTime.utc(
                occurrence.date.year,
                occurrence.date.month,
                occurrence.date.day,
              ),
            )
            .inDays;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'cardio_occurrences',
        where:
            future
                ? "plan_id = ? AND local_date >= ? AND status = 'planned' AND session_id IS NULL AND (locked = 0 OR id = ?)"
                : "id = ? AND status = 'planned' AND session_id IS NULL",
        whereArgs:
            future
                ? [occurrence.planId, dateKey(occurrence.date), occurrence.id]
                : [occurrence.id],
      );
      if (!rows.any((r) => r['id'] == occurrence.id)) {
        throw StateError('Protected or unavailable occurrence');
      }
      for (final row in rows) {
        final old = DateTime.parse(row['local_date'] as String);
        if (future &&
            old.weekday != occurrence.date.weekday &&
            row['id'] != occurrence.id) {
          continue;
        }
        await txn.insert('cardio_occurrence_origins', {
          'occurrence_id': row['id'],
          'original_date': row['local_date'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await txn.update(
          'cardio_occurrences',
          {
            'local_date': dateKey(
              DateTime(old.year, old.month, old.day + offset),
            ),
            'locked': 1,
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
      if (future) {
        final programs = await txn.query(
          'training_programs',
          where: 'id=?',
          whereArgs: [occurrence.planId],
        );
        if (programs.isNotEmpty) {
          final data =
              jsonDecode(programs.single['program_json'] as String)
                  as Map<String, dynamic>;
          data['runningDays'] =
              (List<int>.from(data['runningDays'] as List)
                  .map((d) => d == occurrence.date.weekday ? date.weekday : d)
                  .toSet()
                  .toList()
                ..sort());
          await txn.update(
            'training_programs',
            {'program_json': jsonEncode(data)},
            where: 'id=?',
            whereArgs: [occurrence.planId],
          );
        }
      }
    });
  }

  Future<void> editOccurrence(
    ScheduledCardioWorkout occurrence,
    CardioWorkout workout,
  ) async {
    workout.validate();
    if (workout.sport != occurrence.workout.sport) {
      throw StateError('Replacement must keep the sport');
    }
    await db.transaction((txn) async {
      final rows = await txn.query(
        'cardio_occurrences',
        where: "id=? AND plan_id=? AND status='planned' AND session_id IS NULL",
        whereArgs: [occurrence.id, occurrence.planId],
      );
      if (rows.length != 1) {
        throw StateError('Protected or unavailable occurrence');
      }
      final saved = CardioWorkout.fromJson(
        jsonDecode(rows.single['workout_json'] as String)
            as Map<String, dynamic>,
      );
      if (saved.sport != workout.sport) {
        throw StateError('Replacement must keep the sport');
      }
      await txn.update(
        'cardio_occurrences',
        {'workout_json': jsonEncode(workout.toJson()), 'locked': 1},
        where: 'id=?',
        whereArgs: [occurrence.id],
      );
    });
  }

  Future<void> skipOccurrence(String id) async {
    await db.update(
      'cardio_occurrences',
      {'status': 'skipped'},
      where: "id = ? AND status = 'planned'",
      whereArgs: [id],
    );
  }

  Future<void> applyAdjustment(
    Map<String, CardioWorkout> changes,
  ) async => db.transaction((txn) async {
    for (final entry in changes.entries) {
      entry.value.validate();
      await txn.update(
        'cardio_occurrences',
        {'workout_json': jsonEncode(entry.value.toJson())},
        where:
            "id = ? AND status = 'planned' AND locked = 0 AND session_id IS NULL AND local_date >= ?",
        whereArgs: [entry.key, dateKey(DateTime.now())],
      );
    }
  });

  Future<RunningFitnessSnapshot> fitness({DateTime? now}) async {
    final p = await profile();
    final stages =
        p.planning.adaptationHistory
            .where((e) => e['runWalkStage'] != null)
            .toList();
    return RunningFitness().evaluate(
      await history(),
      now ?? DateTime.now(),
      runWalkStage: p.planning.runWalkStage,
      stageSince:
          stages.isEmpty
              ? null
              : DateTime.tryParse(stages.last['createdAt'] as String? ?? ''),
    );
  }

  Future<RunningAdaptationProposal> adaptation(
    CardioTranslate t, {
    DateTime? now,
  }) async {
    final fingerprint = await db.transaction(_adaptationFingerprint);
    final p = await profile();
    ProfileReadiness.requireRunning(p, now: now);
    final planRows = await db.rawQuery(
      '''SELECT c.id, c.request_json FROM cardio_plans c
      JOIN training_plans t ON t.id=c.id WHERE t.status='active' ''',
    );
    final requests = {
      for (final r in planRows)
        r['id'] as String: RunningPlanRequest.fromJson(
          jsonDecode(r['request_json'] as String) as Map<String, dynamic>,
        ),
    };
    final planned =
        (await occurrences())
            .where((o) => requests.containsKey(o.planId))
            .toList();
    final fit = await fitness(now: now);
    var proposal = RunningFitness().propose(p, fit, planned, t);
    if (proposal.changes.isEmpty && !fit.difficult) {
      final structure = RunningForecast().suggestStructure(
        p,
        fit,
        planned,
        requests,
        t,
      );
      if (structure.isNotEmpty) {
        proposal = RunningAdaptationProposal(
          createdAt: fit.asOf,
          ruleVersion: RunningRules.bundled.version,
          fitness: fit,
          changes: structure,
          reason: 'structure',
        );
      }
    }
    if (fingerprint != await db.transaction(_adaptationFingerprint)) {
      throw StateError('stale_proposal');
    }
    return RunningAdaptationProposal(
      createdAt: proposal.createdAt,
      ruleVersion: proposal.ruleVersion,
      fitness: fit,
      changes: proposal.changes,
      reason: proposal.reason,
      easySpeed: proposal.easySpeed,
      runWalkStage: proposal.runWalkStage,
      walkPreparation: proposal.walkPreparation,
      inputFingerprint: fingerprint,
      originals: {
        for (final o in planned.where(
          (o) => proposal.changes.containsKey(o.id),
        ))
          o.id: jsonEncode(o.workout.toJson()),
      },
      expectedDates: {
        for (final o in planned.where(
          (o) => proposal.changes.containsKey(o.id),
        ))
          o.id: dateKey(o.date),
      },
    );
  }

  static Future<String> _adaptationFingerprint(DatabaseExecutor txn) async {
    final profile = await txn.query('cardio_preferences');
    final sessions = await txn.rawQuery(
      '''SELECT s.id, d.snapshot_json, d.runtime_json
      FROM activity_sessions s JOIN cardio_session_details d ON s.id=d.session_id
      WHERE s.status='completed' ORDER BY s.id''',
    );
    final plans = await txn.rawQuery(
      '''SELECT t.id, t.status, c.request_json FROM training_plans t
      JOIN cardio_plans c ON c.id=t.id ORDER BY t.id''',
    );
    final calendar = await txn.query('cardio_occurrences', orderBy: 'id');
    final programs = await txn.query('training_programs', orderBy: 'id');
    final started = await _startedOccurrences(txn);
    return sha256
        .convert(
          utf8.encode(
            jsonEncode([profile, sessions, plans, calendar, programs, started]),
          ),
        )
        .toString();
  }

  Future<void> dismissAdaptation(RunningAdaptationProposal proposal) async {
    await db.transaction((txn) async {
      final rows = await txn.query('cardio_preferences');
      if (rows.isEmpty) return;
      final json =
          jsonDecode(rows.single['profile_json'] as String)
              as Map<String, dynamic>;
      final planning = Map<String, dynamic>.from(
        json['planning'] as Map? ?? {},
      );
      planning['dismissedAdaptations'] =
          {
            ...List<String>.from(
              planning['dismissedAdaptations'] as List? ?? [],
            ),
            proposal.evidenceKey,
          }.toList();
      json['planning'] = planning;
      await txn.update('cardio_preferences', {
        'profile_json': jsonEncode(json),
      }, where: 'id=0');
    });
  }

  /// One transaction: protected rows are rechecked at acceptance time, and the
  /// applied rule/evidence are saved with the profile for backup and audit.
  Future<void> acceptAdaptation(RunningAdaptationProposal proposal) async {
    if (proposal.changes.isEmpty) return;
    await db.transaction((txn) async {
      final rows = await txn.query('cardio_preferences');
      if (rows.isEmpty) throw StateError('missing_profile');
      final json =
          jsonDecode(rows.single['profile_json'] as String)
              as Map<String, dynamic>;
      final p = AthleteRunningProfile.fromJson(json);
      ProfileReadiness.requireRunning(p);
      final history = [...p.planning.adaptationHistory];
      final key = proposal.createdAt.toIso8601String();
      if (history.any((e) => e['createdAt'] == key)) return;
      if (proposal.inputFingerprint != null &&
          proposal.inputFingerprint != await _adaptationFingerprint(txn)) {
        throw StateError('stale_proposal');
      }
      if (proposal.easySpeed != null &&
          p.planning.paceUpdatedAt != null &&
          proposal.createdAt.difference(p.planning.paceUpdatedAt!).inDays < 7) {
        throw StateError('stale_proposal');
      }
      var changed = 0;
      final started = await _startedOccurrences(txn);
      for (final e in proposal.changes.entries) {
        if (started.containsKey(e.key)) {
          if (proposal.inputFingerprint != null) {
            throw StateError('stale_proposal');
          }
          continue;
        }
        final current = await txn.query(
          'cardio_occurrences',
          where:
              "id=? AND status='planned' AND locked=0 AND session_id IS NULL AND local_date>=?",
          whereArgs: [e.key, dateKey(DateTime.now())],
        );
        if (current.isEmpty) {
          if (proposal.inputFingerprint != null) {
            throw StateError('stale_proposal');
          }
          continue;
        }
        final old = CardioWorkout.fromJson(
          jsonDecode(current.single['workout_json'] as String)
              as Map<String, dynamic>,
        );
        if (proposal.originals[e.key] != null &&
            (proposal.originals[e.key] != jsonEncode(old.toJson()) ||
                proposal.expectedDates[e.key] !=
                    current.single['local_date'])) {
          throw StateError('stale_proposal');
        }
        final updated = e.value;
        if (old.sport != updated.sport) throw StateError('sport_changed');
        for (final manual in old.steps.where(
          (s) => s.targetSource == 'manual',
        )) {
          final replacement =
              updated.steps.where((s) => s.id == manual.id).firstOrNull;
          if (replacement == null ||
              jsonEncode(manual.toJson()) != jsonEncode(replacement.toJson())) {
            throw StateError('manual_target_changed');
          }
        }
        updated.validate();
        changed += await txn.update(
          'cardio_occurrences',
          {'workout_json': jsonEncode(updated.toJson())},
          where: 'id=?',
          whereArgs: [e.key],
        );
      }
      if (changed == 0) return;
      history.add(proposal.toJson());
      json['planning'] = {
        ...p.planning.toJson(),
        if (proposal.easySpeed != null) ...{
          'easySpeed': proposal.easySpeed,
          'paceUpdatedAt': key,
        },
        if (proposal.runWalkStage != null)
          'runWalkStage': proposal.runWalkStage,
        if (proposal.walkPreparation != null)
          'walkPreparation': proposal.walkPreparation,
        'adaptationHistory': history,
      };
      AthleteRunningProfile.fromJson(json).validate();
      await txn.update('cardio_preferences', {
        'profile_json': jsonEncode(json),
      }, where: 'id=0');
    });
  }

  Future<Map<String, CardioWorkout>> targetAdjustment(
    AthleteRunningProfile profile,
  ) async {
    final changes = <String, CardioWorkout>{};
    for (final occurrence in await occurrences()) {
      if (occurrence.status != 'planned' ||
          occurrence.locked ||
          occurrence.sessionId != null ||
          dateKey(occurrence.date).compareTo(dateKey(DateTime.now())) < 0) {
        continue;
      }
      final workout = occurrence.workout;
      if (!workout.steps.any((s) => s.targetSource != 'manual')) continue;
      changes[occurrence.id] = CardioWorkout.fromJson({
        ...workout.toJson(),
        'steps': [
          for (final step in workout.steps)
            CardioTraining.refreshTarget(
              step,
              profile,
              sport: workout.sport,
            ).toJson(),
        ],
      });
    }
    return changes;
  }

  Future<String> begin(CardioWorkout workout, {String? occurrenceId}) async {
    workout.validate();
    final sessionId = UuidV4.generate();
    await db.transaction((txn) async {
      final active = await txn.query(
        'activity_sessions',
        where: "status = 'active'",
        limit: 1,
      );
      if (active.isNotEmpty) throw StateError('active_session');
      final now = DateTime.now();
      await txn.insert('activity_sessions', {
        'id': sessionId,
        'activity_type': activityType(workout.sport),
        'status': 'active',
        'source': 'manual',
        'name_snapshot': workout.name,
        'started_at_utc': now.toUtc().millisecondsSinceEpoch,
        'timezone_offset_minutes': now.timeZoneOffset.inMinutes,
        'created_at_utc': now.toUtc().millisecondsSinceEpoch,
      });
      await txn.insert('activity_session_tags', {
        'session_id': sessionId,
        'tag_code': 'cardio',
        'position': 0,
      });
      await txn.insert('cardio_session_details', {
        'session_id': sessionId,
        'snapshot_json': jsonEncode({
          'workout': workout.toJson(),
          'occurrenceId': occurrenceId,
        }),
      });
      if (occurrenceId != null) {
        final linked = await txn.update(
          'cardio_occurrences',
          {'session_id': sessionId},
          where: "id=? AND status='planned' AND session_id IS NULL",
          whereArgs: [occurrenceId],
        );
        if (linked != 1) throw StateError('occurrence_already_started');
      }
    });
    return sessionId;
  }

  static String activityType(CardioSport sport) => switch (sport) {
    CardioSport.running => 'running',
    CardioSport.walking => 'walking',
    CardioSport.cycling => 'cycling',
    _ => 'cardio',
  };
  Future<void> cancelStart(String id) async {
    await db.transaction((txn) async {
      final changed = await txn.update(
        'activity_sessions',
        {'status': 'discarded'},
        where: "id = ? AND status = 'active'",
        whereArgs: [id],
      );
      if (changed > 0) {
        await txn.update(
          'cardio_occurrences',
          {'session_id': null},
          where: "session_id=? AND status='planned'",
          whereArgs: [id],
        );
      }
    });
  }

  Future<void> saveRuntime(Map<String, dynamic> runtime) async {
    final id = runtime['sessionId'] as String;
    await db.transaction((txn) async {
      final details = await txn.query(
        'cardio_session_details',
        where: 'session_id = ?',
        whereArgs: [id],
      );
      if (details.isEmpty) throw StateError('Unknown cardio session');
      await txn.update(
        'cardio_session_details',
        {'runtime_json': jsonEncode(runtime)},
        where: 'session_id = ?',
        whereArgs: [id],
      );
      if (runtime['status'] != 'completed') return;
      final completedAt =
          (runtime['endedAt'] as num?)?.toInt() ??
          DateTime.now().toUtc().millisecondsSinceEpoch;
      await txn.update(
        'activity_sessions',
        {'status': 'completed', 'ended_at_utc': completedAt},
        where: 'id = ?',
        whereArgs: [id],
      );
      final snapshot =
          jsonDecode(details.single['snapshot_json'] as String)
              as Map<String, dynamic>;
      if (snapshot['occurrenceId'] != null) {
        await txn.update(
          'cardio_occurrences',
          {'status': 'completed', 'session_id': id},
          where: 'id = ?',
          whereArgs: [snapshot['occurrenceId']],
        );
      }
      await txn.delete(
        'activity_metric_values',
        where: 'session_id = ? AND activity_item_id IS NULL',
        whereArgs: [id],
      );
      for (final metric in [
        ('duration', 'activeSeconds', 'second'),
        ('distance', 'distanceMeters', 'meter'),
      ]) {
        final value = (runtime[metric.$2] as num?)?.toDouble() ?? 0;
        if (metric.$1 == 'distance' && runtime['indoor'] == true) continue;
        await txn.insert('activity_metric_values', {
          'id': '$id:${metric.$1}',
          'session_id': id,
          'metric_code': metric.$1,
          'canonical_value': value,
          'entered_value': value,
          'entered_unit_code': metric.$3,
          'source': 'manual',
          'recorded_at_utc': completedAt,
        });
      }
      for (final raw in runtime['results'] as List? ?? []) {
        final result = Map<String, dynamic>.from(raw as Map);
        final itemId = '$id:${result['id']}';
        await txn.insert('activity_items', {
          'id': itemId,
          'session_id': id,
          'display_name_snapshot': result['name'] ?? '',
          'sort_order': result['index'] ?? 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await txn.insert('activity_efforts', {
          'id': '$itemId:effort',
          'activity_item_id': itemId,
          'effort_type': 'interval',
          'sort_order': 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        for (final metric in [
          ('duration', 'seconds', 'second'),
          ('distance', 'meters', 'meter'),
        ]) {
          if (metric.$1 == 'distance' && runtime['indoor'] == true) continue;
          final value = (result[metric.$2] as num?)?.toDouble() ?? 0;
          await txn.insert('activity_metric_values', {
            'id': '$itemId:${metric.$1}',
            'session_id': id,
            'activity_item_id': itemId,
            'effort_id': '$itemId:effort',
            'metric_code': metric.$1,
            'canonical_value': value,
            'entered_value': value,
            'entered_unit_code': metric.$3,
            'source': 'manual',
            'recorded_at_utc': completedAt,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<void> saveSamples(
    String sessionId,
    List<Map<String, dynamic>> samples,
  ) async => db.transaction((txn) async {
    for (final s in samples) {
      await txn.insert('cardio_sensor_samples', {
        'session_id': sessionId,
        'sequence': s['sequence'],
        'sample_json': jsonEncode(s),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  });
  Future<List<Map<String, Object?>>> history() =>
      db.rawQuery('''SELECT s.*, d.snapshot_json, d.runtime_json
    FROM activity_sessions s JOIN cardio_session_details d ON s.id = d.session_id
    WHERE s.status = 'completed' ORDER BY s.started_at_utc DESC''');
  Future<List<Map<String, Object?>>> recoverable() => db.rawQuery(
    '''SELECT s.id, d.runtime_json
    FROM activity_sessions s JOIN cardio_session_details d ON s.id = d.session_id WHERE s.status = 'active' ''',
  );
  Future<List<Map<String, dynamic>>> route(
    String id, {
    String? recordingId,
  }) async {
    String? legacyHealthId;
    if (recordingId != 'phone') {
      final details = await db.query(
        'cardio_session_details',
        where: 'session_id = ?',
        whereArgs: [id],
      );
      if (details.isNotEmpty) {
        final snapshot =
            jsonDecode(details.single['snapshot_json'] as String)
                as Map<String, dynamic>;
        recordingId ??=
            CardioRecording.preferred(
              snapshot,
              jsonDecode(details.single['runtime_json'] as String)
                  as Map<String, dynamic>,
            )?.id;
        final health = snapshot['health'] as Map?;
        if (health != null) {
          legacyHealthId =
              '${health['provider']}:${health['sourceId']}:${health['externalId']}';
        }
      }
    }
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM cardio_sensor_samples WHERE session_id = ?',
            [id],
          ),
        ) ??
        0;
    final stride = (count / 1000).ceil().clamp(1, 1000000);
    final result = <Map<String, dynamic>>[];
    Map<String, dynamic>? previous;
    var cursor = -1, segment = 0, index = 0;
    void keep(Map<String, dynamic> point) {
      if (result.isEmpty || result.last['sequence'] != point['sequence']) {
        result.add(point);
      }
    }

    while (true) {
      final rows = await db.rawQuery(
        'SELECT sequence,sample_json FROM cardio_sensor_samples WHERE session_id=? AND sequence>? ORDER BY sequence LIMIT 500',
        [id, cursor],
      );
      if (rows.isEmpty) break;
      for (final row in rows) {
        cursor = row['sequence'] as int;
        final point =
            jsonDecode(row['sample_json'] as String) as Map<String, dynamic>;
        if (recordingId != null &&
            (point['recordingId'] ??
                    (point['source'] == null || point['source'] == 'phone_gps'
                        ? 'phone'
                        : legacyHealthId)) !=
                recordingId) {
          continue;
        }
        final lat = point['latitude'] as num?, lon = point['longitude'] as num?;
        final time = point['timestamp'] as num?;
        if (point['active'] == false ||
            lat == null ||
            lon == null ||
            !lat.isFinite ||
            !lon.isFinite ||
            lat.abs() > 90 ||
            lon.abs() > 180 ||
            time == null) {
          if (previous != null) keep(previous);
          previous = null;
          segment++;
          continue;
        }
        final gap =
            point['gap'] == true ||
            previous == null ||
            time - (previous['timestamp'] as num) > 15000;
        if (gap) {
          if (previous != null) keep(previous);
          segment++;
        }
        point['routeSegment'] = segment;
        point['sequence'] = cursor;
        if (gap || index++ % stride == 0) keep(point);
        previous = point;
      }
    }
    if (previous != null) keep(previous);
    return result;
  }

  Future<void> feedback(
    String id,
    int effort,
    bool discomfort, {
    bool? talkComfort,
    String? recovery,
    String environment = 'unknown',
    String? runType,
    bool? continuous,
  }) async {
    if (effort < 1 ||
        effort > 10 ||
        (recovery != null && !['ready', 'tired', 'poor'].contains(recovery))) {
      throw const FormatException('Invalid feedback');
    }
    final rows = await db.query(
      'cardio_session_details',
      where: 'session_id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return;
    final value =
        jsonDecode(rows.single['snapshot_json'] as String)
            as Map<String, dynamic>;
    value['feedback'] =
        RunFeedback(
          effort: effort,
          discomfort: discomfort,
          talkComfort: talkComfort,
          recovery: recovery,
          environment: environment,
          runType: runType,
          continuous: continuous,
        ).toJson();
    await db.update(
      'cardio_session_details',
      {'snapshot_json': jsonEncode(value)},
      where: 'session_id = ?',
      whereArgs: [id],
    );
  }
}
