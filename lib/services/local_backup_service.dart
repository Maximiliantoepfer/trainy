import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'catalog_repository.dart';
import 'database_schema_v2.dart';
import 'exercise_image_service.dart';

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

  Future<Map<String, dynamic>> exportAll() async {
    final db = await AppDatabase.instance.database;
    final tables = <String, dynamic>{};
    for (final table in DatabaseSchemaV2.userDataTables.reversed) {
      final rows =
          (await db.query(
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
    if (archive.length > 5000) {
      throw const FormatException('Backup contains too many files.');
    }
    for (final item in archive) {
      _validateArchivePath(item.name);
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
        manifest['formatVersion'] != formatVersion ||
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
      await temporary.transaction((txn) async {
        for (final table in DatabaseSchemaV2.userDataTables.reversed) {
          final rows = tableData[table] as List<dynamic>? ?? const [];
          for (final raw in rows) {
            final row = Map<String, Object?>.from(raw as Map);
            if (table == 'user_settings') {
              row['sync_enabled'] = 0;
              row['last_sync_millis'] = 0;
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
      });
      await AppDatabase.instance.assertIntegrity(database: temporary);
    } finally {
      await temporary.close();
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
