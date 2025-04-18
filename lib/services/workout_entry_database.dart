import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/workout_entry.dart';
import 'app_database.dart';

class WorkoutEntryDatabase {
  static final WorkoutEntryDatabase instance = WorkoutEntryDatabase._init();
  WorkoutEntryDatabase._init();

  Future<Database> get _db async => await AppDatabase.instance.database;

  Future<void> insertEntry(WorkoutEntry entry) async {
    final db = await _db;
    await db.insert('workout_entries', {
      'id': entry.id,
      'workoutId': entry.workoutId,
      'date': entry.date.toIso8601String(),
      'results': jsonEncode(entry.results),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<WorkoutEntry>> getEntriesForWorkout(int workoutId) async {
    final db = await _db;
    final result = await db.query(
      'workout_entries',
      where: 'workoutId = ?',
      whereArgs: [workoutId],
      orderBy: 'date DESC',
    );

    return result.map((row) {
      return WorkoutEntry(
        id: row['id'] as int,
        workoutId: row['workoutId'] as int,
        date: DateTime.parse(row['date'] as String),
        results: jsonDecode(row['results'] as String),
      );
    }).toList();
  }

  Future<DateTime?> getLastDate(int workoutId) async {
    final entries = await getEntriesForWorkout(workoutId);
    return entries.isEmpty ? null : entries.first.date;
  }

  Future<List<WorkoutEntry>> getAllEntries() async {
    final db = await _db;
    final result = await db.query('workout_entries', orderBy: 'date ASC');

    return result.map((row) {
      return WorkoutEntry(
        id: row['id'] as int,
        workoutId: row['workoutId'] as int,
        date: DateTime.parse(row['date'] as String),
        results: jsonDecode(row['results'] as String),
      );
    }).toList();
  }
}
