import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/models/training_program.dart';
import 'package:trainy/repositories/cardio_repository.dart';
import 'package:trainy/repositories/training_program_repository.dart';
import 'package:trainy/services/cardio_training.dart';
import 'package:trainy/services/database_schema_v2.dart';
import 'package:trainy/services/database_service.dart';
import 'package:trainy/services/profile_readiness.dart';
import 'package:trainy/services/running_assessment.dart';
import 'support/confirmed_profiles.dart';

void main() {
  final start = DateTime(2030, 1, 7);
  RunningPlanProposal plan(AthleteRunningProfile p) =>
      RunningPlanGenerator().generate(
        p,
        RunningPlanRequest(targetMeters: 5000, startDate: start),
        (s) => s,
      );

  test(
    'old or visited profiles are not confirmed; unknown load is allowed',
    () {
      final old = confirmedRunner({'setupVersion': 0, 'confirmedAnswers': []});
      expect(
        ProfileReadiness.running(old),
        containsAll(['confirmProfile', 'volume']),
      );
      expect(() => plan(old), throwsA(isA<ProfileIncomplete>()));
      final ready = confirmedRunner({
        'weeklyMeters': null,
        'recentRunsPerWeek': null,
        'loadSource': 'unknown',
      });
      expect(ProfileReadiness.running(ready), isEmpty);
      expect(RunningAssessment.level(ready), RunningLevel.beginner);
      expect(ready.toJson()['loadSource'], 'unknown');
      expect(
        ProfileReadiness.running(confirmedRunner({'referenceSeconds': null})),
        contains('reference'),
      );
      expect(
        ProfileReadiness.running(
          confirmedRunner({'referenceKind': 'maximal', 'referenceDate': null}),
        ),
        contains('testDate'),
      );
    },
  );

  test('45 minutes produces 9:30 easy cap and no lower speed bound', () {
    final p = confirmedRunner();
    final easy = CardioTraining.prescribe(p, CardioIntensity.easy);
    expect(CardioUnits.pace(easy.maxSpeed, DistanceSystem.metric), '9:30 /km');
    expect(easy.minSpeed, isNull);
    expect(easy.targetSource, 'estimated');
    final interval = CardioTraining.prescribe(p, CardioIntensity.interval);
    expect(interval.minSpeed, closeTo(5000 / 2700, .00001));
    expect(interval.maxSpeed, closeTo(5000 / 2700 / .95, .00001));
    final manual = easy.copyWith(maxSpeed: 2, targetSource: 'manual');
    expect(CardioTraining.refreshTarget(manual, p), same(manual));
    final walk = confirmedRunner({
      'referenceKind': 'runWalk',
      'continuousMinutes': 10,
    });
    final walkStep = CardioTraining.prescribe(walk, CardioIntensity.easy);
    expect(walkStep.maxSpeed, isNull);
    expect(walkStep.minSpeed, isNull);
  });

  test(
    'other distances normalize orientation but do not become race benchmarks',
    () {
      final p = confirmedRunner({
        'referenceMeters': 10000,
        'referenceSeconds': 6000,
      });
      expect(p.easySpeed, closeTo(5000 / (6000 * math.pow(.5, 1.06)), .00001));
      expect(p.fiveKmSpeed(start), isNull);
      expect(
        AthleteRunningProfile.fromJson(
          jsonDecode(jsonEncode(p.toJson())),
        ).toJson(),
        p.toJson(),
      );
    },
  );
  test(
    'target refresh preserves gentle interval and progression roles after serialization',
    () {
      final proposal = plan(confirmedRunner());
      final changed = confirmedRunner({'referenceSeconds': 2400});
      for (final variant in ['lightInterval', 'progressionMid']) {
        final original = proposal.occurrences
            .expand((o) => o.workout.steps)
            .firstWhere((s) => s.targetVariant == variant);
        final step = CardioStep.fromJson(original.toJson());
        final updated = CardioTraining.refreshTarget(step, changed, now: start);
        expect(updated.id, original.id);
        expect(updated.targetVariant, variant);
        expect(updated.intensity, CardioIntensity.steady);
        if (variant == 'lightInterval') {
          expect(updated.maxSpeed, closeTo(changed.easySpeed! / .95, .00001));
        } else {
          expect(updated.maxSpeed, lessThan(changed.easySpeed!));
        }
        updated.validate();
      }
    },
  );

  test(
    'load and continuous ability, never 49/60-minute boundaries, determine level',
    () {
      for (final time in [1800, 2940, 3000, 3540, 3600, 3660]) {
        expect(
          RunningAssessment.level(confirmedRunner({'referenceSeconds': time})),
          RunningLevel.beginner,
        );
      }
      expect(
        RunningAssessment.level(confirmedRunner({'continuousMinutes': 29})),
        RunningLevel.starting,
      );
      expect(
        RunningAssessment.level(confirmedRunner({'returningAfterBreak': true})),
        RunningLevel.starting,
      );
      expect(
        RunningAssessment.level(confirmedRunner({'level': 'experienced'})),
        RunningLevel.beginner,
      );
      expect(
        RunningAssessment.level(
          confirmedRunner({
            'level': 'intermediate',
            'weeklyMeters': 20000,
            'experienceMonths': 6,
            'longestMeters': 8000,
          }),
        ),
        RunningLevel.intermediate,
      );
      expect(
        RunningAssessment.level(
          confirmedRunner({
            'level': 'experienced',
            'weeklyMeters': 60000,
            'experienceMonths': 24,
            'longestMeters': 15000,
            'recentRunsPerWeek': 5,
          }),
        ),
        RunningLevel.experienced,
      );
    },
  );

  test(
    'two and three day beginners get progression, fartlek, varied intervals and recovery',
    () {
      for (final days in [
        [2, 6],
        [1, 3, 6],
      ]) {
        final result = plan(confirmedRunner({'weekdays': days}));
        List<ScheduledCardioWorkout> week(int n) =>
            result.occurrences
                .where((o) => calendarDays(o.date, start) ~/ 7 == n)
                .toList();
        expect(
          week(0).any((o) => o.workout.templateCode == 'progression'),
          isTrue,
        );
        expect(week(1).any((o) => o.workout.templateCode == 'fartlek'), isTrue);
        expect(
          week(2).any((o) => o.workout.templateCode == 'intervalSession'),
          isTrue,
        );
        expect(
          week(3).every(
            (o) => o.workout.steps.every(
              (s) => s.intensity == CardioIntensity.easy,
            ),
          ),
          isTrue,
        );
        for (final o in result.occurrences) {
          o.workout.validate();
        }
        final light =
            week(
              1,
            ).firstWhere((o) => o.workout.templateCode == 'fartlek').workout;
        expect(
          light.steps
              .where((s) => s.repeat > 1)
              .every((s) => s.amount <= 90 && s.recoverySeconds >= 90),
          isTrue,
        );
      }
      final base = plan(
        confirmedRunner({
          'level': 'starting',
          'continuousMinutes': 10,
          'referenceKind': 'runWalk',
        }),
      );
      expect(base.baseWeeks, 9);
      expect(
        base.occurrences
            .expand((o) => o.workout.steps)
            .any(
              (s) =>
                  s.intensity == CardioIntensity.threshold ||
                  s.intensity == CardioIntensity.interval,
            ),
        isFalse,
      );
      expect(
        base.occurrences
            .take(12)
            .every((o) => o.workout.templateCode == 'runWalk'),
        isTrue,
      );
    },
  );

  test(
    'cross-sport and disjoint strength are allowed; concrete duplicate focus is flagged',
    () {
      final slots = [
        ProgramSlot(weekday: 1, label: 'push'),
        ProgramSlot(weekday: 1, label: 'pull'),
        ProgramSlot(weekday: 1, label: 'pushCore'),
      ];
      final p = TrainingProgram(name: 'Test', start: start, slots: slots);
      ProgramEntry entry(int i) => ProgramEntry(
        id: '$i',
        planId: p.id,
        date: start,
        name: slots[i].label,
        kind: 'strength',
        slotId: slots[i].id,
      );
      final run = ProgramEntry(
        id: 'run',
        planId: p.id,
        date: start,
        name: 'Easy',
        kind: 'running',
      );
      expect(planPlacementWarning(p, entry(0), start, [run, entry(1)]), isNull);
      expect(
        planPlacementWarning(p, entry(0), start, [entry(2)]),
        'strengthOverlap',
      );
      expect(
        planPlacementWarning(p, entry(0), start.add(const Duration(days: 1)), [
          entry(2),
        ]),
        isNull,
      );
    },
  );

  group('repository profile gates are transactional', () {
    late Database db;
    late TrainingProgramRepository repo;
    late CardioRepository cardio;
    setUpAll(sqfliteFfiInit);
    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          onCreate: (d, _) => DatabaseSchemaV2.create(d),
          version: DatabaseSchemaV2.schemaVersion,
          onConfigure: (d) => d.execute('PRAGMA foreign_keys=ON'),
        ),
      );
      final service = DatabaseService(database: db);
      repo = TrainingProgramRepository(database: service);
      cardio = CardioRepository(database: service);
    });
    tearDown(() async {
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await db.close();
    });
    test(
      'draft cannot activate, and rejected saves leave no partial records',
      () async {
        final p = TrainingProgram(
          name: 'Test',
          start: start,
          slots: ProgramSplits.slots([1, 3, 5], 'fullBody'),
        );
        await repo.saveDraft('plan:new', {
          'configured': ['strength'],
          'program': p.toJson(),
        });
        await expectLater(repo.save(p), throwsA(isA<ProfileIncomplete>()));
        expect(await repo.plans(), isEmpty);
        await seedProfiles(db);
        await repo.save(p);
        await repo.saveUserProfile(const UserTrainingProfile());
        // Already-active plans stay usable without retroactively losing history.
        await repo.save(p);
        final other = TrainingProgram(
          name: 'Other',
          start: start,
          slots: [ProgramSlot(weekday: 2, label: 'mobility', kind: 'mobility')],
        );
        await repo.save(other);
        await expectLater(
          repo.activate(p.id),
          throwsA(isA<ProfileIncomplete>()),
        );
        expect(await repo.activeId(), other.id);
      },
    );
    test(
      'legacy direct running save and regenerated blocks enforce the same contract',
      () async {
        final proposal = plan(confirmedRunner());
        await expectLater(
          cardio.savePlan(proposal, 'Run'),
          throwsA(isA<ProfileIncomplete>()),
        );
        expect(await db.query('cardio_occurrences'), isEmpty);
        await seedProfiles(db);
        final p = TrainingProgram(
          name: 'Run',
          start: start,
          runningDays: [1, 3, 6],
        );
        await repo.save(p, running: proposal);
        final ids = (await cardio.occurrences()).map((o) => o.id).toSet();
        await cardio.saveProfile(const AthleteRunningProfile());
        await expectLater(
          repo.save(p, running: proposal),
          throwsA(isA<ProfileIncomplete>()),
        );
        expect((await cardio.occurrences()).map((o) => o.id).toSet(), ids);
      },
    );
  });
}
