import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/active_workout_provider.dart';
import '../screens/workout_run_screen.dart';

const Duration _kBannerAnim = Duration(milliseconds: 200);

class ActiveWorkoutBanner extends StatelessWidget {
  const ActiveWorkoutBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final active = context.watch<ActiveWorkoutProvider>();
    final isVisible = active.isActive && active.workout != null;

    return AnimatedSwitcher(
      duration: _kBannerAnim,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.15),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child:
          isVisible
              ? _BannerContent(
                active: active,
                key: const ValueKey('banner-content'),
              )
              : const SizedBox(key: ValueKey('banner-empty'), height: 0),
    );
  }
}

class _BannerContent extends StatelessWidget {
  final ActiveWorkoutProvider active;
  const _BannerContent({required this.active, super.key});

  @override
  Widget build(BuildContext context) {
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
                    (_, sec, __) => AnimatedSwitcher(
                      duration: _kBannerAnim,
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        final curved = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                          reverseCurve: Curves.easeIn,
                        );
                        return FadeTransition(
                          opacity: curved,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(curved),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        _formatBannerTime(sec),
                        key: ValueKey(sec),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
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
}

String _formatBannerTime(int seconds) {
  final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  final secs = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$secs';
}
