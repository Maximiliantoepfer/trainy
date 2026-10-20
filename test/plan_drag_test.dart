import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/models/training_program.dart';
import 'package:trainy/widgets/plan_week_block.dart';
import 'package:trainy/widgets/plan_drag_target.dart';

void main() {
  testWidgets(
    'long press moves a single entry onto an occupied day and protects started entries',
    (t) async {
      final date = DateTime(2030, 1, 7);
      final entries = [
        ProgramEntry(
          id: 'a',
          planId: 'p',
          date: date,
          kind: 'strength',
          name: 'Push',
        ),
        ProgramEntry(
          id: 'b',
          planId: 'p',
          date: date.add(const Duration(days: 1)),
          kind: 'running',
          name: 'Easy',
        ),
        ProgramEntry(
          id: 'locked',
          planId: 'p',
          date: date,
          kind: 'strength',
          name: 'Started',
          sessionId: 's',
        ),
      ];
      ProgramEntry? moved;
      DateTime? target;
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: ListView(
              children: [
                PlanWeekBlock(
                  monday: date,
                  entries: entries,
                  onMove: (e, day) {
                    moved = e;
                    target = day;
                  },
                  entryBuilder:
                      (e) => PlanWorkoutTile(
                        entry: e,
                        onTap: () {},
                        units: DistanceSystem.metric,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(LongPressDraggable<ProgramEntry>), findsNWidgets(2));
      final gesture = await t.startGesture(t.getCenter(find.text('Push')));
      await t.pump(const Duration(milliseconds: 500));
      await gesture.moveTo(t.getCenter(find.text('Easy')));
      await t.pump(const Duration(milliseconds: 80));
      await gesture.up();
      await t.pumpAndSettle();
      expect(moved?.id, 'a');
      expect(target, date.add(const Duration(days: 1)));
      expect(entries.length, 3);
      expect(entries[1].date, target);
      expect(movablePlanEntry(entries.last), isFalse);
      expect(t.takeException(), isNull);
    },
  );
}
