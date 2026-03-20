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
    final batch = db.batch();

    batch.delete(
      'exercises_in_workouts',
      where: 'workoutId = ?',
      whereArgs: [workoutId],
    );

    for (int i = 0; i < exerciseIds.length; i++) {
      batch.insert('exercises_in_workouts', {
        'id': DateTime.now().microsecondsSinceEpoch + i,
        'workoutId': workoutId,
        'exerciseId': exerciseIds[i],
        'sort': i,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Workout>> getAllWorkouts() async {
    final db = await _db;
    final rows = await db.query('workouts',
      where: 'isArchived = 0',
      orderBy: 'name COLLATE NOCASE ASC');

    // Alle Tages-Zuordnungen in einer Query laden
    final dayRows = await db.query('workout_day_assignments');
    final dayMap = <int, Set<int>>{};
    for (final r in dayRows) {
      final wId = (r['workoutId'] as num).toInt();
      final day = (r['dayOfWeek'] as num).toInt();
      dayMap.putIfAbsent(wId, () => <int>{}).add(day);
    }

    final result = <Workout>[];

    for (final row in rows) {
      final workoutId = (row['id'] as num).toInt();
      final mapping = await db.query(
        'exercises_in_workouts',
        where: 'workoutId = ?',
        whereArgs: [workoutId],
        orderBy: 'sort ASC',
      );
      final ids = mapping.map((m) => (m['exerciseId'] as num).toInt()).toList();
      result.add(
        Workout(
          id: workoutId,
          name: (row['name'] ?? '') as String,
          description: (row['description'] ?? '') as String,
          exerciseIds: ids,
          assignedDays: dayMap[workoutId] ?? const {},
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

  Future<void> setWorkoutDays(int workoutId, Set<int> days) async {
    final db = await _db;
    final batch = db.batch();
    batch.delete('workout_day_assignments',
      where: 'workoutId = ?', whereArgs: [workoutId]);
    for (final day in days) {
      batch.insert('workout_day_assignments', {
        'workoutId': workoutId,
        'dayOfWeek': day,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteWorkout(int id) async {
    final db = await _db;
    // Soft-delete: Workout archivieren statt löschen
    await db.update('workouts', {'isArchived': 1},
      where: 'id = ?', whereArgs: [id]);
    await db.delete(
      'exercises_in_workouts',
      where: 'workoutId = ?',
      whereArgs: [id],
    );
    await db.delete(
      'workout_day_assignments',
      where: 'workoutId = ?',
      whereArgs: [id],
    );
  }

  /// Sucht ein archiviertes Workout mit gleichem Namen (case-insensitive).
  Future<Workout?> findArchivedByName(String name) async {
    final db = await _db;
    final rows = await db.query('workouts',
      where: 'isArchived = 1 AND LOWER(name) = LOWER(?)',
      whereArgs: [name.trim()],
      limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return Workout(
      id: (row['id'] as num).toInt(),
      name: (row['name'] ?? '') as String,
      description: (row['description'] ?? '') as String,
    );
  }

  /// Reaktiviert ein archiviertes Workout.
  Future<void> unarchiveWorkout(int id) async {
    final db = await _db;
    await db.update('workouts', {'isArchived': 0},
      where: 'id = ?', whereArgs: [id]);
  }
}
