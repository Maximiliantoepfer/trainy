import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/workout.dart';
import '../models/workout_planning.dart';
import '../providers/workout_provider.dart';
import '../repositories/workout_planning_repository.dart';
import '../utils/goal_utils.dart';

/// Recurring, local-first weekly planning template.  Drag is complemented by
/// a complete overflow menu so that the same operation works with keyboard,
/// screen readers and reduced motion.
class WeeklyPlannerScreen extends StatefulWidget {
  const WeeklyPlannerScreen({super.key});

  @override
  State<WeeklyPlannerScreen> createState() => _WeeklyPlannerScreenState();
}

class _WeeklyPlannerScreenState extends State<WeeklyPlannerScreen> {
  final WorkoutPlanningRepository _repository = WorkoutPlanningRepository();
  List<WeeklyWorkoutPlacement> _placements = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final placements = await _repository.weeklyPlacements();
    if (!mounted) return;
    setState(() {
      _placements = placements;
      _loading = false;
    });
  }

  List<WeeklyWorkoutPlacement> _forDay(int day) => _placements
      .where((placement) => placement.weekday == day)
      .toList(growable: false)
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  Future<void> _move(WeeklyWorkoutPlacement placement, int day, int index) async {
    try {
      await _repository.movePlacement(
        placementId: placement.id,
        targetWeekday: day,
        targetIndex: index,
      );
      HapticFeedback.selectionClick();
      await _load();
    } on StateError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.workoutAlreadyPlanned)),
        );
      }
    }
  }

  Future<void> _add(int weekday) async {
    final workouts = context.read<WorkoutProvider>().workouts;
    final scheduled = _forDay(weekday).map((value) => value.workoutId).toSet();
    final workout = await showModalBottomSheet<Workout>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final item in workouts.where((item) => !scheduled.contains(item.canonicalId)))
              ListTile(
                leading: GoalIcon(item.primaryGoalCode),
                title: Text(item.name),
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );
    if (workout == null) return;
    await _repository.assignToDay(workoutId: workout.canonicalId, weekday: weekday);
    if (!mounted) return;
    await context.read<WorkoutProvider>().loadWorkouts();
    await _load();
  }

  Future<void> _moveMenu(WeeklyWorkoutPlacement placement) async {
    final day = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: List.generate(
            7,
            (index) => ListTile(
              title: Text(_dayLabel(context, index + 1)),
              selected: placement.weekday == index + 1,
              onTap: () => Navigator.pop(context, index + 1),
            ),
          ),
        ),
      ),
    );
    if (day != null) await _move(placement, day, _forDay(day).length);
  }

  Future<void> _removePlacement(WeeklyWorkoutPlacement placement) async {
    await _repository.removePlacement(placement.id);
    if (!mounted) return;
    await context.read<WorkoutProvider>().loadWorkouts();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final workoutById = {
      for (final workout in context.watch<WorkoutProvider>().workouts)
        workout.canonicalId: workout,
    };
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.weeklyPlanner)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final day = index + 1;
                final placements = _forDay(day);
                return _WeekdayDropZone(
                  dayLabel: _dayLabel(context, day),
                  day: day,
                  placements: placements,
                  workoutById: workoutById,
                  onDrop: (placement, insertIndex) => _move(placement, day, insertIndex),
                  onAdd: () => _add(day),
                  onRemove: _removePlacement,
                  onMoveMenu: _moveMenu,
                  onMoveUp: (placement) => _move(
                    placement,
                    day,
                    (placements.indexWhere((item) => item.id == placement.id) - 1).clamp(0, placements.length),
                  ),
                  onMoveDown: (placement) => _move(
                    placement,
                    day,
                    (placements.indexWhere((item) => item.id == placement.id) + 1).clamp(0, placements.length),
                  ),
                );
              },
            ),
    );
  }
}

class _WeekdayDropZone extends StatelessWidget {
  const _WeekdayDropZone({
    required this.dayLabel,
    required this.day,
    required this.placements,
    required this.workoutById,
    required this.onDrop,
    required this.onAdd,
    required this.onRemove,
    required this.onMoveMenu,
    required this.onMoveUp,
    required this.onMoveDown,
  });
  final String dayLabel;
  final int day;
  final List<WeeklyWorkoutPlacement> placements;
  final Map<String, Workout> workoutById;
  final Future<void> Function(WeeklyWorkoutPlacement, int) onDrop;
  final VoidCallback onAdd;
  final Future<void> Function(WeeklyWorkoutPlacement) onRemove;
  final Future<void> Function(WeeklyWorkoutPlacement) onMoveMenu;
  final Future<void> Function(WeeklyWorkoutPlacement) onMoveUp;
  final Future<void> Function(WeeklyWorkoutPlacement) onMoveDown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<WeeklyWorkoutPlacement>(
      onWillAcceptWithDetails: (details) => details.data.weekday != day || placements.length > 1,
      onAcceptWithDetails: (details) => onDrop(details.data, placements.length),
      builder: (context, candidates, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty ? scheme.primaryContainer : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: candidates.isNotEmpty ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.45),
            width: candidates.isNotEmpty ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(dayLabel, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                tooltip: context.l10n.addWorkoutToDay,
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
              ),
            ]),
            if (placements.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(context.l10n.noWorkoutPlanned, style: TextStyle(color: scheme.onSurfaceVariant)),
              )
            else
              for (var index = 0; index < placements.length; index++)
                _PlacementChip(
                  placement: placements[index],
                  workout: workoutById[placements[index].workoutId],
                  onDropBefore: (value) => onDrop(value, index),
                  onRemove: onRemove,
                  onMoveMenu: onMoveMenu,
                  onMoveUp: onMoveUp,
                  onMoveDown: onMoveDown,
                  canMoveUp: index > 0,
                  canMoveDown: index < placements.length - 1,
                ),
          ],
        ),
      ),
    );
  }
}

class _PlacementChip extends StatelessWidget {
  const _PlacementChip({
    required this.placement,
    required this.workout,
    required this.onDropBefore,
    required this.onRemove,
    required this.onMoveMenu,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.canMoveUp,
    required this.canMoveDown,
  });
  final WeeklyWorkoutPlacement placement;
  final Workout? workout;
  final Future<void> Function(WeeklyWorkoutPlacement) onDropBefore;
  final Future<void> Function(WeeklyWorkoutPlacement) onRemove;
  final Future<void> Function(WeeklyWorkoutPlacement) onMoveMenu;
  final Future<void> Function(WeeklyWorkoutPlacement) onMoveUp;
  final Future<void> Function(WeeklyWorkoutPlacement) onMoveDown;
  final bool canMoveUp;
  final bool canMoveDown;

  @override
  Widget build(BuildContext context) {
    final value = workout;
    if (value == null) return const SizedBox.shrink();
    return DragTarget<WeeklyWorkoutPlacement>(
      onWillAcceptWithDetails: (details) => details.data.id != placement.id,
      onAcceptWithDetails: (details) => onDropBefore(details.data),
      builder: (context, candidates, _) => LongPressDraggable<WeeklyWorkoutPlacement>(
        data: placement,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: 260, child: _ChipContent(workout: value, elevated: true)),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: _ChipContent(workout: value)),
        child: _ChipContent(
          workout: value,
          highlighted: candidates.isNotEmpty,
          trailing: PopupMenuButton<_PlacementAction>(
            tooltip: context.l10n.moveWorkout,
            onSelected: (action) async {
              switch (action) {
                case _PlacementAction.move: await onMoveMenu(placement);
                case _PlacementAction.up: await onMoveUp(placement);
                case _PlacementAction.down: await onMoveDown(placement);
                case _PlacementAction.remove: await onRemove(placement);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: _PlacementAction.move, child: Text(context.l10n.moveWorkout)),
              PopupMenuItem(enabled: canMoveUp, value: _PlacementAction.up, child: Text(context.l10n.moveUp)),
              PopupMenuItem(enabled: canMoveDown, value: _PlacementAction.down, child: Text(context.l10n.moveDown)),
              PopupMenuItem(value: _PlacementAction.remove, child: Text(context.l10n.remove)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PlacementAction { move, up, down, remove }

class _ChipContent extends StatelessWidget {
  const _ChipContent({required this.workout, this.trailing, this.elevated = false, this.highlighted = false});
  final Workout workout;
  final Widget? trailing;
  final bool elevated;
  final bool highlighted;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? scheme.primaryContainer : scheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: elevated ? [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: Row(children: [
        GoalIcon(workout.primaryGoalCode, color: scheme.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(workout.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

String _dayLabel(BuildContext context, int day) => [
  context.l10n.monday,
  context.l10n.tuesday,
  context.l10n.wednesday,
  context.l10n.thursday,
  context.l10n.friday,
  context.l10n.saturday,
  context.l10n.sunday,
][day - 1];
