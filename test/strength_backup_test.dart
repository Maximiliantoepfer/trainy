import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/models/strength_equipment.dart';
import 'package:trainy/models/strength_plan.dart';
import 'package:trainy/services/strength_routines.dart';
import 'package:trainy/models/training_profile.dart';
import 'package:trainy/models/training_program.dart';
import 'package:trainy/repositories/training_program_repository.dart';
import 'package:trainy/repositories/training_profile_repository.dart';
import 'package:trainy/repositories/workout_planning_repository.dart';
import 'package:trainy/services/app_database.dart';
import 'package:trainy/services/catalog_repository.dart';
import 'package:trainy/services/local_backup_service.dart';
import 'package:trainy/services/strength_planning.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'generated setups, confirmed profile, prescriptions and drafts round-trip',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await Directory.systemTemp.createTemp(
        'trainy-strength-backup-',
      );
      await databaseFactory.setDatabasesPath(dir.path);
      try {
        expect(await CatalogRepository.instance.load(), isTrue);
        final repo = TrainingProgramRepository();
        await repo.initialize();
        final now = DateTime.utc(2030, 1, 7);
        final places = [
          for (final id in ['home', 'gym'])
            TrainingProfileRecord(
              id: id,
              name: id,
              equipmentCodes: StrengthEquipment.gym,
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
        ];
        for (final p in places) {
          await TrainingProfileRepository().save(p);
        }
        const user = UserTrainingProfile(
          strengthProfileId: 'home',
          strengthProfileIds: ['home', 'gym'],
          strengthLevel: 'beginner',
          strengthGoal: 'buildMuscle',
          strengthPreference: 'guided',
          strengthSetupVersion: 2,
          strengthAnswers: {
            'level',
            'goal',
            'places',
            'equipment',
            'preference',
          },
        );
        await repo.saveUserProfile(user);
        final program = TrainingProgram(
          name: 'Both places',
          start: now,
          slots: [ProgramSlot(weekday: 1, label: 'fullBody')],
        );
        final generated = StrengthPlanning.generate(
          planId: program.id,
          user: user,
          places: places,
          slots: program.slots,
          goal: user.strengthGoal,
          minutes: 60,
          label: (s) => s,
        );
        final proposal = StrengthPlanProposal(
          workouts: [
            for (final w in generated.workouts)
              w
                  .copyWith(
                    variants: [
                      for (final v in w.variants)
                        v.copyWith(
                          warmup: StrengthRoutines.preset(
                            'fullBody',
                            cooling: false,
                          ),
                        ),
                    ],
                  )
                  .confirmReview(),
          ],
        );
        await repo.saveDraft('strength-plan:draft', proposal.toJson());
        await repo.save(program, strength: proposal);
        final backup = LocalBackupService(documentsDirectory: () async => dir);
        final zip = await backup.exportZipFile(includeImages: false);
        await repo.clearDraft('strength-plan:draft');
        await backup.restoreZipFile(zip);
        expect((await repo.userProfile()).strengthProfileIds, ['home', 'gym']);
        expect((await repo.userProfile()).strengthSetupVersion, 2);
        expect(await repo.draft('strength-plan:draft'), proposal.toJson());
        final workouts = WorkoutPlanningRepository();
        expect((await workouts.workouts()).length, 1);
        final variants = await workouts.setupsForWorkout(
          proposal.workouts.single.id,
        );
        expect(variants.length, 2);
        expect(
          variants
              .expand((v) => v.groups)
              .expand((g) => g.selectedVariant.slots)
              .every(
                (s) =>
                    (s.prescription!.source == 'generated:v1' &&
                        s.prescription!.restSeconds > 0) ||
                    (s.prescription!.source == 'routine' &&
                        s.prescription!.durationSeconds == 30),
              ),
          isTrue,
        );
        final restored = (await repo.plans()).single;
        expect(
          (await repo.entries(
            restored,
            now,
            now.add(const Duration(days: 7)),
          )).length,
          1,
        );
      } finally {
        await AppDatabase.instance.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
