import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trainy/providers/locale_provider.dart';
import 'package:trainy/widgets/language_preference_picker.dart';

void main() {
  testWidgets('language values stay short and neutral on a wide control', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            child: LanguagePreferencePicker(
              preference: AppLanguagePreference.system,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('System'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('language values use a single-line dropdown when narrow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: LanguagePreferencePicker(
              preference: AppLanguagePreference.german,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byType(DropdownButtonFormField<AppLanguagePreference>),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
