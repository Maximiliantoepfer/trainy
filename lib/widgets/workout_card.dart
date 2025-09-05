// lib/widgets/workout_card.dart

import 'package:flutter/material.dart';
import 'package:trainy/models/workout.dart';

class WorkoutCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;
  const WorkoutCard({super.key, required this.workout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white;
    final primary = Theme.of(context).colorScheme.primary;
    final bgColor = Theme.of(context).cardColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fitness_center, size: 20, color: primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    workout.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              workout.description.isEmpty ? '—' : workout.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: textColor.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _meta(
                  Icons.list_alt,
                  '${workout.exerciseIds.length} Übungen',
                  context,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text, BuildContext context) {
    final textColor =
        Theme.of(context).textTheme.bodySmall?.color ?? Colors.white;
    return Row(
      children: [
        Icon(icon, size: 16, color: textColor.withOpacity(0.6)),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: textColor.withOpacity(0.8)),
        ),
      ],
    );
  }
}
