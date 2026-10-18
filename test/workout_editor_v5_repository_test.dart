import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/models/workout_planning.dart';
import 'package:trainy/models/workout_plan.dart';
import 'package:trainy/models/workout.dart';
import 'package:trainy/models/exercise.dart';
import 'package:trainy/providers/active_workout_provider.dart';
import 'package:trainy/repositories/activity_repository.dart';
import 'package:trainy/repositories/workout_planning_repository.dart';
import 'package:trainy/services/database_schema_v2.dart';
import 'package:trainy/services/database_service.dart';
import 'package:trainy/services/local_backup_service.dart';

void main() {
  late Database db;
  late WorkoutPlanningRepository planning;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        version: 5,
        onCreate: (db, _) => DatabaseSchemaV2.create(db),
      ),
    );
    planning = WorkoutPlanningRepository(
      database: DatabaseService(database: db),
    );
    await db.insert('training_profiles_v2', {
      'id': 'home',
      'name': 'Home',
      'created_at_utc': 1,
      'updated_at_utc': 1,
    });
    for (var id = 1; id <= 4; id++) {
      await db.insert('exercises', {
        'id': id,
        'name': 'Exercise $id',
        'description': '',
        'trackedFields': '{}',
        'defaultValues': '{}',
        'lastValues': '{}',
        'units': '{}',
        'origin': 'custom',
      });
    }
  });
  tearDown(() => db.close());

  Future<WorkoutSetup> create() async {
    final workout = await planning.createWorkout(
      const WorkoutEditorDraft(
        name: 'Test',
        primaryGoal: WorkoutPrimaryGoal.strength,
        setupName: 'Home',
        profileId: 'home',
        exerciseIds: [1, 2, 3],
      ),
    );
    return (await planning.setupsForWorkout(workout.canonicalId)).single;
  }

  WorkoutSetupGroup core(WorkoutSetup setup) =>
      setup.groups.firstWhere((g) => g.kind == WorkoutGroupKind.core);

  test(
    'group and slot ordering is shared, isolated, stable and transactional',
    () async {
      final setup = await create();
      final clone = await planning.createSetup(
        workoutId: setup.workoutId,
        name: 'Studio',
        copyFromSetupId: setup.id,
      );
      final slots = core(setup).selectedVariant.slots;
      await planning.createGroupFromSlots(
        setupId: setup.id,
        name: 'Chest',
        slotIds: [slots[2].id, slots[0].id],
      );
      var current = (await planning.setupsForWorkout(
        setup.workoutId,
      )).firstWhere((s) => s.id == setup.id);
      final chest = current.groups.firstWhere(
        (g) => g.kind == WorkoutGroupKind.custom,
      );
      expect(chest.selectedVariant.slots.map((s) => s.localExerciseId), [3, 1]);
      await planning.reorderGroups(setup.workoutId, [
        chest.id,
        core(current).id,
      ]);
      final both = await planning.setupsForWorkout(setup.workoutId);
      expect(
        both.every(
          (s) =>
              s.groups.map((g) => g.kind).join(',') ==
              [
                WorkoutGroupKind.warmup,
                WorkoutGroupKind.custom,
                WorkoutGroupKind.core,
                WorkoutGroupKind.cooldown,
              ].join(','),
        ),
        isTrue,
      );
      expect(
        core(both.firstWhere((s) => s.id == clone.id)).selectedVariant.slots,
        hasLength(3),
      );
      expect((await planning.launchPlanForSetup(setup.id)).exerciseIds, [
        3,
        1,
        2,
      ]);
      final before = await db.query('workout_groups_v2');
      await expectLater(
        planning.reorderGroups(setup.workoutId, [chest.id, chest.id]),
        throwsArgumentError,
      );
      expect(await db.query('workout_groups_v2'), before);
      await expectLater(
        planning.moveSlotToGroup(
          slotId: slots[0].id,
          setupId: clone.id,
          targetGroupId: chest.id,
        ),
        throwsStateError,
      );
      await expectLater(
        planning.removeSlots([slots[0].id], setupId: clone.id),
        throwsStateError,
      );
      await expectLater(
        planning.setSlotsOptional([slots[0].id], true, setupId: clone.id),
        throwsStateError,
      );
      await expectLater(
        planning.setSlotOptional(slots[0].id, true, setupId: clone.id),
        throwsStateError,
      );
      await expectLater(
        planning.removeSlot(slots[0].id, setupId: clone.id),
        throwsStateError,
      );
      await planning.moveSlotToGroup(
        slotId: slots[2].id,
        setupId: setup.id,
        targetGroupId: chest.id,
        targetIndex: 1,
      );
      current = (await planning.setupsForWorkout(
        setup.workoutId,
      )).firstWhere((s) => s.id == setup.id);
      expect(
        current.groups
            .firstWhere((g) => g.id == chest.id)
            .selectedVariant
            .slots
            .map((s) => s.localExerciseId),
        [1, 3],
      );
      await planning.addExercisesToCore(
        setupId: setup.id,
        groupId: current.groups.first.id,
        exerciseIds: [4],
      );
      expect((await planning.launchPlanForSetup(setup.id)).exerciseIds, [
        4,
        1,
        3,
        2,
      ]);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test(
    'schema 4 upgrade preserves content and corrects warmup/core sort tie',
    () async {
      final setup = await create();
      await db.execute(
        'ALTER TABLE activity_sessions DROP COLUMN selection_snapshot',
      );
      await db.execute(
        'ALTER TABLE activity_session_groups DROP COLUMN plan_snapshot',
      );
      await db.update(
        'workout_groups_v2',
        {'sort_order': 0},
        where: 'workout_id = ?',
        whereArgs: [setup.workoutId],
      );
      await db.update('app_meta', {
        'value': '4',
      }, where: "key = 'schema_version'");
      await DatabaseSchemaV2.upgrade(db, 4, 5);
      final updated = (await planning.setupsForWorkout(setup.workoutId)).single;
      expect(updated.groups.first.kind, WorkoutGroupKind.warmup);
      expect(updated.groups.last.kind, WorkoutGroupKind.cooldown);
      expect(core(updated).selectedVariant.slots, hasLength(3));
      await DatabaseSchemaV2.upgrade(db, 4, 5);
      expect((await db.query('exercises')).length, 4);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(LocalBackupService.isCompatibleSchema(4, '2026-10-16.4'), isTrue);
      expect(LocalBackupService.isCompatibleSchema(4, 'unknown'), isFalse);
      expect(LocalBackupService.isCompatibleSchema(3, '2026-10-16.3'), isFalse);
    },
  );

  test(
    'session snapshot restores group order and replacements without changing efforts',
    () async {
      final repository = ActivityRepository(
        databaseService: DatabaseService(database: db),
      );
      const groups = [
        WorkoutSessionPlanGroup(
          workoutGroupId: 21,
          sourceId: 'stable-group',
          name: 'warmup',
          kind: WorkoutGroupKind.warmup,
          selectedGroupVariantId: 22,
          variants: [
            WorkoutSessionPlanGroupVariant(
              id: 22,
              name: 'warmup',
              slots: [
                WorkoutSessionPlanSlot(
                  id: 23,
                  exerciseId: 1,
                  isOptional: false,
                ),
                WorkoutSessionPlanSlot(id: 24, exerciseId: 3, isOptional: true),
              ],
            ),
          ],
        ),
      ];
      final session = await repository.startWorkoutActivity(
        localWorkoutId: 5,
        nameSnapshot: 'Original title',
        activityType: 'strength',
        tags: ['strength'],
        items: const [
          ActivityItemSnapshotInput(localExerciseId: 1, displayName: 'One'),
        ],
        groups: groups,
        selectionSnapshot: {
          'exercises': [1],
          'groups': {'21': 22},
          'slots': {'23': 1},
          'optional': [],
        },
      );
      await repository.recordEffort(
        sessionId: session.sessionId,
        activityItemId: session.activityItemIds[1]!,
        metrics: const [],
      );
      final before = await db.query('activity_efforts');
      await repository.addActivityItem(
        sessionId: session.sessionId,
        sourceLocalId: '2',
        displayNameSnapshot: 'Two',
      );
      await repository.savePlanSnapshot(
        sessionId: session.sessionId,
        groups: groups,
        selection: {
          'exercises': [1, 2],
          'groups': {'21': 22},
          'slots': {'23': 1, '24': 2},
          'optional': [24],
        },
      );
      final restored = (await repository.latestActiveWorkout())!;
      expect(restored.groups.single.kind, WorkoutGroupKind.warmup);
      expect(restored.groups.single.sourceId, 'stable-group');
      expect(restored.selection['slots'], {'23': 1, '24': 2});
      expect(restored.selection['optional'], [24]);
      expect(await db.query('activity_efforts'), before);
      expect(await db.query('activity_session_groups'), hasLength(1));
      expect(
        restored.items.every((row) => row['session_group_id'] != null),
        isTrue,
      );
      final active = ActiveWorkoutProvider(
        activityRepository: repository,
        loadWorkouts: () async => [Workout(id: 5, name: 'Renamed after start')],
        loadExercises:
            () async => [
              for (final id in [1, 2, 3])
                Exercise(
                  id: id,
                  name: 'Exercise $id',
                  description: '',
                  trackSets: true,
                  trackReps: true,
                  trackWeight: false,
                  trackDuration: false,
                  trackDistance: false,
                  defaultValues: const {},
                  lastValues: const {},
                  units: const {},
                  icon: null,
                ),
            ],
      );
      await active.restorePersistedWorkout();
      expect(active.workout!.name, 'Original title');
      expect(active.exercises.map((e) => e.id), [1, 2]);
      expect(active.sessionPlanGroups.single.kind, WorkoutGroupKind.warmup);
      expect(active.slotExerciseSelections, {23: 1, 24: 2});
      expect(active.enabledOptionalSlotIds, {24});
      expect(active.setsByExercise[1], hasLength(1));
      active.dispose();
      await repository.completeSession(session.sessionId);
      await expectLater(
        repository.savePlanSnapshot(
          sessionId: session.sessionId,
          groups: groups,
          selection: {},
        ),
        throwsStateError,
      );
    },
  );
}
