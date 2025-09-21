// lib/workout_card.dart

import 'package:flutter/material.dart';
import '../models/workout.dart';

const Duration _kCardAnim = Duration(milliseconds: 200);

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
    final baseColor = Theme.of(context).cardColor;
    final highlightColor = scheme.primary.withOpacity(0.14);

    return AnimatedContainer(
      duration: _kCardAnim,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow:
            selected
                ? [
                  BoxShadow(
                    color: scheme.primary.withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
                : const [],
      ),
      child: Material(
        color: selected ? highlightColor : baseColor,
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.fitness_center_rounded,
                    size: 26,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
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
                          '${workout.exerciseIds.length} Ãœbung(en)',
                          style: bodyStyle?.copyWith(
                            color: textTheme.bodySmall?.color?.withOpacity(0.7),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: onPrimaryActionTap ?? onTap,
                  icon: AnimatedSwitcher(
                    duration: _kCardAnim,
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                        reverseCurve: Curves.easeIn,
                      );
                      return FadeTransition(
                        opacity: curved,
                        child: ScaleTransition(scale: curved, child: child),
                      );
                    },
                    child: Icon(
                      selected ? Icons.delete_forever_rounded : Icons.edit,
                      key: ValueKey(selected),
                    ),
                  ),
                  color: selected ? Colors.red : scheme.primary,
                  tooltip: selected ? 'LÃ¶schen' : 'Bearbeiten',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
