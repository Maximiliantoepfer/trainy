import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/repositories/cardio_repository.dart';
import 'package:trainy/repositories/training_program_repository.dart';
import 'package:trainy/models/training_program.dart';
import 'package:trainy/models/workout_planning.dart';
import 'package:trainy/repositories/workout_planning_repository.dart';
import 'package:trainy/repositories/activity_repository.dart';
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
        final originalDb = await AppDatabase.instance.database;
        await originalDb.insert('training_profiles_v2', {
          'id': 'backup-home',
          'name': 'Home',
          'created_at_utc': 1,
          'updated_at_utc': 1,
        });
        for (var i = 1; i <= 2; i++) {
          await originalDb.insert('exercises', {
            'id': i,
            'name': 'Exercise $i',
            'description': '',
            'trackedFields': '{}',
            'defaultValues': '{}',
            'lastValues': '{}',
            'units': '{}',
            'origin': 'custom',
          });
        }
        final strength = WorkoutPlanningRepository();
        final workout = await strength.createWorkout(
          const WorkoutEditorDraft(
            name: 'Strength backup',
            primaryGoal: WorkoutPrimaryGoal.strength,
            setupName: 'Home',
            profileId: 'backup-home',
            exerciseIds: [1, 2],
            prescriptions: {1: StrengthPrescription(sets: 3)},
          ),
        );
        final plan = TrainingProgram(
          name: 'My mixed plan',
          start: DateTime(2030, 1, 7),
          slots: [
            ProgramSlot(
              weekday: 1,
              label: 'pushCore',
              focus: ['push', 'core'],
              workoutId: workout.canonicalId,
            ),
          ],
          endDate: DateTime(2030, 3, 1),
        );
        await programs.save(plan);
        final before =
            (await programs.entries(
              plan,
              plan.start,
              DateTime(2030, 1, 14),
            )).single;
        final setup =
            (await strength.setupsForWorkout(workout.canonicalId)).single;
        await programs.splitStrength(before, {
          setup.groups.expand((g) => g.selectedVariant.slots).first.id,
        }, DateTime(2030, 1, 9));
        final parts = await programs.entries(
          plan,
          plan.start,
          DateTime(2030, 1, 14),
        );
        final firstPart = (await strength.workouts()).firstWhere(
          (w) => w.canonicalId == parts.first.workoutId,
        );
        final activity = ActivityRepository();
        final session = await activity.startWorkoutActivity(
          localWorkoutId: firstPart.id,
          nameSnapshot: firstPart.name,
          activityType: 'strength',
          tags: ['strength'],
          items: [],
          workoutId: firstPart.canonicalId,
          trainingProgramId: plan.id,
          plannedOccurrenceId: parts.first.id,
          startedAt: plan.start,
        );
        await activity.completeSession(
          session.sessionId,
          endedAt: plan.start.add(const Duration(minutes: 20)),
        );
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
          AthleteRunningProfile(
            backupSensorData: true,
            referenceSeconds: 1800,
            bestSeconds: 1500,
            bestDate: DateTime(2026, 10, 1),
          ),
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
        expect((await db.query('strength_occurrence_parts')).length, 2);
        expect(
          (await db.query('strength_session_links')).single['session_id'],
          session.sessionId,
        );
        expect((await db.query('workout_slot_prescriptions')).length, 2);
        expect((await repo.profile()).bestSeconds, 1500);
        final restoredParts = await programs.entries(
          (await programs.plans()).single,
          plan.start,
          DateTime(2030, 1, 14),
        );
        expect(restoredParts.map((e) => e.id), parts.map((e) => e.id));
        expect(restoredParts.where((e) => e.completed).length, 1);
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
