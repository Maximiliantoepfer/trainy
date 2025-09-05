import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import '../models/exercise.dart';

class ExerciseDatabase {
  static final ExerciseDatabase instance = ExerciseDatabase._init();
  ExerciseDatabase._init();

  Future<Database> get _db async => AppDatabase.instance.database;

  // ---- Öffentliche, kompatible API ----

  Future<int> addOrUpdateExercise({
    int? id,
    required String name,
    String description = '',
    required bool trackSets,
    required bool trackReps,
    required bool trackWeight,
    required bool trackDuration,
    Map<String, String>? defaultValues,
    Map<String, String>? lastValues,
    Map<String, String>? units,
    int? icon,
  }) async {
    final exerciseId = id ?? DateTime.now().millisecondsSinceEpoch;
    final e = Exercise(
      id: exerciseId,
      name: name,
      description: description,
      trackSets: trackSets,
      trackReps: trackReps,
      trackWeight: trackWeight,
      trackDuration: trackDuration,
      defaultValues: defaultValues ?? const {},
      lastValues: lastValues ?? const {},
      units: units ?? const {},
      icon: icon,
    );
    await upsertExercise(e);
    return exerciseId;
  }

  // ---- Kernmethoden ----

  Future<void> upsertExercise(Exercise e) async {
    final db = await _db;
    await db.insert('exercises', {
      'id': e.id,
      'name': e.name,
      'description': e.description,
      'trackedFields': jsonEncode({
        'sets': e.trackSets,
        'reps': e.trackReps,
        'weight': e.trackWeight,
        'duration': e.trackDuration,
      }),
      'defaultValues': jsonEncode(e.defaultValues),
      'lastValues': jsonEncode(e.lastValues),
      'units': jsonEncode(e.units),
      'icon': e.icon,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateLastValues(
    int exerciseId,
    Map<String, String> lastValues,
  ) async {
    final db = await _db;
    await db.update(
      'exercises',
      {'lastValues': jsonEncode(lastValues)},
      where: 'id = ?',
      whereArgs: [exerciseId],
    );
  }

  Future<List<Exercise>> getAllExercises() async {
    final db = await _db;
    final rows = await db.query(
      'exercises',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> deleteExercise(int id) async {
    final db = await _db;
    await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Helpers ----

  Exercise _fromRow(Map<String, Object?> r) {
    Map<String, dynamic> _parseMap(Object? v) {
      if (v == null) return {};
      try {
        final d = jsonDecode(v as String);
        if (d is Map) {
          return d.map((k, v) => MapEntry(k.toString(), v));
        }
        return {};
      } catch (_) {
        return {};
      }
    }

    final tracked = _parseMap(r['trackedFields']);
    final defVals = _parseMap(r['defaultValues']);
    final lastVals = _parseMap(r['lastValues']);
    final units = _parseMap(r['units']);

    bool tf(String key) => (tracked[key] ?? false) == true;

    Map<String, String> _toStrMap(Map<String, dynamic> m) =>
        m.map((k, v) => MapEntry(k, v?.toString() ?? ''));

    return Exercise(
      id: (r['id'] as num).toInt(),
      name: (r['name'] ?? '') as String,
      description: (r['description'] ?? '') as String,
      trackSets: tf('sets'),
      trackReps: tf('reps'),
      trackWeight: tf('weight'),
      trackDuration: tf('duration'),
      defaultValues: _toStrMap(defVals),
      lastValues: _toStrMap(lastVals),
      units: _toStrMap(units),
      icon: r['icon'] as int?,
    );
  }
}
