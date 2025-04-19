// Angepasst: Zugriff auf results['exercises'] statt results['values']

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/workout_entry.dart';
import '../models/workout.dart';
import '../models/exercise_in_workout.dart';
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
  String? _selectedExerciseName;
  String? _selectedMetric;

  @override
  Widget build(BuildContext context) {
    final workoutProvider = Provider.of<WorkoutProvider>(context);
    final workouts = workoutProvider.workouts;

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

    final exercises = selectedWorkout.exercises;
    final exerciseNames = exercises.map((e) => e.name).toSet().toList();
    exerciseNames.sort();

    if (_selectedExerciseName == null && exerciseNames.isNotEmpty) {
      _selectedExerciseName = exerciseNames.first;
    }

    final selectedExercise = exercises.firstWhere(
      (e) => e.name == _selectedExerciseName,
      orElse:
          () => ExerciseInWorkout(
            id: 0,
            workoutId: selectedWorkout.id,
            exerciseId: 0,
            name: '',
            description: '',
            trackedFields: [],
            defaultValues: {},
            units: {},
            icon: Icons.help_outline,
            position: 0,
          ),
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
                  e.results['exercises'] != null,
            )
            .map((e) {
              final exercises = e.results['exercises'];
              double value = 0;

              if (exercises is List) {
                final match = exercises.firstWhere(
                  (ex) => ex is Map && ex['name'] == _selectedExerciseName,
                  orElse: () => null,
                );

                if (match != null && match['fields'] is Map) {
                  final fields = match['fields'];
                  if (fields[_selectedMetric] is num) {
                    value = (fields[_selectedMetric] as num).toDouble();
                  } else if (fields[_selectedMetric] is String) {
                    value = double.tryParse(fields[_selectedMetric]) ?? 0.0;
                  }
                }
              }

              print(
                "📊 Entry: ${e.date} / ${_selectedExerciseName} / ${_selectedMetric} → $value",
              );
              return {'date': e.date, 'value': value};
            })
            .toList()
          ..sort(
            (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
          );

    final spots =
        relevantEntries.asMap().entries.map((e) {
          return FlSpot(e.key.toDouble(), e.value['value'] as double);
        }).toList();

    final Map<int, String> labels = {};
    for (var i = 0; i < relevantEntries.length; i++) {
      final date = relevantEntries[i]['date'] as DateTime;
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
              'Trainingsdaten',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            DropdownButton<int>(
              isExpanded: true,
              value: _selectedWorkoutId,
              items:
                  availableWorkouts.map((w) {
                    return DropdownMenuItem(value: w.id, child: Text(w.name));
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedWorkoutId = value;
                  _selectedExerciseName = null;
                  _selectedMetric = null;
                });
              },
            ),
            const SizedBox(height: 8),

            DropdownButton<String>(
              isExpanded: true,
              value: _selectedExerciseName,
              items:
                  exerciseNames
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedExerciseName = value;
                  _selectedMetric = null;
                });
              },
            ),
            const SizedBox(height: 8),

            DropdownButton<String>(
              isExpanded: true,
              value: _selectedMetric,
              items:
                  metrics
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedMetric = value;
                });
              },
            ),
            const SizedBox(height: 12),

            if (spots.isEmpty)
              const Text('Keine Daten für diese Auswahl.')
            else
              AspectRatio(
                aspectRatio: 1.6,
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        spots: spots,
                        color: Theme.of(context).colorScheme.primary,
                        barWidth: 3,
                        belowBarData: BarAreaData(show: false),
                        dotData: FlDotData(show: true),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          interval: _calculateXInterval(labels.length),
                          getTitlesWidget: (value, _) {
                            final index = value.toInt();
                            if (labels.containsKey(index)) {
                              return Text(
                                labels[index]!,
                                style: const TextStyle(fontSize: 11),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                          getTitlesWidget:
                              (value, _) => Text(
                                '${value.toInt()}',
                                style: const TextStyle(fontSize: 11),
                              ),
                        ),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: true),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _calculateXInterval(int length) {
    if (length <= 5) return 1;
    if (length <= 10) return 2;
    if (length <= 20) return 3;
    return (length / 5).roundToDouble();
  }
}
