import 'package:sqflite/sqflite.dart';
import '../models/workout.dart';
import 'app_database.dart';

class WorkoutDatabase {
  static final WorkoutDatabase instance = WorkoutDatabase._init();
  WorkoutDatabase._init();

  Future<Database> get _db async => AppDatabase.instance.database;

  Future<void> upsertWorkout(Workout workout) async {
    final db = await _db;
    await db.insert('workouts', {
      'id': workout.id,
      'name': workout.name,
      'description': workout.description,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (workout.exerciseIds.isNotEmpty) {
      await setWorkoutExercises(workout.id, workout.exerciseIds);
    }
  }

  Future<void> setWorkoutExercises(int workoutId, List<int> exerciseIds) async {
    final db = await _db;
    await db.delete(
      'exercises_in_workouts',
      where: 'workoutId = ?',
      whereArgs: [workoutId],
    );

    for (var i = 0; i < exerciseIds.length; i++) {
      await db.insert('exercises_in_workouts', {
        'id': DateTime.now().microsecondsSinceEpoch + i,
        'workoutId': workoutId,
        'exerciseId': exerciseIds[i],
        'sort': i,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<Workout>> getAllWorkouts() async {
    final db = await _db;
    final rows = await db.query('workouts', orderBy: 'name COLLATE NOCASE ASC');
    final result = <Workout>[];

    for (final row in rows) {
      final workoutId = (row['id'] as num).toInt();
      final mapping = await db.query(
        'exercises_in_workouts',
        where: 'workoutId = ?',
        whereArgs: [workoutId],
        orderBy: '"sort" ASC',
      );
      final ids = mapping.map((m) => (m['exerciseId'] as num).toInt()).toList();
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
