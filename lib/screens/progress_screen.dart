// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:trainy/widgets/weekly_activity_chart.dart';
import '../providers/progress_provider.dart';
import '../widgets/filtered_exercise_progress_chart.dart';
import '../widgets/trainings_calendar.dart';

enum TimeRange { last7Days, last30Days, last90Days, last365Days }

class ProgressScreen extends StatefulWidget {
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  TimeRange _selectedRange = TimeRange.last7Days;

  DateTime get _rangeStart {
    final now = DateTime.now();
    switch (_selectedRange) {
      case TimeRange.last7Days:
        return now.subtract(const Duration(days: 6));
      case TimeRange.last30Days:
        return now.subtract(const Duration(days: 29));
      case TimeRange.last90Days:
        return now.subtract(const Duration(days: 89));
      case TimeRange.last365Days:
        return now.subtract(const Duration(days: 364));
    }
  }

  double getAverageDuration(List<double> durations) {
    if (durations.isEmpty) return 0;
    return durations.reduce((a, b) => a + b) / durations.length;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProgressProvider>(context);
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final formatter = DateFormat('yyyy-MM-dd');

    final trainedDays =
        provider.entries
            .where(
              (e) => e.date.isAfter(monday.subtract(const Duration(days: 1))),
            )
            .map((e) => formatter.format(e.date))
            .toSet();

    final trainingsDieseWoche = trainedDays.length;
    final entriesInRange =
        provider.entries.where((e) => e.date.isAfter(_rangeStart)).toList();

    final Map<String, double> durationMap = {};
    for (var entry in entriesInRange) {
      final key = formatter.format(entry.date);
      final duration = (entry.results['durationInMinutes'] ?? 0) as int;
      durationMap.update(
        key,
        (old) => old + duration.toDouble(),
        ifAbsent: () => duration.toDouble(),
      );
    }

    final sortedKeys = durationMap.keys.toList()..sort();
    final barGroups = List.generate(sortedKeys.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: durationMap[sortedKeys[i]]!,
            width: 14,
            color: Theme.of(context).colorScheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
        ],
      );
    });

    final labels =
        sortedKeys
            .map((e) => DateFormat('E', 'de').format(DateTime.parse(e)))
            .toList();

    final averageDuration = getAverageDuration(durationMap.values.toList());

    return Scaffold(
      appBar: AppBar(title: const Text('Fortschritt')),
      body:
          provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : provider.entries.isEmpty
              ? const Center(child: Text('Noch keine Workouts abgeschlossen.'))
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    WeeklyActivityChart(
                      trainedDays: trainedDays,
                      monday: monday,
                      weeklyGoal: provider.weeklyGoal,
                      trainingsDieseWoche: trainingsDieseWoche,
                      onGoalChanged: (newGoal) {
                        provider.setWeeklyGoal(newGoal);
                      },
                    ),

                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ToggleButtons(
                        borderRadius: BorderRadius.circular(12),
                        isSelected:
                            TimeRange.values
                                .map((e) => e == _selectedRange)
                                .toList(),
                        onPressed: (index) {
                          setState(() {
                            _selectedRange = TimeRange.values[index];
                          });
                        },
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('7 T'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('30 T'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('3 M'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('1 J'),
                          ),
                        ],
                      ),
                    ),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Workout-Dauer',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Ø ${averageDuration.toStringAsFixed(1)} min',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            AspectRatio(
                              aspectRatio: 1.6,
                              child: BarChart(
                                BarChartData(
                                  barGroups: barGroups,
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        interval: 1,
                                        showTitles: true,
                                        reservedSize: 32,
                                        getTitlesWidget: (value, _) {
                                          final index = value.toInt();
                                          if (index < labels.length) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 6,
                                              ),
                                              child: Text(
                                                labels[index],
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          }
                                          return const Text('');
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        interval: 10,
                                        reservedSize: 40,
                                        getTitlesWidget: (value, _) {
                                          return Text(
                                            '${value.toInt()} min',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          );
                                        },
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
                    ),

                    // WeightProgressChart(entries: provider.entries),
                    FilteredExerciseProgressChart(entries: provider.entries),

                    const SizedBox(height: 24),
                    TrainingCalendar(entries: provider.entries),
                  ],
                ),
              ),
    );
  }
}
