import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout_entry.dart';
import '../providers/progress_provider.dart';
import '../providers/exercise_provider.dart';
import '../widgets/trainings_calendar.dart';
import '../widgets/filtered_exercise_progress_chart.dart';
import '../widgets/pinned_chart_card.dart';
import '../widgets/chart_data_builder.dart';

class ProgressInsightsScreen extends StatelessWidget {
  const ProgressInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProgressProvider>();
    final entries = provider.entries;
    final pinnedCharts = provider.pinnedCharts;
    final allExercises = context.watch<ExerciseProvider>().exercises;

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // Trainingskalender
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: TrainingsCalendar(entries: entries),
            ),
          ),
          const SizedBox(height: 12),
          // Empfehlung immer oben
          Builder(builder: (context) {
            final rec = _findRecommendation(entries, allExercises);
            if (rec == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PinnedChartCard(
                isRecommendation: true,
                recommendedExerciseId: rec.$1,
                recommendedMetric: rec.$2,
              ),
            );
          }),
          // Gepinnte Charts (Drag & Drop sortierbar)
          if (pinnedCharts.isNotEmpty)
            _buildReorderablePinnedCharts(context, pinnedCharts, provider),
          // Exercise-Progress
          const FilteredExerciseProgressChart(),
        ],
      ),
    );
  }

  Widget _buildReorderablePinnedCharts(
    BuildContext context,
    List<dynamic> pinnedCharts,
    ProgressProvider provider,
  ) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: pinnedCharts.length,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(animation.value);
            final elevation = 4.0 * t;
            final scale = 1.0 + 0.02 * t;
            return Transform.scale(
              scale: scale,
              child: Material(
                elevation: elevation,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      onReorder: (oldIndex, newIndex) {
        provider.reorderPinnedCharts(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final pc = pinnedCharts[index];
        return Padding(
          key: ValueKey(pc.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: PinnedChartCard(pinnedChart: pc),
        );
      },
    );
  }

  (int, String)? _findRecommendation(
    List<WorkoutEntry> entries,
    List<dynamic> exercises,
  ) {
    if (entries.isEmpty || exercises.isEmpty) return null;

    final counts = <int, int>{};
    for (final entry in entries) {
      for (final exId in entry.results.keys) {
        counts[exId] = (counts[exId] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topExId = sorted.first.key;
    final exercise = exercises.cast<dynamic>().firstWhere(
      (ex) => ex.id == topExId,
      orElse: () => null,
    );
    if (exercise == null) return null;

    final metric = defaultMetricForExercise(
      trackSets: exercise.trackSets as bool,
      trackReps: exercise.trackReps as bool,
      trackWeight: exercise.trackWeight as bool,
      trackDuration: exercise.trackDuration as bool,
      trackDistance: exercise.trackDistance as bool,
    );

    return (topExId, metric);
  }
}
