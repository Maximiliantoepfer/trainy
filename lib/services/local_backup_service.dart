// lib/services/local_backup_service.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:sqflite/sqflite.dart';
import 'app_database.dart';
import 'exercise_image_service.dart';

class LocalBackupService {
  LocalBackupService._();
  static final LocalBackupService instance = LocalBackupService._();

  /// Exportiert die vollständige lokale Datenbank (relevante Tabellen) als JSON-Map.
  Future<Map<String, dynamic>> exportAll() async {
    final db = await AppDatabase.instance.database;
    final result = <String, dynamic>{};
    Future<List<Map<String, Object?>>> q(String table) async =>
        await db.query(table);

    result['version'] = 3;
    result['exportedAt'] = DateTime.now().toIso8601String();
    result['exercises'] = await q('exercises');
    result['workouts'] = await q('workouts');
    result['exercises_in_workouts'] = await q('exercises_in_workouts');
    result['workout_entries'] = await q('workout_entries');
    result['merge_history'] = await q('merge_history');
    result['workout_day_assignments'] = await q('workout_day_assignments');
    result['pinned_charts'] = await q('pinned_charts');
    for (final table in const [
      'exercise_goal_labels',
      'exercise_images',
      'duplicate_suggestions',
      'exercise_redirects',
      'training_profiles',
      'workout_variants',
      'workout_groups',
      'workout_group_variants',
      'workout_variant_group_selections',
      'workout_slots',
      'workout_slot_alternatives',
      'workout_sessions',
      'workout_session_group_selections',
      'workout_session_slot_selections',
    ]) {
      result[table] = await q(table);
    }
    return result;
  }

  /// Versioned, local-only archive. Images are opt-in and never include the
  /// bundled catalog assets.
  Future<Uint8List> exportZip({bool includeImages = true}) async {
    final data = await exportAll();
    final archive =
        Archive()..addFile(
          ArchiveFile('database.json', 0, utf8.encode(jsonEncode(data))),
        );
    if (includeImages) {
      for (final raw in data['exercise_images'] as List<dynamic>? ?? const []) {
        final row = Map<String, dynamic>.from(raw as Map);
        final relative = row['relativePath'] as String?;
        if (relative == null) continue;
        final file = await ExerciseImageService.instance.resolve(relative);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        if (bytes.length > 12 * 1024 * 1024) continue;
        archive.addFile(ArchiveFile('images/$relative', bytes.length, bytes));
      }
    }
    return ZipEncoder().encodeBytes(archive);
  }

  Future<void> restoreZip(Uint8List bytes, {bool replace = true}) async {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    if (archive.length > 5000) {
      throw const FormatException('Archive contains too many files.');
    }
    final databaseFile = archive.find('database.json');
    final databaseBytes = databaseFile?.readBytes();
    if (databaseBytes == null) {
      throw const FormatException('Archive database is missing.');
    }
    final data = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(databaseBytes)) as Map,
    );
    await restoreAll(data, replace: replace);
    for (final item in archive) {
      final name = item.name.replaceAll('\\', '/');
      if (!name.startsWith('images/') ||
          name.contains('..') ||
          item.isDirectory) {
        continue;
      }
      final relative = name.substring('images/'.length);
      final content = item.readBytes();
      if (content == null || content.length > 12 * 1024 * 1024) continue;
      final target = await ExerciseImageService.instance.resolve(
        relative,
        createParent: true,
      );
      await target.writeAsBytes(content, flush: true);
    }
  }

  /// Ersetzt (oder ergänzt) lokale Daten durch ein zuvor exportiertes Backup.
  Future<void> restoreAll(
    Map<String, dynamic> data, {
    bool replace = true,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      if (replace) {
        for (final table in const [
          'workout_session_slot_selections',
          'workout_session_group_selections',
          'workout_sessions',
          'workout_slot_alternatives',
          'workout_slots',
          'workout_variant_group_selections',
          'workout_group_variants',
          'workout_groups',
          'workout_variants',
          'training_profiles',
          'exercise_redirects',
          'duplicate_suggestions',
          'exercise_images',
          'exercise_goal_labels',
        ]) {
          await txn.delete(table);
        }
        await txn.delete('pinned_charts');
        await txn.delete('workout_day_assignments');
        await txn.delete('merge_history');
        await txn.delete('workout_entries');
        await txn.delete('exercises_in_workouts');
        await txn.delete('workouts');
        await txn.delete('exercises');
      }

      Future<void> insertAll(String table, List<dynamic>? rows) async {
        if (rows == null) return;
        for (final row in rows) {
          final map = Map<String, Object?>.from(row as Map);
          if (table == 'exercises') {
            const oldGoals = {
              'Kraft': 'strength',
              'Ausdauer': 'endurance',
              'Cardio': 'cardio',
              'Mobilität': 'mobility',
            };
            final oldGoal = map['goal'];
            if (oldGoal is String && oldGoals.containsKey(oldGoal)) {
              map['goal'] = oldGoals[oldGoal];
            }
            // Older backups predate these fields; SQLite supplies the schema
            // defaults, which preserve user content until catalog reconciliation.
          }
          await txn.insert(
            table,
            map,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      await insertAll('exercises', data['exercises'] as List<dynamic>?);
      await insertAll('workouts', data['workouts'] as List<dynamic>?);
      await insertAll(
        'exercises_in_workouts',
        data['exercises_in_workouts'] as List<dynamic>?,
      );
      await insertAll(
        'workout_entries',
        data['workout_entries'] as List<dynamic>?,
      );
      await insertAll('merge_history', data['merge_history'] as List<dynamic>?);
      await insertAll(
        'workout_day_assignments',
        data['workout_day_assignments'] as List<dynamic>?,
      );
      await insertAll('pinned_charts', data['pinned_charts'] as List<dynamic>?);
      for (final table in const [
        'exercise_goal_labels',
        'exercise_images',
        'duplicate_suggestions',
        'exercise_redirects',
        'training_profiles',
        'workout_variants',
        'workout_groups',
        'workout_group_variants',
        'workout_variant_group_selections',
        'workout_slots',
        'workout_slot_alternatives',
        'workout_sessions',
        'workout_session_group_selections',
        'workout_session_slot_selections',
      ]) {
        await insertAll(table, data[table] as List<dynamic>?);
      }
    });
  }
}
