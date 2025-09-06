import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import '../models/workout_entry.dart';

/// Persistiert Workout-Sessions.
/// Eine Session wird als mehrere Zeilen gespeichert – **eine Zeile pro Exercise**.
/// `valuesJson` enthält aggregierte Werte (z. B. letzte Wdh./Gewicht, Sets, Dauer).
class WorkoutEntryDatabase {
  static final WorkoutEntryDatabase instance = WorkoutEntryDatabase._init();
  WorkoutEntryDatabase._init();

  Future<Database> get _db async => AppDatabase.instance.database;

  /// Insert eine aggregierte Session: Eine Zeile pro Exercise.
  Future<void> insertEntry(
    WorkoutEntry entry, {
    required int sessionDurationSeconds,
  }) async {
    final db = await _db;
    final ts = entry.date.millisecondsSinceEpoch;

    final batch = db.batch();
    entry.results.forEach((exerciseId, values) {
      final jsonMap = Map<String, dynamic>.from(values);
      batch.insert('workout_entries', {
        'workoutId': entry.workoutId,
        'exerciseId': exerciseId,
        'timestamp': ts,
        'valuesJson': jsonEncode(jsonMap),
        'durationSeconds': sessionDurationSeconds, // Session-Dauer in Sek.
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });

    await batch.commit(noResult: true);
  }

  /// Aggregierte Einträge für den Progress-Screen.
  Future<List<WorkoutEntry>> getAggregatedEntries() async {
    final db = await _db;
    final rows = await db.query(
      'workout_entries',
      orderBy: 'timestamp DESC, id DESC',
    );

    // Gruppieren nach (workoutId, timestamp)
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final r in rows) {
      final key = '${r['workoutId']}|${r['timestamp']}';
      grouped.putIfAbsent(key, () => []).add(r);
    }

    final result = <WorkoutEntry>[];
    grouped.forEach((key, groupRows) {
      final parts = key.split('|');
      final workoutId = int.parse(parts[0]);
      final ts = int.parse(parts[1]);

      final resultsMap = <int, Map<String, dynamic>>{};
      int? pickId;

      for (final r in groupRows) {
        pickId ??= (r['id'] as num).toInt();
        final exerciseId = (r['exerciseId'] as num).toInt();

        Map<String, dynamic> values;
        try {
          final decoded = jsonDecode((r['valuesJson'] as String?) ?? '{}');
          values =
              decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
        } catch (_) {
          values = <String, dynamic>{};
        }

        // Typ-Normalisierung
        Map<String, dynamic> fixed = Map<String, dynamic>.from(values);
        void _fixNum(String key) {
          final v = fixed[key];
          if (v == null) return;
          if (key == 'sets' || key == 'reps' || key == 'duration') {
            if (v is int) return;
            if (v is String) {
              final parsed = int.tryParse(v);
              if (parsed != null) fixed[key] = parsed;
            } else if (v is num) {
              fixed[key] = v.toInt();
            }
          } else if (key == 'weight') {
            if (v is double) return;
            if (v is String) {
              final parsed = double.tryParse(v);
              if (parsed != null) fixed[key] = parsed;
            } else if (v is num) {
              fixed[key] = v.toDouble();
            }
          }
        }

        _fixNum('sets');
        _fixNum('reps');
        _fixNum('weight');
        _fixNum('duration');

        resultsMap[exerciseId] = fixed;
      }

      result.add(
        WorkoutEntry(
          id: pickId ?? ts, // Fallback
          workoutId: workoutId,
          date: DateTime.fromMillisecondsSinceEpoch(ts),
          results: resultsMap,
        ),
      );
    });

    return result;
  }

  /// **NEU**: Einzelne Kennzahl (z. B. 'sets' | 'reps' | 'weight' | 'duration')
  /// innerhalb einer Zeile aktualisieren.
  ///
  /// Die Zeile wird eindeutig über (workoutId, exerciseId, timestamp) gefunden.
  Future<void> updateMetric({
    required int workoutId,
    required int exerciseId,
    required int timestamp,
    required String field,
    required num value,
  }) async {
    final db = await _db;

    final rows = await db.query(
      'workout_entries',
      where: 'workoutId = ? AND exerciseId = ? AND timestamp = ?',
      whereArgs: [workoutId, exerciseId, timestamp],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final row = rows.first;
    Map<String, dynamic> map;
    try {
      map =
          jsonDecode((row['valuesJson'] as String?) ?? '{}')
              as Map<String, dynamic>;
    } catch (_) {
      map = {};
    }

    // Feld setzen (bestehende bleiben unverändert)
    map[field] = value;

    await db.update(
      'workout_entries',
      {'valuesJson': jsonEncode(map)},
      where: 'id = ?',
      whereArgs: [(row['id'] as num).toInt()],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Rohdaten (alle Zeilen) eines Workouts
  Future<List<Map<String, dynamic>>> getEntriesForWorkout(int workoutId) async {
    final db = await _db;
    return db.query(
      'workout_entries',
      where: 'workoutId = ?',
      whereArgs: [workoutId],
      orderBy: 'timestamp DESC, id DESC',
    );
  }
}
