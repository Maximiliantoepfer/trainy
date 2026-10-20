import 'dart:io';
import 'dart:convert';
import 'cardio_native_lifecycle.dart';
import 'data_operation.dart';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'database_schema_v2.dart';
import 'exercise_image_service.dart';
import 'settings_database.dart';

enum DataStartupState { ready, migrated, needsRecovery }

class DataStartupResult {
  const DataStartupResult._(this.state, {this.error});

  const DataStartupResult.ready() : this._(DataStartupState.ready);
  const DataStartupResult.migrated() : this._(DataStartupState.migrated);
  const DataStartupResult.needsRecovery(Object error)
    : this._(DataStartupState.needsRecovery, error: error);

  final DataStartupState state;
  final Object? error;

  bool get isReady => state != DataStartupState.needsRecovery;
}

/// Coordinates destructive data transitions independently of the UI.
///
/// Database metadata is authoritative. The preference marker is only a
/// reconstructable cache and can never delete a valid epoch-2 database.
class DataLifecycleCoordinator {
  DataLifecycleCoordinator._();

  static final instance = DataLifecycleCoordinator._();

  static const _epochPreferenceKey = 'training_data_epoch';
  static const accountDeletionPendingKey = 'account_deletion_pending';
  static const _legacyDatabaseNames = <String>['trainy.db'];
  static const _temporaryDirectoryNames = <String>[
    'trainy_imports',
    'trainy_restore',
    'trainy_backup_cache',
  ];

  Future<DataStartupResult> ensureReady() async {
    final preferences = await SharedPreferences.getInstance();
    final databaseFile = File(await AppDatabase.instance.databasePath);
    final databaseExisted = await databaseFile.exists();
    final legacyExisted = await _legacyDatabaseExists();

    if (!databaseExisted) {
      if (legacyExisted) await _deleteLegacyDatabases();
      try {
        final db = await AppDatabase.instance.database;
        await AppDatabase.instance.assertIntegrity(database: db);
        await preferences.setInt(
          _epochPreferenceKey,
          DatabaseSchemaV2.dataEpoch,
        );
        if (legacyExisted) {
          await preferences.setBool(
            SettingsDatabase.syncEnabledPreferenceKey,
            false,
          );
          return const DataStartupResult.migrated();
        }
        return const DataStartupResult.ready();
      } catch (error) {
        await AppDatabase.instance.close();
        return DataStartupResult.needsRecovery(error);
      }
    }

    try {
      final db = await AppDatabase.instance.database;
      final epoch = await DatabaseSchemaV2.readEpoch(db);
      if (epoch != DatabaseSchemaV2.dataEpoch) {
        throw DatabaseEpochMismatch(epoch);
      }
      await AppDatabase.instance.assertIntegrity(database: db);
      final markerWasMissing =
          preferences.getInt(_epochPreferenceKey) != DatabaseSchemaV2.dataEpoch;
      await preferences.setInt(_epochPreferenceKey, DatabaseSchemaV2.dataEpoch);
      return markerWasMissing
          ? const DataStartupResult.migrated()
          : const DataStartupResult.ready();
    } on DatabaseEpochMismatch catch (error) {
      await AppDatabase.instance.close();
      final actual = error.actualEpoch;
      if (actual == null || actual >= DatabaseSchemaV2.dataEpoch) {
        return DataStartupResult.needsRecovery(error);
      }
      // A genuine older epoch is the only automatic destructive transition.
      await _deleteTrainingFiles(includeV2: true);
      await preferences.setBool(
        SettingsDatabase.syncEnabledPreferenceKey,
        false,
      );
      try {
        final db = await AppDatabase.instance.database;
        await AppDatabase.instance.assertIntegrity(database: db);
        await preferences.setInt(
          _epochPreferenceKey,
          DatabaseSchemaV2.dataEpoch,
        );
        return const DataStartupResult.migrated();
      } catch (recreateError) {
        await AppDatabase.instance.close();
        return DataStartupResult.needsRecovery(recreateError);
      }
    } catch (error) {
      await AppDatabase.instance.close();
      return DataStartupResult.needsRecovery(error);
    }
  }

  @Deprecated('Use ensureReady() and handle the recovery state.')
  Future<DataStartupResult> applyDataEpoch() => ensureReady();

  Future<DataStartupResult> retryRecovery() => ensureReady();

  /// Saves the raw SQLite files without opening a potentially damaged DB.
  Future<String> exportRecoveryCopy() async {
    await AppDatabase.instance.close();
    final sourcePath = await AppDatabase.instance.databasePath;
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      ':',
      '-',
    );
    final documents = await getApplicationDocumentsDirectory();
    final target = Directory(
      path.join(documents.path, 'Trainy-Recovery', timestamp),
    );
    await target.create(recursive: true);
    var copied = 0;
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final source = File('$sourcePath$suffix');
      if (!await source.exists()) continue;
      await source.copy(path.join(target.path, path.basename(source.path)));
      copied++;
    }
    if (copied == 0) {
      throw StateError('No local database files were found.');
    }
    return target.path;
  }

  /// Deletes training data while preserving login and visual preferences.
  Future<void> resetLocalTrainingData() => DataOperation.instance.mutateLocal(
    () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_epochPreferenceKey);
      await preferences.setBool(
        SettingsDatabase.syncEnabledPreferenceKey,
        false,
      );
      await _deleteTrainingFiles(includeV2: true);
      final db = await AppDatabase.instance.database;
      await AppDatabase.instance.assertIntegrity(database: db);
      await preferences.setInt(_epochPreferenceKey, DatabaseSchemaV2.dataEpoch);
    },
  );

  Future<void> markAccountDeletionPending({
    required String uid,
    required String phase,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      accountDeletionPendingKey,
      jsonEncode({'uid': uid, 'phase': phase}),
    );
  }

  Future<bool> hasPendingAccountDeletion() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.containsKey(accountDeletionPendingKey);
  }

  Future<bool> hasConfirmedLocalDeletion() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.get(accountDeletionPendingKey);
    if (raw is! String) return false;
    try {
      final pending = jsonDecode(raw);
      return pending is Map &&
          pending['phase'] == 'authDeleted' &&
          pending['uid'] is String;
    } on FormatException {
      return false;
    }
  }

  Future<void> clearAccountDeletionPending() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(accountDeletionPendingKey);
  }

  Future<void> completePendingAccountDeletionIfNeeded({
    required bool isSignedIn,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.get(accountDeletionPendingKey);
    // Legacy booleans do not prove that Auth deletion succeeded. In particular,
    // logging out must never turn an interrupted remote request into a reset.
    if (raw is! String || isSignedIn) {
      return;
    }
    if (!await hasConfirmedLocalDeletion()) return;
    await deleteAllLocalData();
  }

  Future<void> deleteAllLocalData() => DataOperation.instance.mutateLocal(
    () async {
      final preferences = await SharedPreferences.getInstance();
      await _deleteTrainingFiles(includeV2: true);
      final db = await AppDatabase.instance.database;
      await AppDatabase.instance.assertIntegrity(database: db);
      // Preserve the retry journal until local recreation has succeeded.
      await preferences.clear();
      await preferences.setInt(_epochPreferenceKey, DatabaseSchemaV2.dataEpoch);
    },
  );

  Future<bool> _legacyDatabaseExists() async {
    final databaseDirectory = await getDatabasesPath();
    for (final name in _legacyDatabaseNames) {
      if (await File(path.join(databaseDirectory, name)).exists()) return true;
    }
    return false;
  }

  Future<void> _deleteLegacyDatabases() async {
    await AppDatabase.instance.close();
    final databaseDirectory = await getDatabasesPath();
    for (final name in _legacyDatabaseNames) {
      final filePath = path.join(databaseDirectory, name);
      await deleteDatabase(filePath);
      for (final suffix in const ['-wal', '-shm', '-journal']) {
        final companion = File('$filePath$suffix');
        if (await companion.exists()) await companion.delete();
      }
    }
  }

  Future<void> _deleteTrainingFiles({required bool includeV2}) async {
    if (includeV2) {
      await DataOperation.step('native-stop', CardioNativeLifecycle.discard);
    }
    await DataOperation.step('database-close', AppDatabase.instance.close);
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
