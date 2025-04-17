import 'package:sqflite/sqflite.dart';
import '../models/exercise.dart';
import 'app_database.dart';

class ExerciseDatabase {
  static final ExerciseDatabase instance = ExerciseDatabase._init();
  ExerciseDatabase._init();

  Future<Database> get _db async => await AppDatabase.instance.database;

  Future<void> insertExercise(Exercise exercise) async {
    final db = await _db;
    await db.insert(
      'exercises',
      exercise.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Exercise>> getAllExercises() async {
    final db = await _db;
    final result = await db.query('exercises');
    return result.map((json) => Exercise.fromMap(json)).toList();
  }

  Future<void> deleteExercise(int id) async {
    final db = await _db;
    await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteExercises(List<int> ids) async {
    final db = await _db;
    final idList = ids.join(',');
    await db.delete('exercises', where: 'id IN ($idList)');
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

  Future close() async {
    final db = await _db;
    db.close();
  }
}
