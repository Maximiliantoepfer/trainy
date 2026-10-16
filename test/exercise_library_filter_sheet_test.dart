import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/models/catalog_exercise.dart';
import 'package:trainy/models/training_profile.dart';
import 'package:trainy/widgets/exercise_library_filter_sheet.dart';

void main() {
  testWidgets(
    'combines label, profile and source without changing another setting',
    (tester) async {
      CatalogQuery? result;
      final now = DateTime.utc(2026);
      final profiles = [
        TrainingProfileRecord(
          id: 'home',
          name: 'Homegym',
          equipmentCodes: const {'bodyweight', 'dumbbell'},
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
        TrainingProfileRecord(
          id: 'studio',
          name: 'Studio',
          equipmentCodes: const {'barbell', 'machine', 'cable'},
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.cyan),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: FilledButton(
                    onPressed: () async {
                      result = await showExerciseLibraryFilterSheet(
                        context,
                        initialQuery: const CatalogQuery(text: 'press'),
                        profiles: profiles,
                      );
                    },
                    child: const Text('Öffnen'),
                  ),
                ),
          ),
        ),
      );

      await tester.tap(find.text('Öffnen'));
      await tester.pumpAndSettle();
      expect(find.text('Aktivitäten'), findsNothing);

      await tester.tap(find.text('Kraft'));
      await tester.tap(find.text('Studio'));
      await tester.tap(find.text('Eigen'));
      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();

      expect(result?.text, 'press');
      expect(result?.goalCode, 'strength');
      expect(result?.profileId, 'studio');
      expect(result?.availableEquipment, {'barbell', 'machine', 'cable'});
      expect(result?.source, ExerciseSourceFilter.custom);
      expect(tester.takeException(), isNull);
    },
  );
}
