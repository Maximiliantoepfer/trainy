import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/progress_provider.dart';
import '../widgets/trainings_calendar.dart';
import '../widgets/filtered_exercise_progress_chart.dart';

class ProgressInsightsScreen extends StatelessWidget {
  const ProgressInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<ProgressProvider>().entries;

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
          // Exercise-Progress
          const FilteredExerciseProgressChart(),
        ],
      ),
    );
  }
}
