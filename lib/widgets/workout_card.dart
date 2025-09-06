// lib/workout_card.dart

import 'package:flutter/material.dart';
import '../models/workout.dart';

class WorkoutCard extends StatelessWidget {
  final Workout workout;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPrimaryActionTap;

  const WorkoutCard({
    super.key,
    required this.workout,
    required this.onTap,
    this.onLongPress,
    this.onPrimaryActionTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final titleStyle = textTheme.titleMedium;
    final bodyStyle = textTheme.bodySmall;

    return Material(
      color: Theme.of(context).cardColor,
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Leading-Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.fitness_center,
                  size: 26,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              // Titel + Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                    const SizedBox(height: 4),
                    if (workout.exerciseIds.isNotEmpty)
                      Text(
                        '${workout.exerciseIds.length} Übung(en)',
                        style: bodyStyle?.copyWith(
                          color: Theme.of(
                            context,
                          ).textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Trailing: Stift oder roter Mülleimer
              IconButton(
                onPressed: onPrimaryActionTap ?? onTap,
                icon: Icon(
                  selected ? Icons.delete_forever_rounded : Icons.edit,
                ),
                color: selected ? Colors.red : scheme.primary,
                tooltip: selected ? 'Löschen' : 'Bearbeiten',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
