import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/widgets/hold_to_finish_button.dart';
import 'package:trainy/themes/app_theme.dart';

void main() {
  testWidgets(
    'finish requires three seconds from touch down, cancels on release and provides accessible confirmation',
    (tester) async {
      var finished = 0, confirmed = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppTheme.dark(Colors.orange),
          home: Scaffold(
            body: Center(
              child: HoldToFinishButton(
                onFinish: () => finished++,
                onAccessibleFinish: () => confirmed++,
              ),
            ),
          ),
        ),
      );
      final button = find.byType(HoldToFinishButton);
      var touch = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2900));
      expect(finished, 0);
      await touch.up();
      await tester.pump(const Duration(seconds: 1));
      expect(finished, 0);
      touch = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(finished, 1);
      await touch.up();
      touch = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      await touch.moveTo(Offset.zero);
      await tester.pump(const Duration(seconds: 4));
      await touch.up();
      expect(finished, 1);
      final node = tester.getSemantics(
        find.bySemanticsLabel('Training beenden'),
      );
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pump();
      expect(confirmed, 1);
      expect(finished, 1);
      semantics.dispose();
    },
  );
}
