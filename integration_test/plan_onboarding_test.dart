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

/// Real Android SQLite + complete local running setup. Android integration targets
/// build as com.example.trainy.integration, separately from the installed app.
/// Uses an isolated in-memory database as an additional guard.
/// Run via tool/test_android_integration.ps1, which prebuilds/verifies the test
/// package before Flutter captures its identity for uninstall during teardown.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
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
        await tester.enterText(
          find.byKey(const ValueKey('running-time')),
          '45',
        );
        await next();
        await choose('Normaler Trainingslauf');
        await next();
        await tester.enterText(
          find.byKey(const ValueKey('running-longest')),
          '7,5',
        );
        await next();
        await next();
        await next();
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
        expect((await cardio.repository.profile()).setupVersion, 1);
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
