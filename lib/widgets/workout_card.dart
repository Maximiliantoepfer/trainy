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
    final count = workout.exerciseIds.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: selected
            ? scheme.primary.withOpacity(0.08)
            : Theme.of(context).cardColor,
        border: selected
            ? Border.all(color: scheme.primary.withOpacity(0.3), width: 1.5)
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.fitness_center_rounded,
                      size: 20, color: scheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(workout.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium),
                      if (count > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.list_rounded, size: 14,
                                color: scheme.onSurfaceVariant.withOpacity(0.5)),
                            const SizedBox(width: 4),
                            Text('$count',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant.withOpacity(0.6),
                                fontWeight: FontWeight.w600,
                              )),
                          ],
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
                        )
                      : Icon(Icons.chevron_right_rounded,
                          key: const ValueKey('chevron'),
                          color: scheme.onSurfaceVariant.withOpacity(0.3)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
