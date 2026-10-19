import 'package:sqflite/sqflite.dart';

abstract final class CardioSchema {
  // Child-first, matching DatabaseSchemaV2.userDataTables and backup restore.
  static const tables = [
    'cardio_health_inbox',
    'cardio_sensor_samples',
    'cardio_session_details',
    'cardio_occurrences',
    'cardio_plans',
    'cardio_workouts',
    'cardio_preferences',
  ];
  static Future<void> create(DatabaseExecutor db) async {
    for (final sql in statements) {
      await db.execute(sql);
    }
  }

  static const statements = [
    '''CREATE TABLE IF NOT EXISTS cardio_preferences(
      id INTEGER PRIMARY KEY CHECK(id = 0), profile_json TEXT NOT NULL)''',
    '''CREATE TABLE IF NOT EXISTS cardio_workouts(
      id TEXT PRIMARY KEY, workout_json TEXT NOT NULL, updated_at_utc INTEGER NOT NULL,
      FOREIGN KEY(id) REFERENCES workout_templates(id) ON DELETE CASCADE)''',
    '''CREATE TABLE IF NOT EXISTS cardio_plans(
      id TEXT PRIMARY KEY, request_json TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1,
      FOREIGN KEY(id) REFERENCES training_plans(id) ON DELETE CASCADE)''',
    '''CREATE TABLE IF NOT EXISTS cardio_occurrences(
      id TEXT PRIMARY KEY, plan_id TEXT NOT NULL, local_date TEXT NOT NULL,
      workout_json TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'planned'
        CHECK(status IN ('planned','completed','skipped')),
      locked INTEGER NOT NULL DEFAULT 0 CHECK(locked IN (0,1)), session_id TEXT,
      FOREIGN KEY(plan_id) REFERENCES cardio_plans(id) ON DELETE CASCADE,
      FOREIGN KEY(session_id) REFERENCES activity_sessions(id) ON DELETE SET NULL)''',
    '''CREATE TABLE IF NOT EXISTS cardio_session_details(
      session_id TEXT PRIMARY KEY, snapshot_json TEXT NOT NULL, runtime_json TEXT,
      FOREIGN KEY(session_id) REFERENCES activity_sessions(id) ON DELETE CASCADE)''',
    '''CREATE TABLE IF NOT EXISTS cardio_sensor_samples(
      session_id TEXT NOT NULL, sequence INTEGER NOT NULL, sample_json TEXT NOT NULL,
      PRIMARY KEY(session_id, sequence),
      FOREIGN KEY(session_id) REFERENCES activity_sessions(id) ON DELETE CASCADE)''',
    '''CREATE TABLE IF NOT EXISTS cardio_health_inbox(
      provider TEXT NOT NULL, external_id TEXT NOT NULL, record_json TEXT NOT NULL,
      decision TEXT NOT NULL DEFAULT 'pending' CHECK(decision IN ('pending','accepted','dismissed')),
      PRIMARY KEY(provider, external_id))''',
    'CREATE INDEX IF NOT EXISTS idx_cardio_date ON cardio_occurrences(local_date)',
    'CREATE INDEX IF NOT EXISTS idx_cardio_plan ON cardio_occurrences(plan_id)',
    'CREATE INDEX IF NOT EXISTS idx_cardio_session ON cardio_occurrences(session_id)',
  ];
}
