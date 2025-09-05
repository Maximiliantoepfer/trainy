// lib/widgets/weekly_activity_chart.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeeklyActivityChart extends StatelessWidget {
  final Set<String> trainedDays;
  final DateTime monday;
  final int weeklyGoal;
  final int trainingsDieseWoche;
  final ValueChanged<int> onGoalChanged;

  const WeeklyActivityChart({
    super.key,
    required this.trainedDays,
    required this.monday,
    required this.weeklyGoal,
    required this.trainingsDieseWoche,
    required this.onGoalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final fmt = DateFormat('EEE');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Diese Woche',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Row(
                children: [
                  Icon(Icons.flag_outlined, size: 18, color: primary),
                  const SizedBox(width: 6),
                  DropdownButton<int>(
                    value: weeklyGoal,
                    onChanged: (v) => v != null ? onGoalChanged(v) : null,
                    items:
                        const [1, 2, 3, 4, 5, 6, 7]
                            .map(
                              (g) => DropdownMenuItem(
                                value: g,
                                child: Text('$g×/Woche'),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:
                days.map((d) {
                  final key = DateFormat('yyyy-MM-dd').format(d);
                  final hit = trainedDays.contains(key);
                  return Column(
                    children: [
                      Text(fmt.format(d)),
                      const SizedBox(height: 6),
                      CircleAvatar(
                        radius: 8,
                        backgroundColor: hit ? primary : Colors.grey[700],
                      ),
                    ],
                  );
                }).toList(),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (trainingsDieseWoche / weeklyGoal).clamp(0.0, 1.0),
            backgroundColor: Colors.grey[800],
            color: primary,
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
    );
  }
}
