import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/models/cardio_route.dart';
import 'package:trainy/models/training_program.dart';
import 'package:trainy/models/workout_planning.dart';
import 'package:trainy/repositories/activity_repository.dart';
import 'package:trainy/repositories/training_program_repository.dart';
import 'package:trainy/repositories/workout_planning_repository.dart';
import 'package:trainy/services/cardio_training.dart';
import 'package:trainy/services/database_schema_v2.dart';
import 'package:trainy/services/database_service.dart';
import 'package:trainy/services/strength_templates.dart';
import 'package:trainy/widgets/activity_day_badge.dart';

import 'support/confirmed_profiles.dart';

void main() {
  test(
    'duration parser accepts minutes, localized decimals and explicit seconds',
    () {
      for (final input in ['45', '45.0', '45,0', '45:00']) {
        expect(CardioUnits.parseDuration(input), 2700);
      }
      for (final input in ['45.5', '45,5', '45:30']) {
        expect(CardioUnits.parseDuration(input), 2730);
      }
      expect(CardioUnits.parseDuration('1:30:00'), 5400);
      for (final input in [
        '0',
        '-1',
        'NaN',
        '1:60',
        '1:2:60',
        '1:2:3:4',
        '1e2',
      ]) {
        expect(CardioUnits.parseDuration(input), isNull);
      }
    },
  );
  test(
    'easy reference and best time coexist, estimates are not a benchmark',
    () {
      final now = DateTime(2030, 1, 1);
      final p = AthleteRunningProfile(
        referenceSeconds: 2100,
        referenceMeters: 5000,
        bestSeconds: 1500,
        bestMeters: 5000,
        bestDate: now,
      );
      final copy = AthleteRunningProfile.fromJson(p.toJson());
      expect(copy.easySpeed, closeTo(5000 / 2100, .0001));
      expect(copy.fiveKmSpeed(now), closeTo(5000 / 1500, .0001));
      final easy = AthleteRunningProfile(referenceSeconds: 2100);
      expect(easy.fiveKmSpeed(now), isNull);
      final target = CardioTraining.prescribe(
        easy,
        CardioIntensity.easy,
        now: now,
      );
      target.validate();
      expect(target.minSpeed, isNull);
      expect(target.maxSpeed, closeTo(1000 / 445, .0001));
      expect(target.targetSource, 'estimated');
      final interval = CardioTraining.prescribe(
        easy,
        CardioIntensity.interval,
        now: now,
      );
      expect(interval.minSpeed, closeTo(5000 / 2100, .0001));
      final manual = target.copyWith(targetSource: 'manual', maxSpeed: 1);
      expect(CardioTraining.refreshTarget(manual, p), same(manual));
      expect(
        CardioTraining.refreshTarget(
          manual,
          p,
          force: true,
          now: now,
        ).targetSource,
        'benchmark',
      );
    },
  );
  test('standing recovery does not disable work-interval auto-pause', () {
    final steps =
        CardioWorkout(
          name: 'Intervals',
          steps: [
            CardioStep(repeat: 2, recoverySeconds: 60, standingRecovery: true),
          ],
        ).expandedSteps();
    expect(steps.map((s) => s.standingRecovery), [false, true, false]);
    expect(steps[1].movement, 'rest');
  });
  test(
    'first long run respects reported longest distance without a maximal test',
    () {
      for (final seconds in [2100.0, 2700.0]) {
        final profile = AthleteRunningProfile(
          setupVersion: 1,
          confirmedAnswers: confirmedAnswers,
          referenceKind: 'normal',
          level: RunningLevel.beginner,
          continuousMinutes: 45,
          referenceSeconds: seconds,
          canRunFiveKm: true,
          recentRunsPerWeek: 3,
          longestMeters: 3000,
        );
        final plan = RunningPlanGenerator().generate(
          profile,
          RunningPlanRequest(
            startDate: DateTime(2030, 1, 7),
            targetMeters: 5000,
          ),
          (s) => s,
        );
        final first =
            plan.occurrences
                .firstWhere((o) => o.workout.templateCode == 'longRun')
                .workout
                .steps
                .single;
        expect(first.amount * first.maxSpeed!, lessThanOrEqualTo(3000));
      }
    },
  );
  test('mixed split, explicit focus and defaults survive serialization', () {
    final p = TrainingProgram(
      name: 'Training plan',
      start: DateTime(2030),
      slots: ProgramSplits.slots([1, 2, 5], 'mixedSplit'),
    );
    final copy = TrainingProgram.fromJson(p.toJson());
    expect(copy.availableDays, [1, 2, 3, 4, 5, 6, 7]);
    expect(copy.slots.map((s) => s.label), [
      'pushCore',
      'pullLegs',
      'fullBody',
    ]);
    expect(copy.slots[1].legHeavy, isTrue);
    expect(copy.slots[0].legHeavy, isFalse);
    expect(ProgramSplits.suggestedDays(copy.availableDays, 3), [1, 3, 5]);
    final run = ProgramSplits.suggestedDays(
      copy.availableDays,
      3,
      avoid: {1, 3, 5},
    );
    expect(run.toSet().intersection({1, 3, 5}), isEmpty);
  });
  test('base and extra templates keep user sets; no pretend home pull-up', () {
    final push = StrengthTemplates.exercises('pushCore');
    expect(push.where((e) => !e.extra).length, 5);
    expect(push.first.prescription.sets, 3);
    expect(StrengthTemplates.pullup.forEquipment({'bodyweight'}), isNull);
    expect(
      StrengthTemplates.pullup.forEquipment({'bodyweight', 'pull_up_bar'}),
      isNotNull,
    );
    expect(
      StrengthTemplates.exercises('fullBody').where((e) => !e.extra).length,
      6,
    );
    expect(
      StrengthTemplates.exercises(
        'upper',
      ).every((e) => !['legs', 'core'].contains(e.focus)),
      isTrue,
    );
  });
  test(
    'partial day and streak use every dated occurrence, strength has priority',
    () {
      final monday = DateTime(2030, 1, 7);
      ProgramEntry e(String id, String kind, bool done, DateTime date) =>
          ProgramEntry(
            id: id,
            planId: 'p',
            date: date,
            name: id,
            kind: kind,
            completed: done,
          );
      final values = [
        e('run', 'running', true, monday),
        e('strength', 'strength', false, monday),
      ];
      final state = ActivityDayState.fromEntries(values);
      expect(state.kind, 'strength');
      expect(state.fraction, .5);
      expect(state.done, isFalse);
      expect(datedPlanStreak(values, monday.add(const Duration(days: 2))), 0);
      expect(
        datedPlanStreak([
          e('done', 'strength', true, monday),
        ], monday.add(const Duration(days: 2))),
        1,
      );
    },
  );
  test('routes preserve GPS gaps even with sparse display sampling', () {
    final samples = [
      for (var i = 0; i < 4; i++)
        {
          'latitude': 52.0 + i / 1000,
          'longitude': 13.0,
          'timestamp': i * 1000,
          'routeSegment': i < 2 ? 1 : 2,
        },
    ];
    expect(routeSegments(samples).map((s) => s.length), [2, 2]);
    expect(
      routeSegments([
        {'latitude': 52, 'longitude': 13, 'timestamp': 0},
        {'latitude': 52.1, 'longitude': 13, 'timestamp': 20000},
      ]).length,
      2,
    );
    expect(routeLongitude(-179.9, 179.9), closeTo(180.1, .0001));
  });

  group('dated strength storage', () {
    late Database db;
    late DatabaseService database;
    late TrainingProgramRepository programs;
    late WorkoutPlanningRepository workouts;
    final monday = DateTime(2030, 1, 7);
    setUpAll(sqfliteFfiInit);
    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseSchemaV2.schemaVersion,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
          onCreate: (db, _) => DatabaseSchemaV2.create(db),
        ),
      );
      database = DatabaseService(database: db);
      programs = TrainingProgramRepository(database: database);
      await seedProfiles(db);
      workouts = WorkoutPlanningRepository(database: database);
      await db.insert('training_profiles_v2', {
        'id': 'home',
        'name': 'Home',
        'created_at_utc': 1,
        'updated_at_utc': 1,
      });
      for (var i = 1; i <= 4; i++) {
        await db.insert('exercises', {
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
    });
    tearDown(() async {
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await db.close();
    });
    Future<(TrainingProgram, WorkoutSetup, ProgramEntry)> fixture() async {
      final w = await workouts.createWorkout(
        const WorkoutEditorDraft(
          name: 'Full body',
          primaryGoal: WorkoutPrimaryGoal.strength,
          setupName: 'Home',
          profileId: 'home',
          exerciseIds: [1, 2, 3, 4],
          prescriptions: {
            1: StrengthPrescription(sets: 3),
            2: StrengthPrescription(sets: 2),
          },
        ),
      );
      final setup = (await workouts.setupsForWorkout(w.canonicalId)).single;
      final p = TrainingProgram(
        name: 'Training plan',
        start: monday,
        slots: [
          ProgramSlot(weekday: 1, label: 'fullBody', workoutId: w.canonicalId),
        ],
      );
      await programs.save(p);
      final entry =
          (await programs.entries(
            p,
            monday,
            monday.add(const Duration(days: 7)),
          )).single;
      return (p, setup, entry);
    }

    test(
      'split partitions slots once, preserves prescriptions and next week; undo restores',
      () async {
        final (p, setup, entry) = await fixture();
        final slots =
            setup.groups.expand((g) => g.selectedVariant.slots).toList();
        await programs.splitStrength(
          entry,
          slots.take(2).map((s) => s.id).toSet(),
          monday.add(const Duration(days: 2)),
        );
        final parts = await programs.entries(
          p,
          monday,
          monday.add(const Duration(days: 7)),
        );
        expect(parts.length, 2);
        expect(parts.every((e) => e.splitSourceId == entry.id), isTrue);
        final combined = <int>[];
        for (final part in parts) {
          final s = (await workouts.setupsForWorkout(part.workoutId!)).single;
          combined.addAll(
            s.groups
                .expand((g) => g.selectedVariant.slots)
                .map((s) => s.localExerciseId),
          );
        }
        expect(combined.toSet(), {1, 2, 3, 4});
        expect(combined.length, 4);
        expect((await db.query('workout_slot_prescriptions')).length, 4);
        final next = await programs.entries(
          p,
          monday.add(const Duration(days: 7)),
          monday.add(const Duration(days: 14)),
        );
        expect(next.single.workoutId, entry.workoutId);
        await programs.undoSplit(entry.id);
        expect(
          (await programs.entries(
            p,
            monday,
            monday.add(const Duration(days: 7)),
          )).single.workoutId,
          entry.workoutId,
        );
        expect((await db.query('workout_templates')).length, 1);
        expect((await db.query('workout_slot_prescriptions')).length, 2);
        expect(
          (await db.query(
            'exercises',
          )).every((e) => e['defaultValues'] == '{}'),
          isTrue,
        );
      },
    );
    test(
      'started split parts cannot be moved or undone; session links survive',
      () async {
        final (p, setup, entry) = await fixture();
        final slots =
            setup.groups.expand((g) => g.selectedVariant.slots).toList();
        await programs.splitStrength(entry, {
          slots.first.id,
        }, monday.add(const Duration(days: 2)));
        final parts = await programs.entries(
          p,
          monday,
          monday.add(const Duration(days: 7)),
        );
        final part = parts.first;
        final w = (await workouts.workouts()).firstWhere(
          (w) => w.canonicalId == part.workoutId,
        );
        final session = await ActivityRepository(
          databaseService: database,
        ).startWorkoutActivity(
          localWorkoutId: w.id,
          nameSnapshot: w.name,
          activityType: 'strength',
          tags: ['strength'],
          items: [],
          workoutId: w.canonicalId,
          trainingProgramId: p.id,
          plannedOccurrenceId: part.id,
          startedAt: part.date,
        );
        await expectLater(programs.undoSplit(entry.id), throwsStateError);
        await expectLater(
          programs.moveStrength(
            p,
            part,
            monday.add(const Duration(days: 3)),
            future: false,
          ),
          throwsStateError,
        );
        await ActivityRepository(databaseService: database).completeSession(
          session.sessionId,
          endedAt: part.date.add(const Duration(minutes: 20)),
        );
        final after = await programs.entries(
          p,
          monday,
          monday.add(const Duration(days: 7)),
        );
        expect(after.where((e) => e.completed).length, 1);
      },
    );
    test(
      'future weekday change retains split parts and dated overrides without duplicates',
      () async {
        final (p, setup, first) = await fixture();
        final next =
            (await programs.entries(
              p,
              monday.add(const Duration(days: 7)),
              monday.add(const Duration(days: 14)),
            )).single;
        await programs.splitStrength(next, {
          setup.groups.expand((g) => g.selectedVariant.slots).first.id,
        }, monday.add(const Duration(days: 9)));
        final third =
            (await programs.entries(
              p,
              monday.add(const Duration(days: 14)),
              monday.add(const Duration(days: 21)),
            )).single;
        await programs.moveStrength(
          p,
          third,
          monday.add(const Duration(days: 17)),
          future: false,
        );
        await programs.moveStrength(
          p,
          first,
          monday.add(const Duration(days: 1)),
          future: true,
        );
        final changed = (await programs.plans()).single;
        final entries = await programs.entries(
          changed,
          monday,
          monday.add(const Duration(days: 21)),
        );
        expect(entries.length, 4);
        expect(entries.map((e) => calendarDays(e.date, monday)), [1, 7, 9, 17]);
        expect(entries.where((e) => e.splitSourceId != null).length, 2);
        final source =
            entries.firstWhere((e) => e.splitSourceId != null).splitSourceId!;
        await programs.undoSplit(source);
        final restored = await programs.entries(
          changed,
          monday,
          monday.add(const Duration(days: 21)),
        );
        expect(restored.map((e) => calendarDays(e.date, monday)), [1, 8, 17]);
      },
    );
    test('schema 8 upgrade is additive and idempotent', () async {
      final (p, setup, entry) = await fixture();
      for (final table in [
        'strength_session_links',
        'strength_occurrence_parts',
        'workout_slot_prescriptions',
      ]) {
        await db.execute('DROP TABLE $table');
      }
      await DatabaseSchemaV2.upgrade(db, 8, 9);
      await DatabaseSchemaV2.upgrade(db, 8, 9);
      expect((await programs.plans()).single.id, p.id);
      expect(
        (await workouts.setupsForWorkout(entry.workoutId!)).single.id,
        setup.id,
      );
      expect((await db.query('exercises')).length, 4);
      expect(await db.query('strength_occurrence_parts'), isEmpty);
    });
    test(
      'editing a started slot preserves history and only changes future recurrences',
      () async {
        final (p, _, entry) = await fixture();
        final workout = (await workouts.workouts()).single;
        final activity = ActivityRepository(databaseService: database);
        final session = await activity.startWorkoutActivity(
          localWorkoutId: workout.id,
          nameSnapshot: workout.name,
          activityType: 'strength',
          tags: ['strength'],
          items: [],
          workoutId: workout.canonicalId,
          trainingProgramId: p.id,
          plannedOccurrenceId: entry.id,
          startedAt: monday,
        );
        await activity.completeSession(
          session.sessionId,
          endedAt: monday.add(const Duration(minutes: 30)),
        );
        await programs.save(
          p.copyWith(
            slots: [
              p.slots.single.copyWith(
                label: 'pushCore',
                focus: ['push', 'core'],
              ),
            ],
          ),
        );
        final changed = (await programs.plans()).single;
        final entries = await programs.entries(
          changed,
          monday,
          monday.add(const Duration(days: 14)),
        );
        expect(entries.length, 2);
        expect(entries.first.id, entry.id);
        expect(entries.first.sessionId, session.sessionId);
        expect(entries.first.completed, isTrue);
        expect(entries.last.slotId, isNot(entry.slotId));
        final shortened = changed.copyWith(
          endDate: monday.subtract(const Duration(days: 1)),
          start: monday.subtract(const Duration(days: 7)),
        );
        await programs.save(shortened);
        expect(
          (await programs.entries(
            shortened,
            monday,
            monday.add(const Duration(days: 14)),
          )).single.sessionId,
          session.sessionId,
        );
      },
    );
    test(
      'invalid split is atomic; end date is inclusive; moving does not duplicate',
      () async {
        final (p, setup, entry) = await fixture();
        await expectLater(
          programs.splitStrength(entry, {
            'missing',
          }, monday.add(const Duration(days: 1))),
          throwsStateError,
        );
        expect((await db.query('workout_templates')).length, 1);
        final short = p.copyWith(endDate: monday);
        await programs.save(short);
        await expectLater(
          programs.splitStrength(entry, {
            setup.groups.expand((g) => g.selectedVariant.slots).first.id,
          }, monday.add(const Duration(days: 1))),
          throwsStateError,
        );
        expect(
          (await programs.entries(
            short,
            monday,
            monday.add(const Duration(days: 14)),
          )).length,
          1,
        );
        await expectLater(
          programs.moveStrength(
            short,
            entry,
            monday.add(const Duration(days: 1)),
            future: false,
          ),
          throwsStateError,
        );
        final cloned = await workouts.createSetup(
          workoutId: entry.workoutId!,
          name: 'Second',
          copyFromSetupId: setup.id,
        );
        expect(
          cloned.groups
              .expand((g) => g.selectedVariant.slots)
              .where((s) => s.prescription != null)
              .length,
          2,
        );
      },
    );
  });
}
