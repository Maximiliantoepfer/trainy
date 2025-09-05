// filtered_exercise_progress_chart.dart (NEU: Überarbeitung für exerciseId)

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/workout_entry.dart';
import '../models/workout.dart';
import '../providers/exercise_provider.dart';
import '../providers/workout_provider.dart';

class FilteredExerciseProgressChart extends StatefulWidget {
  final List<WorkoutEntry> entries;

  const FilteredExerciseProgressChart({super.key, required this.entries});

  @override
  State<FilteredExerciseProgressChart> createState() =>
      _FilteredExerciseProgressChartState();
}

class _FilteredExerciseProgressChartState
    extends State<FilteredExerciseProgressChart> {
  int? _selectedWorkoutId;
  int? _selectedExerciseId;
  String? _selectedMetric;

  @override
  Widget build(BuildContext context) {
    final workoutProvider = Provider.of<WorkoutProvider>(context);
    final exerciseProvider = Provider.of<ExerciseProvider>(context);
    final workouts = workoutProvider.workouts;
    final exercises = exerciseProvider.exercises;

    final availableWorkouts =
        workouts
            .where((w) => widget.entries.any((e) => e.workoutId == w.id))
            .toList();
    availableWorkouts.sort((a, b) => a.name.compareTo(b.name));

    if (_selectedWorkoutId == null && availableWorkouts.isNotEmpty) {
      _selectedWorkoutId = availableWorkouts.first.id;
    }

    final selectedWorkout = workouts.firstWhere(
      (w) => w.id == _selectedWorkoutId,
      orElse:
          () =>
              Workout(id: 0, name: 'Unbekannt', exercises: [], description: ''),
    );

    final workoutExerciseIds =
        selectedWorkout.exercises.map((e) => e.exerciseId).toSet().toList();
    final filteredExercises =
        exercises.where((e) => workoutExerciseIds.contains(e.id)).toList();
    filteredExercises.sort((a, b) => a.name.compareTo(b.name));

    if (_selectedExerciseId == null && filteredExercises.isNotEmpty) {
      _selectedExerciseId = filteredExercises.first.id;
    }

    final selectedExercise = exercises.firstWhere(
      (e) => e.id == _selectedExerciseId,
      orElse: () => exercises.first,
    );

    final metrics = selectedExercise.trackedFields;
    if (_selectedMetric == null && metrics.isNotEmpty) {
      _selectedMetric = metrics.first;
    }

    final relevantEntries =
        widget.entries
            .where(
              (e) =>
                  e.workoutId == _selectedWorkoutId &&
                  e.results[_selectedExerciseId] != null,
            )
            .toList();

    final chartData =
        relevantEntries.map((e) {
          final fields = e.results[_selectedExerciseId];
          double value = 0;
          if (fields is Map) {
            final fieldVal = fields?[_selectedMetric];
            if (fieldVal is num) value = fieldVal.toDouble();
            if (fieldVal is String) value = double.tryParse(fieldVal) ?? 0.0;
          }
          return {'date': e.date, 'value': value};
        }).toList();

    chartData.sort(
      (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
    );

    final spots =
        chartData.asMap().entries.map((e) {
          return FlSpot(e.key.toDouble(), e.value['value'] as double);
        }).toList();

    final labels = <int, String>{};
    for (int i = 0; i < chartData.length; i++) {
      final date = chartData[i]['date'] as DateTime;
      labels[i] = DateFormat('dd.MM.').format(date);
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trainingsverlauf',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            DropdownButton<int>(
              isExpanded: true,
              value: _selectedWorkoutId,
              items:
                  availableWorkouts
                      .map(
                        (w) =>
                            DropdownMenuItem(value: w.id, child: Text(w.name)),
                      )
                      .toList(),
              onChanged:
                  (val) => setState(() {
                    _selectedWorkoutId = val;
                    _selectedExerciseId = null;
                    _selectedMetric = null;
                  }),
            ),
            const SizedBox(height: 8),

            DropdownButton<int>(
              isExpanded: true,
              value: _selectedExerciseId,
              items:
                  filteredExercises
                      .map(
                        (e) =>
                            DropdownMenuItem(value: e.id, child: Text(e.name)),
                      )
                      .toList(),
              onChanged:
                  (val) => setState(() {
                    _selectedExerciseId = val;
                    _selectedMetric = null;
                  }),
            ),
            const SizedBox(height: 8),

            DropdownButton<String>(
              isExpanded: true,
              value: _selectedMetric,
              items:
                  metrics
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
              onChanged: (val) => setState(() => _selectedMetric = val),
            ),
            const SizedBox(height: 12),

            if (spots.isEmpty)
              const Text('Keine Daten verfügbar.')
            else
              AspectRatio(
                aspectRatio: 1.6,
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        barWidth: 3,
                        dotData: FlDotData(show: true),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, _) {
                            final index = value.toInt();
                            return Text(
                              labels[index] ?? '',
                              style: const TextStyle(fontSize: 11),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: true),
                    gridData: FlGridData(show: false),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
