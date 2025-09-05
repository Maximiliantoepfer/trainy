// lib/widgets/trainings_calendar.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout_entry.dart';

class TrainingCalendar extends StatelessWidget {
  final List<WorkoutEntry> entries;
  const TrainingCalendar({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    final formatter = DateFormat('yyyy-MM-dd');

    final days = List<DateTime>.generate(
      endOfMonth.day,
      (i) => DateTime(now.year, now.month, i + 1),
    );

    final trained = entries.map((e) => formatter.format(e.date)).toSet();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kalender', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  days.map((d) {
                    final key = formatter.format(d);
                    final hit = trained.contains(key);
                    return Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            hit
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade700),
                      ),
                      child: Text(
                        '${d.day}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
