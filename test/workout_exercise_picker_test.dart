import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/models/catalog_exercise.dart';
import 'package:trainy/models/exercise.dart';
import 'package:trainy/providers/exercise_provider.dart';
import 'package:trainy/services/catalog_repository.dart';
import 'package:trainy/widgets/workout_exercise_picker.dart';

class LocalExercises extends ExerciseProvider {
  @override
  List<Exercise> get exercises => [
    const Exercise(
      id: 3,
      name: 'Pushups',
      description: '',
      catalogId: 'free:Pushups',
      trackSets: true,
      trackReps: true,
      trackWeight: false,
      trackDuration: false,
      trackDistance: false,
      defaultValues: {},
      lastValues: {},
      units: {},
      icon: null,
      goalCodes: ['strength'],
    ),
    const Exercise(
      id: 4,
      name: 'Custom mobility',
      description: '',
      trackSets: false,
      trackReps: false,
      trackWeight: false,
      trackDuration: true,
      trackDistance: false,
      defaultValues: {},
      lastValues: {},
      units: {},
      icon: null,
      goalCodes: ['mobility'],
    ),
  ];
  int materializations = 0;
  @override
  Future<int> addCatalogExercise(LocalizedCatalogExercise item) async {
    materializations++;
    return 99;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    expect(await CatalogRepository.instance.load(), isTrue);
  });
  testWidgets(
    'full catalog is available, merged once, and selection stays lazy',
    (tester) async {
      final provider = LocalExercises();
      ExercisePickerResult? result;
      await tester.pumpWidget(
        ChangeNotifierProvider<ExerciseProvider>.value(
          value: provider,
          child: MaterialApp(
            locale: const Locale('de'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: TextButton(
                      onPressed: () async {
                        result =
                            await showModalBottomSheet<ExercisePickerResult>(
                              context: context,
                              isScrollControlled: true,
                              builder:
                                  (_) => const WorkoutExercisePicker(
                                    single: true,
                                    availableEquipment: {'bodyweight'},
                                  ),
                            );
                      },
                      child: const Text('Open'),
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(
        list.childrenDelegate.estimatedChildCount,
        CatalogRepository.instance.definitions.length + 1,
      );
      await tester.enterText(find.byType(TextField), 'Push-Up');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('free:Pushups')), findsOneWidget);
      expect(provider.materializations, 0);
      await tester.enterText(find.byType(TextField), 'Zottman');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('free:Zottman_Curl')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('free:Zottman_Curl')));
      await tester.pumpAndSettle();
      expect(result!.catalogIds, {'free:Zottman_Curl'});
      expect(provider.materializations, 0);
      expect(tester.takeException(), isNull);
      provider.dispose();
    },
  );

  testWidgets('label and text jointly filter custom and catalog rows', (
    tester,
  ) async {
    final provider = LocalExercises();
    await tester.pumpWidget(
      ChangeNotifierProvider<ExerciseProvider>.value(
        value: provider,
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WorkoutExercisePicker(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beweglichkeit').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Custom mobility');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('local:4')), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Liegestütz');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('free:Pushups')), findsNothing);
    // Scapular push-ups are a legitimate mobility result; normal push-ups are not.
    expect(
      find.byKey(const ValueKey('trainy:routine_scapularPushup')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    provider.dispose();
  });
}
