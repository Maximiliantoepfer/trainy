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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.fitness_center_rounded,
                    size: 24,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.list_rounded, size: 14,
                            color: workout.exerciseIds.isNotEmpty
                                ? scheme.onSurfaceVariant
                                : scheme.onSurfaceVariant.withValues(alpha: 0.4)),
                          const SizedBox(width: 4),
                          Text(
                            workout.exerciseIds.isNotEmpty
                                ? '${workout.exerciseIds.length} Übungen'
                                : 'Keine Übungen',
                            style: textTheme.bodySmall?.copyWith(
                              color: workout.exerciseIds.isEmpty
                                  ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                                  : null,
                            ),
                          ),
                        ],
                      ),
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
