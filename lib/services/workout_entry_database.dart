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
  /// [sessionDurationSeconds] ist die **Gesamtdauer** der Session und wird in jeder Zeile mitgeschrieben.
  Future<void> insertEntry(
    WorkoutEntry entry, {
    required int sessionDurationSeconds,
  }) async {
    final db = await _db;
    final batch = db.batch();
    int seq = 0;

    entry.results.forEach((exerciseId, values) {
      final jsonMap = <String, dynamic>{};
      values.forEach((k, v) => jsonMap[k] = v);

      batch.insert('workout_entries', {
        'id': DateTime.now().microsecondsSinceEpoch + (seq++),
        'workoutId': entry.workoutId,
        'exerciseId': exerciseId,
        'timestamp': entry.date.millisecondsSinceEpoch,
        'valuesJson': jsonEncode(jsonMap),
        'durationSeconds': sessionDurationSeconds, // <-- Sessiondauer
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });

    await batch.commit(noResult: true);
  }

  /// Aggregierte Einträge zurückgeben (zu Listenaufbau im Progress-Screen geeignet).
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
          if (decoded is Map<String, dynamic>) {
            values = decoded;
          } else if (decoded is Map) {
            values = decoded.map((k, v) => MapEntry(k.toString(), v));
          } else {
            values = <String, dynamic>{};
          }
        } catch (_) {
          values = <String, dynamic>{};
        }

        // sanfte Typ-Normierung
        void _fixNum(String key) {
          final v = values[key];
          if (v == null) return;
          if (key == 'sets' || key == 'reps' || key == 'duration') {
            final parsed = int.tryParse('$v');
            if (parsed != null) values[key] = parsed;
          } else if (key == 'weight') {
            final parsed = double.tryParse('$v');
            if (parsed != null) values[key] = parsed;
          }
        }

        _fixNum('sets');
        _fixNum('reps');
        _fixNum('weight');
        _fixNum('duration');

        resultsMap[exerciseId] = values;
      }

      result.add(
        WorkoutEntry(
          id: pickId ?? DateTime.now().millisecondsSinceEpoch,
          workoutId: workoutId,
          date: DateTime.fromMillisecondsSinceEpoch(ts),
          results: resultsMap,
        ),
      );
    });

    return result;
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
