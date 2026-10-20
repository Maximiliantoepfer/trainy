import 'package:trainy/models/catalog_exercise.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trainy/models/strength_equipment.dart';
import 'package:trainy/models/strength_plan.dart';
import 'package:trainy/models/training_profile.dart';
import 'package:trainy/models/training_program.dart';
import 'package:trainy/models/workout_planning.dart';
import 'package:trainy/repositories/training_program_repository.dart';
import 'package:trainy/repositories/workout_planning_repository.dart';
import 'package:trainy/services/catalog_repository.dart';
import 'package:trainy/services/database_schema_v2.dart';
import 'package:trainy/services/database_service.dart';
import 'package:trainy/services/profile_readiness.dart';
import 'package:trainy/services/strength_planning.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final date = DateTime(2030, 1, 7);
  TrainingProfileRecord place(String id, Set<String> equipment) =>
      TrainingProfileRecord(
        id: id,
        name: id,
        equipmentCodes: equipment,
        createdAtUtc: date,
        updatedAtUtc: date,
      );
  final home = place('home', {
    'bodyweight',
    'dumbbell',
    'bench',
    'pull_up_bar',
    'bands',
    'dip_bars',
  });
  final gym = place('gym', StrengthEquipment.gym);
  UserTrainingProfile user({
    String level = 'beginner',
    String preference = 'guided',
  }) => UserTrainingProfile(
    strengthProfileId: 'home',
    strengthProfileIds: ['home', 'gym'],
    strengthSetupVersion: 2,
    strengthLevel: level,
    strengthGoal: 'buildMuscle',
    strengthPreference: preference,
    strengthAnswers: {'level', 'goal', 'places', 'equipment', 'preference'},
  );
  List<ProgramSlot> slots(int count, {String pair = 'mixedSplit'}) {
    final labels = StrengthPlanning.labels(count, pair: pair),
        focuses =
            StrengthPlanning.labels(
              count,
              pair: pair,
            ).map(StrengthPlanning.focus).toList();
    final days = StrengthPlanning.suggestDays([1, 2, 3, 4, 5, 6, 7], focuses);
    return [
      for (var i = 0; i < days.length; i++)
        ProgramSlot(
          id: 's$i',
          weekday: days[i],
          label: labels[i],
          focus: focuses[i].toList(),
        ),
    ];
  }

  StrengthPlanProposal generate({
    int count = 3,
    int minutes = 60,
    UserTrainingProfile? profile,
    List<TrainingProfileRecord>? places,
  }) => StrengthPlanning.generate(
    planId: 'p',
    user: profile ?? user(),
    places: places ?? [home, gym],
    slots: slots(count),
    goal: 'buildMuscle',
    minutes: minutes,
    label: (s) => s,
  );
  setUpAll(() async {
    sqfliteFfiInit();
    expect(await CatalogRepository.instance.load(), isTrue);
  });

  test(
    'lower back prefers a hyperextension bench and falls back only without it',
    () {
      for (final equipped in [false, true]) {
        final proposal = StrengthPlanning.generate(
          planId: 'back',
          user: user(),
          places: [
            place('home', {'bodyweight', if (equipped) 'back_extension'}),
            gym,
          ],
          slots: [
            ProgramSlot(weekday: 1, label: 'Back', focus: ['lowerBack']),
          ],
          goal: 'buildMuscle',
          minutes: 30,
          label: (s) => s,
        );
        final ids = proposal.workouts.single.variants.first.exercises.map(
          (e) => e.catalogId,
        );
        expect(
          ids,
          contains(
            equipped ? 'free:Hyperextensions_Back_Extensions' : 'free:Superman',
          ),
        );
        if (equipped) expect(ids, isNot(contains('free:Superman')));
      }
    },
  );

  test(
    'all recommended splits respect recovery including Sunday to Monday',
    () {
      for (final pair in ['mixedSplit', 'upperLower']) {
        for (var n = 1; n <= 6; n++) {
          final values = slots(n, pair: pair);
          expect(values.length, n);
          expect(
            StrengthPlanning.recoveryConflicts(
              values.map((s) => s.weekday).toList(),
              values.map((s) => s.effectiveFocus).toList(),
            ),
            0,
            reason: '$n $pair',
          );
        }
      }
      expect(
        StrengthPlanning.recoveryConflicts(
          [1, 7],
          [
            {'chest'},
            {'push'},
          ],
        ),
        1,
      );
      expect(
        StrengthPlanning.recoveryConflicts(
          [1, 3],
          [
            {'chest'},
            {'push'},
          ],
        ),
        0,
      );
      expect(
        StrengthPlanning.suggestDays(
          [1, 2],
          [
            {'push'},
            {'push'},
            {'legs'},
          ],
        ),
        isEmpty,
      );
    },
  );
  test('curated exercises resolve and pullups require a bar', () {
    for (final c in StrengthPlanning.candidates) {
      expect(
        CatalogRepository.instance.localized(c.id, 'de'),
        isNotNull,
        reason: c.id,
      );
    }
    final result = CatalogRepository.instance.search(
      'en',
      CatalogQuery(availableEquipment: {'bodyweight'}),
    );
    expect(result.any((e) => e.definition.id == 'free:Pullups'), isFalse);
  });
  test(
    'deterministic complete proposals, beginner sets and different location variants',
    () {
      final a = generate();
      expect(a.toJson(), generate().toJson());
      expect(a.ready, isTrue);
      expect(a.workouts.length, 3);
      for (final w in a.workouts) {
        expect(w.variants.length, 2);
        expect(
          w.variants.first.exercises.map((e) => e.catalogId).toList(),
          isNot(w.variants.last.exercises.map((e) => e.catalogId).toList()),
        );
        for (final v in w.variants) {
          expect(v.estimatedSeconds, lessThanOrEqualTo(3600));
          expect(v.exercises.every((e) => e.prescription.sets <= 2), isTrue);
          expect(
            v.exercises.every(
              (e) => StrengthPlanning.candidates.any(
                (c) =>
                    c.id == e.catalogId &&
                    (v.profileId == 'home' ? home : gym).equipmentCodes
                        .containsAll(c.equipment),
              ),
            ),
            isTrue,
          );
        }
      }
      expect(
        StrengthPlanProposal.fromJson(
          jsonDecode(jsonEncode(a.toJson())),
        ).toJson(),
        a.toJson(),
      );
    },
  );
  test(
    'time and missing equipment remain explicit, never silently complete',
    () {
      final short = generate(minutes: 10);
      expect(short.ready, isFalse);
      expect(
        short.workouts
            .expand((w) => w.variants)
            .every((v) => v.estimatedSeconds <= 600),
        isTrue,
      );
      final bare = generate(
        places: [
          place('home', {'bodyweight'}),
          gym,
        ],
      );
      expect(bare.workouts.first.variants.first.missing, isNotEmpty);
      expect(bare.ready, isFalse);
      final old = UserTrainingProfile.fromJson({
        ...user().toJson(),
        'strengthSetupVersion': 1,
      });
      expect(() => generate(profile: old), throwsA(isA<ProfileIncomplete>()));
      final unilateral = const StrengthExerciseDraft(
        catalogId: 'x',
        unilateral: true,
        prescription: StrengthPrescription(sets: 2),
      );
      expect(
        unilateral.estimatedSeconds,
        greaterThan(
          const StrengthExerciseDraft(
            catalogId: 'x',
            prescription: StrengthPrescription(sets: 2),
          ).estimatedSeconds,
        ),
      );
    },
  );

  group('atomic materialization', () {
    late Database db;
    late TrainingProgramRepository repo;
    late WorkoutPlanningRepository workouts;
    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseSchemaV2.schemaVersion,
          onConfigure: (d) => d.execute('PRAGMA foreign_keys=ON'),
          onCreate: (d, _) => DatabaseSchemaV2.create(d),
        ),
      );
      final database = DatabaseService(database: db);
      repo = TrainingProgramRepository(database: database);
      workouts = WorkoutPlanningRepository(database: database);
      for (final p in [home, gym]) {
        await db.insert('training_profiles_v2', {
          'id': p.id,
          'name': p.name,
          'created_at_utc': 1,
          'updated_at_utc': 1,
        });
      }
      await repo.saveUserProfile(user());
    });
    tearDown(() async {
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await db.close();
    });
    TrainingProgram program() =>
        TrainingProgram(id: 'p', name: 'Plan', start: date, slots: slots(3));
    test(
      'two places produce one calendar, prescriptions survive, retry is idempotent',
      () async {
        final proposal = StrengthPlanProposal(
          workouts: generate().workouts.map((w) => w.confirmReview()).toList(),
        );
        await repo.save(program(), strength: proposal, locale: 'de');
        await repo.save(program(), strength: proposal, locale: 'de');
        expect((await workouts.workouts()).length, 3);
        final p = (await repo.plans()).single;
        final entries = await repo.entries(
          p,
          date,
          date.add(const Duration(days: 7)),
        );
        expect(entries.length, 3);
        expect(entries.every((e) => !e.needsWorkout), isTrue);
        final variants = await workouts.setupsForWorkout(
          proposal.workouts.first.id,
        );
        expect(variants.length, 2);
        expect(
          variants.first.groups
              .expand((g) => g.selectedVariant.slots)
              .every((s) => s.prescription!.restSeconds > 0),
          isTrue,
        );
        expect(p.strengthSettings['proposal'], proposal.toJson());
        await repo.replaceStrengthOccurrence(
          p,
          entries.first,
          proposal.workouts.last.id,
        );
        final replacement =
            (await repo.entries(
              p,
              date,
              date.add(const Duration(days: 7)),
            )).first;
        expect(replacement.workoutId, proposal.workouts.last.id);
        await repo.moveStrength(
          p,
          replacement,
          date.add(const Duration(days: 1)),
          future: false,
        );
        final moved = (await repo.entries(
          p,
          date,
          date.add(const Duration(days: 7)),
        )).firstWhere((e) => e.id == replacement.id);
        expect(moved.workoutId, proposal.workouts.last.id);
      },
    );
    test(
      'bad catalog item rolls back every template, variant and plan',
      () async {
        final a = generate();
        final w = a.workouts.last, v = a.workouts.last.variants.last;
        final broken = StrengthPlanProposal(
          workouts: [
            ...a.workouts.take(2),
            w.copyWith(
              variants: [
                w.variants.first,
                v.copyWith(
                  exercises: [
                    ...v.exercises,
                    const StrengthExerciseDraft(
                      catalogId: 'missing',
                      prescription: StrengthPrescription(sets: 2),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
        await expectLater(
          repo.save(program(), strength: broken),
          throwsStateError,
        );
        expect(await db.query('workout_templates'), isEmpty);
        expect(await db.query('training_programs'), isEmpty);
        expect(await db.query('exercises'), isEmpty);
      },
    );
    test(
      'direct generation activation requires versioned confirmed answers',
      () async {
        await repo.saveUserProfile(
          UserTrainingProfile.fromJson({
            ...user().toJson(),
            'strengthAnswers': [],
          }),
        );
        await expectLater(
          repo.save(program(), strength: generate()),
          throwsA(isA<ProfileIncomplete>()),
        );
        expect(await db.query('workout_templates'), isEmpty);
      },
    );
  });
}
