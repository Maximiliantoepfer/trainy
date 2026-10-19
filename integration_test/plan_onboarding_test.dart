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
        await tester.tap(find.text('Trainingsplan erstellen'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilterChip, 'Kraft'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Laufen'));
        await tester.tap(find.text('Weiter'));
        await tester.pumpAndSettle();
        expect(find.byType(CardioProfileScreen), findsOneWidget);
        await tester.tap(find.text('Anfänger'));
        await tester.ensureVisible(find.text('Ja'));
        await tester.tap(find.text('Ja'));
        await tester.tap(find.text('Weiter'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(1), '32:30');
        await tester.tap(find.text('Weiter'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, '7,5');
        await tester.ensureVisible(find.text('2'));
        await tester.tap(find.text('2'));
        await tester.tap(find.text('Weiter'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Speichern'));
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
        expect((await cardio.repository.profile()).referenceSeconds, 1950);
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
}
