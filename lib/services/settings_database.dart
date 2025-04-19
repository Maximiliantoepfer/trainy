import 'package:sqflite/sqflite.dart';
import 'app_database.dart';

class SettingsDatabase {
  static final SettingsDatabase instance = SettingsDatabase._init();
  SettingsDatabase._init();

  Future<Database> get _db async => await AppDatabase.instance.database;

  Future<int> getWeeklyGoal() async {
    final db = await _db;
    final result = await db.query('user_settings', limit: 1);
    if (result.isNotEmpty) {
      return result.first['weekly_goal'] as int;
    } else {
      await db.insert('user_settings', {'weekly_goal': 2});
      return 2;
    }
  }

  Future<void> setWeeklyGoal(int value) async {
    final db = await _db;
    await db.insert('user_settings', {
      'weekly_goal': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
