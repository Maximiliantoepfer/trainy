import 'package:trainy/screens/strength_profile_screen.dart';
import 'package:trainy/services/catalog_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/providers/active_workout_provider.dart';
import 'package:trainy/providers/cardio_provider.dart';
import 'package:trainy/providers/training_program_provider.dart';
import 'package:trainy/providers/workout_provider.dart';
import 'package:trainy/providers/progress_provider.dart';
import 'package:trainy/repositories/cardio_repository.dart';
import 'package:trainy/repositories/training_program_repository.dart';
import 'package:trainy/repositories/workout_planning_repository.dart';
import 'package:trainy/screens/cardio_profile_screen.dart';
import 'package:trainy/screens/plan_home_screen.dart';
import 'package:trainy/screens/training_plan_setup_screen.dart';
import 'package:trainy/services/app_database.dart';
import 'package:trainy/services/database_service.dart';
import 'package:trainy/themes/app_theme.dart';
import 'package:trainy/providers/training_profile_provider.dart';
import 'package:trainy/repositories/training_profile_repository.dart';
import 'package:trainy/services/data_lifecycle_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/models/running_preferences.dart';
import 'package:trainy/services/cardio_training.dart';
import 'package:trainy/services/cardio_health_service.dart';
import 'package:trainy/widgets/running_recommendation_card.dart';
import 'package:trainy/widgets/running_forecast_view.dart';

/// Real Android SQLite + complete local running setup. Android integration targets
/// build as com.example.trainy.integration, separately from the installed app.
/// Uses an isolated in-memory database as an additional guard.
/// Run via tool/test_android_integration.ps1, which prebuilds/verifies the test
/// package before Flutter captures its identity for uninstall during teardown.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'future forecast and accepted Health evidence lead to a single confirmed update',
    (tester) async {
      final db = await AppDatabase.instance.openIsolated(inMemoryDatabasePath);
      final repo = CardioRepository(database: DatabaseService(database: db));
      final provider = CardioProvider(repository: repo);
      final now = DateTime.now();
      final profile = AthleteRunningProfile(
        referenceSeconds: 2700,
        continuousMinutes: 45,
        recentRunsPerWeek: 3,
        level: RunningLevel.beginner,
        experienceMonths: 2,
        referenceKind: 'normal',
        setupVersion: 1,
        weekdays: const [2, 4, 6],
        confirmedAnswers: const {
          'goal',
          'complaints',
          'weeklyMinutes',
          'desiredDays',
          'availableDays',
          'minutesPerSession',
          'hardTrainingDays',
          'routePreference',
          'walkBreaks',
          'audio',
          'level',
          'experience',
          'continuous',
          'frequency',
          'volume',
          'reference',
          'referenceKind',
        },
        planning: const RunningPreferences(
          goal: 'runFaster',
          complaints: 'none',
          desiredDays: 3,
          minutesPerSession: 60,
          hardTrainingDays: [5],
          routePreference: 'time',
          walkBreaks: true,
          audio: true,
        ),
      );
      try {
        await repo.saveProfile(profile);
        final plan = RunningPlanGenerator().generate(
          profile,
          RunningPlanRequest(targetMeters: 5000, startDate: now),
          (key) => key,
        );
        await repo.savePlan(plan, 'Forecast integration');
        final health = CardioHealthService(repo);
        for (final day in [1, 3, 5]) {
          final start =
              now.subtract(Duration(days: day)).millisecondsSinceEpoch;
          await health.accept({
            'provider': 'health_connect',
            'externalId': 'fixture-$day',
            'sourceId': 'integration.fixture',
            'sport': 'running',
            'start': start,
            'end': start + 1800000,
            'distance': 3420,
            'indoor': false,
          }, name: 'Test run');
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
        await provider.load();
        expect(provider.recommendation?.reason, 'easyPaceEvidence');
        expect(provider.recommendation!.fitness.easySourceIds, hasLength(3));
        await tester.pumpWidget(
          ChangeNotifierProvider<CardioProvider>.value(
            value: provider,
            child: MaterialApp(
              locale: const Locale('de'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                body: ListView(
                  children: [
                    const RunningRecommendationCard(),
                    RunningForecastView(occurrences: provider.occurrences),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Deine nächsten Wochen'));
        await tester.pumpAndSettle();
        expect(find.textContaining('intervalSession'), findsWidgets);
        await tester.ensureVisible(find.text('Vorschlag ansehen'));
        await tester.tap(find.text('Vorschlag ansehen'));
        await tester.pumpAndSettle();
        expect((await repo.profile()).planning.adaptationHistory, isEmpty);
        final accept = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        );
        await tester.tap(accept);
        await tester.pumpAndSettle();
        expect((await repo.profile()).planning.adaptationHistory, hasLength(1));
        expect(
          (await repo.occurrences()).map((o) => o.id),
          plan.occurrences.map((o) => o.id),
        );
        expect(provider.recommendation, isNull);
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        provider.dispose();
        await db.close();
      }
    },
  );
  testWidgets(
    'isolated Android local reset drains polling and retains visual settings',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('test_visual_accent', 'orange');
      final db = await AppDatabase.instance.database;
      await db.insert('workouts', {
        'name': 'Disposable reset fixture',
        'description': '',
      });
      final polling = CardioProvider();
      await polling.initialize();
      try {
        await DataLifecycleCoordinator.instance.resetLocalTrainingData();
        expect(
          await (await AppDatabase.instance.database).query('workouts'),
          isEmpty,
        );
        expect(prefs.getString('test_visual_accent'), 'orange');
        await DataLifecycleCoordinator.instance.resetLocalTrainingData();
        await AppDatabase.instance.assertIntegrity();
      } finally {
        polling.dispose();
        await AppDatabase.instance.close();
        await prefs.remove('test_visual_accent');
      }
    },
  );
  testWidgets(
    'offline plan setup persists profile, activates shared plan and returns home',
    (tester) async {
      final db = await AppDatabase.instance.openIsolated(inMemoryDatabasePath);
      final database = DatabaseService(database: db);
      final repo = TrainingProgramRepository(database: database);
      final plans = TrainingProgramProvider(repository: repo);
      final cardio = CardioProvider(
        repository: CardioRepository(database: database),
      );
      final workouts = WorkoutProvider(
        repository: WorkoutPlanningRepository(database: database),
      );
      final active = ActiveWorkoutProvider();
      try {
        await plans.load();
        await cardio.load();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: plans),
              ChangeNotifierProvider.value(value: cardio),
              ChangeNotifierProvider.value(value: workouts),
              ChangeNotifierProvider.value(value: active),
              ChangeNotifierProvider(create: (_) => ProgressProvider()),
              ChangeNotifierProvider(
                create:
                    (_) => TrainingProfileProvider(
                      store: TrainingProfileRepository(database: database),
                    ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(const Color(0xFF0EC7FF)),
              locale: const Locale('de'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const PlanHomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Trainingsplan erstellen'));
        await tester.tap(find.text('Trainingsplan erstellen'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Laufen'));
        await tester.tap(find.text('Weiter'));
        await tester.pumpAndSettle();
        expect(find.byType(CardioProfileScreen), findsOneWidget);
        Future<void> next() async {
          await tester.tap(find.text('Weiter'));
          await tester.pumpAndSettle();
        }

        Future<void> choose(String text) async {
          await Scrollable.ensureVisible(
            tester.element(find.text(text).first),
            alignment: .5,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(text).first);
        }

        await choose('Tempo verbessern');
        await next();
        await choose('Keine');
        await next();
        await choose('Anfänger');
        await next();
        await choose('Weniger als 6 Monate');
        await next();
        await tester.enterText(
          find.byKey(const ValueKey('running-continuous')),
          '45',
        );
        await next();
        await choose('2');
        await next();
        await choose('Weiß ich nicht');
        await next();
        await next(); // optional longest run, one question
        await choose('3');
        await next();
        await next(); // available days
        await tester.enterText(
          find.byKey(const ValueKey('minutesPerSession')),
          '45',
        );
        await next();
        await choose('Nein');
        await next();
        await next(); // other training
        await tester.enterText(
          find.byKey(const ValueKey('running-time')),
          '45',
        );
        await next();
        await choose('Normaler Trainingslauf');
        await next();
        await next();
        await next();
        await next(); // pulse source
        await choose('Karvonen-Schätzung');
        await next();
        await next(); // optional favorite routes; no walk-break/audio questions
        await tester.tap(find.text('Profil bestätigen'));
        await tester.pumpAndSettle();
        expect(find.byType(CardioProfileScreen), findsNothing);
        expect(find.byType(TrainingPlanSetupScreen), findsOneWidget);
        await tester.tap(find.text('Weiter'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).first,
          'Offline 5 km',
        );
        await tester.tap(find.text('Plan verwenden'));
        await tester.pumpAndSettle();
        expect(find.byType(TrainingPlanSetupScreen), findsNothing);
        expect(find.text('Offline 5 km'), findsOneWidget);
        expect(plans.active?.name, 'Offline 5 km');
        expect((await cardio.repository.profile()).referenceSeconds, 2700);
        expect((await cardio.repository.profile()).setupVersion, 3);
        expect((await cardio.repository.profile()).canRunFiveKm, true);
        expect((await cardio.repository.occurrences()).length, greaterThan(15));
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        plans.dispose();
        cardio.dispose();
        workouts.dispose();
        active.dispose();
        await db.close();
      }
    },
  );
  testWidgets(
    'strength proposal activates complete workouts and running is explicitly deferred',
    (tester) async {
      final db = await AppDatabase.instance.openIsolated(inMemoryDatabasePath);
      final database = DatabaseService(database: db);
      final repo = TrainingProgramRepository(database: database);
      final plans = TrainingProgramProvider(repository: repo);
      final cardio = CardioProvider(
        repository: CardioRepository(database: database),
      );
      final workouts = WorkoutProvider(
        repository: WorkoutPlanningRepository(database: database),
      );
      final active = ActiveWorkoutProvider();
      final profiles = TrainingProfileProvider(
        store: TrainingProfileRepository(database: database),
      );
      try {
        await plans.load();
        await cardio.load();
        await profiles.reload();
        expect(await CatalogRepository.instance.load(), isTrue);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: plans),
              ChangeNotifierProvider.value(value: cardio),
              ChangeNotifierProvider.value(value: workouts),
              ChangeNotifierProvider.value(value: active),
              ChangeNotifierProvider.value(value: profiles),
              ChangeNotifierProvider(create: (_) => ProgressProvider()),
            ],
            child: MaterialApp(
              theme: AppTheme.dark(const Color(0xFFFF5722)),
              locale: const Locale('de'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const PlanHomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> tap(String label) async {
          await tester.ensureVisible(find.text(label).first);
          await tester.tap(find.text(label).first);
          await tester.pumpAndSettle();
        }

        await tap('Trainingsplan erstellen');
        await tap('Kraft');
        await tap('Laufen');
        await tap('Weiter');
        expect(find.byType(StrengthProfileScreen), findsOneWidget);
        await tap('Anfänger');
        await tap('Weiter');
        await tap('Fit bleiben');
        await tap('Weiter');
        await tap('Gym');
        await tap('Weiter');
        await tap('Profil bestätigen');
        expect((await repo.userProfile()).strengthSetupVersion, 2);
        await tap('Weiter');
        await tap('60 min');
        await tap('Weiter');
        await tap('Weiter');
        expect(find.byType(CardioProfileScreen), findsNothing);
        for (var i = 0; i < 3; i++) {
          await tap('Workout prüfen');
          await tap('Workout bestätigen');
        }
        await tap('Weiter');
        expect(find.text('Dein Kraftplan ist vorbereitet.'), findsOneWidget);
        expect(find.byType(CardioProfileScreen), findsNothing);
        await tap('Jetzt ohne Laufen fortfahren');
        await tester.enterText(
          find.byType(TextFormField).first,
          'Kraft komplett',
        );
        await tap('Plan verwenden');
        for (
          var i = 0;
          i < 150 && find.byType(TrainingPlanSetupScreen).evaluate().isNotEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpAndSettle();
        expect(find.byType(TrainingPlanSetupScreen), findsNothing);
        expect(plans.active?.name, 'Kraft komplett');
        expect(plans.active!.hasRunning, isFalse);
        expect(workouts.workouts.length, 3);
        for (final slot in plans.active!.currentSlots) {
          expect(slot.workoutId, isNotNull);
          final setups = await WorkoutPlanningRepository(
            database: database,
          ).setupsForWorkout(slot.workoutId!);
          expect(setups.single.exerciseCount, greaterThan(2));
        }
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        plans.dispose();
        cardio.dispose();
        workouts.dispose();
        active.dispose();
        profiles.dispose();
        await db.close();
      }
    },
  );
}
