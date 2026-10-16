import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/models/workout.dart';
import 'package:trainy/models/workout_plan.dart';
import 'package:trainy/models/workout_planning.dart';
import 'package:trainy/providers/active_workout_provider.dart';
import 'package:trainy/screens/workout_run_screen.dart';
import 'workout_editor_v5_widget_test.dart' show exercise;

void main() {
  testWidgets(
    'training renders localized vertical sections and keeps optional groups reachable',
    (tester) async {
      final active = ActiveWorkoutProvider();
      final exercises = [
        exercise(1, 'Warmup exercise'),
        exercise(2, 'Chest exercise'),
        exercise(3, 'Stretch'),
      ];
      final groups = [
        for (var i = 1; i <= 3; i++)
          WorkoutSessionPlanGroup(
            workoutGroupId: i,
            name: ['warmup', 'Brust', 'cooldown'][i - 1],
            kind:
                [
                  WorkoutGroupKind.warmup,
                  WorkoutGroupKind.custom,
                  WorkoutGroupKind.cooldown,
                ][i - 1],
            selectedGroupVariantId: i,
            variants: [
              WorkoutSessionPlanGroupVariant(
                id: i,
                name: 'internal',
                slots: [
                  WorkoutSessionPlanSlot(
                    id: i,
                    exerciseId: i,
                    isOptional: i == 3,
                  ),
                ],
              ),
            ],
          ),
      ];
      await tester.pumpWidget(
        ChangeNotifierProvider<ActiveWorkoutProvider>.value(
          value: active,
          child: MaterialApp(
            locale: const Locale('de'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: WorkoutRunScreen(
              workout: Workout(id: 7, name: 'Training'),
              exercises: exercises,
              allExercises: exercises,
              sessionPlanGroups: groups,
              initialSlotSelections: const {1: 1, 2: 2, 3: 3},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('core'), findsNothing);
      expect(find.text('warmup'), findsNothing);
      expect(find.text('internal'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Aufwärmen')).dy,
        lessThan(tester.getTopLeft(find.text('Warmup exercise')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Warmup exercise')).dy,
        lessThan(tester.getTopLeft(find.text('Brust')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Brust')).dy,
        lessThan(tester.getTopLeft(find.text('Chest exercise')).dy),
      );
      expect(find.text('Cooldown'), findsOneWidget);
      expect(find.text('Stretch'), findsNothing);
      expect(find.byIcon(Icons.add_task_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_task_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Stretch'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      active.dispose();
    },
  );
}
