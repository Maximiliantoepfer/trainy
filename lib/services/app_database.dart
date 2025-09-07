import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._();
  AppDatabase._();

  static const _dbName = 'trainy.db';
  static const _dbVersion = 4; // ⬅️ v4: Cloud-Sync Settings

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    _database = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    // Exercises
    await db.execute('''
      CREATE TABLE exercises(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        trackedFields TEXT NOT NULL,   -- json array
        defaultValues TEXT NOT NULL,   -- json map
        lastValues TEXT NOT NULL,      -- json map
        units TEXT NOT NULL,           -- json map
        icon INTEGER
      )
    ''');

    // Workouts
    await db.execute('''
      CREATE TABLE workouts(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL
      )
    ''');

    // Mapping Übungen ↔ Workouts
    await db.execute('''
      CREATE TABLE exercises_in_workouts(
        id INTEGER PRIMARY KEY,
        workoutId INTEGER NOT NULL,
        exerciseId INTEGER NOT NULL,
        sort INTEGER NOT NULL,
        FOREIGN KEY(workoutId) REFERENCES workouts(id) ON DELETE CASCADE,
        FOREIGN KEY(exerciseId) REFERENCES exercises(id) ON DELETE CASCADE
      )
    ''');

    // User Settings
    await db.execute('''
      CREATE TABLE user_settings(
        id INTEGER PRIMARY KEY,    -- immer 0
        weekly_goal INTEGER NOT NULL,
        sync_enabled INTEGER NOT NULL DEFAULT 0,
        last_sync_millis INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.insert('user_settings', {
      'id': 0,
      'weekly_goal': 2,
      'sync_enabled': 0,
      'last_sync_millis': 0,
    });

    // Workout-Einträge (eine Zeile je Exercise & Session; aggregiertes valuesJson)
    await db.execute('''
      CREATE TABLE workout_entries(
        id INTEGER PRIMARY KEY,
        workoutId INTEGER NOT NULL,
        exerciseId INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        valuesJson TEXT NOT NULL,
        durationSeconds INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Defensive Upgrades – idempotent
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exercises(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        trackedFields TEXT NOT NULL,
        defaultValues TEXT NOT NULL,
        lastValues TEXT NOT NULL,
        units TEXT NOT NULL,
        icon INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS workouts(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS exercises_in_workouts(
        id INTEGER PRIMARY KEY,
        workoutId INTEGER NOT NULL,
        exerciseId INTEGER NOT NULL,
        sort INTEGER NOT NULL
      )
    ''');

    // Defaults & Anlage user_settings falls fehlend
    final settings = await db.query('user_settings', limit: 1);
    if (settings.isEmpty) {
      await db.insert('user_settings', {'id': 0, 'weekly_goal': 2});
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_entries(
        id INTEGER PRIMARY KEY,
        workoutId INTEGER NOT NULL,
        exerciseId INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        valuesJson TEXT NOT NULL,
        durationSeconds INTEGER NOT NULL
      )
    ''');

    // v4: neue Spalten für Cloud-Sync-Settings (idempotent)
    try {
      await db.execute(
        'ALTER TABLE user_settings ADD COLUMN sync_enabled INTEGER NOT NULL DEFAULT 0',
      );
    } catch (_) {}
    try {
      await db.execute(
        'ALTER TABLE user_settings ADD COLUMN last_sync_millis INTEGER NOT NULL DEFAULT 0',
      );
    } catch (_) {}
  }
}
