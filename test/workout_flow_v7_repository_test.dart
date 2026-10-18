import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/models/training_profile.dart';
import 'package:trainy/models/workout_planning.dart';
import 'package:trainy/providers/training_profile_provider.dart';
import 'package:trainy/providers/workout_provider.dart';
import 'package:trainy/repositories/training_profile_repository.dart';
import 'package:trainy/repositories/workout_planning_repository.dart';
import 'package:trainy/services/database_schema_v2.dart';
import 'package:trainy/services/database_service.dart';

void main() {
  late Database db;
  late TrainingProfileRepository profiles;
  late WorkoutPlanningRepository planning;
  final now = DateTime.utc(2026, 10, 19);
  TrainingProfileRecord profile(
    String id, {
    String? name,
    Set<String> equipment = const {'bodyweight'},
  }) => TrainingProfileRecord(
    id: id,
    name: name ?? id,
    equipmentCodes: equipment,
    createdAtUtc: now,
    updatedAtUtc: now,
  );
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseSchemaV2.schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => DatabaseSchemaV2.create(db),
      ),
    );
    final service = DatabaseService(database: db);
    profiles = TrainingProfileRepository(database: service);
    planning = WorkoutPlanningRepository(database: service);
    for (var i = 1; i <= 3; i++) {
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
  tearDown(() => db.close());

  WorkoutEditorDraft draft({String? profileId = 'home', String? creationId}) =>
      WorkoutEditorDraft(
        name: 'ÄÖÜäöüß',
        primaryGoal: WorkoutPrimaryGoal.strength,
        setupName: 'Home Gym',
        profileId: profileId,
        exerciseIds: [3, 1, 2],
        creationId: creationId,
      );

  test(
    'profile update keeps setup, group, default and historical session foreign keys',
    () async {
      await profiles.save(profile('home'));
      await profiles.select('home');
      final workout = await planning.createWorkout(draft());
      final setup =
          (await planning.setupsForWorkout(workout.canonicalId)).single;
      await db.insert('activity_sessions', {
        'id': 'past',
        'profile_id': 'home',
        'workout_id': workout.canonicalId,
        'workout_variant_id': setup.id,
        'activity_type': 'strength',
        'status': 'completed',
        'name_snapshot': 'Historic',
        'started_at_utc': 1,
        'ended_at_utc': 2,
        'timezone_offset_minutes': 0,
        'created_at_utc': 1,
      });
      final history = await db.query('activity_sessions');
      final variants = await db.query('workout_group_variants_v2');
      await profiles.save(
        profile('home', name: 'Zuhause Ö', equipment: {'dumbbell'}),
      );
      expect(await profiles.selectedProfileId(), 'home');
      expect(
        (await planning.setupsForWorkout(
          workout.canonicalId,
        )).single.profile?.name,
        'Zuhause Ö',
      );
      expect(await db.query('workout_group_variants_v2'), variants);
      expect(await db.query('activity_sessions'), history);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test(
    'new workouts require an active profile; stable retry ID never duplicates',
    () async {
      await expectLater(
        planning.createWorkout(draft(profileId: null)),
        throwsArgumentError,
      );
      await expectLater(
        planning.createWorkout(draft(profileId: 'missing')),
        throwsStateError,
      );
      await profiles.save(profile('home'));
      final provider = WorkoutProvider(repository: planning);
      addTearDown(provider.dispose);
      for (var attempt = 0; attempt < 2; attempt++) {
        await provider.createWorkout(
          name: 'Test',
          profileId: 'home',
          exerciseIds: [3, 1, 2],
          creationId: 'stable-draft',
        );
      }
      expect(provider.workouts, hasLength(1));
      expect(await db.query('workout_templates'), hasLength(1));
      final setup = (await planning.setupsForWorkout('stable-draft')).single;
      expect((await planning.launchPlanForSetup(setup.id)).exerciseIds, [
        3,
        1,
        2,
      ]);
      await profiles.archive('home');
      await expectLater(planning.createWorkout(draft()), throwsStateError);
      // Archived profiles and old workouts are still readable and runnable.
      expect((await planning.launchPlanForSetup(setup.id)).exerciseIds, [
        3,
        1,
        2,
      ]);
    },
  );

  test(
    'copy, empty and legacy profile binding preserve independent content',
    () async {
      for (final id in ['home', 'gym', 'travel', 'legacy']) {
        await profiles.save(profile(id));
      }
      final workout = await planning.createWorkout(draft());
      final home =
          (await planning.setupsForWorkout(workout.canonicalId)).single;
      final gym = await planning.createSetup(
        workoutId: workout.canonicalId,
        name: 'Gym',
        profileId: 'gym',
        copyFromSetupId: home.id,
        creationId: 'gym-setup',
      );
      final retry = await planning.createSetup(
        workoutId: workout.canonicalId,
        name: 'Gym',
        profileId: 'gym',
        creationId: 'gym-setup',
      );
      expect(retry.id, gym.id);
      final empty = await planning.createSetup(
        workoutId: workout.canonicalId,
        name: 'Travel',
        profileId: 'travel',
        contents: SetupContents.empty,
      );
      expect((await planning.launchPlanForSetup(gym.id)).exerciseIds, [
        3,
        1,
        2,
      ]);
      expect(
        (await planning.launchPlanForSetup(empty.id)).exerciseIds,
        isEmpty,
      );
      await expectLater(
        planning.createSetup(
          workoutId: workout.canonicalId,
          name: 'Duplicate',
          profileId: 'gym',
        ),
        throwsStateError,
      );
      final unlinked = await planning.createSetup(
        workoutId: workout.canonicalId,
        name: 'Legacy',
        copyFromSetupId: home.id,
      );
      await planning.bindProfileToSetup(
        setupId: unlinked.id,
        profileId: 'legacy',
      );
      expect((await planning.launchPlanForSetup(unlinked.id)).exerciseIds, [
        3,
        1,
        2,
      ]);
      await expectLater(
        planning.bindProfileToSetup(setupId: home.id, profileId: 'gym'),
        throwsStateError,
      );
      expect(
        (await planning.setupsForWorkout(
          workout.canonicalId,
        )).firstWhere((s) => s.id == home.id).profile?.id,
        'home',
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test(
    'onboarding is atomic, repeatable and never overwrites existing equipment',
    () async {
      expect(await profiles.setupState(), ProfileSetupState.required);
      final home = profile('home', name: 'Home Gym');
      final gym = profile(
        'gym',
        name: 'Gym',
        equipment: TrainingProfileRepository.gymEquipment,
      );
      expect(gym.equipmentCodes, isNot(contains('pool')));
      expect(gym.equipmentCodes, isNot(contains('bicycle')));
      expect(gym.equipmentCodes, isNot(contains('other')));
      await expectLater(
        profiles.completeSetup(
          profiles: [home, gym],
          preferredProfileId: 'absent',
        ),
        throwsA(isA<TrainingProfileRepositoryException>()),
      );
      expect(await profiles.profiles(), isEmpty);
      expect(await profiles.setupState(), ProfileSetupState.required);
      await profiles.completeSetup(
        profiles: [home, gym],
        preferredProfileId: home.id,
      );
      await profiles.save(home.copyWith(equipmentCodes: {'bands'}));
      await profiles.completeSetup(
        profiles: [home, gym],
        preferredProfileId: home.id,
      );
      expect(await profiles.profiles(), hasLength(2));
      expect(
        (await profiles.profiles())
            .firstWhere((p) => p.id == home.id)
            .equipmentCodes,
        {'bands'},
      );
      expect(await profiles.setupState(), ProfileSetupState.completed);
      expect(await profiles.selectedProfileId(), home.id);
    },
  );

  test(
    'schema 5 upgrade offers optional onboarding without touching data',
    () async {
      await profiles.save(profile('home'));
      final workout = await planning.createWorkout(draft());
      final before = await db.query('workout_templates');
      await db.execute(
        'ALTER TABLE user_settings DROP COLUMN profile_setup_state',
      );
      await DatabaseSchemaV2.upgrade(db, 5, 6);
      expect(await profiles.setupState(), ProfileSetupState.offer);
      expect(await db.query('workout_templates'), before);
      expect(
        (await planning.setupsForWorkout(
          workout.canonicalId,
        )).single.profile?.id,
        'home',
      );
      expect(await DatabaseSchemaV2.readEpoch(db), 2);
      await profiles.dismissSetupOffer();
      expect(await profiles.setupState(), ProfileSetupState.dismissed);
    },
  );

  test(
    'shared provider publishes additions, edits, preference and archive',
    () async {
      final shared = TrainingProfileProvider(store: profiles);
      addTearDown(shared.dispose);
      var changes = 0;
      shared.addListener(() => changes++);
      await shared.reload();
      await shared.save(profile('home'));
      await shared.select('home');
      expect(shared.activeProfiles.single.name, 'home');
      expect(shared.preferredProfileId, 'home');
      await shared.save(profile('home', name: 'New name'));
      expect(shared.activeProfiles.single.name, 'New name');
      await shared.archive('home');
      expect(shared.activeProfiles, isEmpty);
      expect(shared.preferredProfileId, isNull);
      expect(changes, greaterThan(4));
    },
  );
}
