// lib/services/workout_database.dart

import 'package:sqflite/sqflite.dart';
import '../models/workout.dart';
import 'app_database.dart';

class WorkoutDatabase {
  static final WorkoutDatabase instance = WorkoutDatabase._init();
  WorkoutDatabase._init();

  Future<Database> get _db async => AppDatabase.instance.database;

  Future<void> upsertWorkout(Workout workout) async {
    final db = await _db;
    // Upsert workout row
    await db.insert('workouts', {
      'id': workout.id,
      'name': workout.name,
      'description': workout.description,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Replace exercise links
    await db.delete(
      'exercises_in_workouts',
      where: 'workoutId = ?',
      whereArgs: [workout.id],
    );
    for (int i = 0; i < workout.exerciseIds.length; i++) {
      await db.insert('exercises_in_workouts', {
        'id': DateTime.now().microsecondsSinceEpoch + i,
        'workoutId': workout.id,
        'exerciseId': workout.exerciseIds[i],
        'position': i,
        'customValues': null,
      });
    }
  }

  Future<List<Workout>> getAllWorkouts() async {
    final db = await _db;
    final rows = await db.query('workouts', orderBy: 'name COLLATE NOCASE');
    final List<Workout> result = [];
    for (final row in rows) {
      final workoutId = row['id'] as int;
      final exRows = await db.query(
        'exercises_in_workouts',
        where: 'workoutId = ?',
        whereArgs: [workoutId],
        orderBy: 'position ASC, id ASC',
      );
      final ids = exRows.map((r) => r['exerciseId'] as int).toList();
      result.add(
        Workout(
          id: workoutId,
          name: (row['name'] ?? '') as String,
          description: (row['description'] ?? '') as String,
          exerciseIds: ids,
        ),
      );
    }
    return result;
  }

  Future<void> updateWorkoutName(int workoutId, String newName) async {
    final db = await _db;
    await db.update(
      'workouts',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [workoutId],
    );
  }

  Future<void> updateWorkoutExercises(
    int workoutId,
    List<int> exerciseIds,
  ) async {
    final db = await _db;
    await db.delete(
      'exercises_in_workouts',
      where: 'workoutId = ?',
      whereArgs: [workoutId],
    );
    for (int i = 0; i < exerciseIds.length; i++) {
      await db.insert('exercises_in_workouts', {
        'id': DateTime.now().microsecondsSinceEpoch + i,
        'workoutId': workoutId,
        'exerciseId': exerciseIds[i],
        'position': i,
        'customValues': null,
      });
    }
  }

  Future<void> deleteWorkout(int id) async {
    final db = await _db;
    await db.delete('workouts', where: 'id = ?', whereArgs: [id]);
    await db.delete(
      'exercises_in_workouts',
      where: 'workoutId = ?',
      whereArgs: [id],
    );
  }
}
