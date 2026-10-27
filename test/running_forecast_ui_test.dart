import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trainy/l10n/generated/app_localizations.dart';
import 'package:trainy/models/cardio.dart';
import 'package:trainy/models/training_program.dart';
import 'package:trainy/providers/cardio_provider.dart';
import 'package:trainy/repositories/cardio_repository.dart';
import 'package:trainy/services/cardio_training.dart';
import 'package:trainy/services/running_fitness.dart';
import 'package:trainy/themes/app_theme.dart';
import 'package:trainy/widgets/plan_week_block.dart';
import 'package:trainy/widgets/running_forecast_view.dart';
import 'package:trainy/widgets/running_recommendation_card.dart';
import 'support/confirmed_profiles.dart';

class SuggestionRepository extends CardioRepository {
  late RunningAdaptationProposal proposal;
  bool accepted = false, dismissed = false;
  @override
  Future<RunningAdaptationProposal> adaptation(
    CardioTranslate t, {
    DateTime? now,
  }) async => proposal;
  @override
  Future<void> acceptAdaptation(RunningAdaptationProposal p) async {
    accepted = true;
  }

  @override
  Future<void> dismissAdaptation(RunningAdaptationProposal p) async {
    dismissed = true;
  }
}

class SuggestionProvider extends CardioProvider {
  SuggestionProvider(SuggestionRepository repo) : super(repository: repo);
  @override
  Future<void> load() async {
    recommendation = null;
    revision++;
    notifyListeners();
  }
}

void main() {
  late SuggestionRepository repo;
  late SuggestionProvider provider;
  late List<ScheduledCardioWorkout> occurrences;
  setUp(() {
    repo = SuggestionRepository();
    provider = SuggestionProvider(repo);
    final p = confirmedRunner();
    final plan = RunningPlanGenerator().generate(
      p,
      RunningPlanRequest(targetMeters: 5000, startDate: DateTime(2030, 1, 7)),
      (k) => k,
    );
    occurrences = plan.occurrences;
    provider.profile = p;
    provider.occurrences = occurrences;
    repo.proposal = RunningAdaptationProposal(
      createdAt: DateTime(2030, 1, 7),
      ruleVersion: 5,
      fitness: RunningFitnessSnapshot(asOf: DateTime(2030, 1, 7)),
      reason: 'easyPaceEvidence',
      changes: {occurrences.first.id: occurrences.first.workout},
    );
    provider.recommendation = repo.proposal;
  });
  tearDown(() => provider.dispose());
  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    bool large = false,
    bool dark = true,
  }) async {
    tester.view.physicalSize = Size(large ? 320 : 390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<CardioProvider>.value(
        value: provider,
        child: MaterialApp(
          locale: Locale(large ? 'en' : 'de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme:
              dark
                  ? AppTheme.dark(Colors.deepOrange)
                  : AppTheme.light(Colors.blue),
          builder:
              (c, w) => MediaQuery(
                data: MediaQuery.of(
                  c,
                ).copyWith(textScaler: TextScaler.linear(large ? 1.8 : 1)),
                child: w!,
              ),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final large in [false, true]) {
    testWidgets(
      'forecast navigates to a future week; readable at large=$large',
      (tester) async {
        DateTime? chosen;
        await mount(
          tester,
          RunningForecastView(
            occurrences: occurrences,
            onWeek: (v) => chosen = v,
          ),
          large: large,
          dark: !large,
        );
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
        expect(find.textContaining('intervalSession'), findsWidgets);
        final week = find.byKey(ValueKey(DateTime(2030, 1, 21)));
        await tester.ensureVisible(week);
        await tester.tap(week);
        expect(chosen, DateTime(2030, 1, 21));
        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .pixels,
          0,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'recommendation leads to preview and one confirmation; large=$large',
      (tester) async {
        await mount(
          tester,
          const RunningRecommendationCard(),
          large: large,
          dark: !large,
        );
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(repo.accepted, false);
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.ensureVisible(find.byType(ExpansionTile));
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
        expect(find.textContaining(large ? 'Current' : 'Bisher'), findsWidgets);
        final accept = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        );
        await tester.ensureVisible(accept);
        await tester.tap(accept);
        await tester.pumpAndSettle();
        expect(repo.accepted, true);
        expect(provider.recommendation, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('later dismisses without applying', (tester) async {
    await mount(tester, const RunningRecommendationCard());
    await tester.tap(find.text('Später'));
    await tester.pumpAndSettle();
    expect(repo.dismissed, true);
    expect(repo.accepted, false);
    expect(find.byType(Card), findsNothing);
  });
  testWidgets(
    'future automatic targets are provisional, locked workouts are not',
    (tester) async {
      final o = occurrences.first;
      ProgramEntry entry(bool locked) => ProgramEntry(
        id: o.id,
        planId: o.planId,
        date: o.date,
        name: o.workout.name,
        kind: 'running',
        cardio: ScheduledCardioWorkout(
          id: o.id,
          planId: o.planId,
          date: o.date,
          workout: o.workout,
          locked: locked,
        ),
      );
      await mount(
        tester,
        PlanWorkoutTile(
          entry: entry(false),
          onTap: () {},
          units: DistanceSystem.metric,
        ),
      );
      expect(find.textContaining('Pace vorläufig'), findsOneWidget);
      await mount(
        tester,
        PlanWorkoutTile(
          entry: entry(true),
          onTap: () {},
          units: DistanceSystem.imperial,
        ),
      );
      expect(find.textContaining('Pace vorläufig'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
