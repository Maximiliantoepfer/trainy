import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:trainy/services/workout_entry_database.dart';
import 'package:trainy/models/workout_entry.dart';

enum TimeRange { last7Days, last30Days, last90Days, last365Days }

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  List<WorkoutEntry> _allEntries = [];
  bool _isLoading = true;
  TimeRange _selectedRange = TimeRange.last7Days;
  int _weeklyGoal = 2;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final all = await WorkoutEntryDatabase.instance.getAllEntries();
    all.sort((a, b) => a.date.compareTo(b.date));
    setState(() {
      _allEntries = all;
      _isLoading = false;
    });
  }

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

  List<WorkoutEntry> get _filteredEntries =>
      _allEntries.where((e) => e.date.isAfter(_rangeStart)).toList();

  List<BarChartGroupData> _buildBarGroups() {
    final formatter = DateFormat('yyyy-MM-dd');
    final map = <String, double>{};

    for (var entry in _filteredEntries) {
      final key = formatter.format(entry.date);
      final duration = (entry.results['durationInMinutes'] ?? 0) as int;
      map.update(
        key,
        (old) => old + duration,
        ifAbsent: () => duration.toDouble(),
      );
    }

    final sortedKeys = map.keys.toList()..sort();

    return List.generate(sortedKeys.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: map[sortedKeys[i]]!,
            width: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      );
    });
  }

  List<String> get _barLabels {
    final formatter = DateFormat('d.M.');
    return _filteredEntries
        .map((e) => formatter.format(e.date))
        .toSet()
        .toList()
      ..sort();
  }

  Widget _buildModernDropdown() {
    return InputDecorator(
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TimeRange>(
          value: _selectedRange,
          isExpanded: true,
          onChanged: (newRange) {
            setState(() {
              _selectedRange = newRange!;
            });
          },
          items: const [
            DropdownMenuItem(
              value: TimeRange.last7Days,
              child: Text('Letzte 7 Tage'),
            ),
            DropdownMenuItem(
              value: TimeRange.last30Days,
              child: Text('Letzte 30 Tage'),
            ),
            DropdownMenuItem(
              value: TimeRange.last90Days,
              child: Text('Letzte 3 Monate'),
            ),
            DropdownMenuItem(
              value: TimeRange.last365Days,
              child: Text('Letztes Jahr'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyTracker() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final formatter = DateFormat('yyyy-MM-dd');

    final trainedDays =
        _allEntries
            .where(
              (e) => e.date.isAfter(monday.subtract(const Duration(days: 1))),
            )
            .map((e) => formatter.format(e.date))
            .toSet();

    int trainingsDieseWoche = trainedDays.length;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aktivität diese Woche',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children:
                  days.map((date) {
                    final weekday = DateFormat.E(
                      'de',
                    ).format(date).substring(0, 2); // Mo, Di, ...
                    final isTrained = trainedDays.contains(
                      formatter.format(date),
                    );
                    return CircleAvatar(
                      backgroundColor:
                          isTrained ? Colors.green : Colors.grey[800],
                      radius: 20,
                      child: Text(
                        weekday,
                        style: TextStyle(
                          color: isTrained ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Wöchentliches Ziel:'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _weeklyGoal,
                  onChanged: (value) {
                    setState(() {
                      _weeklyGoal = value!;
                    });
                  },
                  items:
                      List.generate(7, (i) => i + 1).map((goal) {
                        return DropdownMenuItem(
                          value: goal,
                          child: Text('$goal x'),
                        );
                      }).toList(),
                ),
                const SizedBox(width: 16),
                Chip(
                  backgroundColor:
                      trainingsDieseWoche >= _weeklyGoal
                          ? Colors.green
                          : Colors.red,
                  label: Text(
                    trainingsDieseWoche >= _weeklyGoal
                        ? 'Ziel erreicht 🎉'
                        : 'Noch nicht erreicht',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Workout-Dauer (Minuten)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1.6,
              child: BarChart(
                BarChartData(
                  barGroups: _buildBarGroups(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        interval: 1,
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          final labels = _barLabels;
                          if (index < labels.length) {
                            return Text(
                              labels[index],
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, interval: 10),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fortschritt')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _allEntries.isEmpty
              ? const Center(child: Text('Noch keine Workouts abgeschlossen.'))
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    _buildWeeklyTracker(),
                    const SizedBox(height: 24),
                    _buildModernDropdown(),
                    const SizedBox(height: 16),
                    _buildBarChartCard(),
                  ],
                ),
              ),
    );
  }
}
