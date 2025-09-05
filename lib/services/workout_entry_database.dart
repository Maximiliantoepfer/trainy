import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import '../models/workout_entry.dart';

/// Persistiert Workout-Einträge in der Tabelle `workout_entries`.
///
/// Tabellen-Schema (bestehend):
/// id INTEGER PK,
/// workoutId INTEGER,
/// exerciseId INTEGER,
/// timestamp INTEGER (ms since epoch),
/// valuesJson TEXT (JSON der Felder pro Übung/Satz),
/// durationSeconds INTEGER (optionales Feld; wir befüllen es defensiv)
class WorkoutEntryDatabase {
  static final WorkoutEntryDatabase instance = WorkoutEntryDatabase._init();
  WorkoutEntryDatabase._init();

  Future<Database> get _db async => AppDatabase.instance.database;

  /// Bestehende API (von älterem Code genutzt): schreibt **je Satz** eine Zeile.
  Future<void> insertEntries({
    required int workoutId,
    required int durationSeconds,
    required Map<int, List<Map<String, String>>> setsByExercise,
    required DateTime date,
  }) async {
    final db = await _db;
    final batch = db.batch();

    int seq = 0;
    setsByExercise.forEach((exerciseId, sets) {
      for (final set in sets) {
        batch.insert('workout_entries', {
          'id': DateTime.now().microsecondsSinceEpoch + (seq++),
          'workoutId': workoutId,
          'exerciseId': exerciseId,
          'timestamp': date.millisecondsSinceEpoch,
          'valuesJson': jsonEncode(set), // raw Satzwerte
          'durationSeconds': durationSeconds,
        });
      }
    });

    await batch.commit(noResult: true);
  }

  /// Neu: Speichert eine **aggregierte Session** (ein WorkoutEntry) als mehrere Zeilen –
  /// eine Zeile pro Exercise mit dem aggregierten valuesJson.
  Future<void> insertEntry(WorkoutEntry entry) async {
    final db = await _db;
    final batch = db.batch();

    int seq = 0;
    entry.results.forEach((exerciseId, aggregatedValues) {
      // aggregatedValues ist z. B. { 'sets': 3, 'reps': 10, 'weight': 50.0, 'duration': 60 }
      // Wir speichern das Paket direkt als JSON in einer Zeile.
      final jsonMap = <String, dynamic>{};
      aggregatedValues.forEach((k, v) => jsonMap[k] = v);

      // Falls eine Gesamtdauer vorhanden ist, auch ins separate durationSeconds-Feld spiegeln (optional).
      final dur =
          (aggregatedValues['duration'] is int)
              ? aggregatedValues['duration'] as int
              : 0;

      batch.insert('workout_entries', {
        'id': DateTime.now().microsecondsSinceEpoch + (seq++),
        'workoutId': entry.workoutId,
        'exerciseId': exerciseId,
        'timestamp': entry.date.millisecondsSinceEpoch,
        'valuesJson': jsonEncode(jsonMap),
        'durationSeconds': dur,
      });
    });

    await batch.commit(noResult: true);
  }

  /// Neu: Lädt **alle Sessions** und gruppiert die raw-Zeilen nach (workoutId, timestamp)
  /// zu `WorkoutEntry`-Objekten mit `results`-Map.
  Future<List<WorkoutEntry>> getAllEntries() async {
    final db = await _db;

    final rows = await db.query(
      'workout_entries',
      orderBy: 'timestamp DESC, id DESC',
    );
    if (rows.isEmpty) return <WorkoutEntry>[];

    // grouping key: "$workoutId|$timestamp"
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final r in rows) {
      final workoutId = (r['workoutId'] as num).toInt();
      final ts = (r['timestamp'] as num).toInt();
      final key = '$workoutId|$ts';
      (grouped[key] ??= []).add(r);
    }

    final List<WorkoutEntry> result = [];
    grouped.forEach((key, groupRows) {
      // key split
      final parts = key.split('|');
      final workoutId = int.parse(parts[0]);
      final ts = int.parse(parts[1]);

      final resultsMap = <int, Map<String, dynamic>>{};
      int? pickId;

      for (final r in groupRows) {
        pickId ??= (r['id'] as num).toInt();
        final exerciseId = (r['exerciseId'] as num).toInt();

        final valuesStr = r['valuesJson'] as String? ?? '{}';
        Map<String, dynamic> jsonValues;
        try {
          final decoded = jsonDecode(valuesStr);
          if (decoded is Map<String, dynamic>) {
            jsonValues = decoded;
          } else if (decoded is Map) {
            jsonValues = decoded.map((k, v) => MapEntry(k.toString(), v));
          } else {
            jsonValues = <String, dynamic>{};
          }
        } catch (_) {
          jsonValues = <String, dynamic>{};
        }

        // Normierung: Zahlenfelder hart auf int/double casten, wenn erkennbar
        if (jsonValues.containsKey('sets') && jsonValues['sets'] is! int) {
          final v = jsonValues['sets'];
          final parsed = int.tryParse('$v');
          if (parsed != null) jsonValues['sets'] = parsed;
        }
        if (jsonValues.containsKey('reps') && jsonValues['reps'] is! int) {
          final v = jsonValues['reps'];
          final parsed = int.tryParse('$v');
          if (parsed != null) jsonValues['reps'] = parsed;
        }
        if (jsonValues.containsKey('duration') &&
            jsonValues['duration'] is! int) {
          final v = jsonValues['duration'];
          final parsed = int.tryParse('$v');
          if (parsed != null) jsonValues['duration'] = parsed;
        }
        if (jsonValues.containsKey('weight') && jsonValues['weight'] is! num) {
          final v = jsonValues['weight'];
          final parsed = double.tryParse('$v'.replaceAll(',', '.'));
          if (parsed != null) jsonValues['weight'] = parsed;
        }

        resultsMap[exerciseId] = jsonValues;
      }

      result.add(
        WorkoutEntry(
          id: pickId ?? ts, // stabile ID aus erster Zeile (fallback: timestamp)
          workoutId: workoutId,
          date: DateTime.fromMillisecondsSinceEpoch(ts),
          results: resultsMap,
        ),
      );
    });

    // Bereits nach timestamp DESC sortiert durch query; zur Sicherheit nochmal:
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  /// Bestehende Helper-Methode: alle Zeilen zu einem Workout (ungrouped/raw).
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
