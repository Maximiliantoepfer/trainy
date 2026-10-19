import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/cardio.dart';
import '../services/cardio_training.dart';
import '../services/database_service.dart';
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
  Future<List<ScheduledCardioWorkout>> occurrences() async =>
      (await db.query('cardio_occurrences', orderBy: 'local_date, id'))
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
              sessionId: r['session_id'] as String?,
            ),
          )
          .toList();
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
                ? "plan_id = ? AND local_date >= ? AND status = 'planned' AND (locked = 0 OR id = ?)"
                : "id = ? AND status = 'planned'",
        whereArgs:
            future
                ? [occurrence.planId, dateKey(occurrence.date), occurrence.id]
                : [occurrence.id],
      );
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
    await db.update(
      'cardio_occurrences',
      {'workout_json': jsonEncode(workout.toJson()), 'locked': 1},
      where: "id = ? AND status = 'planned'",
      whereArgs: [occurrence.id],
    );
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
            "id = ? AND status = 'planned' AND locked = 0 AND local_date >= ?",
        whereArgs: [entry.key, dateKey(DateTime.now())],
      );
    }
  });

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
    await db.update(
      'activity_sessions',
      {'status': 'discarded'},
      where: "id = ? AND status = 'active'",
      whereArgs: [id],
    );
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
  Future<List<Map<String, dynamic>>> route(String id) async {
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM cardio_sensor_samples WHERE session_id = ?',
            [id],
          ),
        ) ??
        0;
    final stride = (count / 1000).ceil().clamp(1, 1000000);
    return (await db.rawQuery(
          'SELECT sample_json FROM cardio_sensor_samples WHERE session_id = ? AND sequence % ? = 0 ORDER BY sequence LIMIT 1001',
          [id, stride],
        ))
        .map(
          (r) => jsonDecode(r['sample_json'] as String) as Map<String, dynamic>,
        )
        .toList();
  }

  Future<void> feedback(String id, int effort, bool discomfort) async {
    final rows = await db.query(
      'cardio_session_details',
      where: 'session_id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return;
    final value =
        jsonDecode(rows.single['snapshot_json'] as String)
            as Map<String, dynamic>;
    value['feedback'] = {'rpe': effort, 'discomfort': discomfort};
    await db.update(
      'cardio_session_details',
      {'snapshot_json': jsonEncode(value)},
      where: 'session_id = ?',
      whereArgs: [id],
    );
  }
}
