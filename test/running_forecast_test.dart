import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/providers/cardio_provider.dart';
import 'package:trainy/repositories/cardio_repository.dart';
import 'package:trainy/services/cardio_health_service.dart';
import 'package:trainy/services/cardio_training.dart';
import 'package:trainy/services/database_schema_v2.dart';
import 'package:trainy/services/database_service.dart';
import 'package:trainy/services/running_fitness.dart';
import 'package:trainy/services/running_forecast.dart';
import 'support/confirmed_profiles.dart';

Map<String, Object?> healthRun(
  DateTime now,
  int day, {
  String provider = 'health_connect',
  bool? continuous = true,
  bool pause = false,
  String type = 'easy',
  String origin = 'watch.vendor',
}) {
  final start = now.subtract(Duration(days: day)).millisecondsSinceEpoch;
  return {
    'id': '$provider:$day',
    'source': provider,
    'started_at_utc': start,
    'runtime_json': jsonEncode({
      'status': 'completed',
      'sport': 'running',
      'activeSeconds': 1800,
      'elapsedSeconds': 1800,
      'startedAt': start,
      'endedAt': start + 1800000,
      'distanceMeters': 3420,
      'distanceMeasured': true,
      'durationBasis': 'elapsed',
      'hadPause': pause,
    }),
    'snapshot_json': jsonEncode({
      'health': {
        'provider': provider,
        'sourceId': origin,
        'externalId': '$day',
      },
      'feedback': {
        'rpe': 4,
        'discomfort': false,
        'talkComfort': true,
        'recovery': 'ready',
        'environment': 'flat',
        'runType': type,
        'continuous': continuous,
      },
    }),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2030, 1, 7, 12);
  final engine = RunningFitness();
  for (final provider in ['health_connect', 'healthkit']) {
    test(
      '$provider: confirmed continuous runs contribute without invented GPS coverage',
      () {
        final fit = engine.evaluate([
          for (final day in [1, 3, 5]) healthRun(now, day, provider: provider),
        ], now);
        expect(fit.easySpeed, closeTo(1.9, .0001));
        expect(fit.easySourceIds, hasLength(3));
        expect(fit.toleratedRuns, 3);
        expect(fit.weeklySeconds, 1350);
        for (final input in [
          [
            for (final d in [1, 3, 5])
              healthRun(now, d, provider: provider, continuous: null),
          ],
          [
            for (final d in [1, 3, 5])
              healthRun(now, d, provider: provider, pause: true),
          ],
          [
            for (final d in [1, 3, 5])
              healthRun(now, d, provider: provider, type: 'otherRun'),
          ],
        ]) {
          expect(engine.evaluate(input, now).easySpeed, isNull);
        }
      },
    );
  }
  test('overlapping providers never count as multiple comparable runs', () {
    final fit = engine.evaluate([
      healthRun(now, 1),
      healthRun(now, 1, provider: 'healthkit'),
      healthRun(now, 3),
    ], now);
    expect(fit.sourceIds, hasLength(2));
    expect(fit.easySpeed, isNull);
    expect(fit.excluded.values, contains('overlappingRecording'));
  });
  test(
    'pace forecast updates all future weeks and progression ramps, preserving structures',
    () {
      final p = confirmedRunner();
      final plan = RunningPlanGenerator().generate(
        p,
        RunningPlanRequest(targetMeters: 5000, startDate: now),
        (k) => k,
      );
      final fit = engine.evaluate([
        for (final d in [1, 3, 5]) healthRun(now, d),
      ], now);
      final proposal = engine.propose(p, fit, plan.occurrences, (k) => k);
      expect(proposal.reason, 'easyPaceEvidence');
      expect(proposal.changes.keys, contains(plan.occurrences.last.id));
      final oldSpeed =
          CardioTraining.prescribe(p, CardioIntensity.easy, now: now).maxSpeed!;
      expect(proposal.easySpeed, closeTo(oldSpeed * 1.02, .00001));
      for (final o in plan.occurrences) {
        final next = proposal.changes[o.id]!;
        next.validate();
        expect(next.id, o.workout.id);
        expect(
          next.steps.map(
            (s) => (s.id, s.amount, s.repeat, s.recoverySeconds, s.intensity),
          ),
          o.workout.steps.map(
            (s) => (s.id, s.amount, s.repeat, s.recoverySeconds, s.intensity),
          ),
        );
        expect(next.targetEvidenceIds, fit.easySourceIds);
        expect(CardioWorkout.fromJson(next.toJson()).toJson(), next.toJson());
      }
      final accepted = AthleteRunningProfile.fromJson({
        ...p.toJson(),
        'planning': {
          ...p.planning.toJson(),
          'adaptationHistory': [proposal.toJson()],
        },
      });
      expect(
        engine.propose(accepted, fit, plan.occurrences, (k) => k).changes,
        isEmpty,
      );
    },
  );
  test(
    'existing easy-only weeks receive a capped structure proposal, never personal edits',
    () {
      final p = confirmedRunner({
        'weekdays': [2, 4, 6],
      });
      final req = RunningPlanRequest(
        targetMeters: 5000,
        startDate: now,
        hardTrainingDays: [5],
      );
      final plan = RunningPlanGenerator().generate(p, req, (k) => k);
      final old = [
        for (final o in plan.occurrences)
          ScheduledCardioWorkout(
            id: o.id,
            planId: o.planId,
            date: o.date,
            workout: CardioWorkout(
              id: o.workout.id,
              name: 'Dauerlauf',
              templateCode: 'easySession',
              trainingPhase: o.workout.trainingPhase,
              ruleVersion: 4,
              steps: [
                CardioTraining.prescribe(p, CardioIntensity.easy, amount: 1500),
              ],
            ),
          ),
      ];
      final changes = RunningForecast().suggestStructure(
        p,
        RunningFitnessSnapshot(asOf: now),
        old,
        {plan.id: req},
        (k) => k,
      );
      expect(
        changes.values.any((w) => w.templateCode == 'progression'),
        isTrue,
      );
      expect(
        changes.values.any((w) => w.templateCode == 'intervalSession'),
        isTrue,
      );
      for (final w in changes.values) {
        expect(RunningForecast.duration(w), lessThanOrEqualTo(1500.001));
      }
      final protected = [
        for (final o in old)
          ScheduledCardioWorkout(
            id: o.id,
            planId: o.planId,
            date: o.date,
            workout: o.workout,
            locked: true,
          ),
      ];
      expect(
        RunningForecast().suggestStructure(
          p,
          RunningFitnessSnapshot(asOf: now),
          protected,
          {plan.id: req},
          (k) => k,
        ),
        isEmpty,
      );
    },
  );

  group('automatic recommendation lifecycle', () {
    late Database db;
    late CardioRepository repo;
    late CardioProvider provider;
    late DateTime today;
    setUpAll(sqfliteFfiInit);
    setUp(() async {
      today = DateTime.now();
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseSchemaV2.schemaVersion,
          onCreate: (d, _) => DatabaseSchemaV2.create(d),
        ),
      );
      repo = CardioRepository(database: DatabaseService(database: db));
      provider = CardioProvider(repository: repo);
      final profile = confirmedRunner();
      await repo.saveProfile(profile);
      await repo.savePlan(
        RunningPlanGenerator().generate(
          profile,
          RunningPlanRequest(targetMeters: 5000, startDate: today),
          (k) => k,
        ),
        'Plan',
      );
      // Exercise the actual accepted Health import path, including no route permission.
      final health = CardioHealthService(repo);
      for (final day in [1, 3, 5]) {
        final start =
            today.subtract(Duration(days: day)).millisecondsSinceEpoch;
        await health.accept({
          'provider': 'health_connect',
          'externalId': '$day',
          'sourceId': 'watch.vendor',
          'sport': 'running',
          'start': start,
          'end': start + 1800000,
          'distance': 3420,
          'indoor': false,
        }, name: 'Watch run');
      }
      for (final row in await repo.history()) {
        await repo.feedback(
          row['id'] as String,
          4,
          false,
          talkComfort: true,
          recovery: 'ready',
          environment: 'flat',
          runType: 'easy',
          continuous: true,
        );
      }
    });
    tearDown(() async {
      provider.dispose();
      await db.close();
    });
    test(
      'load computes, offers and confirms once without rewriting IDs/history',
      () async {
        final before = await repo.occurrences();
        final history = await repo.history();
        await provider.load();
        expect(provider.recommendationError, isNull);
        final proposal = provider.recommendation!;
        expect(proposal.reason, 'easyPaceEvidence');
        expect(
          (await repo.occurrences()).map((o) => o.workout.toJson()),
          before.map((o) => o.workout.toJson()),
        );
        await repo.acceptAdaptation(proposal);
        await repo.acceptAdaptation(proposal);
        await provider.load();
        expect(provider.recommendation, isNull);
        expect((await repo.profile()).planning.adaptationHistory, hasLength(1));
        expect(
          (await repo.occurrences()).map((o) => o.id),
          before.map((o) => o.id),
        );
        expect(await repo.history(), history);
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      },
    );
    test(
      'later survives reload and does not repeatedly prompt for the same evidence',
      () async {
        await provider.load();
        final proposal = provider.recommendation!;
        await repo.dismissAdaptation(proposal);
        await provider.load();
        expect(provider.recommendation, isNull);
        expect(
          (await repo.profile()).planning.dismissedAdaptations,
          contains(proposal.evidenceKey),
        );
      },
    );
    test(
      'feedback changing while preview is open invalidates the whole proposal',
      () async {
        await provider.load();
        final proposal = provider.recommendation!;
        final before =
            (await repo.occurrences()).map((o) => o.workout.toJson()).toList();
        await repo.feedback(
          (await repo.history()).first['id'] as String,
          9,
          true,
        );
        await expectLater(repo.acceptAdaptation(proposal), throwsStateError);
        expect(
          (await repo.occurrences()).map((o) => o.workout.toJson()),
          before,
        );
        await provider.load();
        expect(provider.recommendation!.reason, 'reduceLoad');
      },
    );
    test(
      'starting a proposed workout invalidates the proposal instead of applying half a week',
      () async {
        await provider.load();
        final proposal = provider.recommendation!;
        final id = proposal.changes.keys.first;
        await db.update(
          'cardio_occurrences',
          {'locked': 1},
          where: 'id=?',
          whereArgs: [id],
        );
        final before =
            (await repo.occurrences()).map((o) => o.workout.toJson()).toList();
        await expectLater(repo.acceptAdaptation(proposal), throwsStateError);
        expect(
          (await repo.occurrences()).map((o) => o.workout.toJson()),
          before,
        );
      },
    );
    test(
      'changing an unprotected target while preview is open rolls back atomically',
      () async {
        await provider.load();
        final proposal = provider.recommendation!;
        final id = proposal.changes.keys.last;
        final row = (await repo.occurrences()).singleWhere((o) => o.id == id);
        await db.update(
          'cardio_occurrences',
          {
            'workout_json': jsonEncode({
              ...row.workout.toJson(),
              'name': 'New name',
            }),
          },
          where: 'id=?',
          whereArgs: [id],
        );
        final before =
            (await repo.occurrences()).map((o) => o.workout.toJson()).toList();
        await expectLater(repo.acceptAdaptation(proposal), throwsStateError);
        expect(
          (await repo.occurrences()).map((o) => o.workout.toJson()),
          before,
        );
      },
    );
  });
}
