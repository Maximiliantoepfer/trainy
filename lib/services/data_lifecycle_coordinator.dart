import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'database_schema_v2.dart';
import 'exercise_image_service.dart';
import 'settings_database.dart';

/// Coordinates destructive data transitions independently of the UI.
///
/// The epoch marker is written only after the new database passed both the
/// SQLite integrity and foreign-key checks. Consequently an interrupted reset
/// is safely repeated on the next start.
class DataLifecycleCoordinator {
  DataLifecycleCoordinator._();

  static final instance = DataLifecycleCoordinator._();

  static const _epochPreferenceKey = 'training_data_epoch';
  static const accountDeletionPendingKey = 'account_deletion_pending';
  static const _legacyDatabaseNames = <String>['trainy.db'];
  static const _temporaryDirectoryNames = <String>[
    'trainy_imports',
    'trainy_restore',
  ];

  Future<void> applyDataEpoch() async {
    final preferences = await SharedPreferences.getInstance();
    var resetPerformed = false;
    if (preferences.getInt(_epochPreferenceKey) != DatabaseSchemaV2.dataEpoch) {
      await _deleteTrainingFiles(includeV2: true);
      resetPerformed = true;
    }
    try {
      final db = await AppDatabase.instance.database;
      await AppDatabase.instance.assertIntegrity(database: db);
    } catch (_) {
      // A process death during file creation can leave a structurally valid
      // but incomplete SQLite file. Epoch data is intentionally disposable.
      await _deleteTrainingFiles(includeV2: true);
      resetPerformed = true;
      final db = await AppDatabase.instance.database;
      await AppDatabase.instance.assertIntegrity(database: db);
    }
    await preferences.setInt(_epochPreferenceKey, DatabaseSchemaV2.dataEpoch);
    if (resetPerformed) {
      await preferences.setBool(
        SettingsDatabase.syncEnabledPreferenceKey,
        false,
      );
    }
  }

  /// Deletes training data while preserving login and visual preferences.
  Future<void> resetLocalTrainingData() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_epochPreferenceKey);
    await preferences.setBool(SettingsDatabase.syncEnabledPreferenceKey, false);
    await _deleteTrainingFiles(includeV2: true);
    final db = await AppDatabase.instance.database;
    await AppDatabase.instance.assertIntegrity(database: db);
    await preferences.setInt(_epochPreferenceKey, DatabaseSchemaV2.dataEpoch);
  }

  Future<void> markAccountDeletionPending() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(accountDeletionPendingKey, true);
  }

  Future<bool> hasPendingAccountDeletion() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(accountDeletionPendingKey) == true;
  }

  Future<void> clearAccountDeletionPending() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(accountDeletionPendingKey);
  }

  /// Completes the local half after Auth deletion succeeded but the process
  /// was interrupted. It must be called after Firebase initialization.
  Future<void> completePendingAccountDeletionIfNeeded({
    required bool isSignedIn,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(accountDeletionPendingKey) != true || isSignedIn) {
      return;
    }
    await deleteAllLocalData();
  }

  /// Removes database, images and all device preferences. It creates a fresh,
  /// verified epoch-2 database so the app can return directly to onboarding.
  Future<void> deleteAllLocalData() async {
    final preferences = await SharedPreferences.getInstance();
    await _deleteTrainingFiles(includeV2: true);
    await preferences.clear();
    final db = await AppDatabase.instance.database;
    await AppDatabase.instance.assertIntegrity(database: db);
    await preferences.setInt(_epochPreferenceKey, DatabaseSchemaV2.dataEpoch);
  }

  Future<void> _deleteTrainingFiles({required bool includeV2}) async {
    await AppDatabase.instance.close();
    final databaseDirectory = await getDatabasesPath();
    final names = <String>{
      ..._legacyDatabaseNames,
      if (includeV2) AppDatabase.databaseName,
    };
    for (final name in names) {
      final filePath = path.join(databaseDirectory, name);
      await deleteDatabase(filePath);
      for (final suffix in const ['-wal', '-shm', '-journal']) {
        final companion = File('$filePath$suffix');
        if (await companion.exists()) await companion.delete();
      }
    }

    await ExerciseImageService.instance.deleteAllImages();
    final documents = await getApplicationDocumentsDirectory();
    for (final name in _temporaryDirectoryNames) {
      final directory = Directory(path.join(documents.path, name));
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  }
}
