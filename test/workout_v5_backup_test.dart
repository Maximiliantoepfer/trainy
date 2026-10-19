import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/services/app_database.dart';
import 'package:trainy/services/local_backup_service.dart';
import 'package:trainy/services/database_schema_v2.dart';
import 'package:trainy/services/training_program_schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final sourceVersion in [4, 5, 6, 7]) {
    test(
      'schema-$sourceVersion ZIP stages into current schema without touching active data on invalid FK',
      () async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final directory = await Directory.systemTemp.createTemp(
          'trainy-v5-backup-',
        );
        await databaseFactory.setDatabasesPath(directory.path);
        final service = LocalBackupService(
          documentsDirectory: () async => directory,
        );
        try {
          var db = await AppDatabase.instance.database;
          await db.insert('workout_templates', {
            'id': 'saved',
            'name': 'Original',
            'primary_goal_code': 'strength',
            'created_at_utc': 1,
            'updated_at_utc': 1,
          });
          final data = await service.exportAll();
          data['schemaVersion'] = sourceVersion;
          final revision =
              sourceVersion >= 6
                  ? '2026-10-19.$sourceVersion'
                  : '2026-10-16.$sourceVersion';
          data['schemaRevision'] = revision;
          for (final table in TrainingProgramSchema.tables) {
            (data['tables'] as Map).remove(table);
          }
          for (final row
              in sourceVersion < 6 ? data['tables']['user_settings'] : []) {
            (row as Map).remove('profile_setup_state');
          }
          Uint8List zip(Map<String, dynamic> data) {
            final bytes = utf8.encode(jsonEncode(data));
            final manifest = utf8.encode(
              jsonEncode({
                'format': 'trainy-backup',
                'formatVersion': 2,
                'dataEpoch': 2,
                'schemaVersion': sourceVersion,
                'schemaRevision': revision,
                'images': {},
                'includesImages': false,
                'database': {
                  'path': 'database.json',
                  'size': bytes.length,
                  'sha256': sha256.convert(bytes).toString(),
                },
              }),
            );
            return ZipEncoder().encodeBytes(
              Archive()
                ..addFile(
                  ArchiveFile('manifest.json', manifest.length, manifest),
                )
                ..addFile(ArchiveFile('database.json', bytes.length, bytes)),
            );
          }

          final valid = zip(data);
          await db.update('workout_templates', {'name': 'Changed'});
          await service.restoreZip(valid);
          db = await AppDatabase.instance.database;
          expect(
            (await db.query('workout_templates')).single['name'],
            'Original',
          );
          expect(await db.getVersion(), DatabaseSchemaV2.schemaVersion);
          expect(
            (await db.query('user_settings')).single['profile_setup_state'],
            sourceVersion < 6 ? 'offer' : 'required',
          );
          expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
          data['tables']['workout_weekly_schedule'] = [
            {
              'id': 'invalid',
              'workout_id': 'missing',
              'weekday': 1,
              'sort_order': 0,
            },
          ];
          await expectLater(
            service.restoreZip(zip(data)),
            throwsA(isA<DatabaseException>()),
          );
          expect(
            (await (await AppDatabase.instance.database).query(
              'workout_templates',
            )).single['name'],
            'Original',
          );
          final current = await service.exportZip(includeImages: false);
          await service.restoreZip(current);
          expect(
            (await (await AppDatabase.instance.database).query(
              'workout_templates',
            )).single['name'],
            'Original',
          );
        } finally {
          await AppDatabase.instance.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }
}
