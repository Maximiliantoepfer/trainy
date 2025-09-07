// lib/services/settings_database.dart

import 'package:sqflite/sqflite.dart';
import 'app_database.dart';

class SettingsDatabase {
  static final SettingsDatabase instance = SettingsDatabase._init();
  SettingsDatabase._init();

  Future<Database> get _db async => AppDatabase.instance.database;

  Future<int> getWeeklyGoal() async {
    final db = await _db;
    final result = await db.query('user_settings', limit: 1);
    if (result.isNotEmpty) {
      return (result.first['weekly_goal'] ?? 2) as int;
    } else {
      await db.insert('user_settings', {
        'id': 0,
        'weekly_goal': 2,
        'sync_enabled': 0,
        'last_sync_millis': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return 2;
    }
  }

  Future<void> setWeeklyGoal(int value) async {
    final db = await _db;
    await db.update(
      'user_settings',
      {'weekly_goal': value},
      where: 'id = ?',
      whereArgs: [0],
    );
  }

  // --- Cloud Sync Flags ---
  Future<bool> getSyncEnabled() async {
    final db = await _db;
    final r = await db.query('user_settings', limit: 1);
    if (r.isNotEmpty) {
      final v = (r.first['sync_enabled'] ?? 0) as int;
      return v == 1;
    }
    return false;
  }

  Future<void> setSyncEnabled(bool enabled) async {
    final db = await _db;
    await db.update(
      'user_settings',
      {'sync_enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [0],
    );
  }

  Future<int> getLastSyncMillis() async {
    final db = await _db;
    final r = await db.query('user_settings', limit: 1);
    if (r.isNotEmpty) {
      return (r.first['last_sync_millis'] ?? 0) as int;
    }
    return 0;
  }

  Future<void> setLastSyncMillis(int tsMillis) async {
    final db = await _db;
    await db.update(
      'user_settings',
      {'last_sync_millis': tsMillis},
      where: 'id = ?',
      whereArgs: [0],
    );
  }
}
