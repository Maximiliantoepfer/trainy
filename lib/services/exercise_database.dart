import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import '../models/exercise.dart';
import '../data/standard_exercises.dart';

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
    bool trackDistance = false,
    Map<String, String>? defaultValues,
    Map<String, String>? lastValues,
    Map<String, String>? units,
    int? icon,
    String? goal,
  }) async {
    // Dedup: Bei neuer Übung prüfen, ob identische schon existiert
    if (id == null) {
      final existingId = await findByIdentity(
        name: name, goal: goal,
        trackSets: trackSets, trackReps: trackReps,
        trackWeight: trackWeight, trackDuration: trackDuration,
        trackDistance: trackDistance,
      );
      if (existingId != null) return existingId;
    }

    final exerciseId = id ?? DateTime.now().millisecondsSinceEpoch;
    final e = Exercise(
      id: exerciseId,
      name: name,
      description: description,
      trackSets: trackSets,
      trackReps: trackReps,
      trackWeight: trackWeight,
      trackDuration: trackDuration,
      trackDistance: trackDistance,
      defaultValues: defaultValues ?? const {},
      lastValues: lastValues ?? const {},
      units: units ?? const {},
      icon: icon,
      goal: goal,
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
        'distance': e.trackDistance,
      }),
      'defaultValues': jsonEncode(e.defaultValues),
      'lastValues': jsonEncode(e.lastValues),
      'units': jsonEncode(e.units),
      'icon': e.icon,
      'goal': e.goal,
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

  // ---- Dedup ----

  /// Sucht eine bestehende Übung mit identischer Identität
  /// (Name case-insensitive + Ziel + Tracking-Felder).
  Future<int?> findByIdentity({
    required String name,
    required String? goal,
    required bool trackSets,
    required bool trackReps,
    required bool trackWeight,
    required bool trackDuration,
    bool trackDistance = false,
  }) async {
    final db = await _db;
    final trackedJson = jsonEncode({
      'sets': trackSets,
      'reps': trackReps,
      'weight': trackWeight,
      'duration': trackDuration,
      'distance': trackDistance,
    });
    final rows = await db.rawQuery(
      'SELECT id FROM exercises '
      'WHERE LOWER(name) = LOWER(?) '
      'AND trackedFields = ? '
      'AND (goal = ? OR (goal IS NULL AND ? IS NULL)) '
      'LIMIT 1',
      [name, trackedJson, goal, goal],
    );
    if (rows.isEmpty) return null;
    return (rows.first['id'] as num).toInt();
  }

  /// Bereinigt bestehende Duplikate beim App-Start.
  /// Gruppiert Übungen nach Identität und mergt Duplikate in die
  /// Übung mit den meisten Workout-Einträgen.
  Future<void> deduplicateExercises() async {
    final exercises = await getAllExercises();

    final groups = <String, List<Exercise>>{};
    for (final e in exercises) {
      final key = '${e.name.toLowerCase()}'
          '|${e.goal}'
          '|${e.trackSets}|${e.trackReps}|${e.trackWeight}|${e.trackDuration}|${e.trackDistance}';
      groups.putIfAbsent(key, () => []).add(e);
    }

    for (final group in groups.values) {
      if (group.length <= 1) continue;

      // Gewinner = Übung mit den meisten Einträgen
      int winnerId = group.first.id;
      int maxEntries = 0;
      for (final e in group) {
        final count = await countEntriesForExercise(e.id);
        if (count > maxEntries) {
          maxEntries = count;
          winnerId = e.id;
        }
      }

      // Alle anderen in den Gewinner mergen
      for (final e in group) {
        if (e.id == winnerId) continue;
        await mergeExercises(e.id, winnerId);
      }
    }
  }

  // ---- Helpers ----

  /// Stellt sicher, dass alle Standardübungen in der DB vorhanden sind.
  /// Neue Übungen werden nur eingefügt, wenn ihr Key noch nicht in
  /// `seeded_standards` eingetragen ist. Dadurch bleibt eine vom User
  /// umbenannte Standardübung erhalten, ohne dass das Original erneut
  /// angelegt wird.
  Future<void> ensureStandardExercises() async {
    final db = await _db;
    for (final std in standardExercises) {
      final existing = await db.query(
        'seeded_standards',
        where: 'key = ?',
        whereArgs: [std.key],
      );
      if (existing.isNotEmpty) continue;

      // Guard A: War diese Standardübung schon mal gemergt?
      final mergedAway = await db.query(
        'merge_history',
        where: 'sourceKey = ?',
        whereArgs: [std.key],
        limit: 1,
      );
      if (mergedAway.isNotEmpty) {
        await db.insert('seeded_standards', {'key': std.key},
            conflictAlgorithm: ConflictAlgorithm.ignore);
        continue;
      }

      // Guard B: Existiert bereits eine Übung mit gleichem Namen?
      final nameMatch = await db.rawQuery(
        'SELECT id FROM exercises WHERE LOWER(name) = LOWER(?) LIMIT 1',
        [std.name],
      );
      if (nameMatch.isNotEmpty) {
        await db.insert('seeded_standards', {'key': std.key},
            conflictAlgorithm: ConflictAlgorithm.ignore);
        continue;
      }

      await addOrUpdateExercise(
        name: std.name,
        trackSets: std.trackSets,
        trackReps: std.trackReps,
        trackWeight: std.trackWeight,
        trackDuration: std.trackDuration,
        trackDistance: std.trackDistance,
        goal: std.goal,
      );
      await db.insert('seeded_standards', {'key': std.key});
    }
  }

  // ---- Merge ----

  /// Zählt wie viele workout_entries für eine Übung existieren.
  Future<int> countEntriesForExercise(int exerciseId) async {
    final db = await _db;
    return Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM workout_entries WHERE exerciseId = ?',
        [exerciseId],
      ),
    ) ?? 0;
  }

  /// Gibt die Namen aller Übungen zurück, die in [exerciseId] zusammengeführt wurden.
  Future<List<String>> getMergeHistory(int exerciseId) async {
    final db = await _db;
    final rows = await db.query(
      'merge_history',
      columns: ['sourceName'],
      where: 'targetId = ?',
      whereArgs: [exerciseId],
      orderBy: 'mergedAt ASC',
    );
    return rows.map((r) => r['sourceName'] as String).toList();
  }

  /// Führt [sourceId] in [targetId] zusammen.
  /// Alle workout_entries und Workout-Zuordnungen werden auf target übertragen,
  /// die Quell-Übung wird gelöscht.
  Future<MergeResult> mergeExercises(int sourceId, int targetId) async {
    final db = await _db;
    return db.transaction((txn) async {
      // 1. workout_entries: sourceId → targetId
      final movedEntries = await txn.rawUpdate(
        'UPDATE workout_entries SET exerciseId = ? WHERE exerciseId = ?',
        [targetId, sourceId],
      );

      // 2. exercises_in_workouts: sourceId → targetId
      //    Wenn target schon im selben Workout → source-Eintrag löschen
      final sourceLinks = await txn.query(
        'exercises_in_workouts',
        where: 'exerciseId = ?',
        whereArgs: [sourceId],
      );
      int movedWorkouts = 0;
      for (final link in sourceLinks) {
        final workoutId = link['workoutId'] as int;
        final targetExists = await txn.query(
          'exercises_in_workouts',
          where: 'workoutId = ? AND exerciseId = ?',
          whereArgs: [workoutId, targetId],
        );
        if (targetExists.isNotEmpty) {
          await txn.delete(
            'exercises_in_workouts',
            where: 'id = ?',
            whereArgs: [link['id']],
          );
        } else {
          await txn.update(
            'exercises_in_workouts',
            {'exerciseId': targetId},
            where: 'id = ?',
            whereArgs: [link['id']],
          );
          movedWorkouts++;
        }
      }

      // 3. Source-Name nachschlagen (vor Löschung)
      final sourceRows = await txn.query(
        'exercises',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [sourceId],
      );
      final sourceName = sourceRows.isNotEmpty
          ? sourceRows.first['name'] as String
          : 'Unbekannt';

      // 4. Prüfen ob Source eine Standardübung war (Name → Key)
      String? sourceKey;
      for (final std in standardExercises) {
        if (std.name.toLowerCase() == sourceName.toLowerCase()) {
          sourceKey = std.key;
          break;
        }
      }

      // 5. Ketten-Handling: A→B, dann B→C ⇒ A→C + B→C
      await txn.rawUpdate(
        'UPDATE merge_history SET targetId = ? WHERE targetId = ?',
        [targetId, sourceId],
      );

      // 6. Merge protokollieren
      await txn.insert('merge_history', {
        'sourceName': sourceName,
        'sourceKey': sourceKey,
        'targetId': targetId,
        'mergedAt': DateTime.now().toUtc().toIso8601String(),
      });

      // 7. Quell-Übung löschen
      await txn.delete('exercises', where: 'id = ?', whereArgs: [sourceId]);

      return MergeResult(movedEntries: movedEntries, movedWorkouts: movedWorkouts);
    });
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
      trackDistance: tf('distance'),
      defaultValues: _toStrMap(defVals),
      lastValues: _toStrMap(lastVals),
      units: _toStrMap(units),
      icon: r['icon'] as int?,
      goal: r['goal'] as String?,
    );
  }
}

class MergeResult {
  final int movedEntries;
  final int movedWorkouts;
  const MergeResult({required this.movedEntries, required this.movedWorkouts});
}
