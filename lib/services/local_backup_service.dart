import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'catalog_repository.dart';
import 'database_schema_v2.dart';
import 'exercise_image_service.dart';
import 'cardio_native_lifecycle.dart';
import 'training_program_schema.dart';

/// Versioned data-epoch-2 backup. Old row-merging JSON backups are rejected.
class LocalBackupService {
  LocalBackupService({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  static final LocalBackupService instance = LocalBackupService();
  static const formatVersion = 2;
  static const _maxArchiveBytes = 96 * 1024 * 1024;
  static const _maxFileBytes = 12 * 1024 * 1024;
  static const maximumStreamingArchiveBytes = 512 * 1024 * 1024;

  Future<Map<String, dynamic>> exportAll() async {
    final db = await AppDatabase.instance.database;
    return db.transaction((txn) => _snapshot(txn));
  }

  Future<Map<String, dynamic>> _snapshot(
    DatabaseExecutor txn, {
    bool sensors = true,
  }) async {
    final tables = <String, dynamic>{};
    var preferences = await txn.query('user_training_profile');
    if (preferences.isEmpty) {
      preferences = await txn.query('cardio_preferences');
    }
    final includeSensors =
        sensors &&
        preferences.isNotEmpty &&
        (jsonDecode(preferences.single['profile_json'] as String)
                as Map)['backupSensorData'] ==
            true;
    for (final table in DatabaseSchemaV2.userDataTables.reversed) {
      if (table == 'cardio_sensor_samples' && !includeSensors) {
        tables[table] = <Object>[];
        continue;
      }
      final rows =
          (await txn.query(
            table,
          )).map((row) => Map<String, Object?>.from(row)).toList();
      if (table == 'user_settings') {
        for (final row in rows) {
          row['sync_enabled'] = 0;
          row['last_sync_millis'] = 0;
        }
      }
      tables[table] = rows;
    }
    return {
      'dataEpoch': DatabaseSchemaV2.dataEpoch,
      'schemaVersion': DatabaseSchemaV2.schemaVersion,
      'schemaRevision': DatabaseSchemaV2.schemaRevision,
      'catalogVersion': CatalogRepository.instance.catalogVersion ?? 'unknown',
      'exportedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
    };
  }

  /// Format 3 separates high-volume samples into a streamed NDJSON member.
  /// The caller owns the returned temporary directory and must delete it.
  Future<File> exportZipFile({bool includeImages = true}) async {
    final parent = await _documentsDirectory();
    final directory = await Directory(
      path.join(parent.path, 'trainy_backup_cache'),
    ).create(recursive: true);
    final staging = await directory.createTemp('export-');
    try {
      final samples = File(path.join(staging.path, 'sensors.ndjson'));
      final sink = samples.openWrite();
      late Map<String, dynamic> data;
      try {
        final db = await AppDatabase.instance.database;
        await db.transaction((txn) async {
          data = await _snapshot(txn, sensors: false);
          final tables = data['tables'] as Map;
          final preferences =
              (tables['user_training_profile'] as List).isNotEmpty
                  ? tables['user_training_profile'] as List
                  : tables['cardio_preferences'] as List;
          final enabled =
              preferences.isNotEmpty &&
              (jsonDecode((preferences.single as Map)['profile_json'] as String)
                      as Map)['backupSensorData'] ==
                  true;
          if (enabled) {
            var rowId = 0;
            while (true) {
              final rows = await txn.rawQuery(
                'SELECT rowid AS cursor, * FROM cardio_sensor_samples WHERE rowid > ? ORDER BY rowid LIMIT 500',
                [rowId],
              );
              if (rows.isEmpty) break;
              for (final raw in rows) {
                rowId = raw['cursor'] as int;
                sink.writeln(
                  jsonEncode(Map<String, Object?>.from(raw)..remove('cursor')),
                );
              }
              await sink.flush();
            }
          }
        });
      } finally {
        await sink.close();
      }
      final databaseFile = File(path.join(staging.path, 'database.json'));
      await databaseFile.writeAsString(jsonEncode(data));
      Future<Map<String, Object>> digest(File file) async => {
        'size': await file.length(),
        'sha256': (await sha256.bind(file.openRead()).first).toString(),
      };
      final imageManifest = <String, Map<String, Object>>{},
          images = <String, File>{};
      if (includeImages) {
        for (final table in ['exercise_images', 'exercise_images_v2']) {
          for (final row in (data['tables'] as Map)[table] as List) {
            final relative =
                ((row as Map)['relativePath'] ?? row['relative_path'])
                    as String?;
            if (relative == null || images.containsKey(relative)) continue;
            final image = await ExerciseImageService.instance.resolve(relative);
            if (await image.length() > _maxFileBytes) {
              throw StateError('Exercise image exceeds size limit');
            }
            final copy = File(
              path.join(staging.path, 'image-${images.length}'),
            );
            await image.copy(copy.path);
            images[relative] = copy;
            imageManifest[relative] = await digest(copy);
          }
        }
      }
      final manifest = File(path.join(staging.path, 'manifest.json'));
      await manifest.writeAsString(
        jsonEncode({
          'format': 'trainy-backup',
          'formatVersion': 3,
          'dataEpoch': DatabaseSchemaV2.dataEpoch,
          'schemaVersion': DatabaseSchemaV2.schemaVersion,
          'schemaRevision': DatabaseSchemaV2.schemaRevision,
          'catalogVersion': data['catalogVersion'],
          'includesImages': includeImages,
          'images': imageManifest,
          'database': {'path': 'database.json', ...await digest(databaseFile)},
          'sensors': {'path': 'sensors.ndjson', ...await digest(samples)},
        }),
      );
      final zip = File(path.join(staging.path, 'backup.zip'));
      final encoder = ZipFileEncoder()..create(zip.path);
      try {
        await encoder.addFile(manifest, 'manifest.json');
        await encoder.addFile(databaseFile, 'database.json');
        await encoder.addFile(samples, 'sensors.ndjson');
        for (final entry in images.entries) {
          await encoder.addFile(entry.value, 'images/${entry.key}');
        }
      } finally {
        await encoder.close();
      }
      if (await zip.length() > maximumStreamingArchiveBytes) {
        throw StateError('Backup exceeds size limit');
      }
      return zip;
    } catch (_) {
      await staging.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> restoreZipFile(File file) async {
    if (await file.length() > maximumStreamingArchiveBytes) {
      throw const FormatException('Backup exceeds size limit');
    }
    final input = InputFileStream(file.path);
    try {
      await _restoreArchive(ZipDecoder().decodeStream(input, verify: true));
    } finally {
      await input.close();
    }
  }

  Future<Uint8List> exportZip({bool includeImages = true}) async {
    final data = await exportAll();
    final databaseBytes = utf8.encode(jsonEncode(data));
    final imageManifest = <String, Map<String, Object>>{};
    final imageFiles = <String, Uint8List>{};

    if (includeImages) {
      final paths = <String>{};
      final tables = Map<String, dynamic>.from(data['tables'] as Map);
      for (final table in const ['exercise_images', 'exercise_images_v2']) {
        for (final raw in tables[table] as List<dynamic>? ?? const []) {
          final row = Map<String, dynamic>.from(raw as Map);
          final relative =
              (row['relativePath'] ?? row['relative_path']) as String?;
          if (relative != null) paths.add(relative);
        }
      }
      for (final relative in paths) {
        final file = await ExerciseImageService.instance.resolve(relative);
        if (!await file.exists()) {
          throw StateError('Referenced exercise image is missing: $relative');
        }
        final bytes = await file.readAsBytes();
        if (bytes.length > _maxFileBytes) {
          throw StateError('Exercise image exceeds the size limit: $relative');
        }
        imageFiles[relative] = bytes;
        imageManifest[relative] = {
          'size': bytes.length,
          'sha256': sha256.convert(bytes).toString(),
        };
      }
    }

    final manifest = {
      'format': 'trainy-backup',
      'formatVersion': formatVersion,
      'dataEpoch': DatabaseSchemaV2.dataEpoch,
      'schemaVersion': DatabaseSchemaV2.schemaVersion,
      'schemaRevision': DatabaseSchemaV2.schemaRevision,
      'catalogVersion': data['catalogVersion'],
      'includesImages': includeImages,
      'database': {
        'path': 'database.json',
        'size': databaseBytes.length,
        'sha256': sha256.convert(databaseBytes).toString(),
      },
      'images': imageManifest,
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    final archive =
        Archive()
          ..addFile(
            ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
          )
          ..addFile(
            ArchiveFile('database.json', databaseBytes.length, databaseBytes),
          );
    for (final entry in imageFiles.entries) {
      archive.addFile(
        ArchiveFile('images/${entry.key}', entry.value.length, entry.value),
      );
    }
    return ZipEncoder().encodeBytes(archive);
  }

  Future<void> restoreZip(Uint8List bytes, {bool replace = true}) async {
    if (!replace) {
      throw UnsupportedError('Epoch-2 backups can only replace local data.');
    }
    if (bytes.length > _maxArchiveBytes) {
      throw const FormatException('Backup exceeds the size limit.');
    }
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    await _restoreArchive(archive);
  }

  Future<void> _restoreArchive(Archive archive) async {
    await _ensureRestoreAllowed();
    if (archive.length > 5000) {
      throw const FormatException('Backup contains too many files.');
    }
    final members = <String>{};
    for (final item in archive) {
      _validateArchivePath(item.name);
      if (!members.add(item.name.replaceAll('\\', '/'))) {
        throw const FormatException('Duplicate backup member');
      }
      final limit =
          item.name == 'sensors.ndjson'
              ? 1024 * 1024 * 1024
              : item.name == 'database.json'
              ? _maxArchiveBytes
              : _maxFileBytes;
      if (item.size > limit) {
        throw const FormatException(
          'Uncompressed backup member exceeds size limit',
        );
      }
    }
    if (archive.files
            .where((f) => f.name != 'sensors.ndjson')
            .fold<int>(0, (n, f) => n + f.size) >
        _maxArchiveBytes) {
      throw const FormatException(
        'Uncompressed metadata and images exceed size limit',
      );
    }

    final manifestBytes = archive.find('manifest.json')?.readBytes();
    final databaseBytes = archive.find('database.json')?.readBytes();
    if (manifestBytes == null || databaseBytes == null) {
      throw const FormatException('Backup manifest or database is missing.');
    }
    final manifest = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(manifestBytes)) as Map,
    );
    if (manifest['format'] != 'trainy-backup' ||
        ![formatVersion, 3].contains(manifest['formatVersion']) ||
        manifest['dataEpoch'] != DatabaseSchemaV2.dataEpoch ||
        !isCompatibleSchema(
          manifest['schemaVersion'],
          manifest['schemaRevision'],
        )) {
      throw const FormatException('Incompatible backup version.');
    }
    final databaseManifest = Map<String, dynamic>.from(
      manifest['database'] as Map? ?? const {},
    );
    _verifyBytes(databaseBytes, databaseManifest, 'database.json');

    final decoded = jsonDecode(utf8.decode(databaseBytes));
    if (decoded is! Map) {
      throw const FormatException('Invalid database export.');
    }
    final data = Map<String, dynamic>.from(decoded);
    if (data['dataEpoch'] != DatabaseSchemaV2.dataEpoch ||
        data['schemaVersion'] != manifest['schemaVersion'] ||
        data['schemaRevision'] != manifest['schemaRevision']) {
      throw const FormatException('Incompatible database epoch.');
    }
    final tableData = Map<String, dynamic>.from(
      data['tables'] as Map? ?? const {},
    );
    File? sensorRows;
    Directory? sensorStaging;
    final unknown = tableData.keys.toSet().difference(
      DatabaseSchemaV2.userDataTables.toSet(),
    );
    if (unknown.isNotEmpty) {
      throw FormatException('Backup contains unknown tables: $unknown');
    }

    final imagesManifest = Map<String, dynamic>.from(
      manifest['images'] as Map? ?? const {},
    );
    final includesImages = manifest['includesImages'] == true;
    final imageBytes = <String, Uint8List>{};
    for (final entry in imagesManifest.entries) {
      final relative = entry.key;
      _validateRelativeImagePath(relative);
      final content = archive.find('images/$relative')?.readBytes();
      if (content == null) throw FormatException('Missing image: $relative');
      final typed = Uint8List.fromList(content);
      _verifyBytes(
        typed,
        Map<String, dynamic>.from(entry.value as Map),
        relative,
      );
      imageBytes[relative] = typed;
    }

    final databasesDirectory = await getDatabasesPath();
    final nonce = DateTime.now().microsecondsSinceEpoch;
    final temporaryPath = path.join(
      databasesDirectory,
      'trainy_restore_$nonce.db',
    );
    await deleteDatabase(temporaryPath);
    final temporary = await AppDatabase.instance.openIsolated(temporaryPath);
    try {
      if (manifest['formatVersion'] == 3) {
        final member = archive.find('sensors.ndjson');
        if (member == null || manifest['sensors'] is! Map) {
          throw const FormatException('Missing sensor member');
        }
        final expected = Map<String, dynamic>.from(manifest['sensors'] as Map);
        sensorStaging = await Directory.systemTemp.createTemp(
          'trainy-sensor-restore-',
        );
        sensorRows = File(path.join(sensorStaging.path, 'sensors.ndjson'));
        final output = OutputFileStream(sensorRows.path);
        try {
          member.decompress(output);
        } finally {
          await output.close();
        }
        final checksum =
            (await sha256.bind(sensorRows.openRead()).first).toString();
        if (expected['size'] != await sensorRows.length() ||
            expected['sha256'] != checksum) {
          throw const FormatException('Sensor checksum mismatch');
        }
      }
      await temporary.transaction((txn) async {
        for (final table in DatabaseSchemaV2.userDataTables.reversed) {
          final rows = tableData[table] as List<dynamic>? ?? const [];
          for (final raw in rows) {
            final row = Map<String, Object?>.from(raw as Map);
            if (table == 'user_settings') {
              row['sync_enabled'] = 0;
              row['last_sync_millis'] = 0;
              if ((data['schemaVersion'] as int) < 6) {
                row['profile_setup_state'] = 'offer';
              }
            }
            await txn.insert(
              table,
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
        if (data['schemaVersion'] == 4) {
          await DatabaseSchemaV2.normalizeWorkoutGroupOrder(txn);
        }
        if ((data['schemaVersion'] as int) < 8) {
          await TrainingProgramSchema.migrate(txn);
        }
        if (sensorRows != null) {
          var batch = txn.batch(), count = 0;
          await for (final line in sensorRows
              .openRead()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
            if (line.length > 65536) {
              throw const FormatException('Invalid sensor row');
            }
            final row = Map<String, Object?>.from(jsonDecode(line) as Map);
            if (row.keys.toSet().difference({
              'session_id',
              'sequence',
              'sample_json',
            }).isNotEmpty) {
              throw const FormatException('Invalid sensor fields');
            }
            batch.insert('cardio_sensor_samples', row);
            if (++count % 500 == 0) {
              await batch.commit(noResult: true);
              batch = txn.batch();
            }
          }
          await batch.commit(noResult: true);
        }
      });
      await AppDatabase.instance.assertIntegrity(database: temporary);
    } finally {
      await temporary.close();
      if (sensorStaging != null) await sensorStaging.delete(recursive: true);
    }

    final documents = await _documentsDirectory();
    final stagingRoot = Directory(path.join(documents.path, 'trainy_restore'));
    final stagingImages = Directory(
      path.join(stagingRoot.path, 'exercise_images'),
    );
    if (includesImages) {
      if (await stagingRoot.exists()) await stagingRoot.delete(recursive: true);
      for (final entry in imageBytes.entries) {
        final output = File(
          path.joinAll([stagingRoot.path, ...entry.key.split('/')]),
        );
        await output.parent.create(recursive: true);
        await output.writeAsBytes(entry.value, flush: true);
      }
    }

    final activePath = await AppDatabase.instance.databasePath;
    final activeFile = File(activePath);
    final previousPath = '$activePath.previous';
    final previousFile = File(previousPath);
    final targetImages = Directory(
      path.join(documents.path, 'exercise_images'),
    );
    final previousImages = Directory(
      path.join(documents.path, 'exercise_images.previous-$nonce'),
    );
    await _ensureRestoreAllowed();
    await AppDatabase.instance.close();
    if (await previousFile.exists()) await previousFile.delete();
    if (await activeFile.exists()) await activeFile.rename(previousPath);
    try {
      await File(temporaryPath).rename(activePath);
      final restored = await AppDatabase.instance.database;
      await AppDatabase.instance.assertIntegrity(database: restored);
      if (includesImages) {
        if (await previousImages.exists()) {
          await previousImages.delete(recursive: true);
        }
        if (await targetImages.exists()) {
          await targetImages.rename(previousImages.path);
        }
        if (await stagingImages.exists()) {
          await stagingImages.rename(targetImages.path);
        } else {
          await targetImages.create(recursive: true);
        }
      }
    } catch (_) {
      await AppDatabase.instance.close();
      if (await File(activePath).exists()) await File(activePath).delete();
      if (await previousFile.exists()) await previousFile.rename(activePath);
      if (includesImages) {
        if (await targetImages.exists()) {
          await targetImages.delete(recursive: true);
        }
        if (await previousImages.exists()) {
          await previousImages.rename(targetImages.path);
        }
      }
      rethrow;
    }
    if (await previousFile.exists()) await previousFile.delete();
    if (await previousImages.exists()) {
      await previousImages.delete(recursive: true);
    }
    if (await stagingRoot.exists()) {
      await stagingRoot.delete(recursive: true);
    }
  }

  /// Kept as a narrow compatibility surface for callers. Only v2 exports are
  /// accepted and row merging is intentionally unsupported.
  Future<void> restoreAll(Map<String, dynamic> data, {bool replace = true}) {
    throw UnsupportedError('Use restoreZip for epoch-2 backups.');
  }

  Future<void> _ensureRestoreAllowed() async {
    await CardioNativeLifecycle.ensureRestoreAllowed();
    final db = await AppDatabase.instance.database;
    if ((await db.query(
      'activity_sessions',
      columns: ['id'],
      where: "status = 'active'",
      limit: 1,
    )).isNotEmpty) {
      throw StateError('Finish the active workout before restoring.');
    }
  }

  static void _verifyBytes(
    List<int> bytes,
    Map<String, dynamic> expected,
    String label,
  ) {
    if (expected['size'] != bytes.length ||
        expected['sha256'] != sha256.convert(bytes).toString()) {
      throw FormatException('Checksum mismatch for $label.');
    }
    if (bytes.length > _maxFileBytes && label != 'database.json') {
      throw FormatException('$label exceeds the size limit.');
    }
  }

  static bool isCompatibleSchema(Object? version, Object? revision) =>
      (version == DatabaseSchemaV2.schemaVersion &&
          revision == DatabaseSchemaV2.schemaRevision) ||
      (version == 7 && revision == '2026-10-19.7') ||
      (version == 6 && revision == '2026-10-19.6') ||
      (version == 5 && revision == '2026-10-16.5') ||
      (version == 4 && revision == '2026-10-16.4');

  static void _validateArchivePath(String value) {
    final normalized = value.replaceAll('\\', '/');
    if (normalized.startsWith('/') ||
        normalized.contains('../') ||
        normalized.contains('/..') ||
        RegExp(r'^[A-Za-z]:').hasMatch(normalized)) {
      throw FormatException('Unsafe archive path: $value');
    }
  }

  static void _validateRelativeImagePath(String value) {
    _validateArchivePath(value);
    if (value.isEmpty || !value.startsWith('exercise_images/')) {
      throw FormatException('Invalid image path: $value');
    }
  }
}
