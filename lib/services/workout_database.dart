import 'package:sqflite/sqflite.dart';
import '../models/workout.dart';
import '../models/exercise_in_workout.dart';
import 'app_database.dart';

class WorkoutDatabase {
  static final WorkoutDatabase instance = WorkoutDatabase._init();
  WorkoutDatabase._init();

  Future<Database> get _db async => await AppDatabase.instance.database;

  Future<void> insertWorkout(Workout workout) async {
    final db = await _db;

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
    final db = await _db;
    await db.update(
      'workouts',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [workoutId],
    );
  }

  Future<List<Workout>> getAllWorkouts() async {
    final db = await _db;
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
    final db = await _db;
    await db.delete('workouts', where: 'id = ?', whereArgs: [id]);
    await db.delete(
      'exercises_in_workouts',
      where: 'workoutId = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await _db;
    db.close();
  }
}
