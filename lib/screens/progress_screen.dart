// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/progress_provider.dart';

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
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Aktivität diese Woche',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children:
                                  days.map((date) {
                                    final weekday = DateFormat.E(
                                      'de',
                                    ).format(date).substring(0, 2);
                                    final isTrained = trainedDays.contains(
                                      formatter.format(date),
                                    );
                                    return CircleAvatar(
                                      backgroundColor:
                                          isTrained
                                              ? Colors.green
                                              : Colors.grey[800],
                                      radius: 20,
                                      child:
                                          isTrained
                                              ? const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 20,
                                              )
                                              : Text(
                                                weekday,
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 2,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 10,
                                      ),
                                    ),
                                    child: Slider(
                                      value: provider.weeklyGoal.toDouble(),
                                      min: 1,
                                      max: 7,
                                      divisions: 6,
                                      activeColor:
                                          Theme.of(context).colorScheme.primary,
                                      inactiveColor: Colors.grey,
                                      onChanged: (value) {
                                        provider.setWeeklyGoal(value.round());
                                      },
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color:
                                          trainingsDieseWoche >=
                                                  provider.weeklyGoal
                                              ? Colors.green
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.3),
                                      width: 2,
                                    ),
                                    color: Colors.transparent,
                                    //borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    trainingsDieseWoche >= provider.weeklyGoal
                                        ? '🎯'
                                        : '🚫',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: (trainingsDieseWoche / provider.weeklyGoal)
                                  .clamp(0.0, 1.0),
                              backgroundColor: Colors.grey[800],
                              color: Theme.of(context).colorScheme.primary,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        ),
                      ),
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
                  ],
                ),
              ),
    );
  }
}
