import 'dart:convert';
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
      'goalCodes': jsonEncode(_validatedGoalCodes(workout.goalCodes)),
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
    final rows = await db.query(
      'workouts',
      where: 'isArchived = 0',
      orderBy: 'name COLLATE NOCASE ASC',
    );

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
      final mapping = await db.rawQuery(
        '''SELECT COALESCE(r.targetExerciseId, m.exerciseId) AS exerciseId
           FROM exercises_in_workouts m
           LEFT JOIN exercise_redirects r
             ON r.sourceExerciseId = m.exerciseId AND r.undoneAt IS NULL
           WHERE m.workoutId = ?
           ORDER BY m.sort ASC''',
        [workoutId],
      );
      final ids = <int>[];
      for (final item in mapping) {
        final id = (item['exerciseId'] as num).toInt();
        if (!ids.contains(id)) ids.add(id);
      }
      result.add(
        Workout(
          id: workoutId,
          name: (row['name'] ?? '') as String,
          description: (row['description'] ?? '') as String,
          exerciseIds: ids,
          assignedDays: dayMap[workoutId] ?? const {},
          goalCodes: _goalCodes(row['goalCodes']),
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
    batch.delete(
      'workout_day_assignments',
      where: 'workoutId = ?',
      whereArgs: [workoutId],
    );
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
    await db.update(
      'workouts',
      {'isArchived': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
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
    final rows = await db.query(
      'workouts',
      where: 'isArchived = 1 AND LOWER(name) = LOWER(?)',
      whereArgs: [name.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return Workout(
      id: (row['id'] as num).toInt(),
      name: (row['name'] ?? '') as String,
      description: (row['description'] ?? '') as String,
      goalCodes: _goalCodes(row['goalCodes']),
    );
  }

  /// Reaktiviert ein archiviertes Workout.
  Future<void> unarchiveWorkout(int id) async {
    final db = await _db;
    await db.update(
      'workouts',
      {'isArchived': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setWorkoutGoalCodes(
    int workoutId,
    List<String> goalCodes,
  ) async {
    final normalized = _validatedGoalCodes(goalCodes);
    await (await _db).update(
      'workouts',
      {'goalCodes': jsonEncode(normalized)},
      where: 'id = ?',
      whereArgs: [workoutId],
    );
  }

  static List<String> _goalCodes(Object? raw) {
    try {
      return _validatedGoalCodes(
        List<String>.from(jsonDecode(raw as String? ?? '[]') as List),
      );
    } catch (_) {
      return const ['strength'];
    }
  }

  static List<String> _validatedGoalCodes(Iterable<String> values) {
    const allowed = {'strength', 'endurance', 'cardio', 'mobility'};
    const domains = {'strength', 'cardio', 'mobility'};
    final normalized = <String>[];
    for (final code in values) {
      if (allowed.contains(code) && !normalized.contains(code)) {
        normalized.add(code);
      }
      if (normalized.length == 2) break;
    }
    if (normalized.isEmpty) return const ['strength'];
    if (!normalized.any(domains.contains)) normalized.insert(0, 'cardio');
    if (normalized.length > 2) normalized.removeLast();
    normalized.sort((a, b) {
      final ad = domains.contains(a);
      final bd = domains.contains(b);
      return ad == bd ? 0 : (ad ? -1 : 1);
    });
    return normalized;
  }
}
