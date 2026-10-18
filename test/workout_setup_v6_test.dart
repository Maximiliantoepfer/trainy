import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/models/exercise.dart';
import 'package:trainy/models/training_profile.dart';
import 'package:trainy/models/workout.dart';
import 'package:trainy/models/workout_planning.dart';
import 'package:trainy/providers/active_workout_provider.dart';
import 'package:trainy/providers/exercise_provider.dart';
import 'package:trainy/providers/progress_provider.dart';
import 'package:trainy/providers/workout_provider.dart';
import 'package:trainy/repositories/workout_planning_repository.dart';
import 'package:trainy/screens/home_screen.dart';
import 'package:trainy/screens/workout_detail_screen.dart';
import 'package:trainy/services/catalog_repository.dart';
import 'package:trainy/themes/app_theme.dart';
import 'package:trainy/widgets/training_profile_settings_card.dart';
import 'package:trainy/widgets/workout_exercise_picker.dart';

const unicodeName = 'ÄÖÜäöüß';

class Profiles implements TrainingProfileStore {
  final values = <TrainingProfileRecord>[];
  final attemptedIds = <String>[];
  bool failNextSave = false;
  bool failNextLoad = false;
  @override
  Future<List<TrainingProfileRecord>> profiles({
    bool includeArchived = false,
  }) async {
    if (failNextLoad) {
      failNextLoad = false;
      throw StateError('load failure');
    }
    return List.of(values);
  }

  @override
  Future<void> save(TrainingProfileRecord profile) async {
    attemptedIds.add(profile.id);
    if (failNextSave) {
      failNextSave = false;
      throw StateError('save failure');
    }
    values.removeWhere((p) => p.id == profile.id);
    values.add(profile);
  }

  @override
  Future<void> archive(String profileId) async {}
  @override
  Future<void> select(String? profileId) async =>
      throw StateError('no global selection');
  @override
  Future<String?> selectedProfileId() async => null;
}

class Exercises extends ExerciseProvider {
  final values = <Exercise>[];
  int saves = 0;
  bool failNextSave = false;
  @override
  List<Exercise> get exercises => List.unmodifiable(values);
  @override
  Future<int> addOrUpdateExercise({
    int? id,
    required String name,
    String description = '',
    required bool trackSets,
    required bool trackReps,
    required bool trackWeight,
    required bool trackDuration,
    bool trackDistance = false,
    Map<String, String>? defaultValues,
    Map<String, String>? lastValues,
    Map<String, String>? units,
    int? icon,
    String? goal,
    String? standardKey,
    bool? isNameCustom,
    String? catalogId,
    String? alias,
    String notes = '',
    List<String>? goalCodes,
    List<String>? imagePaths,
  }) async {
    saves++;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('write failure');
    }
    final value = Exercise(
      id: id ?? values.length + 10,
      name: name,
      description: description,
      trackSets: trackSets,
      trackReps: trackReps,
      trackWeight: trackWeight,
      trackDuration: trackDuration,
      trackDistance: trackDistance,
      defaultValues: defaultValues ?? {},
      lastValues: lastValues ?? {},
      units: units ?? {},
      icon: icon,
      goalCodes: goalCodes ?? ['strength'],
      imagePaths: imagePaths ?? [],
    );
    values.removeWhere((e) => e.id == value.id);
    values.add(value);
    notifyListeners();
    return value.id;
  }
}

class Workouts extends WorkoutProvider {
  Workout? saved;
  String? profileId;
  bool failNextSave = false;
  @override
  Future<void> loadWorkouts() async {}
  @override
  Future<Workout> createWorkout({
    required String name,
    String description = '',
    WorkoutPrimaryGoal primaryGoal = WorkoutPrimaryGoal.strength,
    String setupName = 'Standard',
    String? profileId,
    List<int> exerciseIds = const [],
    String? creationId,
  }) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('workout failure');
    }
    this.profileId = profileId;
    return saved = Workout(
      id: 123,
      name: name,
      description: description,
      exerciseIds: exerciseIds,
    );
  }
}

class Progress extends ProgressProvider {
  @override
  Future<void> loadData() async {}
}

class Planning extends WorkoutPlanningRepository {
  final workout = Workout(id: 7, name: 'Ganzkörper', canonicalId: 'workout');
  final Profiles profiles;
  Planning(this.profiles);
  final setups = <WorkoutSetup>[
    const WorkoutSetup(
      id: 'original',
      workoutId: 'workout',
      name: 'Mein kurzer Plan',
      isDefault: true,
      sortOrder: 0,
      groups: [],
    ),
  ];
  @override
  Future<List<Workout>> workouts() async => [workout];
  @override
  Future<List<WorkoutSetup>> setupsForWorkout(String workoutId) async =>
      List.of(setups);
  @override
  Future<WorkoutSetup> createSetup({
    required String workoutId,
    required String name,
    String? profileId,
    String? copyFromSetupId,
    SetupContents contents = SetupContents.copy,
    String? creationId,
  }) async {
    final profile = profiles.values.where((p) => p.id == profileId).firstOrNull;
    final setup = WorkoutSetup(
      id: 'created',
      workoutId: workoutId,
      name: name,
      profile: profile,
      isDefault: false,
      sortOrder: 1,
      groups: const [],
    );
    setups.add(setup);
    return setup;
  }
}

Future<void> mount(
  WidgetTester tester,
  Widget child, {
  Exercises? exercises,
  WorkoutProvider? workouts,
  String locale = 'de',
  bool dark = true,
  double scale = 1,
  double width = 390,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ExerciseProvider>.value(
          value: exercises ?? Exercises(),
        ),
        ChangeNotifierProvider<WorkoutProvider>.value(
          value: workouts ?? Workouts(),
        ),
        ChangeNotifierProvider<ProgressProvider>(create: (_) => Progress()),
        ChangeNotifierProvider<ActiveWorkoutProvider>(
          create: (_) => ActiveWorkoutProvider(),
        ),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme:
            (() {
              final theme =
                  dark
                      ? AppTheme.dark(Colors.cyan)
                      : AppTheme.light(Colors.deepOrange);
              TextStyle? font(TextStyle? style) =>
                  style?.copyWith(fontFamily: 'Roboto');
              ButtonStyle? button(ButtonStyle? style) => style?.copyWith(
                textStyle: WidgetStateProperty.resolveWith(
                  (states) => font(style.textStyle?.resolve(states)),
                ),
              );
              return theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
                appBarTheme: theme.appBarTheme.copyWith(
                  titleTextStyle: font(theme.appBarTheme.titleTextStyle),
                ),
                dialogTheme: theme.dialogTheme.copyWith(
                  titleTextStyle: font(theme.dialogTheme.titleTextStyle),
                ),
                chipTheme: theme.chipTheme.copyWith(
                  labelStyle: font(theme.chipTheme.labelStyle),
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: button(theme.filledButtonTheme.style),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: button(theme.outlinedButtonTheme.style),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: button(theme.textButtonTheme.style),
                ),
              );
            })(),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
                viewInsets: EdgeInsets.only(bottom: keyboard),
              ),
              child: child!,
            ),
        home: RepaintBoundary(key: const ValueKey('v6-golden'), child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> nameWorkout(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('workoutName')));
  tester.testTextInput.updateEditingValue(
    const TextEditingValue(
      text: unicodeName,
      selection: TextSelection.collapsed(offset: 7),
      composing: TextRange(start: 0, end: 7),
    ),
  );
  await tester.pump();
  expect(
    tester
        .widget<TextFormField>(find.byKey(const ValueKey('workoutName')))
        .controller!
        .value
        .composing,
    const TextRange(start: 0, end: 7),
  );
  tester.testTextInput.updateEditingValue(
    const TextEditingValue(
      text: unicodeName,
      selection: TextSelection.collapsed(offset: 7),
    ),
  );
  await tester.tap(find.text('Weiter'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUpAll(() async {
    final config = File('.dart_tool/package_config.json').absolute;
    final packages =
        jsonDecode(await config.readAsString())['packages'] as List;
    final flutter = packages.firstWhere((p) => p['name'] == 'flutter');
    final fonts = config.uri
        .resolve('${flutter['rootUri']}/')
        .resolve('../../bin/cache/artifacts/material_fonts/');
    final textFont = FontLoader('Roboto')..addFont(
      File.fromUri(
        fonts.resolve('roboto-regular.ttf'),
      ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
    await textFont.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    temp = await Directory.systemTemp.createTemp('trainy-v6-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => temp.path,
        );
    await CatalogRepository.instance.load();
  });
  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await temp.delete(recursive: true);
  });

  testWidgets('full-width equal goal tiles and top-aligned description', (
    tester,
  ) async {
    await mount(tester, WorkoutEditorScreen(profileStore: Profiles()));
    final left = tester.getRect(
      find.byKey(const ValueKey('workoutGoal_strength')),
    );
    final right = tester.getRect(
      find.byKey(const ValueKey('workoutGoal_endurance')),
    );
    expect(left.left, 16);
    expect(right.right, 374);
    expect(left.size, right.size);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('workoutDescription')),
    );
    expect(field.minLines, 2);
    expect(field.maxLines, 4);
    expect(field.decoration!.alignLabelWithHint, true);
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/icons/muskel.png'),
        tester.element(find.byType(WorkoutEditorScreen)),
      ),
    );
    await tester.pumpAndSettle();
    // Hide the blinking insertion caret in deterministic screenshots.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('v6-golden')),
      matchesGoldenFile('goldens/workout_setup_v6_dark.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'narrow English large text stacks goals and keeps keyboard actions reachable',
    (tester) async {
      await mount(
        tester,
        WorkoutEditorScreen(profileStore: Profiles()),
        width: 320,
        scale: 2,
        locale: 'en',
        dark: false,
        keyboard: 280,
      );
      final a = find.byKey(const ValueKey('workoutGoal_strength'));
      final b = find.byKey(const ValueKey('workoutGoal_endurance'));
      await tester.dragUntilVisible(
        b,
        find.byType(ListView),
        const Offset(0, -150),
      );
      expect(tester.getRect(a).width, 288);
      expect(tester.getRect(b).width, 288);
      expect(tester.getRect(b).top, greaterThan(tester.getRect(a).top));
      expect(tester.getBottomLeft(find.text('Next')).dy, lessThan(844 - 280));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wizard creates selects and preserves profile with Unicode, retry and back',
    (tester) async {
      final profiles = Profiles()..failNextSave = true;
      final workouts = Workouts()..failNextSave = true;
      await mount(
        tester,
        WorkoutEditorScreen(profileStore: profiles),
        workouts: workouts,
      );
      await nameWorkout(tester);
      await tester.tap(find.byKey(const ValueKey('createWorkoutProfile')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neues Profil'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(
              find.byKey(const ValueKey('trainingProfileEquipment_bodyweight')),
            )
            .selected,
        true,
      );
      await tester.enterText(
        find.byKey(const ValueKey('trainingProfileName')),
        unicodeName,
      );
      await tester.tap(find.byKey(const ValueKey('trainingProfileSubmit')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Lokal speichern fehlgeschlagen'),
        findsOneWidget,
      );
      await tester.tap(find.text('Erneut versuchen'));
      await tester.pumpAndSettle();
      expect(profiles.values.single.name, unicodeName);
      expect(profiles.attemptedIds.toSet().length, 1);
      expect(find.text(unicodeName), findsNWidgets(2));
      await tester.tap(find.text('Zurück'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('workoutName')))
            .controller!
            .text,
        unicodeName,
      );
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      expect(find.text(unicodeName), findsNWidgets(2));
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Workout speichern'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Erneut versuchen'));
      await tester.pumpAndSettle();
      expect(workouts.saved!.name, unicodeName);
      expect(workouts.profileId, profiles.values.single.id);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile load retry and cancelled profile leave wizard intact', (
    tester,
  ) async {
    final profiles = Profiles()..failNextLoad = true;
    await mount(tester, WorkoutEditorScreen(profileStore: profiles));
    await nameWorkout(tester);
    expect(
      find.text('Die Profile konnten nicht geladen werden.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('createWorkoutProfile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neues Profil'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('trainingProfileName')),
      'discard',
    );
    await tester.tap(find.byKey(const ValueKey('trainingProfileCancel')));
    await tester.pumpAndSettle();
    expect(profiles.values, isEmpty);
    expect(find.text('Profil auswählen'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'equipment compact golden, touch targets, and editing never adds bodyweight',
    (tester) async {
      final profiles = Profiles();
      final now = DateTime.utc(2026);
      final old = TrainingProfileRecord(
        id: 'gym',
        name: unicodeName,
        equipmentCodes: const {'machine'},
        createdAtUtc: now,
        updatedAtUtc: now,
      );
      await mount(
        tester,
        Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => showTrainingProfileEditor(
                        context,
                        store: profiles,
                        existing: old,
                      ),
                  child: const Text('open'),
                ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final bodyweight = find.byKey(
        const ValueKey('trainingProfileEquipment_bodyweight'),
      );
      expect(tester.widget<FilterChip>(bodyweight).selected, false);
      expect(tester.getSize(bodyweight).height, greaterThanOrEqualTo(48));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile('goldens/profile_v6_compact.png'),
      );
      await tester.tap(find.byKey(const ValueKey('trainingProfileSubmit')));
      await tester.pumpAndSettle();
      expect(profiles.values.single.equipmentCodes, {'machine'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'existing workout selects newly created profile and excludes its duplicate',
    (tester) async {
      final profiles = Profiles();
      final planning = Planning(profiles);
      await mount(
        tester,
        WorkoutDetailScreen(
          workout: planning.workout,
          repository: planning,
          profileStore: profiles,
        ),
      );
      expect(find.text('Mein kurzer Plan'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('workoutProfileChooser')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neues Profil'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('trainingProfileName')),
        unicodeName,
      );
      await tester.tap(find.byKey(const ValueKey('trainingProfileSubmit')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Übungen übernehmen'));
      await tester.pumpAndSettle();
      expect(planning.setups, hasLength(2));
      expect(find.text(unicodeName), findsOneWidget);
      expect(planning.setups.last.profile?.id, profiles.values.single.id);
      await tester.tap(find.byKey(const ValueKey('workoutProfileChooser')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(unicodeName),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile form remains scrollable with large text and open keyboard',
    (tester) async {
      await mount(
        tester,
        WorkoutEditorScreen(profileStore: Profiles()),
        width: 320,
        scale: 2,
        keyboard: 280,
        locale: 'en',
        dark: false,
      );
      await tester.enterText(
        find.byKey(const ValueKey('workoutName')),
        unicodeName,
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('createWorkoutProfile')),
      );
      await tester.tap(find.byKey(const ValueKey('createWorkoutProfile')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New profile'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('trainingProfileSubmit')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'picker creates preselected custom exercise, preserves selections, retries and clears filters',
    (tester) async {
      final exercises = Exercises()..failNextSave = true;
      await mount(
        tester,
        const WorkoutExercisePicker(selectedCatalogIds: {'free:Pushups'}),
        exercises: exercises,
      );
      await tester.enterText(find.byType(TextField), unicodeName);
      await tester.tap(find.byKey(const ValueKey('pickerCreateExercise')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('exerciseName')))
            .controller!
            .text,
        unicodeName,
      );
      await tester.tap(find.byKey(const ValueKey('exerciseEditorSubmit')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Erneut versuchen'));
      await tester.pumpAndSettle();
      expect(exercises.values.single.name, unicodeName);
      expect(exercises.saves, 2);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.byKey(const ValueKey('local:10')), findsOneWidget);
      expect(
        tester
            .widget<Checkbox>(
              find.descendant(
                of: find.byKey(const ValueKey('local:10')),
                matching: find.byType(Checkbox),
              ),
            )
            .value,
        true,
      );
      await tester.enterText(find.byType(TextField), 'Liegestütz');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Checkbox>(
              find.descendant(
                of: find.byKey(const ValueKey('free:Pushups')),
                matching: find.byType(Checkbox),
              ),
            )
            .value,
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'picker and exercise editor fit narrow large-text keyboard layout',
    (tester) async {
      await mount(
        tester,
        const WorkoutExercisePicker(),
        width: 320,
        scale: 2,
        keyboard: 280,
        locale: 'en',
        dark: false,
      );
      await tester.tap(find.byKey(const ValueKey('pickerCreateExercise')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('exerciseEditorSubmit')).hitTestable(),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('exerciseName')));
      await tester.enterText(
        find.byKey(const ValueKey('exerciseName')),
        unicodeName,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'picker cancel preserves search and single mode returns saved identity',
    (tester) async {
      final exercises = Exercises();
      ExercisePickerResult? result;
      await mount(
        tester,
        Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () async {
                    result = await showModalBottomSheet<ExercisePickerResult>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const WorkoutExercisePicker(single: true),
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
      await tester.enterText(find.byType(TextField), unicodeName);
      await tester.tap(find.byKey(const ValueKey('pickerCreateExercise')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbrechen').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        unicodeName,
      );
      expect(exercises.values, isEmpty);
      await tester.tap(find.byKey(const ValueKey('pickerCreateExercise')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('exerciseEditorSubmit')));
      await tester.pumpAndSettle();
      expect(result!.exerciseIds, {10});
      expect(find.byType(WorkoutExercisePicker), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home empty state has isolated extra spacing', (tester) async {
    await mount(tester, const HomeScreen());
    final spacing = find.byKey(const ValueKey('emptyWorkoutsSpacing'));
    await tester.ensureVisible(spacing);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Padding>(spacing).padding,
      const EdgeInsets.only(top: 32),
    );
    await expectLater(spacing, matchesGoldenFile('goldens/home_empty_v6.png'));
    expect(tester.takeException(), isNull);
  });
}
