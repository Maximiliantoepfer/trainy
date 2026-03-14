import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/active_workout_provider.dart';
import '../utils/duration_utils.dart';
import '../screens/workout_run_screen.dart';

class ActiveWorkoutBanner extends StatelessWidget {
  const ActiveWorkoutBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final active = context.watch<ActiveWorkoutProvider>();
    if (!active.isActive || active.workout == null) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final workout = active.workout!;

    return Semantics(
      label: 'Aktives Workout: ${workout.name}. Tippen zum Fortsetzen.',
      button: true,
      child: Material(
        color: scheme.primaryContainer,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WorkoutRunScreen(
                  workout: workout,
                  exercises: active.exercises,
                  autoStart: false,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.timer_rounded, color: scheme.onPrimaryContainer, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    workout.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<int>(
                  valueListenable: active.elapsedSeconds,
                  builder: (_, sec, __) => Text(
                    DurationFormatter.digital(sec),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onPrimaryContainer, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
