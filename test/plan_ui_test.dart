import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/models/training_program.dart';
import 'package:trainy/providers/active_workout_provider.dart';
import 'package:trainy/providers/cardio_provider.dart';
import 'package:trainy/providers/locale_provider.dart';
import 'package:trainy/providers/progress_provider.dart';
import 'package:trainy/providers/training_program_provider.dart';
import 'package:trainy/providers/workout_provider.dart';
import 'package:trainy/providers/theme_provider.dart';
import 'package:trainy/repositories/cardio_repository.dart';
import 'package:trainy/repositories/training_program_repository.dart';
import 'package:trainy/screens/cardio_profile_screen.dart';
import 'package:trainy/screens/plan_home_screen.dart';
import 'package:trainy/screens/training_plan_setup_screen.dart';
import 'package:trainy/screens/training_plan_screen.dart';
import 'package:trainy/screens/welcome_setup_screen.dart';
import 'package:trainy/widgets/appearance_picker.dart';
import 'package:trainy/widgets/language_preference_picker.dart';
import 'package:trainy/widgets/plan_controls.dart';
import 'package:trainy/providers/training_profile_provider.dart';
import 'package:trainy/repositories/training_profile_repository.dart';
import 'package:trainy/models/training_profile.dart';
import 'package:trainy/themes/app_theme.dart';

class EmptyEquipment extends TrainingProfileRepository {
  @override
  Future<List<TrainingProfileRecord>> profiles({
    bool includeArchived = false,
  }) async => [];
  @override
  Future<String?> selectedProfileId() async => null;
  @override
  Future<ProfileSetupState> setupState() async => ProfileSetupState.required;
}

class MemoryPrograms extends TrainingProgramRepository {
  @override
  Future<List<ProgramEntry>> weekEntries(
    TrainingProgram? p,
    DateTime from,
    DateTime to,
  ) async => p == null ? [] : entries(p, from, to);
  final drafts = <String, Map<String, dynamic>>{};
  final saved = <TrainingProgram>[];
  String? selected;
  @override
  Future<void> initialize() async {}
  @override
  Future<UserTrainingProfile> userProfile() async =>
      const UserTrainingProfile();
  @override
  Future<List<TrainingProgram>> plans() async => saved;
  @override
  Future<String?> activeId() async => selected;
  @override
  Future<Map<String, dynamic>?> draft(String id) async => drafts[id];
  @override
  Future<void> saveDraft(String id, Map<String, dynamic> data) async {
    drafts[id] = data;
  }

  @override
  Future<void> clearDraft(String id) async {
    drafts.remove(id);
  }

  @override
  Future<List<ProgramEntry>> entries(
    TrainingProgram p,
    DateTime from,
    DateTime to,
  ) async => [
    for (final s in p.currentSlots)
      ProgramEntry(
        id: s.id,
        planId: p.id,
        date: DateTime(from.year, from.month, from.day + s.weekday - 1),
        name: s.label,
        kind: s.kind,
        slotId: s.id,
        workoutId: s.workoutId,
      ),
  ];
}

class MemoryCardio extends CardioRepository {
  AthleteRunningProfile value = const AthleteRunningProfile();
  @override
  Future<AthleteRunningProfile> profile() async => value;
  @override
  Future<void> saveProfile(AthleteRunningProfile p) async {
    p.validate();
    value = p;
  }

  @override
  Future<List<CardioWorkout>> workouts() async => [];
  @override
  Future<List<ScheduledCardioWorkout>> occurrences() async => [];
  @override
  Future<List<Map<String, Object?>>> history() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final config = File('.dart_tool/package_config.json').absolute;
    final packages =
        jsonDecode(await config.readAsString())['packages'] as List;
    final flutter = packages.firstWhere((p) => p['name'] == 'flutter');
    final font = config.uri
        .resolve('${flutter['rootUri']}/')
        .resolve('../../bin/cache/artifacts/material_fonts/roboto-regular.ttf');
    await (FontLoader('Roboto')..addFont(
      File.fromUri(font).readAsBytes().then(ByteData.sublistView),
    )).load();
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  late MemoryPrograms programs;
  late TrainingProgramProvider plans;
  late MemoryCardio cardioRepo;
  late CardioProvider cardio;
  late ThemeProvider appearance;
  late LocaleProvider language;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    programs = MemoryPrograms();
    plans = TrainingProgramProvider(repository: programs);
    await plans.load();
    cardioRepo = MemoryCardio();
    cardio = CardioProvider(repository: cardioRepo);
    await cardio.load();
    appearance = ThemeProvider();
    language = LocaleProvider();
    await language.init();
  });
  tearDown(() {
    plans.dispose();
    cardio.dispose();
    appearance.dispose();
    language.dispose();
  });
  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    bool dark = false,
    double width = 390,
    double scale = 1,
    String locale = 'de',
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var theme =
        dark
            ? AppTheme.dark(const Color(0xFF0EC7FF))
            : AppTheme.light(const Color(0xFF0EC7FF));
    ButtonStyle? button(ButtonStyle? style) => style?.copyWith(
      textStyle: WidgetStateProperty.resolveWith(
        (states) =>
            style.textStyle?.resolve(states)?.copyWith(fontFamily: 'Roboto'),
      ),
    );
    theme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
          fontFamily: 'Roboto',
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: button(theme.filledButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: button(theme.textButtonTheme.style),
      ),
      chipTheme: theme.chipTheme.copyWith(
        labelStyle: theme.chipTheme.labelStyle?.copyWith(fontFamily: 'Roboto'),
      ),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: plans),
          ChangeNotifierProvider.value(value: cardio),
          ChangeNotifierProvider.value(value: appearance),
          ChangeNotifierProvider.value(value: language),
          ChangeNotifierProvider(create: (_) => WorkoutProvider()),
          ChangeNotifierProvider(create: (_) => ActiveWorkoutProvider()),
          ChangeNotifierProvider(create: (_) => ProgressProvider()),
          ChangeNotifierProvider(
            create: (_) => TrainingProfileProvider(store: EmptyEquipment()),
          ),
        ],
        child: Consumer<LocaleProvider>(
          builder:
              (context, language, _) => MaterialApp(
                theme: theme,
                locale: language.localeOverride ?? Locale(locale),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                builder:
                    (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                home: RepaintBoundary(
                  key: const ValueKey('plan-golden'),
                  child: child,
                ),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final c = tester.element(find.byKey(const ValueKey('plan-golden')));
      await Future.wait([
        precacheImage(const AssetImage('assets/icons/sofa.png'), c),
        precacheImage(const AssetImage('assets/icons/hantel.png'), c),
      ]);
    });
    await tester.pumpAndSettle();
  }

  test(
    'chosen accent is exact; foregrounds and field outlines meet contrast',
    () {
      for (final color in [
        const Color(0xFF0EC7FF),
        const Color(0xFF5285FA),
        Colors.white,
        Colors.black,
        Colors.yellow,
      ]) {
        for (final theme in [AppTheme.light(color), AppTheme.dark(color)]) {
          final s = theme.colorScheme;
          expect(s.primary, color);
          expect(
            AppTheme.contrast(s.onPrimary, s.primary),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            AppTheme.contrast(s.onSurface, s.surfaceContainerLow),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            AppTheme.contrast(s.onSurfaceVariant, s.surfaceContainerLowest),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            AppTheme.contrast(
              AppTheme.accessibleAccent(s),
              s.surfaceContainerLow,
            ),
            greaterThanOrEqualTo(4.5),
          );
          if (s.brightness == Brightness.light) {
            expect(
              AppTheme.contrast(s.outline, s.surfaceContainerHighest),
              greaterThanOrEqualTo(3),
            );
          }
        }
      }
    },
  );
  for (final dark in [false, true]) {
    testWidgets('plan-first empty home ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      await mount(tester, const PlanHomeScreen(), dark: dark);
      expect(find.text('Trainingsplan erstellen'), findsOneWidget);
      expect(find.text('Ohne Plan trainieren'), findsNothing);
      expect(find.text('Weiteres Workout starten'), findsOneWidget);
      expect(find.text('Ausdauer'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('plan-golden')),
        matchesGoldenFile('goldens/plan_home_${dark ? 'dark' : 'light'}.png'),
      );
    });
  }
  testWidgets(
    'new plan offers seven available days but only three strength sessions',
    (tester) async {
      await mount(tester, const TrainingPlanSetupScreen());
      expect(
        tester.widget<PlanDayPicker>(find.byType(PlanDayPicker)).selected,
        {1, 2, 3, 4, 5, 6, 7},
      );
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      // The contextual strength profile can be left without forcing equipment setup.
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PlanDayPicker>(find.byType(PlanDayPicker))
            .selected
            .length,
        3,
      );
      await tester.tap(find.text('Dein Split'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Push + Bauch / Pull + Beine / Ganzkörper'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PlanDayPicker>(find.byType(PlanDayPicker)).selected,
        {1, 2, 5},
      );
      await tester.ensureVisible(find.text('Push + Bauch'));
      await tester.tap(find.text('Push + Bauch'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChip, 'Push'), findsOneWidget);
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Bauch'))
            .selected,
        isTrue,
      );
      await tester.tap(find.widgetWithText(FilterChip, 'Pull'));
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      final draft = programs.drafts['plan:new']!;
      final saved = TrainingProgram.fromJson(
        Map<String, dynamic>.from(draft['program'] as Map),
      );
      expect(saved.split, 'custom');
      expect(
        saved.currentSlots.firstWhere((s) => s.weekday == 1).effectiveFocus,
        {'push', 'pull', 'core'},
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('appearance fits small display and large German text', (
    tester,
  ) async {
    await mount(
      tester,
      Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: const [AppearancePicker()],
        ),
      ),
      width: 320,
      scale: 1.8,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Dunkel'));
    await tester.pumpAndSettle();
    expect(appearance.themeMode, ThemeMode.dark);
  });
  testWidgets(
    'onboarding can skip every optional service and keeps unfinished plan draft',
    (tester) async {
      var completed = 0;
      programs.drafts['plan:new'] = {'step': 1};
      await mount(
        tester,
        WelcomeSetupScreen(
          completeSetup: () async {
            completed++;
          },
        ),
      );
      expect(find.byType(LanguagePreferencePicker), findsOneWidget);
      expect(find.byType(AppearancePicker), findsNothing);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Weiter'));
        await tester.pumpAndSettle();
      }
      expect(completed, 0);
      await tester.tap(find.text('Fertig'));
      await tester.pumpAndSettle();
      expect(completed, 1);
      expect(programs.drafts['onboarding'], isNull);
      expect(programs.drafts['plan:new'], isNotNull);
      expect(cardioRepo.value.healthEnabled, false);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'onboarding starts with language, applies and saves it immediately',
    (tester) async {
      await mount(tester, const WelcomeSetupScreen(), width: 320, scale: 1.8);
      expect(find.text('Sprache'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Deutsch'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.byType(AppearancePicker), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(language.preference, AppLanguagePreference.english);
      final reloaded = LocaleProvider();
      await reloaded.init();
      expect(reloaded.preference, AppLanguagePreference.english);
      reloaded.dispose();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(AppearancePicker), findsOneWidget);
      expect(programs.drafts['onboarding'], {'stage': 'look'});
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsOneWidget);
      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();
      expect(find.text('Sprache'), findsOneWidget);
      expect(language.localeOverride, isNull);
      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      expect(language.localeOverride, const Locale('de'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'onboarding resumes named and pre-language drafts at the same stage',
    (tester) async {
      for (final draft in [
        {'stage': 'look'},
        {'step': 0},
      ]) {
        programs.drafts['onboarding'] = draft;
        await mount(tester, const WelcomeSetupScreen());
        expect(find.byType(AppearancePicker), findsOneWidget);
        await tester.tap(find.text('Weiter'));
        await tester.pumpAndSettle();
        expect(programs.drafts['onboarding'], {'stage': 'backup'});
        expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      programs.drafts['onboarding'] = {'step': 3};
      await mount(tester, const WelcomeSetupScreen());
      expect(find.text('Fertig'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_outline), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'onboarding failed completion is retryable and never silently finishes',
    (tester) async {
      await mount(
        tester,
        WelcomeSetupScreen(
          completeSetup: () async {
            throw StateError('storage failure');
          },
        ),
      );
      await tester.tap(find.text('Später'));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeSetupScreen), findsOneWidget);
      expect(
        find.text('Nicht gespeichert. Bitte erneut versuchen.'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'shared week shows unassigned split slots ${dark ? 'dark' : 'light'}',
      (tester) async {
        final p = TrainingProgram(
          name: 'Meine Woche',
          start: DateTime(2030, 1, 7),
          strengthGoal: 'getStronger',
          slots: ProgramSplits.slots([1, 3, 5], 'fullBody'),
        );
        programs.saved.add(p);
        programs.selected = p.id;
        await plans.load();
        await mount(
          tester,
          Scaffold(
            appBar: AppBar(title: const Text('Trainy')),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                PlanWeekView(
                  program: p,
                  date: p.start,
                  onDateChanged: (_) {},
                  todayFirst: true,
                ),
                const SizedBox(height: 20),
                const TrainingPlanCard(),
              ],
            ),
          ),
          dark: dark,
        );
        expect(find.text('Workout zuordnen'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('plan-golden')),
          matchesGoldenFile('goldens/plan_week_${dark ? 'dark' : 'light'}.png'),
        );
      },
    );
  }
  testWidgets(
    'performance question is readable at large text without a clipped label',
    (tester) async {
      programs.drafts['running-profile'] = {
        'fields': {'distance': '5', 'time': '32:30'},
        'step': 1,
      };
      await mount(
        tester,
        CardioProfileScreen(provider: cardio, setupRepository: programs),
        width: 390,
        scale: 1.3,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('plan-golden')),
        matchesGoldenFile('goldens/running_profile_light.png'),
      );
    },
  );
  testWidgets(
    'running profile gives field errors, saves one pulse, preserves 5k ability',
    (tester) async {
      await mount(
        tester,
        CardioProfileScreen(provider: cardio, setupRepository: programs),
        width: 320,
        scale: 1.6,
      );
      await tester.scrollUntilVisible(find.text('Ja'), 200);
      await tester.tap(find.text('Ja'));
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), '0:00');
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Zeit über 0'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(1), '32:30');
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '7,5');
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '60');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(cardioRepo.value.canRunFiveKm, true);
      expect(cardioRepo.value.referenceSeconds, 1950);
      expect(cardioRepo.value.longestMeters, 7500);
      expect(cardioRepo.value.restingHeartRate, 60);
      expect(cardioRepo.value.maximumHeartRate, isNull);
      expect(programs.drafts.containsKey('running-profile'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'plan draft resumes preview, displays missing assignments without claiming readiness',
    (tester) async {
      final p = TrainingProgram(
        name: 'My week',
        start: DateTime(2030, 1, 7),
        slots: ProgramSplits.slots([1, 3, 5], 'fullBody'),
      );
      programs.drafts['plan:new'] = {
        'program': p.toJson(),
        'sports': ['strength'],
        'available': [1, 3, 5],
        'step': 2,
        'runningChanged': false,
      };
      await mount(
        tester,
        const TrainingPlanSetupScreen(),
        width: 320,
        scale: 1.5,
        locale: 'en',
      );
      expect(find.text('My week'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Assign workout').first,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Assign workout'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'metric draft survives an imperial switch without rounding canonical distances',
    (tester) async {
      cardioRepo.value = const AthleteRunningProfile(
        units: DistanceSystem.imperial,
      );
      await cardio.load();
      programs.drafts['running-profile'] = {
        'fields': {'distance': '5', 'time': '32:30', 'longest': '7,5'},
        'canonicalMeters': {'distance': 5000.0, 'longest': 7500.0},
        'units': 'metric',
        'step': 3,
        'canFive': true,
      };
      await mount(
        tester,
        CardioProfileScreen(provider: cardio, setupRepository: programs),
      );
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(cardioRepo.value.referenceMeters, 5000);
      expect(cardioRepo.value.longestMeters, 7500);
      expect(cardioRepo.value.referenceSeconds, 1950);
      expect(tester.takeException(), isNull);
    },
  );
}
