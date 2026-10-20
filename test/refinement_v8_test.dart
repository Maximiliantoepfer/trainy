import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/models/training_program.dart';
import 'package:trainy/models/strength_plan.dart';
import 'package:trainy/models/workout_planning.dart';
import 'package:trainy/services/account_deletion.dart';
import 'package:trainy/services/data_operation.dart';
import 'package:trainy/services/strength_routines.dart';
import 'package:trainy/services/cardio_training.dart';
import 'package:trainy/services/database_schema_v2.dart';
import 'package:trainy/services/database_service.dart';
import 'package:trainy/services/planning_label_migration.dart';
import 'package:trainy/repositories/cardio_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'account deletion stops at each failed stage without deleting later data',
    () async {
      for (final failure in [
        'reauthenticate',
        'cloud-delete',
        'account-delete',
        'local-delete',
        null,
      ]) {
        final calls = <String>[];
        Future<void> step(String key) async {
          calls.add(key);
          if (key == failure) {
            throw StateError('private account identifier must not leak');
          }
        }

        final future = AccountDeletion.run(
          reauthenticate: () => step('reauthenticate'),
          stopBackup: () => step('stop'),
          journal: (s) => step('journal:$s'),
          deleteCloud: () => step('cloud-delete'),
          deleteAuth: () => step('account-delete'),
          deleteLocal: () => step('local-delete'),
        );
        if (failure == null) {
          await future;
          expect(calls, [
            'reauthenticate',
            'stop',
            'journal:cloud',
            'cloud-delete',
            'journal:auth',
            'account-delete',
            'journal:authDeleted',
            'local-delete',
          ]);
        } else {
          await expectLater(
            future,
            throwsA(
              isA<DataOperationFailure>()
                  .having((e) => e.stage, 'stage', failure)
                  .having(
                    (e) => e.toString().contains('private'),
                    'redacted',
                    false,
                  ),
            ),
          );
          expect(calls.last, failure);
          if (failure == 'local-delete') {
            expect(calls, contains('journal:authDeleted'));
          }
          if (failure == 'cloud-delete') {
            expect(calls, isNot(contains('account-delete')));
          }
        }
      }
    },
  );
  test(
    'review is content-based, persisted, invalidated by edits and shared by identical days',
    () {
      const v = StrengthVariantDraft(
        profileId: 'home',
        name: 'Home',
        exercises: [
          StrengthExerciseDraft(
            catalogId: 'x',
            prescription: StrengthPrescription(sets: 2),
          ),
        ],
      );
      const a = StrengthWorkoutDraft(
        id: 'a',
        slotId: 's1',
        name: 'Full body',
        variants: [v],
      );
      const b = StrengthWorkoutDraft(
        id: 'b',
        slotId: 's2',
        name: 'Full body',
        variants: [v],
      );
      expect(a.reviewed, false);
      final confirmed = a.confirmReview();
      expect(
        StrengthWorkoutDraft.fromJson(
          jsonDecode(jsonEncode(confirmed.toJson())),
        ).reviewed,
        true,
      );
      expect(StrengthPlanProposal(workouts: [confirmed, b]).reviewed, true);
      expect(confirmed.copyWith(name: 'Other').reviewed, false);
      expect(
        confirmed
            .copyWith(
              variants: [
                v.copyWith(
                  warmup: StrengthRoutines.preset('upper', cooling: false),
                ),
              ],
            )
            .reviewed,
        false,
      );
    },
  );
  test(
    'routines are three minutes, duration prefills correctly, budget needs confirmation',
    () {
      for (final focus in ['upper', 'lower', 'fullBody']) {
        for (final cooling in [false, true]) {
          final items = StrengthRoutines.preset(focus, cooling: cooling);
          expect(
            items.fold<int>(0, (s, e) => s + e.prescription.durationSeconds!),
            180,
          );
          expect(
            items.every((e) => e.prescription.prefill.containsKey('duration')),
            true,
          );
          final v = StrengthVariantDraft(
            profileId: 'h',
            name: 'H',
            exercises: const [
              StrengthExerciseDraft(
                catalogId: 'x',
                prescription: StrengthPrescription(sets: 2),
              ),
            ],
            warmup: items,
            budgetSeconds: 400,
          );
          expect(v.overBudget, true);
          expect(v.ready, false);
          expect(v.copyWith(acceptedExtraTime: true).ready, true);
        }
      }
    },
  );
  test(
    'all replacement running templates are accessible and easy stays time based',
    () {
      const p = AthleteRunningProfile(
        referenceSeconds: 2700,
        referenceKind: 'normal',
        continuousMinutes: 45,
        level: RunningLevel.beginner,
      );
      for (final code in CardioTraining.templateCodes) {
        final w = CardioTraining.replacementTemplate(code, p, (s) => s);
        w.validate();
        expect(w.sport, CardioSport.running);
      }
      final easy = CardioTraining.replacementTemplate('easy5k', p, (s) => s);
      expect(easy.name, 'easySession');
      expect(easy.steps.single.goal, StepGoal.time);
      expect(easy.steps.single.maxSpeed, closeTo(1000 / 570, .001));
    },
  );
  group('isolated occurrence edits', () {
    late Database db;
    late CardioRepository repo;
    setUp(() async {
      sqfliteFfiInit();
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          onConfigure: (d) => d.execute('PRAGMA foreign_keys=ON'),
          onCreate: (d, _) => DatabaseSchemaV2.create(d),
          version: DatabaseSchemaV2.schemaVersion,
        ),
      );
      repo = CardioRepository(database: DatabaseService(database: db));
    });
    tearDown(() async {
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await db.close();
    });
    Future<ScheduledCardioWorkout> seed({
      String status = 'planned',
      bool locked = false,
    }) async {
      final w = CardioWorkout(
        name: 'Lockere Dauereinheit',
        templateCode: 'easySession',
        steps: [CardioStep(amount: 1200)],
      );
      final o = ScheduledCardioWorkout(
        id: 'o',
        planId: 'p',
        date: DateTime(2030, 1, 7),
        workout: w,
        status: status,
        locked: locked,
      );
      await db.insert('training_plans', {
        'id': 'p',
        'name': 'Test',
        'source_type': 'generated',
        'status': 'active',
        'created_at_utc': 1,
        'updated_at_utc': 1,
      });
      await db.insert('cardio_plans', {'id': 'p', 'request_json': '{}'});
      await db.insert('cardio_occurrences', {
        'id': o.id,
        'plan_id': 'p',
        'local_date': dateKey(o.date),
        'workout_json': jsonEncode(w.toJson()),
        'status': status,
        'locked': locked ? 1 : 0,
      });
      return o;
    }

    test(
      'replacement preserves identity/date, rejects another sport and completed state',
      () async {
        final o = await seed();
        final next = CardioTraining.replacementTemplate(
          'fartlek',
          const AthleteRunningProfile(),
          (s) => s,
        );
        await repo.editOccurrence(o, next);
        final saved = (await repo.occurrences()).single;
        expect(saved.id, o.id);
        expect(saved.date, o.date);
        expect(saved.workout.templateCode, 'fartlek');
        final wrong = CardioWorkout(
          name: 'Bike',
          sport: CardioSport.cycling,
          steps: [CardioStep(amount: 600)],
        );
        await expectLater(repo.editOccurrence(saved, wrong), throwsStateError);
        await db.update(
          'cardio_occurrences',
          {'status': 'completed'},
          where: 'id=?',
          whereArgs: [o.id],
        );
        await expectLater(repo.editOccurrence(saved, next), throwsStateError);
        await expectLater(
          repo.move(
            saved,
            saved.date.add(const Duration(days: 1)),
            future: false,
          ),
          throwsStateError,
        );
      },
    );
    test(
      'default-name migration never rewrites completed or manually locked names',
      () async {
        await seed(status: 'completed');
        await PlanningLabelMigration.apply(db);
        expect(
          (await repo.occurrences()).single.workout.name,
          'Lockere Dauereinheit',
        );
        await db.delete(
          'app_meta',
          where: 'key=?',
          whereArgs: ['planning_labels_v1'],
        );
        await db.update('cardio_occurrences', {
          'status': 'planned',
          'locked': 1,
        });
        await PlanningLabelMigration.apply(db);
        expect(
          (await repo.occurrences()).single.workout.name,
          'Lockere Dauereinheit',
        );
        await db.delete(
          'app_meta',
          where: 'key=?',
          whereArgs: ['planning_labels_v1'],
        );
        await db.update('cardio_occurrences', {'locked': 0});
        await PlanningLabelMigration.apply(db);
        expect((await repo.occurrences()).single.workout.name, 'Dauerlauf');
      },
    );
  });
}
