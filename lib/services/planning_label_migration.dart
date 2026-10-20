import 'dart:convert';
import 'package:sqflite/sqflite.dart';

/// Repair only exact generated defaults. Session snapshots and custom names
/// are never rewritten, including completed cardio occurrence snapshots.
abstract final class PlanningLabelMigration {
  static Future<void> apply(DatabaseExecutor db) async {
    if ((await db.query(
      'app_meta',
      where: 'key=?',
      whereArgs: ['planning_labels_v1'],
    )).isNotEmpty) {
      return;
    }
    for (final row in await db.query(
      'workout_templates',
      where: "id LIKE 'generated:%' AND name='pullLegs'",
    )) {
      await db.update(
        'workout_templates',
        {'name': 'Pull + Legs'},
        where: 'id=?',
        whereArgs: [row['id']],
      );
      await db.update(
        'workouts',
        {'name': 'Pull + Legs'},
        where: 'id=? AND name=?',
        whereArgs: [row['legacy_local_id'], 'pullLegs'],
      );
    }
    for (final row in await db.query(
      'cardio_occurrences',
      where: "status='planned' AND locked=0 AND session_id IS NULL",
    )) {
      final data = Map<String, dynamic>.from(
        jsonDecode(row['workout_json'] as String) as Map,
      );
      if (data['templateCode'] != 'easySession' ||
          data['name'] != 'Lockere Dauereinheit') {
        continue;
      }
      data['name'] = 'Dauerlauf';
      await db.update(
        'cardio_occurrences',
        {'workout_json': jsonEncode(data)},
        where: 'id=?',
        whereArgs: [row['id']],
      );
    }
    await db.insert('app_meta', {'key': 'planning_labels_v1', 'value': '1'});
  }
}
