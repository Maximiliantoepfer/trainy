import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._();
  AppDatabase._();

  static const _dbName = 'trainy.db';
  static const _dbVersion = 3; // ↑ Version anheben, falls Schema neu ist

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
        trackedFields TEXT NOT NULL,
        defaultValues TEXT NOT NULL,
        lastValues TEXT NOT NULL,
        units TEXT NOT NULL,
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

    // Mapping Workout → Exercises mit sort
    await db.execute('''
      CREATE TABLE exercises_in_workouts(
        id INTEGER PRIMARY KEY,
        workoutId INTEGER NOT NULL,
        exerciseId INTEGER NOT NULL,
        sort INTEGER NOT NULL,
        FOREIGN KEY(workoutId) REFERENCES workouts(id) ON DELETE CASCADE
      )
    ''');

    // Workout Entries (Logger)
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
    // sehr einfache Migration: fehlende Tabellen anlegen
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS exercises_in_workouts(
          id INTEGER PRIMARY KEY,
          workoutId INTEGER NOT NULL,
          exerciseId INTEGER NOT NULL,
          sort INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
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
    }
  }
}
