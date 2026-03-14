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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: selected
            ? scheme.primaryContainer
            : Theme.of(context).cardColor,
        border: selected
            ? Border.all(color: scheme.primary, width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.fitness_center_rounded,
                    size: 20,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workout.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium,
                      ),
                      if (workout.exerciseIds.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${workout.exerciseIds.length} Übungen',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: selected
                      ? IconButton(
                          key: const ValueKey('delete'),
                          onPressed: onPrimaryActionTap,
                          icon: Icon(Icons.delete_outline_rounded,
                            color: scheme.error),
                          tooltip: 'Löschen',
                        )
                      : Icon(
                          Icons.chevron_right_rounded,
                          key: const ValueKey('chevron'),
                          color: scheme.outline,
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
