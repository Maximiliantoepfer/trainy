import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/models/workout_plan.dart';
import 'package:trainy/widgets/training_profile_settings_card.dart';

Widget _host({
  required TrainingProfileLoader loader,
  required TrainingProfileSaver saver,
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
  Widget? trigger,
}) {
  return MaterialApp(
    locale: locale,
    themeMode: themeMode,
    theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
    darkTheme: ThemeData(
      colorSchemeSeed: Colors.orange,
      brightness: Brightness.dark,
      useMaterial3: true,
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder:
        (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
    home: Scaffold(
      body: Column(
        children: [
          TrainingProfileSettingsCard(
            key: const ValueKey('profileCard'),
            loadProfiles: loader,
            saveProfile: saver,
            idFactory: () => 99,
          ),
          if (trigger != null) trigger,
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('profile flow saves after teardown and refreshes exactly once', (
    tester,
  ) async {
    final profiles = <TrainingProfile>[];
    var loads = 0;
    var saves = 0;
    Future<List<TrainingProfile>> loader() async {
      loads++;
      return List.of(profiles);
    }

    Future<void> saver(TrainingProfile profile) async {
      saves++;
      profiles.add(profile);
    }

    await tester.pumpWidget(_host(loader: loader, saver: saver));
    await tester.pumpAndSettle();
    expect(loads, 1);

    await tester.tap(find.byKey(const ValueKey('addTrainingProfile')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('trainingProfileName')),
      'Studio',
    );
    await tester.tap(
      find.byKey(const ValueKey('trainingProfileEquipment_dumbbell')),
    );
    await tester.tap(find.byKey(const ValueKey('trainingProfileSubmit')));
    await tester.pumpAndSettle();

    expect(saves, 1);
    expect(loads, 2);
    expect(profiles.single.name, 'Studio');
    expect(profiles.single.equipmentCodes, contains('dumbbell'));
    expect(find.text('Studio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('parent rebuilds do not repeat the profile query', (
    tester,
  ) async {
    var loads = 0;
    Future<List<TrainingProfile>> loader() async {
      loads++;
      return const [];
    }

    Future<void> saver(TrainingProfile _) async {}
    late StateSetter rebuild;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return _host(
            loader: loader,
            saver: saver,
            trigger: const Text('parent'),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(loads, 1);

    rebuild(() {});
    await tester.pumpAndSettle();
    expect(loads, 1);
  });

  testWidgets('profile dialog supports cancel, barrier and Android back', (
    tester,
  ) async {
    var saves = 0;
    Future<List<TrainingProfile>> loader() async => const [];
    Future<void> saver(TrainingProfile _) async => saves++;
    await tester.pumpWidget(_host(loader: loader, saver: saver));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('addTrainingProfile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trainingProfileCancel')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('addTrainingProfile')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('addTrainingProfile')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(saves, 0);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'profile card remains usable in German, dark mode and large text',
    (tester) async {
      await tester.pumpWidget(
        _host(
          loader: () async => const [],
          saver: (_) async {},
          locale: const Locale('de'),
          themeMode: ThemeMode.dark,
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('addTrainingProfile')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('trainingProfileName')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
