// lib/services/exercise_database.dart

import 'package:sqflite/sqflite.dart';
import '../models/exercise.dart';
import 'app_database.dart';

class ExerciseDatabase {
  static final ExerciseDatabase instance = ExerciseDatabase._init();
  ExerciseDatabase._init();

  Future<Database> get _db async => AppDatabase.instance.database;

  Future<void> upsertExercise(Exercise exercise) async {
    final db = await _db;
    await db.insert(
      'exercises',
      exercise.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Exercise>> getAllExercises() async {
    final db = await _db;
    final result = await db.query('exercises', orderBy: 'name COLLATE NOCASE');
    return result.map((row) => Exercise.fromMap(row)).toList();
  }

  Future<void> deleteExercises(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _db;
    await db.delete(
      'exercises',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  Future<void> updateLastValues(
    int exerciseId,
    Map<String, String> lastValues,
  ) async {
    final db = await _db;
    await db.update('exercises', {
      'lastValues': lastValues.isEmpty ? '{}' : lastValues,
    });
  }

  Future<void> updateExercise(Exercise exercise) async {
    final db = await _db;
    await db.update(
      'exercises',
      exercise.toMap(),
      where: 'id = ?',
      whereArgs: [exercise.id],
    );
  }
}
