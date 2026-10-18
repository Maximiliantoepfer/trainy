import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import '../models/exercise.dart';
import '../data/standard_exercises.dart';

const _legacyCatalogIds = <String, String>{
  'kraft_bankdruecken': 'free:Barbell_Bench_Press_-_Medium_Grip',
  'kraft_kniebeugen': 'free:Barbell_Squat',
  'kraft_kreuzheben': 'free:Barbell_Deadlift',
  'kraft_schulterdruecken': 'free:Barbell_Shoulder_Press',
  'kraft_langhantelrudern': 'free:Bent_Over_Barbell_Row',
  'kraft_liegestuetze': 'free:Pushups',
  'kraft_push_ups': 'free:Pushups',
  'kraft_pull_ups': 'free:Pullups',
};

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
    String? standardKey,
    bool? isNameCustom,
    String? catalogId,
    String? alias,
    String notes = '',
    List<String>? goalCodes,
    List<String>? imagePaths,
    bool isArchived = false,
  }) async {
    Map<String, Object?>? existing;
    if (id != null) {
      final rows = await (await _db).query(
        'exercises',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isNotEmpty) existing = rows.first;
    }
    final existingStandardKey = existing?['standardKey'] as String?;
    final existingName = existing?['name'] as String?;
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
      standardKey: standardKey ?? existingStandardKey,
      catalogId: catalogId ?? existing?['catalogId'] as String?,
      alias: alias ?? existing?['alias'] as String?,
      notes: notes,
      goalCodes: _validatedGoals(goalCodes ?? _legacyGoalList(goal)),
      imagePaths: imagePaths ?? const [],
      isArchived: isArchived,
      isNameCustom:
          isNameCustom ??
          (existingStandardKey != null && existingName != name
              ? true
              : ((existing?['isNameCustom'] as num?)?.toInt() == 1)),
    );
    await upsertExercise(e);
    return exerciseId;
  }

  // ---- Kernmethoden ----

  Future<void> upsertExercise(Exercise e) async {
    final db = await _db;
    await db.transaction((txn) async {
      final values = <String, Object?>{
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
        'standardKey': e.standardKey,
        'catalogId': e.catalogId,
        'origin': e.catalogId == null ? 'custom' : 'catalog',
        'alias': e.alias,
        'notes': e.notes,
        'isArchived': e.isArchived ? 1 : 0,
        'isNameCustom': e.isNameCustom ? 1 : 0,
      };
      // REPLACE deletes the old row and cascades decided duplicate suggestions
      // and history links. Updating in place preserves these references.
      final count = await txn.update(
        'exercises',
        values,
        where: 'id = ?',
        whereArgs: [e.id],
      );
      if (count == 0) await txn.insert('exercises', values);
      await txn.delete(
        'exercise_goal_labels',
        where: 'exerciseId = ?',
        whereArgs: [e.id],
      );
      final validatedGoals = _validatedGoals(e.goalCodes);
      for (var index = 0; index < validatedGoals.length; index++) {
        await txn.insert('exercise_goal_labels', {
          'exerciseId': e.id,
          'goalCode': validatedGoals[index],
          'position': index,
        });
      }
      await txn.delete(
        'exercise_images',
        where: 'exerciseId = ?',
        whereArgs: [e.id],
      );
      for (var index = 0; index < e.imagePaths.length; index++) {
        await txn.insert('exercise_images', {
          'id': DateTime.now().microsecondsSinceEpoch + index,
          'exerciseId': e.id,
          'relativePath': e.imagePaths[index],
          'isCover': index == 0 ? 1 : 0,
          'sort': index,
        });
      }
    });
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
      where: 'isArchived = 0',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    final labelRows = await db.query('exercise_goal_labels');
    final labels = <int, List<String>>{};
    for (final row in labelRows) {
      labels
          .putIfAbsent((row['exerciseId'] as num).toInt(), () => [])
          .add(row['goalCode'] as String);
    }
    final imageRows = await db.query('exercise_images', orderBy: 'sort ASC');
    final images = <int, List<String>>{};
    for (final row in imageRows) {
      images
          .putIfAbsent((row['exerciseId'] as num).toInt(), () => [])
          .add(row['relativePath'] as String);
    }
    return rows.map((row) => _fromRow(row, labels, images)).toList();
  }

  Future<int?> findExerciseIdByCatalogId(String catalogId) async {
    final rows = await (await _db).query(
      'exercises',
      columns: ['id'],
      where: 'catalogId = ?',
      whereArgs: [catalogId],
      limit: 1,
    );
    return rows.isEmpty ? null : (rows.single['id'] as num).toInt();
  }

  Future<void> deleteExercise(int id) async {
    final db = await _db;
    await db.update(
      'exercises',
      {'isArchived': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
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
    // Name-Vergleich in Dart statt SQL (SQLite LOWER() handelt nur ASCII)
    final rows = await db.rawQuery(
      'SELECT id, name FROM exercises '
      'WHERE trackedFields = ? '
      'AND (goal = ? OR (goal IS NULL AND ? IS NULL))',
      [trackedJson, goal, goal],
    );
    final nameLower = name.toLowerCase();
    for (final row in rows) {
      if ((row['name'] as String).toLowerCase() == nameLower) {
        return (row['id'] as num).toInt();
      }
    }
    return null;
  }

  /// Kept for source compatibility. Duplicates are now only suggestions and
  /// are never merged automatically.
  Future<void> deduplicateExercises() async {
    return;
  }

  Future<void> refreshDuplicateSuggestions(
    Map<String, Iterable<String>> catalogNames,
  ) async {
    final db = await _db;
    final exercises = await getAllExercises();
    final catalogByName = <String, Set<String>>{};
    for (final entry in catalogNames.entries) {
      for (final name in entry.value) {
        final normalized = _normalizedName(name);
        if (normalized.isEmpty) continue;
        catalogByName.putIfAbsent(normalized, () => <String>{}).add(entry.key);
      }
    }
    final candidates = <int, String>{};
    for (final exercise in exercises.where((item) => item.catalogId == null)) {
      final matches = <String>{};
      for (final value in [exercise.name, exercise.alias]) {
        if (value == null || value.trim().isEmpty) continue;
        matches.addAll(
          catalogByName[_normalizedName(value)] ?? const <String>{},
        );
      }
      // An ambiguous label can describe different catalog exercises.  It is
      // safer to show no automatic proposal than to point at the wrong one.
      if (matches.length != 1) continue;
      final targetCatalogId = matches.single;
      candidates[exercise.id] = targetCatalogId;
    }
    await db.transaction((txn) async {
      final existing = await txn.query(
        'duplicate_suggestions',
        orderBy: "CASE WHEN status = 'open' THEN 1 ELSE 0 END, id",
      );
      final known = <String>{};
      for (final row in existing) {
        final source = (row['sourceExerciseId'] as num).toInt();
        final target = row['targetCatalogId'];
        final key = '$source:$target';
        if (row['status'] == 'open' &&
            (candidates[source] != target || known.contains(key))) {
          await txn.delete(
            'duplicate_suggestions',
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        } else {
          known.add(key);
        }
      }
      for (final entry in candidates.entries) {
        if (known.contains('${entry.key}:${entry.value}')) continue;
        await txn.insert('duplicate_suggestions', {
          'sourceExerciseId': entry.key,
          'targetCatalogId': entry.value,
          'confidence': 'high',
          'status': 'open',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }

  Future<List<DuplicateSuggestion>> getOpenDuplicateSuggestions() async {
    final rows = await (await _db).query(
      'duplicate_suggestions',
      where: "status = 'open'",
      orderBy: 'createdAt DESC',
    );
    return rows
        .map(
          (row) => DuplicateSuggestion(
            id: (row['id'] as num).toInt(),
            sourceExerciseId: (row['sourceExerciseId'] as num).toInt(),
            targetExerciseId: row['targetExerciseId'] as int?,
            targetCatalogId: row['targetCatalogId'] as String?,
            confidence: row['confidence'] as String,
          ),
        )
        .toList();
  }

  Future<void> setDuplicateSuggestionStatus(int id, String status) async {
    await (await _db).update(
      'duplicate_suggestions',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---- Helpers ----

  /// Reconciles old 36-item seed rows only. The full catalog is asset-backed,
  /// so no database rows are seeded anymore.
  Future<void> ensureStandardExercises() async {
    final db = await _db;
    await _reconcileLegacyCatalog(db);
  }

  /// Links old, unmodified German seed data to a stable catalog key. We only
  /// touch an exact, unambiguous name match. This also covers old backups,
  /// which did not contain the `seeded_standards` bookkeeping table.
  /// Renamed and custom exercises retain their own names because they cannot
  /// match a catalog name exactly.
  Future<void> _reconcileLegacyCatalog(Database db) async {
    for (final std in standardExercises) {
      final matches = await db.query(
        'exercises',
        columns: ['id'],
        where: 'name = ? AND catalogId IS NULL AND isNameCustom = 0',
        whereArgs: [std.name],
      );
      if (matches.length != 1) continue;
      await db.update(
        'exercises',
        {
          'standardKey': std.key,
          'catalogId': _legacyCatalogIds[std.key],
          'origin':
              _legacyCatalogIds.containsKey(std.key) ? 'catalog' : 'custom',
          'isNameCustom': _legacyCatalogIds.containsKey(std.key) ? 0 : 1,
          'goal': std.goal,
        },
        where: 'id = ?',
        whereArgs: [matches.first['id']],
      );
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
        ) ??
        0;
  }

  /// Lädt alle Merge-Aliase (sourceName → targetId) in einem Query.
  Future<Map<int, List<String>>> getAllMergeAliases() async {
    final db = await _db;
    final rows = await db.query(
      'merge_history',
      columns: ['targetId', 'sourceName'],
    );
    final map = <int, List<String>>{};
    for (final r in rows) {
      final targetId = (r['targetId'] as num).toInt();
      final sourceName = r['sourceName'] as String;
      map.putIfAbsent(targetId, () => []).add(sourceName);
    }
    return map;
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

  /// Gibt die vollständigen Merge-History-Einträge für [exerciseId] zurück.
  Future<List<Map<String, dynamic>>> getMergeHistoryFull(int exerciseId) async {
    final db = await _db;
    return db.query(
      'merge_history',
      where: 'targetId = ?',
      whereArgs: [exerciseId],
      orderBy: 'mergedAt DESC',
    );
  }

  /// Entfernt einen Merge-History-Eintrag. Falls die Quell-Übung eine
  /// Standardübung war, wird sie in seeded_standards eingetragen um
  /// erneutes Seeding zu verhindern.
  Future<void> deleteMergeHistoryEntry(int id) async {
    final db = await _db;
    final rows = await db.query(
      'merge_history',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return;
    final sourceKey = rows.first['sourceKey'] as String?;
    if (sourceKey != null) {
      await db.insert('seeded_standards', {
        'key': sourceKey,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await db.delete('merge_history', where: 'id = ?', whereArgs: [id]);
  }

  /// Redirects a personal exercise to a target without touching completed
  /// entries. The source is archived and can be restored with [undoMerge].
  Future<MergeResult> mergeExercises(int sourceId, int targetId) async {
    final db = await _db;
    return db.transaction((txn) async {
      final sourceRows = await txn.query(
        'exercises',
        where: 'id = ?',
        whereArgs: [sourceId],
        limit: 1,
      );
      if (sourceRows.isEmpty) {
        throw StateError('Source exercise no longer exists.');
      }
      final source = Map<String, Object?>.from(sourceRows.single);
      // Workout definitions and historical entries remain untouched. Active
      // redirects are resolved when a workout is loaded for its next run.
      const changedLinks = <Map<String, Object?>>[];
      final sourceName = source['name'] as String? ?? 'Unknown';
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.update(
        'exercises',
        {'isArchived': 1},
        where: 'id = ?',
        whereArgs: [sourceId],
      );
      await txn.insert('exercise_redirects', {
        'id': DateTime.now().microsecondsSinceEpoch,
        'sourceExerciseId': sourceId,
        'targetExerciseId': targetId,
        'sourceSnapshotJson': jsonEncode(source),
        'changedWorkoutMappingsJson': jsonEncode(changedLinks),
        'createdAt': now,
      });
      // Preserve compatibility with the old history screen; no entries are
      // migrated and the source row is retained as an archived record.
      await txn.insert('merge_history', {
        'sourceName': sourceName,
        'sourceKey': source['standardKey'],
        'targetId': targetId,
        'mergedAt': DateTime.now().toUtc().toIso8601String(),
      });
      return const MergeResult(movedEntries: 0, movedWorkouts: 0);
    });
  }

  Future<void> undoMerge(int redirectId) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'exercise_redirects',
        where: 'id = ? AND undoneAt IS NULL',
        whereArgs: [redirectId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final redirect = rows.single;
      final sourceId = (redirect['sourceExerciseId'] as num).toInt();
      final originalLinks = List<dynamic>.from(
        jsonDecode(redirect['changedWorkoutMappingsJson'] as String) as List,
      );
      await txn.update(
        'exercises',
        {'isArchived': 0},
        where: 'id = ?',
        whereArgs: [sourceId],
      );
      for (final rawLink in originalLinks) {
        final link = Map<String, dynamic>.from(rawLink as Map);
        final action = link.remove('redirectAction');
        if (action == 'retargeted_link') {
          await txn.update(
            'exercises_in_workouts',
            {'exerciseId': sourceId},
            where: 'id = ?',
            whereArgs: [link['id']],
          );
        } else {
          await txn.insert(
            'exercises_in_workouts',
            link,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      await txn.update(
        'exercise_redirects',
        {'undoneAt': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [redirectId],
      );
    });
  }

  Future<List<Map<String, dynamic>>> getActiveRedirectsForTarget(
    int targetId,
  ) async {
    final rows = await (await _db).query(
      'exercise_redirects',
      where: 'targetExerciseId = ? AND undoneAt IS NULL',
      whereArgs: [targetId],
      orderBy: 'createdAt DESC',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  // ---- Helpers ----

  Exercise _fromRow(
    Map<String, Object?> r,
    Map<int, List<String>> labels,
    Map<int, List<String>> images,
  ) {
    Map<String, dynamic> parseMap(Object? v) {
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

    final tracked = parseMap(r['trackedFields']);
    final defVals = parseMap(r['defaultValues']);
    final lastVals = parseMap(r['lastValues']);
    final units = parseMap(r['units']);

    bool tf(String key) => (tracked[key] ?? false) == true;

    Map<String, String> toStrMap(Map<String, dynamic> m) =>
        m.map((k, v) => MapEntry(k, v?.toString() ?? ''));

    final id = (r['id'] as num).toInt();
    return Exercise(
      id: id,
      name: (r['name'] ?? '') as String,
      description: (r['description'] ?? '') as String,
      trackSets: tf('sets'),
      trackReps: tf('reps'),
      trackWeight: tf('weight'),
      trackDuration: tf('duration'),
      trackDistance: tf('distance'),
      defaultValues: toStrMap(defVals),
      lastValues: toStrMap(lastVals),
      units: toStrMap(units),
      icon: r['icon'] as int?,
      goal: r['goal'] as String?,
      standardKey: r['standardKey'] as String?,
      catalogId: r['catalogId'] as String?,
      alias: r['alias'] as String?,
      notes: r['notes'] as String? ?? '',
      goalCodes: labels[id] ?? _legacyGoalList(r['goal'] as String?),
      imagePaths: images[id] ?? const [],
      isArchived: ((r['isArchived'] as num?)?.toInt() ?? 0) == 1,
      isNameCustom: ((r['isNameCustom'] as num?)?.toInt() ?? 1) == 1,
    );
  }

  static List<String> _legacyGoalList(String? goal) {
    const allowed = {'strength', 'endurance', 'cardio', 'mobility'};
    return goal != null && allowed.contains(goal) ? [goal] : const [];
  }

  static List<String> _validatedGoals(Iterable<String> values) {
    const allowed = {'strength', 'endurance', 'cardio', 'mobility'};
    final result = <String>[];
    for (final value in values) {
      if (allowed.contains(value) && !result.contains(value)) result.add(value);
      if (result.length == 2) break;
    }
    if (result.isEmpty) return const ['strength'];
    const domains = {'strength', 'cardio', 'mobility'};
    if (!result.any(domains.contains)) {
      result.insert(0, 'cardio');
      if (result.length > 2) result.removeLast();
    }
    result.sort((a, b) {
      final ad = domains.contains(a);
      final bd = domains.contains(b);
      return ad == bd ? 0 : (ad ? -1 : 1);
    });
    return result;
  }

  static String _normalizedName(String value) => value
      .toLowerCase()
      .replaceAll('ä', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

class MergeResult {
  final int movedEntries;
  final int movedWorkouts;
  const MergeResult({required this.movedEntries, required this.movedWorkouts});
}
