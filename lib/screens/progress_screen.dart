// lib/screens/progress_screen.dart
// (keine tiefen Änderungen nötig – nutzt weiterhin workoutId & exerciseId)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:trainy/widgets/app_title.dart';
import 'package:trainy/widgets/weekly_activity_chart.dart';
import '../providers/progress_provider.dart';
import '../widgets/filtered_exercise_progress_chart.dart';
import '../widgets/trainings_calendar.dart';

enum TimeRange { last7Days, last30Days, last90Days, last365Days }

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  TimeRange range = TimeRange.last30Days;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ProgressProvider>().loadData());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProgressProvider>();
    final entries = provider.entries;

    final now = DateTime.now();
    final start = () {
      switch (range) {
        case TimeRange.last7Days:
          return now.subtract(const Duration(days: 7));
        case TimeRange.last30Days:
          return now.subtract(const Duration(days: 30));
        case TimeRange.last90Days:
          return now.subtract(const Duration(days: 90));
        case TimeRange.last365Days:
          return now.subtract(const Duration(days: 365));
      }
    }();

    final filtered = entries.where((e) => e.date.isAfter(start)).toList();

    // simple per-day bar chart (counts)
    final grouped = <String, int>{};
    final fmt = DateFormat('MM/dd');
    for (final e in filtered) {
      final k = fmt.format(e.date);
      grouped[k] = (grouped[k] ?? 0) + 1;
    }
    final labels = grouped.keys.toList();
    final barGroups = [
      for (int i = 0; i < labels.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [BarChartRodData(toY: (grouped[labels[i]] ?? 0).toDouble())],
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const AppTitle('Progress', icon: Icons.show_chart_outlined),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Text('Zeitraum:'),
              const SizedBox(width: 12),
              DropdownButton<TimeRange>(
                value: range,
                onChanged: (v) => setState(() => range = v ?? range),
                items:
                    TimeRange.values
                        .map(
                          (r) =>
                              DropdownMenuItem(value: r, child: Text(r.name)),
                        )
                        .toList(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (labels.isNotEmpty)
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
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(labels[index]),
                            );
                          }
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
          const SizedBox(height: 16),
          TrainingCalendar(entries: entries),
          const SizedBox(height: 16),
          FilteredExerciseProgressChart(entries: entries),
        ],
      ),
    );
  }
}
