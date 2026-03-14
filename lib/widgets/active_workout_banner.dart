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

    return Material(
      color: scheme.primary.withOpacity(0.08),
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.timer_rounded, color: scheme.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  workout.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<int>(
                valueListenable: active.elapsedSeconds,
                builder: (_, sec, __) => Text(
                  DurationFormatter.digital(sec),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  color: scheme.primary.withOpacity(0.6), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
