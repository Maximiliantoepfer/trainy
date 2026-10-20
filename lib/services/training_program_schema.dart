import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/training_program.dart';
import '../utils/uuid_v4.dart';

abstract final class TrainingProgramSchema {
  static const tables = [
    'strength_session_links',
    'strength_occurrence_parts',
    'workout_slot_prescriptions',
    'cardio_occurrence_origins',
    'plan_slot_overrides',
    'active_training_plan',
    'training_programs',
    'setup_drafts',
    'user_training_profile',
  ];
  static Future<void> create(DatabaseExecutor db) async {
    for (final sql in [
      '''CREATE TABLE IF NOT EXISTS workout_slot_prescriptions(slot_id TEXT PRIMARY KEY,
        sets INTEGER NOT NULL CHECK(sets>0), min_reps INTEGER NOT NULL CHECK(min_reps>0),
        max_reps INTEGER NOT NULL CHECK(max_reps>=min_reps),
        FOREIGN KEY(slot_id) REFERENCES workout_slots_v2(id) ON DELETE CASCADE)''',
      '''CREATE TABLE IF NOT EXISTS strength_occurrence_parts(id TEXT PRIMARY KEY, plan_id TEXT NOT NULL,
        source_occurrence_id TEXT NOT NULL, slot_id TEXT NOT NULL, original_date TEXT NOT NULL,
        local_date TEXT NOT NULL, workout_id TEXT NOT NULL,
        FOREIGN KEY(plan_id) REFERENCES training_plans(id) ON DELETE CASCADE,
        FOREIGN KEY(workout_id) REFERENCES workout_templates(id))''',
      '''CREATE TABLE IF NOT EXISTS strength_session_links(occurrence_id TEXT PRIMARY KEY,
        plan_id TEXT NOT NULL, session_id TEXT NOT NULL UNIQUE,
        FOREIGN KEY(plan_id) REFERENCES training_plans(id) ON DELETE CASCADE,
        FOREIGN KEY(session_id) REFERENCES activity_sessions(id) ON DELETE CASCADE)''',
      '''CREATE TABLE IF NOT EXISTS cardio_occurrence_origins(occurrence_id TEXT PRIMARY KEY,
        original_date TEXT NOT NULL, FOREIGN KEY(occurrence_id) REFERENCES cardio_occurrences(id) ON DELETE CASCADE)''',
      'CREATE TABLE IF NOT EXISTS user_training_profile(id INTEGER PRIMARY KEY CHECK(id=0), profile_json TEXT NOT NULL)',
      'CREATE TABLE IF NOT EXISTS setup_drafts(id TEXT PRIMARY KEY, payload_json TEXT NOT NULL)',
      'CREATE TABLE IF NOT EXISTS training_programs(id TEXT PRIMARY KEY, program_json TEXT NOT NULL, FOREIGN KEY(id) REFERENCES training_plans(id) ON DELETE CASCADE)',
      'CREATE TABLE IF NOT EXISTS active_training_plan(id INTEGER PRIMARY KEY CHECK(id=0), plan_id TEXT, FOREIGN KEY(plan_id) REFERENCES training_plans(id) ON DELETE SET NULL)',
      '''CREATE TABLE IF NOT EXISTS plan_slot_overrides(plan_id TEXT NOT NULL, slot_id TEXT NOT NULL,
        original_date TEXT NOT NULL, local_date TEXT NOT NULL, PRIMARY KEY(plan_id,slot_id,original_date),
        FOREIGN KEY(plan_id) REFERENCES training_plans(id) ON DELETE CASCADE)''',
      'CREATE INDEX IF NOT EXISTS idx_active_training_plan_id ON active_training_plan(plan_id)',
      'CREATE INDEX IF NOT EXISTS idx_strength_parts_plan ON strength_occurrence_parts(plan_id,local_date)',
      'CREATE INDEX IF NOT EXISTS idx_strength_parts_workout ON strength_occurrence_parts(workout_id)',
      'CREATE INDEX IF NOT EXISTS idx_strength_links_plan ON strength_session_links(plan_id)',
    ]) {
      await db.execute(sql);
    }
    final overrideColumns =
        (await db.rawQuery(
          'PRAGMA table_info(plan_slot_overrides)',
        )).map((r) => r['name']).toSet();
    if (!overrideColumns.contains('workout_id')) {
      await db.execute(
        'ALTER TABLE plan_slot_overrides ADD COLUMN workout_id TEXT',
      );
    }
    final columns =
        (await db.rawQuery(
          'PRAGMA table_info(workout_slot_prescriptions)',
        )).map((r) => r['name']).toSet();
    if (!columns.contains('rest_seconds')) {
      await db.execute(
        'ALTER TABLE workout_slot_prescriptions ADD COLUMN rest_seconds INTEGER NOT NULL DEFAULT 90',
      );
    }
    if (!columns.contains('source')) {
      await db.execute(
        "ALTER TABLE workout_slot_prescriptions ADD COLUMN source TEXT NOT NULL DEFAULT 'manual'",
      );
    }
    if (!columns.contains('duration_seconds')) {
      await db.execute(
        'ALTER TABLE workout_slot_prescriptions ADD COLUMN duration_seconds INTEGER CHECK(duration_seconds BETWEEN 1 AND 3600)',
      );
    }
  }

  /// Idempotent, also used in the staging database after restoring older backups.
  static Future<void> migrate(DatabaseExecutor db) async {
    await create(db);
    if ((await db.query('user_training_profile')).isEmpty) {
      final old = await db.query('cardio_preferences');
      final data =
          old.isEmpty
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(
                jsonDecode(old.first['profile_json'] as String) as Map,
              );
      await db.insert('user_training_profile', {
        'id': 0,
        'profile_json': jsonEncode(UserTrainingProfile.fromJson(data).toJson()),
      });
    }
    if ((await db.query('active_training_plan')).isNotEmpty) return;
    final plans = await db.query('training_plans', orderBy: 'created_at_utc');
    final weekly = await db.rawQuery(
      '''SELECT s.*, w.name FROM workout_weekly_schedule s
      JOIN workout_templates w ON s.workout_id=w.id WHERE w.is_archived=0 ORDER BY s.weekday,s.sort_order''',
    );
    final slots = [
      for (final row in weekly)
        ProgramSlot(
          id: row['id'] as String,
          weekday: row['weekday'] as int,
          label: row['name'] as String,
          workoutId: row['workout_id'] as String,
        ),
    ];
    final active = plans.where((p) => p['status'] == 'active').toList();
    final candidates = <String>[];
    for (final row in plans) {
      final id = row['id'] as String;
      final request = await db.query(
        'cardio_plans',
        where: 'id=?',
        whereArgs: [id],
      );
      final r =
          request.isEmpty
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(
                jsonDecode(request.first['request_json'] as String) as Map,
              );
      final occurrences = await db.query(
        'cardio_occurrences',
        where: 'plan_id=?',
        whereArgs: [id],
      );
      final days =
          occurrences
              .map((o) => DateTime.parse(o['local_date'] as String).weekday)
              .toSet()
              .toList()
            ..sort();
      final start =
          DateTime.tryParse(r['startDate'] as String? ?? '') ??
          (row['starts_at_utc'] == null
              ? DateTime.now()
              : DateTime.fromMillisecondsSinceEpoch(
                row['starts_at_utc'] as int,
              ));
      final p = TrainingProgram(
        id: id,
        name: row['name'] as String,
        start: start,
        runningDays: days,
        slots: [
          if (active.length == 1 && row['status'] == 'active') ...slots,
          for (final link in await db.rawQuery(
            '''SELECT l.*,w.name FROM training_plan_workouts l
            JOIN workout_templates w ON w.id=l.workout_id
            WHERE training_plan_id=? AND weekday IS NOT NULL''',
            [id],
          ))
            if (!slots.any(
                  (s) =>
                      s.workoutId == link['workout_id'] &&
                      s.weekday == link['weekday'],
                ) ||
                active.length != 1 ||
                row['status'] != 'active')
              ProgramSlot(
                id: link['id'] as String,
                weekday: link['weekday'] as int,
                label: link['name'] as String,
                workoutId: link['workout_id'] as String,
                from: DateTime(
                  start.year,
                  start.month,
                  start.day -
                      start.weekday +
                      (link['weekday'] as int) +
                      ((link['week_number'] as int) - 1) * 7,
                ),
                until: DateTime(
                  start.year,
                  start.month,
                  start.day -
                      start.weekday +
                      (link['weekday'] as int) +
                      ((link['week_number'] as int) - 1) * 7,
                ),
              ),
        ],
        status: row['status'] as String,
        targetMeters: (r['targetMeters'] as num?)?.toDouble() ?? 5000,
        targetSeconds: (r['targetSeconds'] as num?)?.toDouble(),
        targetDate: DateTime.tryParse(r['targetDate'] as String? ?? ''),
      );
      await db.insert('training_programs', {
        'id': id,
        'program_json': jsonEncode(p.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (row['status'] == 'active') candidates.add(id);
    }
    if (slots.isNotEmpty && active.length != 1) {
      final id = UuidV4.generate(), now = DateTime.now();
      await db.insert('training_plans', {
        'id': id,
        'name': 'Training',
        'status': 'active',
        'created_at_utc': now.toUtc().millisecondsSinceEpoch,
        'updated_at_utc': now.toUtc().millisecondsSinceEpoch,
      });
      await db.insert('training_programs', {
        'id': id,
        'program_json': jsonEncode(
          TrainingProgram(
            id: id,
            name: 'Training',
            start: now,
            slots: slots,
            status: 'active',
          ).toJson(),
        ),
      });
      candidates.add(id);
    }
    await db.insert('active_training_plan', {
      'id': 0,
      'plan_id': candidates.length == 1 ? candidates.single : null,
    });
  }
}
