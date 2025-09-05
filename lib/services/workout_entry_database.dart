// lib/services/workout_entry_database.dart

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/workout_entry.dart';
import 'app_database.dart';

class WorkoutEntryDatabase {
  static final WorkoutEntryDatabase instance = WorkoutEntryDatabase._init();
  WorkoutEntryDatabase._init();

  Future<Database> get _db async => AppDatabase.instance.database;

  Future<void> insertEntry(WorkoutEntry entry) async {
    final db = await _db;
    await db.insert('workout_entries', {
      'id': entry.id,
      'workoutId': entry.workoutId,
      'date': entry.date.toIso8601String(),
      'results': jsonEncode(entry.results),
    });
  }

  Future<List<WorkoutEntry>> getAllEntries() async {
    final db = await _db;
    final result = await db.query('workout_entries', orderBy: 'date ASC');
    return result.map((row) {
      final decoded =
          (jsonDecode(row['results'] as String) as Map<String, dynamic>).map(
            (k, v) =>
                MapEntry(int.parse(k), (v as Map).cast<String, dynamic>()),
          );
      return WorkoutEntry(
        id: row['id'] as int,
        workoutId: row['workoutId'] as int,
        date: DateTime.parse(row['date'] as String),
        results: decoded,
      );
    }).toList();
  }
}
