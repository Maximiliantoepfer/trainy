import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/models/exercise.dart';
import 'package:trainy/models/workout.dart';
import 'package:trainy/models/workout_planning.dart';
import 'package:trainy/providers/exercise_provider.dart';
import 'package:trainy/providers/workout_provider.dart';
import 'package:trainy/repositories/workout_planning_repository.dart';
import 'package:trainy/screens/workout_detail_screen.dart';
import 'package:trainy/themes/app_theme.dart';
import 'package:trainy/widgets/workout_group_editor.dart';

Exercise exercise(int id, String name) => Exercise(
  id: id,
  name: name,
  description: '',
  trackSets: true,
  trackReps: true,
  trackWeight: false,
  trackDuration: false,
  trackDistance: false,
  defaultValues: const {},
  lastValues: const {},
  units: const {},
  icon: null,
);

class Exercises extends ExerciseProvider {
  @override
  List<Exercise> get exercises => [
    exercise(1, 'Liegestütz'),
    exercise(2, 'Klimmzug'),
    for (var i = 3; i <= 22; i++) exercise(i, 'Exercise $i'),
  ];
}

class Planning extends WorkoutPlanningRepository {
  Workout workout = Workout(id: 7, name: 'Ganzkörper', canonicalId: 'workout');
  bool fail = false;
  bool failNextRead = false;
  int groupWrites = 0;
  int slotCount = 2;
  final Map<String, String> slotGroups = {};
  List<String>? reordered;
  (String, String, int?)? moved;
  List<String> groupIds = ['warmup', 'core', 'chest', 'cooldown'];
  bool emptyCore = false;
  WorkoutSetupGroup group(String id) => WorkoutSetupGroup(
    id: id,
    name: id == 'chest' ? 'Brust' : id,
    kind: switch (id) {
      'warmup' => WorkoutGroupKind.warmup,
      'core' => WorkoutGroupKind.core,
      'cooldown' => WorkoutGroupKind.cooldown,
      _ => WorkoutGroupKind.custom,
    },
    sortOrder: groupIds.indexOf(id),
    selectedVariantId: 'v:$id',
    variants: [
      WorkoutSetupGroupVariant(
        id: 'v:$id',
        name: id,
        sortOrder: 0,
        slots: [
          for (var i = 1; i <= slotCount; i++)
            if ((slotGroups['slot:$i'] ?? 'core') == id &&
                !(emptyCore && id == 'core'))
              WorkoutSetupSlot(
                id: 'slot:$i',
                exerciseId: 'e:$i',
                localExerciseId: i,
                isOptional: false,
                sortOrder: i,
              ),
        ],
      ),
    ],
  );
  @override
  Future<List<WorkoutSetup>> setupsForWorkout(String workoutId) async {
    if (failNextRead) {
      failNextRead = false;
      throw StateError('refresh failure');
    }
    return [
      for (final id in ['home', 'studio'])
        WorkoutSetup(
          id: id,
          workoutId: workoutId,
          name: id,
          isDefault: id == 'home',
          sortOrder: 0,
          groups: groupIds.map(group).toList(),
        ),
    ];
  }

  @override
  Future<List<Workout>> workouts() async => [workout];
  @override
  Future<void> updateBasics({
    required Workout workout,
    required String name,
    String? description,
    WorkoutPrimaryGoal? primaryGoal,
  }) async {
    if (fail) throw StateError('test failure');
    this.workout = workout.copyWith(name: name);
  }

  @override
  Future<void> reorderGroups(
    String workoutId,
    List<String> orderedGroupIds,
  ) async {
    groupWrites++;
    reordered = orderedGroupIds;
    groupIds = ['warmup', ...orderedGroupIds, 'cooldown'];
  }

  @override
  Future<void> moveSlotToGroup({
    required String slotId,
    required String setupId,
    required String targetGroupId,
    int? targetIndex,
  }) async {
    moved = (slotId, targetGroupId, targetIndex);
    slotGroups[slotId] = targetGroupId;
  }
}

Future<void> mount(
  WidgetTester tester,
  Planning repo, {
  String locale = 'de',
  bool dark = true,
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final workouts = WorkoutProvider(repository: repo);
  await workouts.loadWorkouts();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WorkoutProvider>.value(value: workouts),
        ChangeNotifierProvider<ExerciseProvider>(create: (_) => Exercises()),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme:
            dark
                ? AppTheme.dark(Colors.deepOrange)
                : AppTheme.light(Colors.teal),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
        home: RepaintBoundary(
          key: const ValueKey('editor-golden'),
          child: WorkoutDetailScreen(workout: repo.workout, repository: repo),
        ),
      ),
    ),
  );
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/icons/muskel.png'),
      tester.element(find.byType(WorkoutDetailScreen)),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(workouts.dispose);
}

void main() {
  testWidgets(
    'tap toggles selections, last deselection closes toolbar, X and back cancel',
    (tester) async {
      await mount(tester, Planning());
      await tester.longPress(find.text('Liegestütz'));
      await tester.pumpAndSettle();
      expect(find.text('1 Übung ausgewählt'), findsOneWidget);
      await tester.tap(find.text('Klimmzug'));
      await tester.pumpAndSettle();
      expect(find.text('2 Übungen ausgewählt'), findsOneWidget);
      await tester.tap(find.text('Liegestütz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Klimmzug'));
      await tester.pumpAndSettle();
      expect(find.text('Gruppieren'), findsNothing);
      expect(find.text('Ganzkörper'), findsOneWidget);
      await tester.longPress(find.text('Liegestütz'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Abbrechen'));
      await tester.pumpAndSettle();
      expect(find.text('Gruppieren'), findsNothing);
      await tester.longPress(find.text('Liegestütz'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Gruppieren'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('equal full widths, compact empty groups, hidden empty core', (
    tester,
  ) async {
    final repo = Planning();
    await mount(tester, repo);
    final warmup = tester.getRect(find.byKey(const ValueKey('group:warmup')));
    final core = tester.getRect(find.byKey(const ValueKey('group:core')));
    final chest = tester.getRect(find.byKey(const ValueKey('group:chest')));
    expect(warmup.width, 358);
    expect(core.width, warmup.width);
    expect(chest.width, warmup.width);
    expect(warmup.height, lessThanOrEqualTo(60));
    expect(find.text('Übungen hierher ziehen'), findsNothing);
    await expectLater(
      find.byKey(const ValueKey('editor-golden')),
      matchesGoldenFile('goldens/workout_editor_v5_dark.png'),
    );
    repo.emptyCore = true;
    await tester.pumpWidget(const SizedBox());
    await mount(tester, repo);
    expect(find.text('Kernübungen'), findsNothing);
  });

  testWidgets(
    'rename validates and refreshes title; failures retain previous name',
    (tester) async {
      final repo = Planning();
      await mount(tester, repo);
      await tester.tap(find.text('Ganzkörper'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Oberkörper');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.text('Oberkörper'), findsOneWidget);
      repo.fail = true;
      await tester.tap(find.text('Oberkörper'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Failed');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.text('Oberkörper'), findsOneWidget);
      expect(find.textContaining('Die Änderung konnte'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('handles start immediately and drop into empty warmup', (
    tester,
  ) async {
    final repo = Planning();
    await mount(tester, repo);
    final grip = find.descendant(
      of: find.byKey(const ValueKey('slot:slot:1')),
      matching: find.byIcon(Icons.drag_indicator),
    );
    final gesture = await tester.startGesture(tester.getCenter(grip));
    await gesture.moveBy(const Offset(0, -12));
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('group:warmup'))),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(repo.moved, ('slot:1', 'warmup', 0));
    expect(find.byType(WorkoutGroupEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large English text keeps actions reachable without overflow', (
    tester,
  ) async {
    await mount(tester, Planning(), locale: 'en', dark: false, scale: 2);
    await tester.ensureVisible(find.text('Liegestütz'));
    await tester.longPress(find.text('Liegestütz'));
    await tester.pumpAndSettle();
    expect(find.text('Required/Optional'), findsOneWidget);
    await expectLater(
      find.byKey(const ValueKey('editor-golden')),
      matchesGoldenFile('goldens/workout_editor_v5_light_selection.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'group handle reorders the middle while warmup and cooldown stay fixed',
    (tester) async {
      final repo = Planning();
      await mount(tester, repo);
      final handle =
          find
              .descendant(
                of: find.byKey(const ValueKey('group:core')),
                matching: find.byIcon(Icons.drag_indicator),
              )
              .first;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveBy(const Offset(0, 15));
      await tester.pump();
      final target =
          tester.getTopLeft(find.byKey(const ValueKey('group:cooldown'))) +
          const Offset(100, -12);
      await gesture.moveTo(target);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(repo.reordered, ['chest', 'core']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switching setup clears the active selection', (tester) async {
    await mount(tester, Planning());
    await tester.longPress(find.text('Liegestütz'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workoutProfileChooser')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('studio').last);
    await tester.pumpAndSettle();
    expect(find.text('Gruppieren'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'temporary core drop zone disappears after dragging from a custom group',
    (tester) async {
      final repo =
          Planning()..slotGroups.addAll({'slot:1': 'chest', 'slot:2': 'chest'});
      await mount(tester, repo);
      expect(find.text('Kernübungen'), findsNothing);
      final handle = find.descendant(
        of: find.byKey(const ValueKey('slot:slot:1')),
        matching: find.byIcon(Icons.drag_indicator),
      );
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      expect(find.text('Kernübungen'), findsOneWidget);
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('group:warmup'))),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(repo.moved, ('slot:1', 'warmup', 0));
      expect(find.text('Kernübungen'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('edge dragging scrolls long groups without a long press', (
    tester,
  ) async {
    await mount(tester, Planning()..slotCount = 22);
    final editor = tester.widget<WorkoutGroupEditor>(
      find.byType(WorkoutGroupEditor),
    );
    final handle = find.descendant(
      of: find.byKey(const ValueKey('slot:slot:1')),
      matching: find.byIcon(Icons.drag_indicator),
    );
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    await gesture.moveTo(const Offset(340, 760));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(editor.scrollController.offset, greaterThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'retry after a refresh failure does not repeat a committed edit',
    (tester) async {
      final repo = Planning();
      await mount(tester, repo);
      repo.failNextRead = true;
      final editor = tester.widget<WorkoutGroupEditor>(
        find.byType(WorkoutGroupEditor),
      );
      await editor.onReorderGroups(['chest', 'core']);
      await tester.pumpAndSettle();
      expect(repo.groupWrites, 1);
      expect(find.text('Liegestütz'), findsOneWidget);
      await tester.tap(find.text('Erneut versuchen'));
      await tester.pumpAndSettle();
      expect(repo.groupWrites, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
