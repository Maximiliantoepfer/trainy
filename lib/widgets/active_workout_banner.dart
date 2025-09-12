import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/active_workout_provider.dart';
import '../screens/workout_run_screen.dart';

class ActiveWorkoutBanner extends StatelessWidget {
  const ActiveWorkoutBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final active = context.watch<ActiveWorkoutProvider>();
    if (!active.isActive || active.workout == null)
      return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final workout = active.workout!;

    return Material(
      color: scheme.surfaceVariant,
      child: InkWell(
        onTap: () {
          final ex = active.exercises;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => WorkoutRunScreen(
                    workout: workout,
                    exercises: ex,
                    autoStart: false,
                  ),
            ),
          );
        },
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.timer, color: scheme.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  workout.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<int>(
                valueListenable: active.elapsedSeconds,
                builder:
                    (_, sec, __) => Text(
                      _format(sec),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  String _format(int s) {
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}
