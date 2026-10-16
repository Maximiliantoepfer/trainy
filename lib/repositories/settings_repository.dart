import '../services/settings_database.dart';

class SettingsRepository {
  SettingsRepository({SettingsDatabase? database})
    : _database = database ?? SettingsDatabase.instance;

  final SettingsDatabase _database;

  Future<int> weeklyGoal() => _database.getWeeklyGoal();
  Future<void> setWeeklyGoal(int value) => _database.setWeeklyGoal(value);
  Future<bool> onboardingDone() => _database.getOnboardingDone();
  Future<void> setOnboardingDone(bool value) =>
      _database.setOnboardingDone(value);
  Future<bool> cloudBackupEnabled() => _database.getSyncEnabled();
  Future<void> setCloudBackupEnabled(bool value) =>
      _database.setSyncEnabled(value);
}
