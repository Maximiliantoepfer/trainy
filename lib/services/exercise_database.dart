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
    final rows = await db.query(
      'exercises',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map((r) => Exercise.fromMap(r)).toList();
  }

  Future<void> deleteExercises(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _db;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete(
      'exercises',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }
}
