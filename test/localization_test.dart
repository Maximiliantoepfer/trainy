import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/models/exercise.dart';
import 'package:trainy/providers/locale_provider.dart';
import 'package:trainy/utils/exercise_localization.dart';
import 'package:trainy/utils/goal_utils.dart';

void main() {
  test('German and English ARB files have identical keys and metadata', () {
    Map<String, dynamic> readArb(String path) =>
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

    final en = readArb('lib/l10n/arb/app_en.arb');
    final de = readArb('lib/l10n/arb/app_de.arb');
    expect(en.keys.toSet(), de.keys.toSet());
  });

  test('generated localizations expose German and English', () async {
    final de = await AppLocalizations.delegate.load(const Locale('de'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    expect(de.settings, 'Einstellungen');
    expect(en.settings, 'Settings');
    expect(de.standardExerciseName('kraft_bankdruecken'), 'Bankdrücken');
    expect(en.standardExerciseName('kraft_bankdruecken'), 'Bench press');
  });

  test(
    'language preference persists locally and supports system default',
    () async {
      SharedPreferences.setMockInitialValues({'app_locale': 'en'});
      final provider = LocaleProvider();
      await provider.init();
      expect(provider.preference, AppLanguagePreference.english);
      expect(provider.localeOverride, const Locale('en'));

      await provider.setPreference(AppLanguagePreference.system);
      expect(provider.localeOverride, isNull);

      expect(
        resolveAppLocale(const Locale('fr'), const [
          Locale('de'),
          Locale('en'),
        ]),
        const Locale('de'),
      );
    },
  );

  test('legacy goals normalize to language-neutral codes', () {
    expect(normalizeGoal('Kraft'), 'strength');
    expect(normalizeGoal('Mobilität'), 'mobility');
    expect(normalizeGoal('cardio'), 'cardio');
  });

  testWidgets('only bundled, unchanged exercises receive a localized name', (
    tester,
  ) async {
    const standard = Exercise(
      id: 1,
      name: 'Bankdrücken',
      description: '',
      trackSets: true,
      trackReps: true,
      trackWeight: true,
      trackDuration: false,
      trackDistance: false,
      defaultValues: {},
      lastValues: {},
      units: {},
      icon: null,
      standardKey: 'kraft_bankdruecken',
      isNameCustom: false,
    );
    const renamed = Exercise(
      id: 2,
      name: 'My bench routine',
      description: '',
      trackSets: true,
      trackReps: true,
      trackWeight: true,
      trackDuration: false,
      trackDistance: false,
      defaultValues: {},
      lastValues: {},
      units: {},
      icon: null,
      standardKey: 'kraft_bankdruecken',
      isNameCustom: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder:
              (context) => Text(
                '${displayExerciseName(context, standard)} / '
                '${displayExerciseName(context, renamed)}',
              ),
        ),
      ),
    );

    expect(find.text('Bench press / My bench routine'), findsOneWidget);
  });
}
