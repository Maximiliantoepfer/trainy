import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/models/running_preferences.dart';
import 'package:trainy/models/training_program.dart';
import 'package:trainy/repositories/cardio_repository.dart';
import 'package:trainy/repositories/training_program_repository.dart';
import 'package:trainy/services/cardio_training.dart';
import 'package:trainy/services/database_schema_v2.dart';
import 'package:trainy/services/database_service.dart';
import 'package:trainy/services/running_replan.dart';
import 'package:trainy/services/running_fitness.dart';
import 'package:trainy/services/running_forecast.dart';
import 'package:trainy/services/running_routes.dart';
import 'support/confirmed_profiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2030, 1, 7);
  test(
    'favorite routes migrate once, rank per day, never shrink to a different route',
    () {
      final legacy = RunningPreferences.fromJson({'routeMeters': 5000});
      expect(legacy.favoriteRoutes.single.meters, 5000);
      expect(
        RunningPreferences.fromJson(legacy.toJson()).favoriteRoutes.length,
        1,
      );
      expect(
        RunningPreferences.fromJson({
          ...legacy.toJson(),
          'favoriteRoutes': [],
        }).favoriteRoutes,
        isEmpty,
      );
      final routes = [
        FavoriteRunningRoute(id: 'a', meters: 5000),
        FavoriteRunningRoute(id: 'b', meters: 3000, weekdays: [1]),
      ];
      expect(
        RunningRoutes.select(
          routes,
          weekday: 1,
          maximumMeters: 6000,
          defaultMeters: 4000,
        )!.id,
        'b',
      );
      expect(
        RunningRoutes.select(
          routes,
          weekday: 2,
          maximumMeters: 6000,
          defaultMeters: 4000,
        )!.id,
        'a',
      );
      expect(
        RunningRoutes.select(
          routes,
          weekday: 2,
          maximumMeters: 2800,
          defaultMeters: 4000,
        ),
        isNull,
      );
      expect(
        RunningRoutes.select(
          [],
          weekday: 1,
          maximumMeters: 4200,
          defaultMeters: 4000,
        )!.meters,
        4000,
      );
    },
  );
  test(
    'whole-run route includes easy warmup and recovery without inflating quality repetitions',
    () {
      final p = confirmedRunner({
        'continuousMinutes': 60,
        'planning': {
          ...confirmedPlanning.toJson(),
          'weeklyMinutes': 180,
          'longestMinutes': 60,
          'longestDate': now.toIso8601String(),
          'longestEffort': 4,
          'minutesPerSession': 90,
          'favoriteRoutes': [
            FavoriteRunningRoute(
              id: 'loop',
              meters: 5500,
              name: 'Park',
            ).toJson(),
          ],
        },
      });
      final plan = RunningPlanGenerator().generate(
        p,
        RunningPlanRequest(targetMeters: 5000, startDate: now),
        (s) => s,
      );
      final quality = plan.occurrences.where(
        (o) =>
            o.workout.routeMeters != null &&
            ['fartlek', 'intervalSession'].contains(o.workout.templateCode),
      );
      expect(quality, isNotEmpty);
      for (final o in quality) {
        final w = o.workout;
        expect(w.steps.last.routeTotalMeters, w.routeMeters);
        expect(w.steps.last.intensity, CardioIntensity.easy);
        expect(
          w.steps.where((s) => s.repeat > 1).single.amount,
          lessThanOrEqualTo(90),
        );
        expect(w.estimatedSeconds, lessThanOrEqualTo(5400));
        expect(
          CardioWorkout.fromJson(w.toJson()).steps.last.routeTotalMeters,
          w.routeMeters,
        );
      }
    },
  );
  test(
    'strenuous longest run and longer interruption do not imply progression',
    () {
      final p = confirmedRunner({
        'continuousMinutes': 30,
        'returningAfterBreak': true,
        'planning': {
          ...confirmedPlanning.toJson(),
          'breakWeeks': 12,
          'longestMinutes': 120,
          'longestDate': now.toIso8601String(),
          'longestEffort': 9,
        },
      });
      final plan = RunningPlanGenerator().generate(
        p,
        RunningPlanRequest(targetMeters: 5000, startDate: now),
        (s) => s,
      );
      expect(
        plan.occurrences.every(
          (o) => ['easySession', 'longRun'].contains(o.workout.templateCode),
        ),
        true,
      );
      expect(
        plan.occurrences.every(
          (o) => o.workout.steps.every(
            (s) => s.goal == StepGoal.time && s.amount <= 1800,
          ),
        ),
        true,
      );
    },
  );
  test(
    'returning runners receive structural suggestions only after current tolerated evidence',
    () {
      final profile = confirmedRunner({
        'returningAfterBreak': true,
        'planning': {...confirmedPlanning.toJson(), 'breakWeeks': 12},
      });
      final request = RunningPlanRequest(
        targetMeters: 5000,
        startDate: now,
        fitness: RunningFitnessSnapshot(asOf: now),
      );
      final plan = RunningPlanGenerator().generate(profile, request, (s) => s);
      final planId = plan.occurrences.first.planId;
      final forecast = RunningForecast();
      expect(
        forecast.suggestStructure(
          profile,
          RunningFitnessSnapshot(asOf: now),
          plan.occurrences,
          {planId: request},
          (s) => s,
        ),
        isEmpty,
      );
      final ready = forecast.suggestStructure(
        profile,
        RunningFitnessSnapshot(
          asOf: now,
          toleratedRuns: 3,
          weeklySeconds: 8100,
          longestSeconds: 2700,
        ),
        plan.occurrences,
        {planId: request},
        (s) => s,
      );
      expect(ready, isNotEmpty);
      expect(ready.values.any((w) => w.templateCode == 'progression'), true);
      for (final entry in ready.entries) {
        final old =
            plan.occurrences.singleWhere((o) => o.id == entry.key).workout;
        expect(
          RunningForecast.duration(entry.value)!,
          lessThanOrEqualTo(RunningForecast.duration(old)! + .01),
        );
      }
    },
  );
  test(
    'replanning preserves protected IDs and history, rejects stale preview and repeat apply',
    () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseSchemaV2.schemaVersion,
          onCreate: (d, _) => DatabaseSchemaV2.create(d),
        ),
      );
      addTearDown(db.close);
      final database = DatabaseService(database: db);
      final cardio = CardioRepository(database: database),
          programs = TrainingProgramRepository(database: database);
      await seedProfiles(db);
      final plan = TrainingProgram(
        name: 'Mixed',
        start: now,
        runningDays: [1, 3, 6],
        slots: [
          ProgramSlot(weekday: 2, label: 'push', focus: ['push']),
        ],
      );
      final running = RunningPlanGenerator().generate(
        await cardio.profile(),
        RunningPlanRequest(targetMeters: 5000, startDate: now),
        (s) => s,
      );
      await programs.save(plan, running: running);
      final before = await cardio.occurrences();
      final completed = before.first;
      final session = await cardio.begin(
        completed.workout,
        occurrenceId: completed.id,
      );
      await cardio.saveRuntime({
        'sessionId': session,
        'status': 'completed',
        'sport': 'running',
        'activeSeconds': 1800,
        'distanceMeters': 3000,
        'results': [],
      });
      final history = await cardio.history();
      final active = before[2];
      final activeSession = await cardio.begin(
        active.workout,
        occurrenceId: active.id,
      );
      expect(
        (await cardio.occurrences())
            .singleWhere((o) => o.id == active.id)
            .sessionId,
        activeSession,
      );
      // Simulate a session started by an older app version without that link.
      await db.update(
        'cardio_occurrences',
        {'session_id': null},
        where: 'id=?',
        whereArgs: [active.id],
      );
      final protected = before[1];
      await db.update(
        'cardio_occurrences',
        {'locked': 1},
        where: 'id = ?',
        whereArgs: [protected.id],
      );
      final oldStrength =
          (await db.query('training_programs')).single['program_json']
              as String;
      final engine = RunningReplan(cardio);
      final stale = await engine.preview(plan, (s) => s, now: now);
      final profile = await cardio.profile();
      await cardio.saveProfile(
        AthleteRunningProfile.fromJson({
          ...profile.toJson(),
          'referenceSeconds': 2600,
        }),
      );
      await expectLater(engine.apply(stale), throwsStateError);
      final valid = await engine.preview(plan, (s) => s, now: now);
      // A normal clock tick must not invalidate a preview that already protects
      // the active occurrence. A start/completion still changes the fingerprint.
      await cardio.saveRuntime({
        'sessionId': activeSession,
        'status': 'active',
        'sport': 'running',
        'activeSeconds': 5,
        'distanceMeters': 7,
      });
      await engine.apply(valid);
      await expectLater(engine.apply(valid), throwsStateError);
      final after = await cardio.occurrences();
      expect(await cardio.history(), history);
      final finished = after.singleWhere((o) => o.id == completed.id);
      expect(finished.status, 'completed');
      expect(finished.sessionId, session);
      expect(finished.workout.toJson(), completed.workout.toJson());
      final stillActive = after.singleWhere((o) => o.id == active.id);
      expect(stillActive.workout.toJson(), active.workout.toJson());
      expect(stillActive.sessionId, activeSession);
      await cardio.acceptAdaptation(
        RunningAdaptationProposal(
          createdAt: now,
          ruleVersion: 6,
          fitness: RunningFitnessSnapshot(asOf: now),
          changes: {
            active.id: CardioWorkout(
              name: 'Must not replace',
              steps: active.workout.steps,
            ),
          },
          reason: 'structure',
        ),
      );
      expect(
        (await cardio.occurrences())
            .singleWhere((o) => o.id == active.id)
            .workout
            .toJson(),
        active.workout.toJson(),
      );
      await cardio.cancelStart(activeSession);
      expect(
        (await cardio.occurrences())
            .singleWhere((o) => o.id == active.id)
            .sessionId,
        isNull,
      );
      final locked = after.singleWhere((o) => o.id == protected.id);
      expect(locked.workout.toJson(), protected.workout.toJson());
      expect(locked.locked, true);
      expect(after.map((o) => o.id).toSet().length, after.length);
      final oldProgram = TrainingProgram.fromJson(
        jsonDecode(oldStrength) as Map<String, dynamic>,
      );
      final updated = (await programs.plans()).single;
      expect(
        updated.slots.map((s) => s.toJson()),
        oldProgram.slots.map((s) => s.toJson()),
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );
}
