import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/utils/goal_utils.dart';

void main() {
  Widget host(String goal) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: GoalIcon(goal, size: 20, color: Colors.teal)),
  );

  testWidgets('strength uses the established muscle-arm asset', (tester) async {
    await tester.pumpWidget(host('strength'));

    final icon = tester.widget<ImageIcon>(find.byType(ImageIcon));
    expect(icon.image, const AssetImage('assets/icons/muskel.png'));
    expect(icon.color, Colors.teal);
    expect(icon.size, 20);
  });

  testWidgets('the remaining goal icons retain their semantic symbols', (
    tester,
  ) async {
    final cases = <String, IconData>{
      'endurance': Icons.directions_run_rounded,
      'cardio': Icons.favorite_rounded,
      'mobility': Icons.self_improvement_rounded,
    };

    for (final entry in cases.entries) {
      await tester.pumpWidget(host(entry.key));
      expect(tester.widget<Icon>(find.byType(Icon)).icon, entry.value);
    }
  });

  testWidgets('goal badges include the matching semantic goal icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: goalBadge(context, 'strength', Theme.of(context).colorScheme),
          ),
        ),
      ),
    );

    expect(find.byType(ImageIcon), findsOneWidget);
    expect(find.text('Strength'), findsOneWidget);
  });
}
