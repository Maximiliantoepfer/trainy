import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/models/training_profile.dart';
import 'package:trainy/widgets/training_profile_settings_card.dart';

class _FakeProfileStore implements TrainingProfileStore {
  final List<TrainingProfileRecord> values = [];
  String? selected;
  int loads = 0;
  int saves = 0;

  @override
  Future<void> archive(String profileId) async {
    final index = values.indexWhere((value) => value.id == profileId);
    values[index] = values[index].copyWith(isArchived: true);
    if (selected == profileId) selected = null;
  }

  @override
  Future<List<TrainingProfileRecord>> profiles({
    bool includeArchived = false,
  }) async {
    loads++;
    return values
        .where((value) => includeArchived || !value.isArchived)
        .toList();
  }

  @override
  Future<void> save(TrainingProfileRecord profile) async {
    saves++;
    final index = values.indexWhere((value) => value.id == profile.id);
    if (index < 0) {
      values.add(profile);
    } else {
      values[index] = profile;
    }
  }

  @override
  Future<void> select(String? profileId) async => selected = profileId;

  @override
  Future<String?> selectedProfileId() async => selected;
}

Widget _host({
  required TrainingProfileStore store,
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
  Widget? trigger,
}) => MaterialApp(
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
    body: SingleChildScrollView(
      child: Column(
        children: [
          TrainingProfileSettingsCard(
            key: const ValueKey('profileCard'),
            store: store,
          ),
          if (trigger != null) trigger,
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('profile flow saves after teardown and refreshes exactly once', (
    tester,
  ) async {
    final store = _FakeProfileStore();
    await tester.pumpWidget(_host(store: store));
    await tester.pumpAndSettle();
    expect(store.loads, 1);

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

    expect(store.saves, 1);
    expect(store.loads, 2);
    expect(store.values.single.name, 'Studio');
    expect(store.values.single.equipmentCodes, contains('dumbbell'));
    expect(store.selected, store.values.single.id);
    expect(find.text('Studio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('parent rebuilds do not repeat the profile query', (
    tester,
  ) async {
    final store = _FakeProfileStore();
    late StateSetter rebuild;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return _host(store: store, trigger: const Text('parent'));
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(store.loads, 1);

    rebuild(() {});
    await tester.pumpAndSettle();
    expect(store.loads, 1);
  });

  testWidgets('profile dialog supports cancel, barrier and Android back', (
    tester,
  ) async {
    final store = _FakeProfileStore();
    await tester.pumpWidget(_host(store: store));
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

    expect(store.saves, 0);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'profile card remains usable in German, dark mode and large text',
    (tester) async {
      await tester.pumpWidget(
        _host(
          store: _FakeProfileStore(),
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
