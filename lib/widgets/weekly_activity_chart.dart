import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeeklyActivityChart extends StatelessWidget {
  final Set<String> trainedDays;
  final DateTime monday;
  final int weeklyGoal;
  final int trainingsDieseWoche;
  final ValueChanged<int> onGoalChanged;

  const WeeklyActivityChart({
    required this.trainedDays,
    required this.monday,
    required this.weeklyGoal,
    required this.trainingsDieseWoche,
    required this.onGoalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final formatter = DateFormat('yyyy-MM-dd');
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fortschritt',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),

            /// Klassische Circle-Anzeige mit Haken
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
                          isTrained ? Colors.green : Colors.grey[800],
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

            /// Wochenziel-Schieberegler + Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                      ),
                    ),
                    child: Slider(
                      value: weeklyGoal.toDouble(),
                      min: 1,
                      max: 7,
                      divisions: 6,
                      activeColor: primary,
                      inactiveColor: Colors.grey,
                      onChanged: (value) => onGoalChanged(value.round()),
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
                          trainingsDieseWoche >= weeklyGoal
                              ? Colors.green
                              : Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    trainingsDieseWoche >= weeklyGoal
                        ? '🎯 Ziel erreicht'
                        : 'Noch ${weeklyGoal - trainingsDieseWoche}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            /// Fortschrittsbalken
            LinearProgressIndicator(
              value: (trainingsDieseWoche / weeklyGoal).clamp(0.0, 1.0),
              backgroundColor: Colors.grey[800],
              color: primary,
              minHeight: 6,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      ),
    );
  }
}
