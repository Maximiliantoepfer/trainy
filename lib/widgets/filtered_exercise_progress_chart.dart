// lib/widgets/filtered_exercise_progress_chart.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/workout_entry.dart';
import '../providers/exercise_provider.dart';

class FilteredExerciseProgressChart extends StatefulWidget {
  final List<WorkoutEntry> entries;
  const FilteredExerciseProgressChart({super.key, required this.entries});

  @override
  State<FilteredExerciseProgressChart> createState() =>
      _FilteredExerciseProgressChartState();
}

class _FilteredExerciseProgressChartState
    extends State<FilteredExerciseProgressChart> {
  int? _selectedExerciseId;

  @override
  Widget build(BuildContext context) {
    final exProvider = context.watch<ExerciseProvider>();
    final exercises = exProvider.exercises;

    final items =
        exercises
            .map((e) => DropdownMenuItem<int>(value: e.id, child: Text(e.name)))
            .toList();

    final entries = widget.entries;

    List<BarChartGroupData> groups = [];
    List<String> labels = [];

    if (_selectedExerciseId != null) {
      final fmt = DateFormat('dd.MM.');
      final data = <String, double>{};
      for (final entry in entries) {
        final results = entry.results[_selectedExerciseId!];
        if (results == null) continue;
        // Beispiel: nimmt das Feld 'Gewicht' falls vorhanden
        final valStr = results['Gewicht']?.toString();
        final val = double.tryParse(valStr ?? '') ?? 0;
        final key = fmt.format(entry.date);
        data[key] = val; // letzte Messung pro Tag überschreibt
      }
      labels = data.keys.toList();
      groups = [
        for (int i = 0; i < labels.length; i++)
          BarChartGroupData(
            x: i,
            barRods: [BarChartRodData(toY: (data[labels[i]] ?? 0))],
          ),
      ];
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Übung:'),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _selectedExerciseId,
                    hint: const Text('auswählen'),
                    items: items,
                    onChanged: (v) => setState(() => _selectedExerciseId = v),
                  ),
                ),
              ],
            ),
            if (groups.isNotEmpty)
              AspectRatio(
                aspectRatio: 1.8,
                child: BarChart(
                  BarChartData(
                    barGroups: groups,
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          interval: 1,
                          showTitles: true,
                          getTitlesWidget: (value, _) {
                            final i = value.toInt();
                            if (i < labels.length) return Text(labels[i]);
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
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
