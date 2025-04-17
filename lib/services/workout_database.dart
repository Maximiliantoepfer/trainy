// lib/services/workout_database.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/workout.dart';
import '../models/exercise_in_workout.dart';

class WorkoutDatabase {
  static final WorkoutDatabase instance = WorkoutDatabase._init();
  static Database? _database;

  WorkoutDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('trainy.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await _createDB(db, newVersion);
        }
      },
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE workouts (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE exercises_in_workouts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      workoutId INTEGER,
      exerciseId INTEGER,
      name TEXT,
      description TEXT,
      trackedFields TEXT,
      defaultValues TEXT,
      units TEXT,
      icon INTEGER,
      position INTEGER
    )
    ''');
  }

  Future<void> insertWorkout(Workout workout) async {
    final db = await instance.database;

    await db.insert('workouts', {
      'id': workout.id,
      'name': workout.name,
      'description': workout.description,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.delete(
      'exercises_in_workouts',
      where: 'workoutId = ?',
      whereArgs: [workout.id],
    );
    for (var ew in workout.exercises) {
      await db.insert('exercises_in_workouts', ew.toMap());
    }
  }

  Future<void> updateWorkoutName(int workoutId, String newName) async {
    final db = await instance.database;
    await db.update(
      'workouts',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [workoutId],
    );
  }

  Future<List<Workout>> getAllWorkouts() async {
    final db = await instance.database;
    final workoutMaps = await db.query('workouts');
    List<Workout> workouts = [];

    for (final map in workoutMaps) {
      final rows = await db.query(
        'exercises_in_workouts',
        where: 'workoutId = ?',
        whereArgs: [map['id']],
        orderBy: 'position ASC',
      );

      final exercises =
          rows.map((row) => ExerciseInWorkout.fromMap(row)).toList();

      workouts.add(
        Workout(
          id: map['id'] as int,
          name: map['name'] as String,
          description: map['description'] as String? ?? '',
          exercises: exercises,
        ),
      );
    }

    return workouts;
  }

  Future<void> deleteWorkout(int id) async {
    final db = await instance.database;
    await db.delete('workouts', where: 'id = ?', whereArgs: [id]);
    await db.delete(
      'exercises_in_workouts',
      where: 'workoutId = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
