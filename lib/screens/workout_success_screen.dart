import 'package:flutter/material.dart';

import '../utils/duration_utils.dart';

class WorkoutSuccessScreen extends StatefulWidget {
  final String workoutName;
  final int durationSeconds;
  final int exerciseCount;
  final int totalSets;

  const WorkoutSuccessScreen({
    super.key,
    required this.workoutName,
    required this.durationSeconds,
    required this.exerciseCount,
    required this.totalSets,
  });

  @override
  State<WorkoutSuccessScreen> createState() => _WorkoutSuccessScreenState();
}

class _WorkoutSuccessScreenState extends State<WorkoutSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: scheme.tertiary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 48,
                      color: scheme.tertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Workout abgeschlossen!',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.workoutName,
                  style: textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _StatChip(
                      icon: Icons.timer_outlined,
                      label: DurationFormatter.verbose(widget.durationSeconds),
                    ),
                    _StatChip(
                      icon: Icons.fitness_center_rounded,
                      label: '${widget.exerciseCount} Übungen',
                    ),
                    if (widget.totalSets > 0)
                      _StatChip(
                        icon: Icons.layers_rounded,
                        label: '${widget.totalSets} Sätze',
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Starke Leistung!',
                  style: textTheme.titleMedium?.copyWith(
                    color: scheme.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fertig'),
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          )),
        ],
      ),
    );
  }
}
