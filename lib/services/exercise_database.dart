// lib/services/exercise_database.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/exercise.dart';

class ExerciseDatabase {
  static final ExerciseDatabase instance = ExerciseDatabase._init();
  static Database? _database;

  ExerciseDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('trainy.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE exercises (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      trackedFields TEXT,
      defaultValues TEXT,
      units TEXT,
      icon INTEGER
    )
    ''');
  }

  Future<void> insertExercise(Exercise exercise) async {
    final db = await instance.database;
    await db.insert(
      'exercises',
      exercise.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Exercise>> getAllExercises() async {
    final db = await instance.database;
    final result = await db.query('exercises');
    return result.map((json) => Exercise.fromMap(json)).toList();
  }

  Future<void> deleteExercise(int id) async {
    final db = await instance.database;
    await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteExercises(List<int> ids) async {
    final db = await instance.database;
    final idList = ids.join(',');
    await db.delete('exercises', where: 'id IN ($idList)');
  }

  Future<void> updateExercise(Exercise exercise) async {
    final db = await instance.database;
    await db.update(
      'exercises',
      exercise.toMap(),
      where: 'id = ?',
      whereArgs: [exercise.id],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
