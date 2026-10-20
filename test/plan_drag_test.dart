import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/models/training_program.dart';
import 'package:trainy/widgets/plan_week_block.dart';
import 'package:trainy/widgets/plan_drag_target.dart';

void main() {
  testWidgets(
    'empty-day padding accepts drop after edge autoscroll across weeks',
    (t) async {
      final monday = DateTime(2030, 1, 7);
      final e = ProgramEntry(
        id: 'a',
        planId: 'p',
        date: monday,
        kind: 'running',
        name: 'Drag',
      );
      final scroll = ScrollController();
      DateTime? dropped;
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              controller: scroll,
              children: [
                PlanDraggable(
                  entry: e,
                  enabled: true,
                  child: const SizedBox(height: 80, child: Text('Drag')),
                ),
                for (var i = 0; i < 21; i++)
                  PlanDayDropTarget(
                    day: monday.add(Duration(days: i)),
                    enabled: true,
                    onMove: (_, d) => dropped = d,
                    child: SizedBox(
                      key: ValueKey('target:$i'),
                      height: 100,
                      width: double.infinity,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Day $i'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final gesture = await t.startGesture(t.getCenter(find.text('Drag')));
      await t.pump(const Duration(milliseconds: 450));
      await gesture.moveTo(const Offset(760, 570));
      for (var i = 0; i < 70; i++) {
        await t.pump(const Duration(milliseconds: 40));
      }
      expect(scroll.offset, greaterThan(700));
      // Move off the edge to a visible empty region, far from the day's text.
      final visible =
          find.byType(PlanDayDropTarget).evaluate().where((el) {
            final box = el.renderObject as RenderBox;
            final y = box.localToGlobal(Offset.zero).dy;
            return y >= 80 && y + 100 <= 500;
          }).first;
      final target = visible.widget as PlanDayDropTarget;
      final box = visible.renderObject as RenderBox;
      await gesture.moveTo(box.localToGlobal(const Offset(760, 50)));
      await t.pump(const Duration(milliseconds: 80));
      await gesture.up();
      await t.pumpAndSettle();
      expect(dropped, target.day);
      expect(dropped!.difference(monday).inDays, greaterThanOrEqualTo(7));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      scroll.dispose();
    },
  );
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
