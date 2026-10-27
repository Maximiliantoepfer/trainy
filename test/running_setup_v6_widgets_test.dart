import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/models/running_preferences.dart';
import 'package:trainy/models/training_program.dart';
import 'package:trainy/providers/cardio_provider.dart';
import 'package:trainy/screens/running_replan_screen.dart';
import 'package:trainy/themes/app_theme.dart';
import 'package:trainy/widgets/favorite_routes_editor.dart';
import 'support/confirmed_profiles.dart';

void main() {
  for (final english in [false, true]) {
    testWidgets(
      'favorite-route editor supports names, day preferences and imperial units; en=$english',
      (t) async {
        t.view.physicalSize = const Size(320, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        var routes = <FavoriteRunningRoute>[];
        await t.pumpWidget(
          MaterialApp(
            locale: Locale(english ? 'en' : 'de'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme:
                english
                    ? AppTheme.light(Colors.cyan)
                    : AppTheme.dark(Colors.orange),
            builder:
                (c, child) => MediaQuery(
                  data: MediaQuery.of(
                    c,
                  ).copyWith(textScaler: TextScaler.linear(english ? 1.8 : 1)),
                  child: child!,
                ),
            home: Scaffold(
              body: StatefulBuilder(
                builder:
                    (c, update) => SingleChildScrollView(
                      child: FavoriteRoutesEditor(
                        routes: routes,
                        units:
                            english
                                ? DistanceSystem.imperial
                                : DistanceSystem.metric,
                        onChanged: (v) => update(() => routes = v),
                      ),
                    ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.text(english ? 'Add route' : 'Strecke hinzufügen'));
        await t.pumpAndSettle();
        await t.enterText(
          find.byType(TextFormField).first,
          english ? '2.5' : '4',
        );
        await t.enterText(find.byType(TextFormField).last, 'Park');
        final day = find.byType(FilterChip).first;
        await t.ensureVisible(day);
        await t.tap(day);
        final save = find.widgetWithText(
          FilledButton,
          english ? 'Save' : 'Speichern',
        );
        await t.ensureVisible(save);
        await t.tap(save);
        await t.pumpAndSettle();
        await t.pump(const Duration(milliseconds: 350));
        expect(routes.single.name, 'Park');
        expect(routes.single.weekdays, [1]);
        expect(routes.single.meters, closeTo(english ? 4023.36 : 4000, .001));
        expect(find.text('Park'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      'replanning starts with compact localized current answers at large text; en=$english',
      (t) async {
        t.view.physicalSize = const Size(320, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final p =
            CardioProvider()
              ..profile = confirmedRunner()
              ..loaded = true;
        addTearDown(p.dispose);
        await t.pumpWidget(
          ChangeNotifierProvider.value(
            value: p,
            child: MaterialApp(
              locale: Locale(english ? 'en' : 'de'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme:
                  english
                      ? AppTheme.light(Colors.purple)
                      : AppTheme.dark(Colors.orange),
              builder:
                  (c, child) => MediaQuery(
                    data: MediaQuery.of(
                      c,
                    ).copyWith(textScaler: const TextScaler.linear(1.8)),
                    child: child!,
                  ),
              home: RunningReplanScreen(
                plan: TrainingProgram(
                  name: 'Run',
                  start: DateTime.now(),
                  runningDays: [1, 3, 6],
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(
          find.text(english ? 'Adjust running plan' : 'Laufplan anpassen'),
          findsOneWidget,
        );
        expect(
          find.text(english ? 'Recalculate' : 'Neu berechnen'),
          findsOneWidget,
        );
        await t.drag(find.byType(ListView), const Offset(0, -1400));
        await t.pumpAndSettle();
        expect(
          t
              .widgetList<Text>(find.byType(Text))
              .where((w) => (w.data ?? '').startsWith('k_')),
          isEmpty,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}
