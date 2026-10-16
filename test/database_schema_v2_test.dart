import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:trainy/repositories/activity_repository.dart';
import 'package:trainy/repositories/exercise_repository.dart';
import 'package:trainy/repositories/training_plan_repository.dart';
import 'package:trainy/repositories/workout_repository.dart';
import 'package:trainy/providers/active_workout_provider.dart';
import 'package:trainy/models/workout.dart';
import 'package:trainy/models/exercise.dart';
import 'package:trainy/services/database_schema_v2.dart';
import 'package:trainy/services/database_service.dart';

void main() {
  late Database database;

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
  });

  tearDown(() => database.close());

  test('enables foreign keys and creates an internally valid schema', () async {
    final foreignKeys = await database.rawQuery('PRAGMA foreign_keys');
    expect(foreignKeys.single.values.single, 1);
    expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    final result = await database.rawQuery('PRAGMA integrity_check');
    expect(result.single.values.single, 'ok');
  });

  test('repeated schema-2 starts preserve existing local data', () async {
    final directory = await Directory.systemTemp.createTemp(
      'trainy-repeated-start-',
    );
    final databasePath = '${directory.path}${Platform.pathSeparator}trainy.db';

    Future<Database> open() => databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: DatabaseSchemaV2.schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => DatabaseSchemaV2.create(db),
        onUpgrade: DatabaseSchemaV2.upgrade,
      ),
    );

    try {
      var persistentDatabase = await open();
      await persistentDatabase.insert('app_meta', {
        'key': 'test_sentinel',
        'value': 'keep-me',
      });
      await persistentDatabase.close();

      for (var start = 0; start < 3; start++) {
        persistentDatabase = await open();
        final sentinel = await persistentDatabase.query(
          'app_meta',
          where: 'key = ?',
          whereArgs: const ['test_sentinel'],
        );
        expect(sentinel.single['value'], 'keep-me');
        await persistentDatabase.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('every foreign-key column starts an index', () async {
    final tables = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
    );
    final missing = <String>[];
    for (final tableRow in tables) {
      final table = tableRow['name']! as String;
      final foreignKeys = await database.rawQuery(
        'PRAGMA foreign_key_list("$table")',
      );
      final indexRows = await database.rawQuery('PRAGMA index_list("$table")');
      final indexedFirstColumns = <String>{};
      for (final indexRow in indexRows) {
        final indexName = indexRow['name']! as String;
        final columns = await database.rawQuery(
          'PRAGMA index_info("$indexName")',
        );
        if (columns.isNotEmpty) {
          indexedFirstColumns.add(columns.first['name']! as String);
        }
      }
      for (final foreignKey in foreignKeys) {
        final column = foreignKey['from']! as String;
        if (!indexedFirstColumns.contains(column)) {
          missing.add('$table.$column');
        }
      }
    }
    expect(missing, isEmpty);
  });

  test('requires domain-first tags and limits exercises to two tags', () async {
    final repository = ExerciseRepository(
      databaseService: DatabaseService(database: database),
    );
    final id = await repository.createCustomExercise(
      name: 'Tempolauf',
      tags: const ['cardio', 'endurance'],
      metrics: const [
        ExerciseMetricConfiguration(
          metricCode: 'duration',
          unitCode: 'second',
          inputLevel: 'exercise',
        ),
      ],
    );
    final tags = await database.query(
      'exercise_tags',
      where: 'exercise_id = ?',
      whereArgs: [id],
      orderBy: 'position',
    );
    expect(tags.map((row) => row['tag_code']), ['cardio', 'endurance']);

    expect(
      () => repository.createCustomExercise(
        name: 'Invalid',
        tags: const ['endurance'],
        metrics: const [],
      ),
      throwsArgumentError,
    );
    expect(
      () => repository.createCustomExercise(
        name: 'Too many',
        tags: const ['strength', 'cardio', 'endurance'],
        metrics: const [],
      ),
      throwsArgumentError,
    );
  });

  test('applies set-null, restrict and cascade ownership rules', () async {
    const profileId = '00000000-0000-4000-8000-000000000001';
    const workoutId = '00000000-0000-4000-8000-000000000002';
    const variantId = '00000000-0000-4000-8000-000000000003';
    const groupId = '00000000-0000-4000-8000-000000000004';
    const groupVariantId = '00000000-0000-4000-8000-000000000005';
    const slotId = '00000000-0000-4000-8000-000000000006';
    const planId = '00000000-0000-4000-8000-000000000007';
    const planWorkoutId = '00000000-0000-4000-8000-000000000008';
    const now = 1;
    final exercises = ExerciseRepository(
      databaseService: DatabaseService(database: database),
    );
    final exerciseId = await exercises.createCustomExercise(
      name: 'Protected exercise',
      tags: const ['strength'],
      metrics: const [],
    );
    await database.insert('training_profiles_v2', {
      'id': profileId,
      'name': 'Studio',
      'created_at_utc': now,
      'updated_at_utc': now,
    });
    await database.insert('workout_templates', {
      'id': workoutId,
      'name': 'Workout',
      'created_at_utc': now,
      'updated_at_utc': now,
    });
    await database.insert('workout_variants_v2', {
      'id': variantId,
      'workout_id': workoutId,
      'profile_id': profileId,
      'name': 'Studio',
    });
    await database.insert('workout_groups_v2', {
      'id': groupId,
      'workout_id': workoutId,
      'name': 'Chest',
    });
    await database.insert('workout_group_variants_v2', {
      'id': groupVariantId,
      'workout_group_id': groupId,
      'profile_id': profileId,
      'name': 'Machines',
    });
    await database.insert('workout_slots_v2', {
      'id': slotId,
      'group_variant_id': groupVariantId,
      'exercise_id': exerciseId,
    });
    await database.delete(
      'training_profiles_v2',
      where: 'id = ?',
      whereArgs: [profileId],
    );
    expect(
      (await database.query('workout_variants_v2')).single['profile_id'],
      isNull,
    );
    expect(
      (await database.query('workout_group_variants_v2')).single['profile_id'],
      isNull,
    );
    await expectLater(
      database.delete(
        'exercise_items',
        where: 'id = ?',
        whereArgs: [exerciseId],
      ),
      throwsA(isA<DatabaseException>()),
    );

    await database.insert('training_plans', {
      'id': planId,
      'name': 'Plan',
      'created_at_utc': now,
      'updated_at_utc': now,
    });
    await database.insert('training_plan_workouts', {
      'id': planWorkoutId,
      'training_plan_id': planId,
      'workout_id': workoutId,
      'week_number': 1,
    });
    await database.delete(
      'training_plans',
      where: 'id = ?',
      whereArgs: [planId],
    );
    expect(await database.query('training_plan_workouts'), isEmpty);
    expect(await database.query('workout_templates'), hasLength(1));

    await database.delete(
      'workout_templates',
      where: 'id = ?',
      whereArgs: [workoutId],
    );
    expect(await database.query('workout_variants_v2'), isEmpty);
    expect(await database.query('workout_groups_v2'), isEmpty);
    expect(await database.query('workout_slots_v2'), isEmpty);
    expect(await database.query('exercise_items'), hasLength(1));
  });

  test('training plans never own or delete reusable workouts', () async {
    final service = DatabaseService(database: database);
    final workouts = WorkoutRepository(databaseService: service);
    final plans = TrainingPlanRepository(databaseService: service);
    final workoutId = await workouts.createWorkout(
      name: '5 km run',
      tags: const ['cardio', 'endurance'],
    );
    final planId = await plans.createPlan(name: 'First 10 km');
    await plans.addWorkout(
      planId: planId,
      workoutId: workoutId,
      weekNumber: 1,
      weekday: 2,
    );
    await plans.deletePlan(planId);

    expect(await database.query('training_plans'), isEmpty);
    expect(await database.query('training_plan_workouts'), isEmpty);
    expect(await database.query('workout_templates'), hasLength(1));
    expect(
      (await database.query('workout_tags')).map((row) => row['tag_code']),
      ['cardio', 'endurance'],
    );
  });

  test(
    'rejects redirect cycles and supports undo without rewriting history',
    () async {
      final repository = ExerciseRepository(
        databaseService: DatabaseService(database: database),
      );
      Future<String> create(String name) => repository.createCustomExercise(
        name: name,
        tags: const ['strength'],
        metrics: const [],
      );
      final first = await create('First');
      final second = await create('Second');
      final redirect = await repository.mergeExercises(first, second);
      expect(await repository.resolveActiveExerciseId(first), second);
      await expectLater(
        repository.mergeExercises(second, first),
        throwsA(isA<DatabaseException>()),
      );
      await repository.undoMerge(redirect);
      expect(await repository.resolveActiveExerciseId(first), first);
    },
  );

  test(
    'records strength efforts and running metrics in one activity model',
    () async {
      final repository = ActivityRepository(
        databaseService: DatabaseService(database: database),
      );
      final strength = await repository.startSession(
        activityType: 'strength',
        nameSnapshot: 'Strength',
        tags: const ['strength'],
      );
      final strengthItem = await repository.addActivityItem(
        sessionId: strength,
        displayNameSnapshot: 'Squat',
      );
      await repository.recordEffort(
        sessionId: strength,
        activityItemId: strengthItem,
        metrics: const [
          ActivityMetricInput(
            metricCode: 'weight',
            canonicalValue: 100,
            enteredValue: 100,
            enteredUnitCode: 'kg',
          ),
          ActivityMetricInput(
            metricCode: 'repetitions',
            canonicalValue: 5,
            enteredValue: 5,
            enteredUnitCode: 'count',
          ),
        ],
      );
      await repository.completeSession(strength);

      final running = await repository.startSession(
        activityType: 'running',
        nameSnapshot: 'Running',
        tags: const ['cardio', 'endurance'],
      );
      final runningItem = await repository.addActivityItem(
        sessionId: running,
        displayNameSnapshot: 'Running',
      );
      await repository.recordItemMetrics(
        sessionId: running,
        activityItemId: runningItem,
        metrics: const [
          ActivityMetricInput(
            metricCode: 'distance',
            canonicalValue: 5000,
            enteredValue: 5,
            enteredUnitCode: 'kilometer',
          ),
          ActivityMetricInput(
            metricCode: 'duration',
            canonicalValue: 1800,
            enteredValue: 1800,
            enteredUnitCode: 'second',
          ),
        ],
      );
      await repository.completeSession(running);

      expect(await database.query('activity_sessions'), hasLength(2));
      expect(await database.query('activity_efforts'), hasLength(1));
      expect(await database.query('activity_metric_values'), hasLength(4));
      expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test(
    'active workout serializes each set before completion and restores it',
    () async {
      final service = DatabaseService(database: database);
      final repository = ActivityRepository(databaseService: service);
      final started = await repository.startWorkoutActivity(
        localWorkoutId: 7,
        nameSnapshot: 'Strength',
        activityType: 'strength',
        tags: const ['strength'],
        items: const [
          ActivityItemSnapshotInput(localExerciseId: 11, displayName: 'Squat'),
        ],
      );
      final provider = ActiveWorkoutProvider(activityRepository: repository);
      provider.start(
        workout: Workout(id: 7, name: 'Strength'),
        exercises: const [
          Exercise(
            id: 11,
            name: 'Squat',
            description: '',
            trackSets: true,
            trackReps: true,
            trackWeight: true,
            trackDuration: false,
            trackDistance: false,
            defaultValues: {},
            lastValues: {},
            units: {},
            icon: null,
          ),
        ],
        activitySessionId: started.sessionId,
        activityItemIds: started.activityItemIds,
      );

      provider.addSet(11, const {'reps': '5', 'weight': '100'});
      await provider.flushPendingWrites();
      expect(await database.query('activity_efforts'), hasLength(1));
      expect(await database.query('activity_metric_values'), hasLength(2));

      provider.updateLastSet(11, const {'reps': '6', 'weight': '102.5'});
      await provider.flushPendingWrites();
      expect(await database.query('activity_efforts'), hasLength(1));
      expect(await database.query('activity_metric_values'), hasLength(2));
      expect((await repository.latestActiveWorkout())!.efforts, isNotEmpty);

      await provider.completePersistedSession();
      provider.clearCompleted();
      expect(
        (await database.query('activity_sessions')).single['status'],
        'completed',
      );
      provider.dispose();
    },
  );
}
