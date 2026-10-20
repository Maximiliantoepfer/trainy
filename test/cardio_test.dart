import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/repositories/cardio_repository.dart';
import 'package:trainy/repositories/activity_repository.dart';
import 'package:trainy/services/cardio_training.dart';
import 'package:trainy/services/cardio_health_service.dart';
import 'package:trainy/services/database_schema_v2.dart';
import 'package:trainy/services/database_service.dart';
import 'package:trainy/services/local_backup_service.dart';
import 'package:trainy/services/cardio_schema.dart';

import 'support/confirmed_profiles.dart';

void main() {
  final now = DateTime(2026, 10, 19);
  final profile = AthleteRunningProfile(
    setupVersion: 1,
    confirmedAnswers: confirmedAnswers,
    referenceKind: 'maximal',
    level: RunningLevel.beginner,
    referenceSeconds: 1500,
    referenceDate: now,
    isMaximal: true,
    weeklyMeters: 15000,
    longestMeters: 6000,
    continuousMinutes: 40,
    experienceMonths: 6,
    restingHeartRate: 60,
    maximumHeartRate: 190,
  );
  String t(String key) => key;
  test('canonical meters, seconds and Karvonen HR reserve round trip', () {
    expect(CardioUnits.distance(1609.344, DistanceSystem.imperial), '1 mi');
    expect(CardioUnits.pace(1000 / 300, DistanceSystem.metric), '5:00 /km');
    expect(
      CardioUnits.pace(1609.344 / 480, DistanceSystem.imperial),
      '8:00 /mi',
    );
    expect(profile.pulse(.6), 138);
    expect(profile.pulse(.7), 151);
    expect(profile.zones[1], (138, 151));
    final decoded = AthleteRunningProfile.fromJson(
      jsonDecode(jsonEncode(profile.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.toJson(), profile.toJson());
    expect(decoded.fiveKmSpeed(now), closeTo(3.333333, .00001));
  });
  test('a normal or stale run is not a maximal benchmark', () {
    expect(
      AthleteRunningProfile.fromJson({
        ...profile.toJson(),
        'isMaximal': false,
      }).fiveKmSpeed(now),
      isNull,
    );
    expect(profile.fiveKmSpeed(now.add(const Duration(days: 91))), isNull);
    expect(profile.fiveKmSpeed(now.subtract(const Duration(days: 1))), isNull);
    expect(const AthleteRunningProfile().zones, isEmpty);
    expect(
      () =>
          const AthleteRunningProfile(
            restingHeartRate: 190,
            maximumHeartRate: 60,
          ).validate(),
      throwsFormatException,
    );
    expect(
      () => const AthleteRunningProfile(weekdays: [1, 1]).validate(),
      throwsFormatException,
    );
  });
  test('repeat slots and recoveries have stable distinct identity', () {
    final w = CardioWorkout(
      name: '4x4',
      steps: [
        CardioStep(
          id: 'interval',
          amount: 240,
          repeat: 4,
          recoverySeconds: 180,
        ),
      ],
    );
    final expanded = w.expandedSteps();
    expect(expanded.length, 7);
    expect(expanded.map((s) => s.id).toSet().length, 7);
    expect(expanded.where((s) => s.movement == 'walk').length, 3);
    expect(expanded.fold<double>(0, (n, s) => n + s.amount), 1500);
    expect(w.expandedSteps().map((s) => s.id), expanded.map((s) => s.id));
    expect(CardioWorkout.fromJson(w.toJson()).toJson(), w.toJson());
  });
  test('all running and non-running templates validate', () {
    for (final code in CardioTraining.templateCodes) {
      final w = CardioTraining.template(code, profile, t, now: now);
      w.validate();
      expect(w.warmup.fold<int>(0, (n, s) => n + s.seconds), 180);
      expect(w.cooldown.fold<int>(0, (n, s) => n + s.seconds), 180);
    }
    for (final sport in CardioSport.values.where(
      (s) => s != CardioSport.running,
    )) {
      final w = CardioTraining.template(
        'intervalSession',
        profile,
        t,
        sport: sport,
        now: now,
      );
      w.validate();
      expect(w.steps.every((s) => s.minSpeed == null), isTrue);
    }
  });
  test('indoor conversion is explicit and requires a prescribed speed', () {
    final w = CardioWorkout(
      name: 'Indoor',
      indoor: true,
      steps: [
        CardioStep(
          goal: StepGoal.distance,
          amount: 1000,
          minSpeed: 2,
          maxSpeed: 3,
        ),
      ],
    );
    expect(w.timeReplacement().steps.single.amount, 400);
    expect(w.steps.single.goal, StepGoal.distance);
    expect(w.timeReplacement().autoPause, isFalse);
    expect(
      () =>
          CardioWorkout(
            name: 'No sensor',
            indoor: true,
            steps: [CardioStep(goal: StepGoal.distance)],
          ).timeReplacement(),
      throwsFormatException,
    );
  });
  test('plan dates, base phase, target warnings and all goal distances', () {
    for (final target in [5000.0, 10000.0, 21097.5, 42195.0]) {
      final plan = RunningPlanGenerator().generate(
        profile,
        RunningPlanRequest(
          targetMeters: target,
          startDate: now,
          targetSeconds: 1200,
          targetDate: now.add(const Duration(days: 14)),
        ),
        t,
      );
      expect(plan.warnings, contains('infeasible'));
      expect(plan.warnings, contains('targetTimeInfo'));
      expect(
        plan.occurrences.every(
          (o) =>
              profile.weekdays.contains(o.date.weekday) &&
              !o.date.isBefore(now),
        ),
        isTrue,
      );
      expect(
        plan.occurrences.map((o) => o.id).toSet().length,
        plan.occurrences.length,
      );
      for (final o in plan.occurrences) {
        o.workout.validate();
      }
    }
    final novice = RunningPlanGenerator().generate(
      const AthleteRunningProfile(
        setupVersion: 1,
        confirmedAnswers: confirmedAnswers,
        referenceKind: 'runWalk',
        referenceSeconds: 3600,
        level: RunningLevel.starting,
        canRunFiveKm: false,
      ),
      RunningPlanRequest(targetMeters: 5000, startDate: now),
      t,
    );
    expect(novice.baseWeeks, 9);
    expect(
      novice.occurrences.first.workout.steps.any((s) => s.movement == 'walk'),
      isTrue,
    );
    expect(
      novice.occurrences
          .take(27)
          .expand((o) => o.workout.steps)
          .every((s) => s.intensity == CardioIntensity.easy),
      isTrue,
    );
  });
  test('health matching requires the same sport, start and duration', () {
    final local = <String, Object?>{
      'activity_type': 'running',
      'started_at_utc': 1000000,
      'ended_at_utc': 2800000,
    };
    final health = <String, dynamic>{
      'sport': 'running',
      'start': 1001000,
      'end': 2801000,
    };
    expect(CardioHealthService.matches(local, health), isTrue);
    expect(
      CardioHealthService.matches(local, {...health, 'sport': 'cycling'}),
      isFalse,
    );
    expect(
      CardioHealthService.matches(local, {...health, 'start': 4000000}),
      isFalse,
    );
  });
  test('schema 6 backup compatibility stays explicit', () {
    expect(LocalBackupService.isCompatibleSchema(6, '2026-10-19.6'), isTrue);
    expect(LocalBackupService.isCompatibleSchema(7, 'unknown'), isFalse);
  });

  test(
    'schema 6 upgrades in place without deleting an existing workout',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp(
        'trainy-cardio-migration-test-',
      );
      final file = '${directory.path}/migration.db';
      Database? db;
      try {
        db = await databaseFactoryFfi.openDatabase(
          file,
          options: OpenDatabaseOptions(
            version: 6,
            onCreate: (db, _) async {
              await DatabaseSchemaV2.create(db);
              for (final table in CardioSchema.tables) {
                await db.execute('DROP TABLE $table');
              }
              await db.update(
                'app_meta',
                {'value': '6'},
                where: 'key = ?',
                whereArgs: ['schema_version'],
              );
              await db.insert('workout_templates', {
                'id': 'existing-strength',
                'name': 'Preserved strength',
                'created_at_utc': 1,
                'updated_at_utc': 1,
              });
            },
          ),
        );
        await db.close();
        db = await databaseFactoryFfi.openDatabase(
          file,
          options: OpenDatabaseOptions(
            version: 7,
            onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
            onUpgrade: DatabaseSchemaV2.upgrade,
          ),
        );
        expect(
          (await db.query('workout_templates')).single['name'],
          'Preserved strength',
        );
        for (final table in CardioSchema.tables) {
          expect(await db.query(table), isEmpty);
        }
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        expect(
          (await db.query(
            'app_meta',
            where: 'key = ?',
            whereArgs: ['schema_version'],
          )).single['value'],
          '${DatabaseSchemaV2.schemaVersion}',
        );
      } finally {
        await db?.close();
        await directory.delete(recursive: true);
      }
    },
  );

  group('local repository', () {
    late Database database;
    late CardioRepository repo;
    setUpAll(sqfliteFfiInit);
    setUp(() async {
      database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseSchemaV2.schemaVersion,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) => DatabaseSchemaV2.create(db),
        ),
      );
      repo = CardioRepository(database: DatabaseService(database: database));
    });
    tearDown(() => database.close());
    test(
      'templates and profiles persist without legacy exercise IDs',
      () async {
        await repo.saveProfile(profile);
        final w = CardioTraining.template('easy5k', profile, t, now: now);
        await repo.saveWorkout(w);
        await repo.saveWorkout(w);
        expect((await repo.workouts()).single.toJson(), w.toJson());
        expect((await repo.profile()).toJson(), profile.toJson());
        expect(await database.query('workouts'), isEmpty);
        expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      },
    );
    test(
      'one active session, idempotent samples and completed metrics',
      () async {
        final w = CardioTraining.template('fourByFour', profile, t, now: now);
        final id = await repo.begin(w);
        await expectLater(repo.begin(w), throwsStateError);
        expect(
          await ActivityRepository(
            databaseService: DatabaseService(database: database),
          ).latestActiveWorkout(),
          isNull,
        );
        final sample = {'sequence': 1, 'latitude': 52.0, 'longitude': 13.0};
        await repo.saveSamples(id, [sample, sample]);
        final runtime = <String, dynamic>{
          'sessionId': id,
          'status': 'completed',
          'activeSeconds': 60,
          'distanceMeters': 200,
          'endedAt': DateTime.now().millisecondsSinceEpoch,
          'results': [
            {
              'id': 'one',
              'index': 0,
              'name': 'First',
              'seconds': 30,
              'meters': 100,
            },
            {
              'id': 'two',
              'index': 1,
              'name': 'Second',
              'seconds': 30,
              'meters': 100,
            },
          ],
        };
        await repo.saveRuntime(runtime);
        await repo.saveRuntime(runtime);
        expect((await repo.history()).length, 1);
        expect((await database.query('cardio_sensor_samples')).length, 1);
        expect((await database.query('activity_items')).length, 2);
        expect((await database.query('activity_metric_values')).length, 6);
        expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      },
    );
    test('indoor completion does not invent measured distance', () async {
      final id = await repo.begin(
        CardioWorkout(
          name: 'Bike',
          indoor: true,
          sport: CardioSport.cycling,
          steps: [CardioStep()],
        ),
      );
      await repo.saveRuntime({
        'sessionId': id,
        'status': 'completed',
        'indoor': true,
        'activeSeconds': 300,
        'distanceMeters': 5000,
      });
      expect(
        (await database.query('activity_metric_values')).single['metric_code'],
        'duration',
      );
    });
    test(
      'move future weekdays, protect edits, complete planned occurrence once',
      () async {
        final plan = RunningPlanGenerator().generate(
          profile,
          RunningPlanRequest(targetMeters: 5000, startDate: now),
          t,
        );
        await repo.saveProfile(profile);
        await repo.savePlan(plan, 'Plan');
        await repo.savePlan(plan, 'Plan');
        final first = (await repo.occurrences()).first;
        await repo.move(
          first,
          first.date.add(const Duration(days: 1)),
          future: true,
        );
        final moved =
            (await repo.occurrences()).where((o) => o.id == first.id).single;
        expect(moved.date.weekday, 2);
        expect(moved.locked, isTrue);
        final replacement = CardioWorkout(
          name: 'Must not replace',
          steps: [CardioStep()],
        );
        await repo.applyAdjustment({first.id: replacement});
        expect(
          (await repo.occurrences())
              .where((o) => o.id == first.id)
              .single
              .workout
              .name,
          first.workout.name,
        );
        final id = await repo.begin(first.workout, occurrenceId: first.id);
        await repo.saveRuntime({
          'sessionId': id,
          'status': 'completed',
          'activeSeconds': 60,
        });
        expect(
          (await repo.occurrences())
              .where((o) => o.id == first.id)
              .single
              .status,
          'completed',
        );
      },
    );
  });
}
