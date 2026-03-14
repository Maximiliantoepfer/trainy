import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._();
  AppDatabase._();

  static const _dbName = 'trainy.db';
  static const _dbVersion = 8; // ⬅️ v8: workout_day_assignments Tabelle

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
        icon INTEGER,
        goal TEXT
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

    // Tracking welche Standardübungen bereits eingefügt wurden
    await db.execute('''
      CREATE TABLE seeded_standards(
        key TEXT PRIMARY KEY
      )
    ''');

    // Merge-History: protokolliert zusammengeführte Übungen
    await db.execute('''
      CREATE TABLE merge_history(
        id INTEGER PRIMARY KEY,
        sourceName TEXT NOT NULL,
        sourceKey TEXT,
        targetId INTEGER NOT NULL,
        mergedAt TEXT NOT NULL
      )
    ''');

    // Workout-Tages-Zuordnung (many-to-many)
    await db.execute('''
      CREATE TABLE workout_day_assignments(
        workoutId INTEGER NOT NULL,
        dayOfWeek INTEGER NOT NULL,
        PRIMARY KEY(workoutId, dayOfWeek),
        FOREIGN KEY(workoutId) REFERENCES workouts(id) ON DELETE CASCADE
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

    // v5: goal column for exercises
    try {
      await db.execute('ALTER TABLE exercises ADD COLUMN goal TEXT');
    } catch (_) {}

    // v5: Umlaut-Fixes für bestehende Seed-Daten
    const umlautFixes = {
      'Bankdruecken': 'Bankdrücken',
      'Schulterdruecken': 'Schulterdrücken',
      'Klimmzuege': 'Klimmzüge',
      'Liegestuetze': 'Liegestütze',
      'Trizeps-Druecken': 'Trizepsdrücken',
    };
    for (final e in umlautFixes.entries) {
      try {
        await db.execute(
          'UPDATE exercises SET name = ? WHERE name = ?',
          [e.value, e.key],
        );
      } catch (_) {}
    }

    // v6: Tracking-Tabelle für Standardübungen
    await db.execute('''
      CREATE TABLE IF NOT EXISTS seeded_standards(
        key TEXT PRIMARY KEY
      )
    ''');

    // v7: Merge-History-Tabelle
    await db.execute('''
      CREATE TABLE IF NOT EXISTS merge_history(
        id INTEGER PRIMARY KEY,
        sourceName TEXT NOT NULL,
        sourceKey TEXT,
        targetId INTEGER NOT NULL,
        mergedAt TEXT NOT NULL
      )
    ''');

    // v8: Workout-Tages-Zuordnung
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_day_assignments(
        workoutId INTEGER NOT NULL,
        dayOfWeek INTEGER NOT NULL,
        PRIMARY KEY(workoutId, dayOfWeek),
        FOREIGN KEY(workoutId) REFERENCES workouts(id) ON DELETE CASCADE
      )
    ''');
  }
}
