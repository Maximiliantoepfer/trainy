import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/models/training_program.dart';
import 'package:trainy/themes/app_theme.dart';
import 'package:trainy/widgets/activity_day_badge.dart';
import 'package:trainy/widgets/cardio_route_view.dart';
import 'package:trainy/widgets/pill_tab_bar.dart';
import 'package:trainy/widgets/week_activity_card.dart';

void main() {
  Future<void> mount(
    WidgetTester t,
    Widget body, {
    bool dark = false,
    double scale = 1,
    String locale = 'de',
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(320, 844);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme:
            dark
                ? AppTheme.dark(const Color(0xFF0EC7FF))
                : AppTheme.light(const Color(0xFF0EC7FF)),
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder:
            (c, child) => MediaQuery(
              data: MediaQuery.of(
                c,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
        home: Scaffold(body: body),
      ),
    );
    await t.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets(
      'compact week keeps strength priority and partial progress, large text $dark',
      (t) async {
        final monday = DateTime(2030, 1, 7);
        DateTime? selected;
        final entries = [
          ProgramEntry(
            id: 'strength',
            planId: 'p',
            date: monday,
            name: 'Push',
            kind: 'strength',
          ),
          ProgramEntry(
            id: 'run',
            planId: 'p',
            date: monday,
            name: 'Easy',
            kind: 'running',
            completed: true,
          ),
        ];
        await mount(
          t,
          ListView(
            children: [
              WeekActivityCard(
                date: monday,
                entries: entries,
                onDateChanged: (d) => selected = d,
              ),
            ],
          ),
          dark: dark,
          scale: 1.8,
        );
        final day =
            t.widgetList<ActivityDayBadge>(find.byType(ActivityDayBadge)).first;
        expect(day.state.kind, 'strength');
        expect(day.state.fraction, .5);
        expect(day.state.done, false);
        await t.tap(find.text('Di'));
        expect(selected, DateTime(2030, 1, 8));
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'route stays entirely local until explicit consent; cancel and no-GPS are clear',
    (t) async {
      final samples = [
        {'latitude': 52.0, 'longitude': 13.0, 'timestamp': 0},
        {'latitude': 52.001, 'longitude': 13.001, 'timestamp': 1000},
        {'latitude': 52.002, 'longitude': 13.002, 'timestamp': 30000},
        {'latitude': 52.003, 'longitude': 13.002, 'timestamp': 31000},
      ];
      await mount(
        t,
        ListView(children: [CardioRouteView(samples: samples)]),
        scale: 1.8,
      );
      expect(find.byType(FlutterMap), findsNothing);
      final paint = t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .firstWhere((p) => p.painter is RouteTracePainter);
      expect((paint.painter as RouteTracePainter).segments.length, 2);
      await t.tap(find.text('Straßenkarte laden'));
      await t.pumpAndSettle();
      expect(find.textContaining('IP-Adresse'), findsOneWidget);
      expect(find.byType(TileLayer), findsNothing);
      await t.tap(find.text('Abbrechen'));
      await t.pumpAndSettle();
      expect(find.byType(FlutterMap), findsNothing);
      await mount(t, const CardioRouteView(samples: []));
      expect(
        find.text('Für diese Einheit sind keine GPS-Routendaten vorhanden.'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('shared pill selection supports swipe and large English labels', (
    t,
  ) async {
    await mount(
      t,
      DefaultTabController(
        length: 2,
        child: Builder(
          builder:
              (c) => Column(
                children: [
                  PillTabBar(
                    labels: const ['Workouts', 'Exercises'],
                    height: PillTabBar.heightFor(c),
                  ),
                  const Expanded(
                    child: TabBarView(
                      children: [
                        Center(child: Text('Workout content')),
                        Center(child: Text('Exercise content')),
                      ],
                    ),
                  ),
                ],
              ),
        ),
      ),
      scale: 1.8,
      locale: 'en',
    );
    await t.drag(find.byType(TabBarView), const Offset(-300, 0));
    await t.pumpAndSettle();
    expect(find.text('Exercise content'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
