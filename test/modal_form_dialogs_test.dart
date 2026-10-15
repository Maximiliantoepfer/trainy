import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/models/exercise.dart';
import 'package:trainy/widgets/modal_form_dialogs.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets(
    'text prompt validates, returns a trimmed result and tears down',
    (tester) async {
      String? result;
      await tester.pumpWidget(
        _host(
          Builder(
            builder:
                (context) => FilledButton(
                  onPressed: () async {
                    result = await showTextPromptDialog(
                      context: context,
                      title: 'Name',
                      label: 'Name',
                      submitLabel: 'Save',
                      cancelLabel: 'Cancel',
                      requiredMessage: 'Required',
                    );
                  },
                  child: const Text('Open'),
                ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('textPromptSubmit')));
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('textPromptField')),
        '  Studio  ',
      );
      await tester.tap(find.byKey(const ValueKey('textPromptSubmit')));
      await tester.pumpAndSettle();

      expect(result, 'Studio');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'text prompt supports cancel, barrier and system back repeatedly',
    (tester) async {
      var completions = 0;
      await tester.pumpWidget(
        _host(
          Builder(
            builder:
                (context) => FilledButton(
                  onPressed: () async {
                    await showTextPromptDialog(
                      context: context,
                      title: 'Name',
                      label: 'Name',
                      submitLabel: 'Save',
                      cancelLabel: 'Cancel',
                      requiredMessage: 'Required',
                    );
                    completions++;
                  },
                  child: const Text('Open'),
                ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('textPromptCancel')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(completions, 3);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('duration, number and exercise inputs return immutable values', (
    tester,
  ) async {
    Object? result;
    var mode = 0;
    const exercise = Exercise(
      id: 1,
      name: 'Run',
      description: '',
      trackSets: false,
      trackReps: true,
      trackWeight: true,
      trackDuration: true,
      trackDistance: true,
      defaultValues: {},
      lastValues: {},
      units: {},
      icon: null,
    );
    await tester.pumpWidget(
      _host(
        Builder(
          builder:
              (context) => FilledButton(
                onPressed: () async {
                  if (mode == 0) {
                    result = await showDurationInputDialog(
                      context: context,
                      title: 'Duration',
                      initialSeconds: 0,
                    );
                  } else if (mode == 1) {
                    result = await showNumberInputDialog(
                      context: context,
                      title: 'Weight',
                      label: 'kg',
                      initialValue: 10,
                      integer: false,
                    );
                  } else {
                    result = await showExerciseValueDialog(
                      context: context,
                      exercise: exercise,
                      title: 'Run',
                    );
                  }
                },
                child: const Text('Open'),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('durationMinutes')), '2');
    await tester.tap(find.byKey(const ValueKey('durationSubmit')));
    await tester.pumpAndSettle();
    expect(result, 120);

    mode = 1;
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('numberInputField')),
      '12,5',
    );
    await tester.tap(find.byKey(const ValueKey('numberInputSubmit')));
    await tester.pumpAndSettle();
    expect(result, 12.5);

    mode = 2;
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('exerciseValue_reps')),
      '8',
    );
    await tester.enterText(
      find.byKey(const ValueKey('exerciseValue_weight')),
      '42.5',
    );
    await tester.enterText(
      find.byKey(const ValueKey('exerciseValue_durationSeconds')),
      '30',
    );
    await tester.tap(find.byKey(const ValueKey('exerciseValueSubmit')));
    await tester.pumpAndSettle();
    expect(result, containsPair('duration', '30'));
    expect(result, containsPair('reps', '8'));
    expect(tester.takeException(), isNull);
  });
}
