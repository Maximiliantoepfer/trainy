import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:trainy/services/workout_entry_database.dart';
import 'package:trainy/models/workout_entry.dart';
import 'package:intl/intl.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  List<WorkoutEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final all = await WorkoutEntryDatabase.instance.getAllEntries();
    all.sort((a, b) => a.date.compareTo(b.date));
    setState(() {
      _entries = all;
      _isLoading = false;
    });
  }

  List<FlSpot> _buildDurationSpots() {
    return _entries.asMap().entries.map((entry) {
      final i = entry.key.toDouble();
      final duration = (entry.value.results['durationInMinutes'] ?? 0) as int;
      return FlSpot(i, duration.toDouble());
    }).toList();
  }

  List<String> _buildDateLabels() {
    final formatter = DateFormat('d. MMM');
    return _entries.map((e) => formatter.format(e.date)).toList();
  }

  LineTouchData _buildTouchData(List<String> labels) {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        //tooltipBgColor: Colors.black87,
        tooltipRoundedRadius: 8,
        getTooltipItems: (spots) {
          return spots.map((spot) {
            final index = spot.x.toInt();
            final dateLabel = index < labels.length ? labels[index] : '';
            final duration = spot.y.toInt();
            return LineTooltipItem(
              '$dateLabel\nDauer: $duration min',
              const TextStyle(color: Colors.white),
            );
          }).toList();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spots = _buildDurationSpots();
    final labels = _buildDateLabels();

    return Scaffold(
      appBar: AppBar(title: const Text('Fortschritt')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _entries.isEmpty
              ? const Center(child: Text('Noch keine Workouts abgeschlossen.'))
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Workout-Dauer (Minuten)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AspectRatio(
                          aspectRatio: 1.6,
                          child: LineChart(
                            LineChartData(
                              lineTouchData: _buildTouchData(labels),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  color: Theme.of(context).colorScheme.primary,
                                  dotData: FlDotData(show: true),
                                ),
                              ],
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, _) {
                                      final index = value.toInt();
                                      if (index < labels.length) {
                                        return Text(
                                          labels[index],
                                          style: const TextStyle(fontSize: 10),
                                        );
                                      }
                                      return const Text('');
                                    },
                                    interval: 1,
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    interval: 5,
                                  ),
                                ),
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              gridData: FlGridData(show: true),
                              borderData: FlBorderData(show: true),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}
