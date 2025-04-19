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

    final daysInMonth = List.generate(
      endOfMonth.day,
      (index) => startOfMonth.add(Duration(days: index)),
    );

    final trainedDays = entries.map((e) => formatter.format(e.date)).toSet();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trainingskalender',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children:
                  daysInMonth.map((day) {
                    final key = formatter.format(day);
                    final trained = trainedDays.contains(key);
                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: trained ? Colors.green : Colors.grey[850],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
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
