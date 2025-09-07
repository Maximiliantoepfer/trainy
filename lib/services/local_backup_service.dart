// lib/services/local_backup_service.dart
import 'package:sqflite/sqflite.dart';
import 'app_database.dart';

class LocalBackupService {
  LocalBackupService._();
  static final LocalBackupService instance = LocalBackupService._();

  /// Exportiert die vollständige lokale Datenbank (relevante Tabellen) als JSON-Map.
  Future<Map<String, dynamic>> exportAll() async {
    final db = await AppDatabase.instance.database;
    final result = <String, dynamic>{};
    Future<List<Map<String, Object?>>> q(String table) async =>
        await db.query(table);

    result['version'] = 1;
    result['exportedAt'] = DateTime.now().toIso8601String();
    result['exercises'] = await q('exercises');
    result['workouts'] = await q('workouts');
    result['exercises_in_workouts'] = await q('exercises_in_workouts');
    result['workout_entries'] = await q('workout_entries');
    return result;
  }

  /// Ersetzt (oder ergänzt) lokale Daten durch ein zuvor exportiertes Backup.
  Future<void> restoreAll(
    Map<String, dynamic> data, {
    bool replace = true,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      if (replace) {
        await txn.delete('workout_entries');
        await txn.delete('exercises_in_workouts');
        await txn.delete('workouts');
        await txn.delete('exercises');
      }

      Future<void> insertAll(String table, List<dynamic>? rows) async {
        if (rows == null) return;
        for (final row in rows) {
          final map = Map<String, Object?>.from(row as Map);
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
    });
  }
}
