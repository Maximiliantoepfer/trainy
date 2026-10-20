import 'package:flutter/material.dart';
import '../models/training_program.dart';

/// Shared completion semantics for the week strip and month calendar.
class ActivityDayState {
  const ActivityDayState({this.planned = 0, this.completed = 0, this.kind});
  factory ActivityDayState.fromEntries(Iterable<ProgramEntry> entries) {
    final values = entries.toList();
    return ActivityDayState(
      planned: values.length,
      completed: values.where((e) => e.completed).length,
      kind:
          values.any((e) => e.kind == 'strength')
              ? 'strength'
              : values.any((e) => e.kind != 'mobility')
              ? 'running'
              : values.isEmpty
              ? null
              : 'mobility',
    );
  }
  final int planned, completed;
  final String? kind;
  bool get done => completed > 0 && completed >= planned;
  double get fraction =>
      planned == 0
          ? (completed > 0 ? 1 : 0)
          : (completed / planned).clamp(0, 1);
}

class ActivityDayBadge extends StatelessWidget {
  const ActivityDayBadge({
    super.key,
    required this.state,
    this.size = 42,
    this.selected = false,
  });
  final ActivityDayState state;
  final double size;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = state.done ? scheme.onTertiary : scheme.onSurfaceVariant;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size - 6,
            height: size - 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  state.done
                      ? scheme.tertiary
                      : scheme.surfaceContainerHighest.withValues(alpha: .65),
            ),
            alignment: Alignment.center,
            child:
                state.done
                    ? Icon(Icons.check_rounded, color: color, size: size * .48)
                    : state.kind == 'strength'
                    ? ImageIcon(
                      const AssetImage('assets/icons/muskel.png'),
                      color: color,
                      size: size * .48,
                    )
                    : state.kind == 'running' || state.kind == 'cardio'
                    ? Icon(Icons.directions_run, color: color, size: size * .48)
                    : state.kind == 'mobility'
                    ? Icon(
                      Icons.self_improvement,
                      color: color,
                      size: size * .48,
                    )
                    : ImageIcon(
                      const AssetImage('assets/icons/sofa.png'),
                      color: color,
                      size: size * .48,
                    ),
          ),
          if (selected)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.primary, width: 2),
                ),
              ),
            ),
          if (state.fraction > 0 && !state.done)
            Positioned.fill(
              left: 4,
              right: 4,
              top: 4,
              bottom: 4,
              child: CircularProgressIndicator(
                value: state.fraction,
                strokeWidth: 3,
                color: scheme.tertiary,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
        ],
      ),
    );
  }
}
