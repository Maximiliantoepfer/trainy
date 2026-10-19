import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/providers/cardio_provider.dart';
import 'package:trainy/screens/cardio_screen.dart';
import 'package:trainy/screens/cardio_editor_screen.dart';
import 'package:trainy/screens/cardio_session_screen.dart';
import 'package:trainy/themes/app_theme.dart';

Future<void> mount(
  WidgetTester tester,
  Widget child, {
  String locale = 'de',
  double scale = 1,
  CardioProvider? provider,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final p = provider ?? (CardioProvider()..loaded = true);
  addTearDown(p.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: p,
      child: MaterialApp(
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme:
            (() {
              final theme = AppTheme.light(Colors.cyan);
              TextStyle? font(TextStyle? style) =>
                  style?.copyWith(fontFamily: 'Roboto');
              ButtonStyle? button(ButtonStyle? style) => style?.copyWith(
                textStyle: WidgetStateProperty.resolveWith(
                  (states) => font(style.textStyle?.resolve(states)),
                ),
              );
              return theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
                appBarTheme: theme.appBarTheme.copyWith(
                  titleTextStyle: font(theme.appBarTheme.titleTextStyle),
                ),
                tabBarTheme: theme.tabBarTheme.copyWith(
                  labelStyle: const TextStyle(fontFamily: 'Roboto'),
                  unselectedLabelStyle: const TextStyle(fontFamily: 'Roboto'),
                ),
                chipTheme: theme.chipTheme.copyWith(
                  labelStyle: font(theme.chipTheme.labelStyle),
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: button(theme.filledButtonTheme.style),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: button(theme.outlinedButtonTheme.style),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: button(theme.textButtonTheme.style),
                ),
              );
            })(),
        builder:
            (ctx, child) => MediaQuery(
              data: MediaQuery.of(
                ctx,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
        home: RepaintBoundary(
          key: const ValueKey('cardio-golden'),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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
  testWidgets(
    'local library renders templates without requesting permissions or a network',
    (tester) async {
      await mount(tester, const CardioScreen());
      expect(find.text('Ausdauer'), findsOneWidget);
      expect(find.byType(Tab), findsNWidgets(3));
      expect(find.text('k_templates'), findsNothing);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('cardio-golden')),
        matchesGoldenFile('goldens/cardio_library.png'),
      );
    },
  );
  testWidgets(
    'step editing fits large English text and supports imperial units',
    (tester) async {
      await mount(
        tester,
        CardioStepScreen(
          step: CardioStep(
            goal: StepGoal.distance,
            amount: 1609.344,
            minSpeed: 1609.344 / 480,
            maxSpeed: 1609.344 / 420,
          ),
          units: DistanceSystem.imperial,
          sport: CardioSport.running,
        ),
        locale: 'en',
        scale: 1.8,
      );
      expect(find.text('mi'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -1600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('active session exposes safe finish and large offline metrics', (
    tester,
  ) async {
    final p = CardioProvider()..loaded = true;
    p.runtime = {
      'sessionId': 'test',
      'status': 'active',
      'name': 'Easy run',
      'sport': 'running',
      'indoor': false,
      'gps': 'gpsReady',
      'index': 0,
      'steps': [
        {
          ...CardioStep(
            id: 'one',
            amount: 300,
            minSpeed: 2,
            maxSpeed: 2.5,
          ).toJson(),
          'displayName': 'Easy run',
        },
      ],
      'stepSeconds': 60.0,
      'stepMeters': 120.0,
      'activeSeconds': 60.0,
      'distanceMeters': 120.0,
      'speed': 2.0,
    };
    await mount(tester, const CardioSessionScreen(), locale: 'en', provider: p);
    expect(find.text('4:00'), findsOneWidget);
    expect(find.text('8:20 /km'), findsWidgets);
    await expectLater(
      find.byKey(const ValueKey('cardio-golden')),
      matchesGoldenFile('goldens/cardio_live.png'),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'missing clips render local instructions and do not auto-start routine',
    (tester) async {
      await mount(
        tester,
        const CardioRoutinePlayer(
          steps: [RoutineStep('ankleRocks')],
          cooling: false,
        ),
      );
      expect(find.text('0:30'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('0:30'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'custom routine validates fields and retains the edited instruction',
    (tester) async {
      await mount(
        tester,
        const CardioRoutineEditor(
          steps: [
            RoutineStep(
              'custom',
              customName: 'My mobility',
              instructions: 'Move gently.',
            ),
          ],
          cooling: false,
        ),
      );
      await tester.tap(find.text('My mobility'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('routineName')), '');
      await tester.enterText(
        find.byKey(const ValueKey('routineDuration')),
        '0',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Move gently.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('routineName')),
        'Daily mobility',
      );
      await tester.enterText(
        find.byKey(const ValueKey('routineDuration')),
        '45',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Daily mobility'), findsOneWidget);
      expect(find.text('0:45'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
