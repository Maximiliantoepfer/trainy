import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trainy/models/catalog_exercise.dart';
import 'package:trainy/models/training_profile.dart';
import 'package:trainy/models/workout.dart';
import 'package:trainy/models/workout_planning.dart';
import 'package:trainy/providers/training_profile_provider.dart';
import 'package:trainy/providers/workout_provider.dart';
import 'package:trainy/repositories/workout_planning_repository.dart';
import 'package:trainy/screens/exercise_screen.dart';
import 'package:trainy/screens/profile_onboarding_screen.dart';
import 'package:trainy/screens/weekly_planner_screen.dart';
import 'package:trainy/screens/workout_detail_screen.dart';
import 'package:trainy/services/catalog_repository.dart';
import 'package:trainy/widgets/training_profile_settings_card.dart';
import 'package:trainy/widgets/workout_exercise_picker.dart';
import 'workout_setup_v6_test.dart' as v6;
import 'workout_editor_v5_widget_test.dart' as v5;

TrainingProfileRecord record(String id) => TrainingProfileRecord(
  id: id,
  name: id,
  equipmentCodes: const {'bodyweight'},
  createdAtUtc: DateTime.utc(2026),
  updatedAtUtc: DateTime.utc(2026),
);

class Profiles extends v6.Profiles implements TrainingProfilePreferencesStore {
  String? preferred;
  ProfileSetupState state = ProfileSetupState.required;
  bool failComplete = false;
  final List<List<String>> attempts = [];
  @override
  Future<String?> selectedProfileId() async => preferred;
  @override
  Future<void> select(String? profileId) async => preferred = profileId;
  @override
  Future<ProfileSetupState> setupState() async => state;
  @override
  Future<void> dismissSetupOffer() async => state = ProfileSetupState.dismissed;
  @override
  Future<void> completeSetup({
    required List<TrainingProfileRecord> profiles,
    required String preferredProfileId,
  }) async {
    attempts.add(profiles.map((p) => p.id).toList());
    if (failComplete) {
      failComplete = false;
      throw StateError('test storage failure');
    }
    for (final p in profiles) {
      await save(p);
    }
    preferred = preferredProfileId;
    state = ProfileSetupState.completed;
  }
}

class Exercises extends v6.Exercises {
  @override
  Future<void> loadExercises() async {}
  @override
  Future<int> addCatalogExercise(LocalizedCatalogExercise item) async {
    final found =
        values.where((e) => e.catalogId == item.definition.id).firstOrNull;
    if (found != null) return found.id;
    final value = v5
        .exercise(100 + values.length, item.content.name)
        .copyWith(catalogId: item.definition.id);
    values.add(value);
    notifyListeners();
    return value.id;
  }
}

class Week extends WorkoutPlanningRepository {
  final first = Workout(id: 1, canonicalId: 'w1', name: 'Morning');
  final second = Workout(id: 2, canonicalId: 'w2', name: 'Evening');
  List<WeeklyWorkoutPlacement> placements = [
    const WeeklyWorkoutPlacement(
      id: 'p1',
      workoutId: 'w1',
      weekday: 1,
      sortOrder: 0,
    ),
    const WeeklyWorkoutPlacement(
      id: 'p2',
      workoutId: 'w2',
      weekday: 1,
      sortOrder: 1,
    ),
  ];
  int removes = 0;
  bool failRead = false;
  (String, int, int)? moved;
  @override
  Future<List<Workout>> workouts() async => [first, second];
  @override
  Future<List<WeeklyWorkoutPlacement>> weeklyPlacements() async {
    if (failRead) {
      failRead = false;
      throw StateError('refresh failure');
    }
    return List.of(placements);
  }

  @override
  Future<void> removePlacement(String placementId) async {
    removes++;
    placements.removeWhere((p) => p.id == placementId);
    failRead = true;
  }

  @override
  Future<void> assignToDay({
    required String workoutId,
    required int weekday,
    int? index,
  }) async {
    placements.insert(
      index ?? 0,
      WeeklyWorkoutPlacement(
        id: 'restored',
        workoutId: workoutId,
        weekday: weekday,
        sortOrder: index ?? 0,
      ),
    );
  }

  @override
  Future<void> movePlacement({
    required String placementId,
    required int targetWeekday,
    required int targetIndex,
  }) async {
    moved = (placementId, targetWeekday, targetIndex);
  }
}

class LaunchPlanning extends v5.Planning {
  String? launched;
  @override
  Future<WorkoutLaunchPlan> launchPlanForSetup(String setupId) async {
    launched = setupId;
    throw StateError(
      'Stop before starting a real session in this routing test',
    );
  }
}

Future<void> capture(WidgetTester tester, Finder finder, String name) async {
  // Asset decoding runs outside the widget-test clock. Wait for every visible
  // image so reference pictures cannot accidentally approve blank thumbnails.
  final context = tester.element(finder.first);
  final images =
      tester.widgetList<Image>(find.byType(Image)).map((i) => i.image).toList();
  await tester.runAsync(() async {
    for (final image in images) {
      await precacheImage(image, context);
    }
  });
  await tester.pumpAndSettle();
  await expectLater(finder, matchesGoldenFile('goldens/$name.png'));
}

void main() {
  setUpAll(() async {
    final config = File('.dart_tool/package_config.json').absolute;
    final packages =
        jsonDecode(await config.readAsString())['packages'] as List;
    final flutter = packages.firstWhere((p) => p['name'] == 'flutter');
    final fonts = config.uri
        .resolve('${flutter['rootUri']}/')
        .resolve('../../bin/cache/artifacts/material_fonts/');
    await (FontLoader('Roboto')..addFont(
      File.fromUri(
        fonts.resolve('roboto-regular.ttf'),
      ).readAsBytes().then(ByteData.sublistView),
    )).load();
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await CatalogRepository.instance.load();
  });

  testWidgets(
    'wizard displays ordered custom/catalog rows and saves exactly this order',
    (tester) async {
      final profiles =
          Profiles()
            ..values.add(record('Home Gym'))
            ..preferred = 'Home Gym';
      final exercises = Exercises()..values.add(v5.exercise(7, 'Meine Übung'));
      final workouts = v6.Workouts();
      await v6.mount(
        tester,
        WorkoutEditorScreen(profileStore: profiles),
        exercises: exercises,
        workouts: workouts,
      );
      await v6.nameWorkout(tester);
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      expect(find.text(v6.unicodeName), findsOneWidget);
      expect(find.text('Neues Workout'), findsNothing);
      await tester.tap(find.text('Übungen hinzufügen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Liegestütz');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('free:Pushups')));
      await tester.enterText(find.byType(TextField), 'Meine Übung');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('local:7')));
      await tester.tap(find.byKey(const ValueKey('pickerApply')));
      await tester.pumpAndSettle();
      expect(find.text('Meine Übung'), findsOneWidget);
      expect(find.text('Liegestütz'), findsOneWidget);
      final list = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      list.onReorder(1, 0);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Meine Übung')).dy,
        lessThan(tester.getTopLeft(find.text('Liegestütz')).dy),
      );
      await capture(
        tester,
        find.byKey(const ValueKey('v6-golden')),
        'workout_v7_selection',
      );
      await tester.tap(find.text('Workout speichern'));
      await tester.pumpAndSettle();
      expect(workouts.saved!.exerciseIds, [7, 101]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'picker deduplicates materialized selections and footer applies zero selections',
    (tester) async {
      final exercises =
          Exercises()
            ..values.add(
              v5.exercise(7, 'Liegestütz').copyWith(catalogId: 'free:Pushups'),
            );
      ExercisePickerResult? result;
      await v6.mount(
        tester,
        Scaffold(
          body: Builder(
            builder:
                (c) => TextButton(
                  onPressed: () async {
                    result = await Navigator.push<ExercisePickerResult>(
                      c,
                      MaterialPageRoute(
                        builder:
                            (_) => const WorkoutExercisePicker(
                              selectedExerciseIds: {7},
                              selectedCatalogIds: {'free:Pushups'},
                            ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
          ),
        ),
        exercises: exercises,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Übernehmen (1)'), findsOneWidget);
      await capture(tester, find.byType(Scaffold).last, 'workout_v7_picker');
      await tester.tap(find.byKey(const ValueKey('free:Pushups')));
      await tester.pumpAndSettle();
      final apply = find.byKey(const ValueKey('pickerApply'));
      expect(tester.getBottomLeft(apply).dy, greaterThan(700));
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(result!.references, isEmpty);
    },
  );

  testWidgets(
    'onboarding retries the same profile IDs and exits required screen after save',
    (tester) async {
      final store = Profiles()..failComplete = true;
      final shared = TrainingProfileProvider(store: store);
      addTearDown(shared.dispose);
      await shared.reload();
      await v6.mount(
        tester,
        Scaffold(
          body: Builder(
            builder:
                (c) => TextButton(
                  onPressed:
                      () => Navigator.push<void>(
                        c,
                        MaterialPageRoute(
                          builder:
                              (_) => RepaintBoundary(
                                key: const ValueKey('onboarding-golden'),
                                child: ProfileOnboardingScreen(
                                  profiles: shared,
                                  required: true,
                                ),
                              ),
                        ),
                      ),
                  child: const Text('open'),
                ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Home Gym'), findsOneWidget);
      expect(find.text('Gym'), findsOneWidget);
      await capture(
        tester,
        find.byKey(const ValueKey('onboarding-golden')),
        'workout_v7_onboarding',
      );
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Erneut versuchen'));
      await tester.pumpAndSettle();
      expect(store.attempts[0], store.attempts[1]);
      expect(shared.activeProfiles, hasLength(2));
      expect(shared.onboardingState, ProfileSetupState.completed);
      expect(find.byType(ProfileOnboardingScreen), findsNothing);
    },
  );

  testWidgets(
    'settings react immediately to profile saved elsewhere and preserve preferred marker',
    (tester) async {
      final shared = TrainingProfileProvider(store: Profiles());
      addTearDown(shared.dispose);
      await shared.reload();
      await v6.mount(
        tester,
        Scaffold(body: TrainingProfileSettingsCard(store: shared)),
      );
      await tester.runAsync(() async {
        await shared.save(record('Gym'));
        await shared.select('Gym');
      });
      await tester.pumpAndSettle();
      expect(find.text('Gym'), findsOneWidget);
      expect(find.textContaining('Standard'), findsOneWidget);
    },
  );

  testWidgets(
    'visible workout setup starts directly without a second chooser',
    (tester) async {
      final repo = LaunchPlanning();
      final workouts = WorkoutProvider(repository: repo);
      await workouts.loadWorkouts();
      addTearDown(workouts.dispose);
      final profiles = Profiles();
      await v6.mount(
        tester,
        WorkoutDetailScreen(
          workout: repo.workout,
          repository: repo,
          profileStore: profiles,
        ),
        workouts: workouts,
        exercises:
            Exercises()
              ..values.addAll([v5.exercise(1, 'A'), v5.exercise(2, 'B')]),
      );
      await tester.tap(find.byKey(const ValueKey('workoutProfileChooser')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('studio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(repo.launched, 'studio');
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  testWidgets(
    'weekly delete refresh retry does not delete twice and undo keeps original position',
    (tester) async {
      final repo = Week();
      final workouts = WorkoutProvider(repository: repo);
      addTearDown(workouts.dispose);
      await workouts.loadWorkouts();
      await v6.mount(
        tester,
        WeeklyPlannerScreen(repository: repo),
        workouts: workouts,
      );
      expect(find.text('Kein Workout geplant'), findsNothing);
      await tester.tap(find.byTooltip('Aus Wochenplan entfernen').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Erneut versuchen').last);
      await tester.pumpAndSettle();
      expect(repo.removes, 1);
      await tester.tap(find.text('Rückgängig'));
      await tester.pumpAndSettle();
      expect(repo.placements.first.workoutId, 'w1');
      expect(repo.placements.first.weekday, 1);
      expect(repo.placements.first.sortOrder, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'library uses accent filter badge and hides absent duplicate action',
    (tester) async {
      final shared = TrainingProfileProvider(store: Profiles());
      addTearDown(shared.dispose);
      await shared.reload();
      await v6.mount(
        tester,
        ChangeNotifierProvider.value(
          value: shared,
          child: const ExerciseScreen(),
        ),
        exercises: Exercises(),
      );
      expect(find.byTooltip('Dubletten prüfen'), findsNothing);
      final badge = tester.widget<Badge>(find.byType(Badge));
      final scheme = Theme.of(tester.element(find.byType(Badge))).colorScheme;
      expect(badge.backgroundColor, scheme.primary);
      expect(badge.textColor, scheme.onPrimary);
    },
  );

  testWidgets(
    'weekly grip moves immediately to another day and empty days stay compact',
    (tester) async {
      final repo = Week();
      final workouts = WorkoutProvider(repository: repo);
      addTearDown(workouts.dispose);
      await workouts.loadWorkouts();
      await v6.mount(
        tester,
        WeeklyPlannerScreen(repository: repo),
        workouts: workouts,
        dark: false,
      );
      await capture(
        tester,
        find.byKey(const ValueKey('v6-golden')),
        'workout_v7_week',
      );
      final grip = find.byIcon(Icons.drag_indicator_rounded).first;
      final drag = await tester.startGesture(tester.getCenter(grip));
      await drag.moveBy(const Offset(0, 15));
      await tester.pump();
      await drag.moveTo(
        tester.getCenter(find.text('Di')) + const Offset(100, 0),
      );
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(repo.moved, ('p1', 2, 0));
      expect(tester.takeException(), isNull);
    },
  );
}
