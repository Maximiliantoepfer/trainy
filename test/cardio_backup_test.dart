import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/repositories/cardio_repository.dart';
import 'package:trainy/repositories/training_program_repository.dart';
import 'package:trainy/models/training_program.dart';
import 'package:trainy/services/app_database.dart';
import 'package:trainy/services/local_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'streamed backup excludes raw data by default and round-trips opt-in samples',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final directory = await Directory.systemTemp.createTemp(
        'trainy-cardio-backup-test-',
      );
      await databaseFactory.setDatabasesPath(directory.path);
      final backup = LocalBackupService(
        documentsDirectory: () async => directory,
      );
      try {
        final repo = CardioRepository();
        final programs = TrainingProgramRepository();
        await programs.initialize();
        final plan = TrainingProgram(
          name: 'My mixed plan',
          start: DateTime.now(),
          slots: ProgramSplits.slots([1, 3, 5], 'fullBody'),
        );
        await programs.save(plan);
        await programs.saveDraft('plan:new', {
          'step': 2,
          'name': 'Not finished',
        });
        await programs.saveUserProfile(
          const UserTrainingProfile(strengthLevel: 'experienced'),
        );
        final id = await repo.begin(
          CardioWorkout(name: 'Offline run', steps: [CardioStep()]),
        );
        await repo.saveRuntime({
          'sessionId': id,
          'status': 'completed',
          'activeSeconds': 100,
          'distanceMeters': 300,
        });
        await repo.saveSamples(
          id,
          List.generate(
            1203,
            (i) => {
              'sequence': i,
              'latitude': 52.0 + i / 100000,
              'longitude': 13.0,
              'timestamp': i * 1000,
            },
          ),
        );
        final private = await backup.exportZipFile(includeImages: false);
        final input = InputFileStream(private.path);
        final archive = ZipDecoder().decodeStream(input);
        expect(archive.find('sensors.ndjson')!.size, 0);
        expect(
          (jsonDecode(utf8.decode(archive.find('manifest.json')!.readBytes()!))
              as Map)['formatVersion'],
          3,
        );
        await input.close();
        await repo.saveProfile(
          const AthleteRunningProfile(backupSensorData: true),
        );
        final optedIn = await backup.exportZipFile(includeImages: false);
        var db = await AppDatabase.instance.database;
        await db.delete('cardio_sensor_samples');
        await backup.restoreZipFile(optedIn);
        db = await AppDatabase.instance.database;
        expect(
          (await db.rawQuery(
            'SELECT COUNT(*) FROM cardio_sensor_samples',
          )).single.values.single,
          1203,
        );
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        expect(await programs.activeId(), plan.id);
        expect(
          (await programs.plans()).single.toJson()['slots'],
          plan.toJson()['slots'],
        );
        expect((await programs.draft('plan:new'))!['step'], 2);
        expect((await programs.userProfile()).strengthLevel, 'experienced');
        expect(
          (await CardioRepository().history()).single['name_snapshot'],
          'Offline run',
        );
        await backup.restoreZipFile(private);
        db = await AppDatabase.instance.database;
        expect(await db.query('cardio_sensor_samples'), isEmpty);
        expect((await CardioRepository().history()).length, 1);
      } finally {
        await AppDatabase.instance.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
