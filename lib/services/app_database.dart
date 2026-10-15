import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._();
  AppDatabase._();

  static const _dbName = 'trainy.db';
  static const _dbVersion = 17;

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
        goal TEXT,
        standardKey TEXT,
        isNameCustom INTEGER NOT NULL DEFAULT 1,
        catalogId TEXT,
        origin TEXT NOT NULL DEFAULT 'custom',
        alias TEXT,
        notes TEXT NOT NULL DEFAULT '',
        isArchived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Workouts
    await db.execute('''
      CREATE TABLE workouts(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        isArchived INTEGER NOT NULL DEFAULT 0,
        goalCodes TEXT NOT NULL DEFAULT '[]'
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
        last_sync_millis INTEGER NOT NULL DEFAULT 0,
        training_days TEXT NOT NULL DEFAULT '',
        insights_order TEXT NOT NULL DEFAULT '',
        onboarding_done INTEGER NOT NULL DEFAULT 0
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
        durationSeconds INTEGER NOT NULL,
        sessionId INTEGER
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

    // Gepinnte Charts (Übung + Metrik)
    await db.execute('''
      CREATE TABLE pinned_charts(
        id INTEGER PRIMARY KEY,
        exerciseId INTEGER NOT NULL,
        metric TEXT NOT NULL,
        sort INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(exerciseId) REFERENCES exercises(id) ON DELETE CASCADE
      )
    ''');

    // Fresh installs do not pass through _onUpgrade, so all v13+ catalog,
    // duplicate and variant tables must be created here as well.
    await _createCatalogTables(db);
    await _createWorkoutVariantTables(db);
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
    // v17: These settings used to be created lazily by their setters. Add
    // them to the schema itself so fresh installs never issue failed SELECTs
    // during their first app start.
    for (final statement in const [
      "ALTER TABLE user_settings ADD COLUMN training_days TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE user_settings ADD COLUMN insights_order TEXT NOT NULL DEFAULT ''",
      'ALTER TABLE user_settings ADD COLUMN onboarding_done INTEGER NOT NULL DEFAULT 0',
    ]) {
      try {
        await db.execute(statement);
      } catch (_) {}
    }

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
        await db.execute('UPDATE exercises SET name = ? WHERE name = ?', [
          e.value,
          e.key,
        ]);
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

    // v9: Soft-Delete für Workouts
    try {
      await db.execute(
        'ALTER TABLE workouts ADD COLUMN isArchived INTEGER NOT NULL DEFAULT 0',
      );
    } catch (_) {}

    // v10: trackDistance für bestehende Cardio-Übungen aktivieren
    if (oldVersion < 10) {
      try {
        final exercises = await db.query('exercises', where: "goal = 'Cardio'");
        for (final row in exercises) {
          final trackedStr = row['trackedFields'] as String? ?? '{}';
          final tracked = jsonDecode(trackedStr) as Map<String, dynamic>;
          if (!tracked.containsKey('distance')) {
            tracked['distance'] = true;
            await db.update(
              'exercises',
              {'trackedFields': jsonEncode(tracked)},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }
      } catch (_) {}
    }

    // v11: Gepinnte Charts
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pinned_charts(
        id INTEGER PRIMARY KEY,
        exerciseId INTEGER NOT NULL,
        metric TEXT NOT NULL,
        sort INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(exerciseId) REFERENCES exercises(id) ON DELETE CASCADE
      )
    ''');
    await _createCatalogTables(db);
    await _createWorkoutVariantTables(db);

    // v12: Stable catalog identity and language-neutral goal values. Existing
    // user-entered names are deliberately kept untouched.
    try {
      await db.execute('ALTER TABLE exercises ADD COLUMN standardKey TEXT');
    } catch (_) {}
    try {
      await db.execute(
        'ALTER TABLE exercises ADD COLUMN isNameCustom INTEGER NOT NULL DEFAULT 1',
      );
    } catch (_) {}
    const legacyGoals = {
      'Kraft': 'strength',
      'Ausdauer': 'endurance',
      'Cardio': 'cardio',
      'Mobilität': 'mobility',
    };
    for (final item in legacyGoals.entries) {
      await db.update(
        'exercises',
        {'goal': item.value},
        where: 'goal = ?',
        whereArgs: [item.key],
      );
    }

    // v13: catalog/user-exercise separation. `standardKey` stays as legacy
    // migration data; all new catalog links use catalogId.
    for (final statement in const [
      'ALTER TABLE exercises ADD COLUMN catalogId TEXT',
      "ALTER TABLE exercises ADD COLUMN origin TEXT NOT NULL DEFAULT 'custom'",
      'ALTER TABLE exercises ADD COLUMN alias TEXT',
      "ALTER TABLE exercises ADD COLUMN notes TEXT NOT NULL DEFAULT ''",
      'ALTER TABLE exercises ADD COLUMN isArchived INTEGER NOT NULL DEFAULT 0',
      "ALTER TABLE workouts ADD COLUMN goalCodes TEXT NOT NULL DEFAULT '[]'",
      'ALTER TABLE workout_entries ADD COLUMN sessionId INTEGER',
    ]) {
      try {
        await db.execute(statement);
      } catch (_) {}
    }
    await _createCatalogTables(db);
    await _createWorkoutVariantTables(db);
    final legacyExerciseRows = await db.query(
      'exercises',
      columns: ['id', 'goal', 'standardKey'],
    );
    for (final row in legacyExerciseRows) {
      final exerciseId = row['id'];
      final goal = row['goal'] as String?;
      if (goal != null && legacyGoals.containsValue(goal)) {
        await db.insert('exercise_goal_labels', {
          'exerciseId': exerciseId,
          'goalCode': goal,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      if (row['standardKey'] != null) {
        await db.update(
          'exercises',
          {'origin': 'catalog'},
          where: 'id = ?',
          whereArgs: [exerciseId],
        );
      }
    }
  }

  Future<void> _createCatalogTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exercise_goal_labels(
        exerciseId INTEGER NOT NULL,
        goalCode TEXT NOT NULL,
        PRIMARY KEY(exerciseId, goalCode)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exercise_images(
        id INTEGER PRIMARY KEY,
        exerciseId INTEGER NOT NULL,
        relativePath TEXT NOT NULL,
        isCover INTEGER NOT NULL DEFAULT 0,
        sort INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS duplicate_suggestions(
        id INTEGER PRIMARY KEY,
        sourceExerciseId INTEGER NOT NULL,
        targetExerciseId INTEGER,
        targetCatalogId TEXT,
        confidence TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'open',
        createdAt INTEGER NOT NULL,
        UNIQUE(sourceExerciseId, targetExerciseId, targetCatalogId)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exercise_redirects(
        id INTEGER PRIMARY KEY,
        sourceExerciseId INTEGER NOT NULL,
        targetExerciseId INTEGER NOT NULL,
        sourceSnapshotJson TEXT NOT NULL,
        changedWorkoutMappingsJson TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        undoneAt INTEGER,
        UNIQUE(sourceExerciseId, targetExerciseId, createdAt)
      )
    ''');
  }

  Future<void> _createWorkoutVariantTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS training_profiles(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        equipmentCodesJson TEXT NOT NULL DEFAULT '[]',
        isArchived INTEGER NOT NULL DEFAULT 0,
        sort INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_variants(
        id INTEGER PRIMARY KEY,
        workoutId INTEGER NOT NULL,
        name TEXT NOT NULL,
        profileId INTEGER,
        sort INTEGER NOT NULL DEFAULT 0,
        isDefault INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_groups(
        id INTEGER PRIMARY KEY,
        workoutId INTEGER NOT NULL,
        name TEXT NOT NULL,
        muscleGroupCode TEXT,
        sort INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_group_variants(
        id INTEGER PRIMARY KEY,
        workoutGroupId INTEGER NOT NULL,
        name TEXT NOT NULL,
        profileId INTEGER,
        sort INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_variant_group_selections(
        workoutVariantId INTEGER NOT NULL,
        workoutGroupId INTEGER NOT NULL,
        groupVariantId INTEGER NOT NULL,
        PRIMARY KEY(workoutVariantId, workoutGroupId)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_slots(
        id INTEGER PRIMARY KEY,
        groupVariantId INTEGER NOT NULL,
        exerciseId INTEGER NOT NULL,
        movementFamilyId TEXT,
        slotKind TEXT NOT NULL DEFAULT 'core',
        sort INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_slot_alternatives(
        id INTEGER PRIMARY KEY,
        workoutSlotId INTEGER NOT NULL,
        exerciseId INTEGER NOT NULL,
        profileId INTEGER,
        sort INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_sessions(
        id INTEGER PRIMARY KEY,
        workoutId INTEGER NOT NULL,
        workoutVariantId INTEGER,
        profileId INTEGER,
        startedAt INTEGER NOT NULL,
        completedAt INTEGER,
        snapshotJson TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_session_group_selections(
        sessionId INTEGER NOT NULL,
        workoutGroupId INTEGER NOT NULL,
        groupVariantId INTEGER NOT NULL,
        PRIMARY KEY(sessionId, workoutGroupId)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_session_slot_selections(
        sessionId INTEGER NOT NULL,
        workoutSlotId INTEGER NOT NULL,
        exerciseId INTEGER NOT NULL,
        PRIMARY KEY(sessionId, workoutSlotId)
      )
    ''');
  }
}
