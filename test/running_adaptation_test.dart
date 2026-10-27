import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/models/running_preferences.dart';
import 'package:trainy/services/cardio_training.dart';
import 'package:trainy/services/running_fitness.dart';
import 'package:trainy/services/running_rules.dart';
import 'package:trainy/services/profile_readiness.dart';
import 'package:trainy/services/database_schema_v2.dart';
import 'package:trainy/services/database_service.dart';
import 'package:trainy/repositories/cardio_repository.dart';
import 'support/confirmed_profiles.dart';

void main() {
  final now = DateTime(2030, 1, 7, 12);
  final engine = RunningFitness();
  Map<String, Object?> run(
    int day, {
    double speed = 1.9,
    String type = 'easySession',
    Map<String, dynamic> runtime = const {},
    Map<String, dynamic> feedback = const {},
    int stage = 0,
  }) => {
    'id': 'run$day',
    'source': 'manual',
    'started_at_utc': now.subtract(Duration(days: day)).millisecondsSinceEpoch,
    'runtime_json': jsonEncode({
      'status': 'completed',
      'sport': 'running',
      'activeSeconds': 1800,
      'distanceMeters': 1800 * speed,
      'gpsCoveredSeconds': 1800,
      'measurementVersion': 2,
      'indoor': false,
      'results': [
        {'partial': false},
      ],
      ...runtime,
    }),
    'snapshot_json': jsonEncode({
      'workout': {'templateCode': type, 'runWalkStage': stage},
      'feedback': {
        'rpe': 4,
        'discomfort': false,
        'talkComfort': true,
        'recovery': 'ready',
        'environment': 'flat',
        ...feedback,
      },
    }),
  };
  ScheduledCardioWorkout occurrence(
    String id, {
    bool locked = false,
    String status = 'planned',
    String? sessionId,
    String code = 'easySession',
    String? phase = 'build',
    List<CardioStep>? steps,
  }) => ScheduledCardioWorkout(
    id: id,
    planId: 'plan',
    date: now.add(const Duration(days: 1)),
    locked: locked,
    status: status,
    sessionId: sessionId,
    workout: CardioWorkout(
      name: 'Run',
      templateCode: code,
      trainingPhase: phase,
      steps:
          steps ??
          [
            CardioTraining.prescribe(
              confirmedRunner(),
              CardioIntensity.easy,
              amount: 1800,
            ),
          ],
    ),
  );

  test('bundled rules match the editable JSON and reject unsafe values', () {
    final source =
        jsonDecode(File('assets/config/running_rules.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(RunningRules.bundled.json, source);
    source['rules']['maximumSpeedIncrease']['value'] = .5;
    expect(() => RunningRules.fromJson(source), throwsFormatException);
  });
  test(
    'open continuation adds load but not pace evidence; old GPS is not certified',
    () {
      final history = [
        for (final day in [1, 3, 6])
          run(
            day,
            runtime: {
              'goalReached': true,
              'plannedHadPause': false,
              'hadPause': true,
              'activeSeconds': 2400,
              'distanceMeters': 4200,
              'gpsCoveredSeconds': 2400,
              'results': [
                {'seconds': 1800, 'meters': 3600, 'partial': false},
                {
                  'seconds': 600,
                  'meters': 600,
                  'partial': false,
                  'continuation': true,
                },
              ],
            },
          ),
      ];
      final fitness = engine.evaluate(history, now);
      expect(fitness.easySpeed, 2);
      expect(fitness.weeklySeconds, 1800);
      expect(fitness.longestSeconds, 2400);
      final legacy = engine.evaluate([
        for (final day in [1, 3, 6])
          run(day, runtime: {'measurementVersion': null}),
      ], now);
      expect(legacy.easySpeed, isNull);
      expect(legacy.sourceIds, hasLength(3));
    },
  );
  test(
    'route preference and per-day budgets use canonical meters without inventing a pace',
    () {
      final p = confirmedRunner({
        'planning': {
          ...confirmedPlanning.toJson(),
          'routePreference': 'distance',
          'routeMeters': 4000,
          'dayMinutes': {'1': 30},
        },
      });
      final result = RunningPlanGenerator().generate(
        p,
        RunningPlanRequest(targetMeters: 5000, startDate: now),
        (s) => s,
      );
      final easy = result.occurrences.first.workout.steps.first;
      expect(easy.goal, StepGoal.time);
      expect(easy.amount + 360, lessThanOrEqualTo(1800.01));
      expect(result.occurrences.first.workout.routeMeters, isNull);
      final noPace = AthleteRunningProfile.fromJson({
        ...p.toJson(),
        'referenceKind': 'none',
        'referenceSeconds': null,
      });
      final timePlan = RunningPlanGenerator().generate(
        noPace,
        RunningPlanRequest(targetMeters: 5000, startDate: now),
        (s) => s,
      );
      expect(
        timePlan.occurrences.first.workout.steps.first.goal,
        StepGoal.time,
      );
    },
  );
  test(
    'walking preparation graduates by feedback rather than calendar and never skips a run/walk stage',
    () {
      final p = confirmedRunner({
        'continuousMinutes': 5,
        'planning': {...confirmedPlanning.toJson(), 'walkPreparation': true},
      });
      final data = engine.evaluate([
        for (var i = 1; i <= 3; i++) run(i, type: 'walkPreparation'),
      ], now);
      final next = engine.propose(p, data, [
        occurrence('walk', code: 'walkPreparation'),
      ], (s) => s);
      expect(next.walkPreparation, false);
      expect(next.runWalkStage, 0);
      expect(next.changes['walk']!.templateCode, 'runWalk');
    },
  );
  test(
    'a load proposal leaves speed unchanged, stays within tolerated workload and does not catch up',
    () {
      final p = confirmedRunner();
      final data = RunningFitnessSnapshot(
        asOf: now,
        toleratedRuns: 3,
        weeklySeconds: 5400,
        longestSeconds: 1800,
        sourceIds: ['a', 'b', 'c'],
      );
      final next = engine.propose(p, data, [
        occurrence(
          'easy',
          steps: [
            CardioTraining.prescribe(p, CardioIntensity.easy, amount: 1500),
          ],
        ),
      ], (s) => s);
      expect(next.reason, 'buildLoad');
      expect(next.easySpeed, isNull);
      expect(next.changes['easy']!.steps.first.amount, 1575);
      expect(
        next.changes['easy']!.steps.first.maxSpeed,
        CardioTraining.prescribe(p, CardioIntensity.easy).maxSpeed,
      );
      final unproven = RunningFitnessSnapshot(asOf: now, weeklySeconds: 900);
      expect(
        engine.propose(p, unproven, [occurrence('easy')], (s) => s).changes,
        isEmpty,
      );
    },
  );
  test(
    'load adaptations preserve recovery/taper while refreshed easy guidance keeps their volume and structure',
    () {
      final p = confirmedRunner();
      final sessions = [
        for (final phase in ['recovery', 'taper', null])
          occurrence(phase ?? 'legacy', phase: phase),
      ];
      final pace = engine.propose(
        p,
        engine.evaluate([run(1), run(3), run(6)], now),
        sessions,
        (s) => s,
      );
      for (final o in sessions) {
        final next = pace.changes[o.id]!;
        expect(next.trainingPhase, o.workout.trainingPhase);
        expect(
          next.steps.map((s) => (s.id, s.amount, s.repeat, s.intensity)),
          o.workout.steps.map((s) => (s.id, s.amount, s.repeat, s.intensity)),
        );
      }
      final data = RunningFitnessSnapshot(
        asOf: now,
        toleratedRuns: 3,
        weeklySeconds: 9000,
        longestSeconds: 3600,
      );
      expect(engine.propose(p, data, sessions, (s) => s).changes, isEmpty);
      final difficult = RunningFitnessSnapshot(asOf: now, difficult: true);
      expect(
        engine.propose(p, difficult, sessions, (s) => s).changes,
        hasLength(3),
      );
      final workout = sessions.first.workout;
      expect(
        CardioWorkout.fromJson(workout.toJson()).trainingPhase,
        'recovery',
      );
      expect(workout.timeReplacement().trainingPhase, 'recovery');
      final plan = RunningPlanGenerator().generate(
        p,
        RunningPlanRequest(targetMeters: 5000, startDate: now),
        (s) => s,
      );
      expect(
        plan.occurrences
            .where(
              (o) =>
                  o.date
                          .difference(DateTime(now.year, now.month, now.day))
                          .inDays ~/
                      7 ==
                  3,
            )
            .every((o) => o.workout.trainingPhase == 'recovery'),
        true,
      );
      expect(plan.occurrences.last.workout.trainingPhase, 'taper');
    },
  );
  test(
    'three comparable easy runs are required, and faster outliers are excluded',
    () {
      expect(engine.evaluate([run(1), run(3)], now).easySpeed, isNull);
      final data = engine.evaluate([run(1), run(3), run(6)], now);
      expect(data.easySpeed, 1.9);
      expect(data.easySourceIds, hasLength(3));
      final outlier = engine.evaluate([
        run(1, speed: 5),
        run(8),
        run(9),
        run(10),
      ], now);
      expect(outlier.easySpeed, 1.9);
      expect(outlier.excluded['run1'], 'paceOutlier');
      expect(
        engine.evaluate([run(1, speed: 5), run(8), run(9)], now).easySpeed,
        isNull,
      );
    },
  );
  test(
    'incomplete sessions do not establish load or long-run tolerance but retain symptom evidence',
    () {
      final data = engine.evaluate([
        run(1, runtime: {'finishedEarly': true}),
        run(2, runtime: {'recovered': true}),
        run(
          3,
          runtime: {
            'results': [
              {'partial': true},
            ],
          },
          feedback: {'discomfort': true},
        ),
      ], now);
      expect(data.weeklySeconds, 0);
      expect(data.longestSeconds, 0);
      expect(data.toleratedRuns, 0);
      expect(data.difficult, true);
      expect(data.excluded.values, everyElement('incomplete'));
    },
  );
  test(
    'intervals, walks, pauses, poor GPS and incomplete runs cannot calibrate easy pace',
    () {
      for (final runtime in [
        {'gpsCoveredSeconds': 400},
        {'hadPause': true},
        {'finishedEarly': true},
        {
          'results': [
            {'partial': true},
          ],
        },
        {'recovered': true},
        {'durationBasis': 'elapsed'},
      ]) {
        expect(
          engine.evaluate([
            for (var i = 1; i <= 3; i++) run(i, runtime: runtime),
          ], now).easySpeed,
          isNull,
        );
      }
      for (final type in ['runWalk', 'intervalSession', 'progression']) {
        expect(
          engine.evaluate([
            for (var i = 1; i <= 3; i++) run(i, type: type),
          ], now).easySpeed,
          isNull,
        );
      }
      expect(
        engine.evaluate([
          run(1),
          run(2),
          run(3, feedback: {'environment': 'heat'}),
        ], now).easySpeed,
        isNull,
      );
      expect(
        engine.evaluate([
          run(1),
          run(2),
          run(3, runtime: {'indoor': true, 'distanceMeasured': true}),
        ], now).easySpeed,
        isNull,
      );
      expect(engine.evaluate([run(1), run(2), run(31)], now).easySpeed, isNull);
      expect(engine.evaluate([run(1), run(1), run(2)], now).easySpeed, isNull);
      expect(
        engine.evaluate([
          run(1),
          run(2),
          run(3, feedback: {'talkComfort': null}),
        ], now).easySpeed,
        isNull,
      );
    },
  );
  test(
    'pace proposals are capped, explain sources and preserve manual/started/completed targets',
    () {
      final p = confirmedRunner();
      final easy = CardioTraining.prescribe(p, CardioIntensity.easy).maxSpeed!;
      final data = engine.evaluate([run(1), run(3), run(6)], now);
      final manual = CardioStep(
        amount: 1200,
        maxSpeed: 2.5,
        targetSource: 'manual',
      );
      final list = [
        occurrence(
          'new',
          steps: [
            CardioStep(amount: 1200, maxSpeed: easy, targetSource: 'estimated'),
            manual,
          ],
        ),
        occurrence('locked', locked: true),
        occurrence('done', status: 'completed'),
        occurrence('started', sessionId: 'session'),
      ];
      final proposal = engine.propose(p, data, list, (s) => s);
      expect(proposal.reason, 'easyPaceEvidence');
      expect(proposal.easySpeed, closeTo(easy * 1.02, .00001));
      expect(proposal.changes.keys, ['new']);
      expect(proposal.changes['new']!.steps.last.toJson(), manual.toJson());
      expect(proposal.changes['new']!.steps.first.amount, 1200);
      final changed = confirmedRunner({
        'planning': {
          ...p.planning.toJson(),
          'easySpeed': easy,
          'paceUpdatedAt':
              now.subtract(const Duration(days: 6)).toIso8601String(),
        },
      });
      expect(engine.propose(changed, data, list, (s) => s).changes, isEmpty);
    },
  );
  test(
    'complaints reduce load instead of raising pace; manual targets remain untouched',
    () {
      final data = engine.evaluate([
        run(1, feedback: {'discomfort': true}),
        run(3),
        run(6),
      ], now);
      expect(data.difficult, true);
      final manual = CardioStep(
        amount: 900,
        targetSource: 'manual',
        maxSpeed: 2,
      );
      final proposal = engine.propose(confirmedRunner(), data, [
        occurrence(
          'one',
          steps: [CardioStep(amount: 1000, targetSource: 'estimated'), manual],
        ),
      ], (s) => s);
      expect(proposal.reason, 'reduceLoad');
      expect(proposal.easySpeed, isNull);
      expect(proposal.changes['one']!.steps.first.amount, 800);
      expect(proposal.changes['one']!.steps.last.toJson(), manual.toJson());
    },
  );
  test(
    'run/walk progresses only after three tolerated completions of the current stage',
    () {
      final history = [
        run(1, type: 'runWalk'),
        run(3, type: 'runWalk'),
        run(5, type: 'runWalk'),
      ];
      final p = confirmedRunner({
        'continuousMinutes': 10,
        'referenceKind': 'none',
        'referenceSeconds': null,
        'planning': {...confirmedPlanning.toJson(), 'minutesPerSession': 10},
      });
      final proposal = engine.propose(p, engine.evaluate(history, now), [
        occurrence('walk', code: 'runWalk'),
      ], (s) => s);
      expect(proposal.runWalkStage, 1);
      expect(
        proposal.changes['walk']!.expandedSteps().fold<double>(
          0,
          (sum, s) => sum + s.amount,
        ),
        lessThanOrEqualTo(240),
      );
      expect(
        engine.evaluate(history, now, runWalkStage: 1).successfulRunWalk,
        0,
      );
      expect(
        engine
            .evaluate(
              history,
              now,
              stageSince: now.subtract(const Duration(days: 2)),
            )
            .successfulRunWalk,
        1,
      );
      expect(
        engine.evaluate([
          run(1, type: 'runWalk', feedback: {'recovery': 'poor'}),
        ], now).successfulRunWalk,
        0,
      );
    },
  );
  test(
    'new answers and manual zones round-trip without confirming legacy profiles',
    () {
      final p = confirmedRunner({
        'referenceKind': 'none',
        'referenceSeconds': null,
        'planning': {
          ...confirmedPlanning.toJson(),
          'zoneMethod': 'manual',
          'zoneSource': 'diagnostic',
          'zoneBounds': [100, 120, 140, 160, 180, 200],
          'dayMinutes': {'1': 30, '3': 45},
          'adaptationHistory': [
            {'ruleVersion': 4, 'createdAt': now.toIso8601String()},
          ],
        },
      });
      expect(ProfileReadiness.running(p), isEmpty);
      final roundtrip = AthleteRunningProfile.fromJson(
        jsonDecode(jsonEncode(p.toJson())),
      );
      expect(roundtrip.toJson(), p.toJson());
      final target = CardioTraining.prescribe(roundtrip, CardioIntensity.easy);
      expect(target.minHeartRate, 120);
      expect(target.maxHeartRate, 140);
      expect(target.maxSpeed, isNull);
      expect(
        ProfileReadiness.running(const AthleteRunningProfile()),
        isNotEmpty,
      );
      expect(
        () =>
            RunningPreferences(
              zoneMethod: 'manual',
              zoneBounds: [100, 90, 120, 150, 180, 200],
            ).validate(),
        throwsFormatException,
      );
    },
  );
  test(
    'all levels, frequencies, goals and distances respect budgets and bounded quality',
    () {
      for (final level in RunningLevel.values) {
        for (var count = 1; count <= 6; count++) {
          for (final goal in ['runFaster', 'runFurther', 'firstDistance']) {
            for (final distance in [5000.0, 10000.0, 21097.5, 42195.0]) {
              final advanced = level.index >= 2;
              final p = confirmedRunner({
                'weekdays': [1, 2, 3, 4, 5, 6, 7],
                'level': level.name,
                'continuousMinutes':
                    level == RunningLevel.starting
                        ? 10
                        : advanced
                        ? 70
                        : 40,
                'experienceMonths': advanced ? 36 : 2,
                'recentRunsPerWeek': advanced ? 5 : 2,
                'longestMeters': advanced ? 12000 : 5000,
                'weeklyMeters': advanced ? 40000 : null,
                'planning': {
                  ...confirmedPlanning.toJson(),
                  'desiredDays': count,
                  'minutesPerSession': 30,
                  'highLoadTolerated': advanced,
                  'goal': goal,
                },
              });
              final result = RunningPlanGenerator().generate(
                p,
                RunningPlanRequest(
                  targetMeters: distance,
                  startDate: now,
                  goal: goal,
                ),
                (s) => s,
              );
              final byWeek = <int, int>{};
              for (final o in result.occurrences) {
                o.workout.validate();
                final seconds = o.workout.expandedSteps().fold<double>(
                  0,
                  (n, s) => n + s.amount,
                );
                expect(
                  seconds + 360,
                  lessThanOrEqualTo(1800.01),
                  reason: '$level/$count/$goal/$distance',
                );
                final quality = o.workout.steps.any(
                  (s) =>
                      s.intensity != CardioIntensity.easy &&
                      s.intensity != CardioIntensity.recovery,
                );
                if (quality) {
                  byWeek.update(
                    o.date.difference(DateTime(2030, 1, 7)).inDays ~/ 7,
                    (n) => n + 1,
                    ifAbsent: () => 1,
                  );
                }
              }
              expect(
                byWeek.values.every(
                  (n) =>
                      n <=
                      (level == RunningLevel.experienced && count >= 5 ? 2 : 1),
                ),
                true,
              );
              if (level == RunningLevel.starting) {
                expect(
                  result.occurrences.map((o) => o.workout.runWalkStage).toSet(),
                  {0},
                );
              }
            }
          }
        }
      }
    },
  );
  test(
    'stale best times do not prescribe pace; request evidence survives serialization',
    () {
      final p = confirmedRunner({
        'referenceKind': 'maximal',
        'isMaximal': true,
        'referenceDate':
            now.subtract(const Duration(days: 91)).toIso8601String(),
      });
      expect(
        CardioTraining.prescribe(p, CardioIntensity.easy, now: now).maxSpeed,
        isNull,
      );
      final req = RunningPlanRequest(
        targetMeters: 5000,
        startDate: now,
        fitness: engine.evaluate([run(1), run(3), run(5)], now),
        dayMinutes: {1: 30},
      );
      expect(
        RunningPlanRequest.fromJson(
          jsonDecode(jsonEncode(req.toJson())),
        ).toJson(),
        req.toJson(),
      );
    },
  );
  test(
    'acceptance is transactional, idempotent and rechecks newly locked rows',
    () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseSchemaV2.schemaVersion,
          onCreate: (d, _) => DatabaseSchemaV2.create(d),
        ),
      );
      final repo = CardioRepository(database: DatabaseService(database: db));
      try {
        final p = confirmedRunner();
        await repo.saveProfile(p);
        final plan = RunningPlanGenerator().generate(
          p,
          RunningPlanRequest(targetMeters: 5000, startDate: now),
          (s) => s,
        );
        await repo.savePlan(plan, 'Test');
        final before = await repo.occurrences();
        final proposal = engine.propose(
          p,
          engine.evaluate([run(1), run(3), run(6)], now),
          before,
          (s) => s,
        );
        expect(proposal.changes.length, greaterThan(1));
        final lockedId = proposal.changes.keys.first;
        final lockedBefore =
            before.firstWhere((o) => o.id == lockedId).workout.toJson();
        await db.update(
          'cardio_occurrences',
          {'locked': 1},
          where: 'id=?',
          whereArgs: [lockedId],
        );
        await repo.acceptAdaptation(proposal);
        await repo.acceptAdaptation(proposal);
        expect((await repo.profile()).planning.adaptationHistory, hasLength(1));
        expect(
          (await repo.occurrences())
              .firstWhere((o) => o.id == lockedId)
              .workout
              .toJson(),
          lockedBefore,
        );
        expect(
          (await repo.occurrences()).map((o) => o.id),
          before.map((o) => o.id),
        );
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      } finally {
        await db.close();
      }
    },
  );
}
