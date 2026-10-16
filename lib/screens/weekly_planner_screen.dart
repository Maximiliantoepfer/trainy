import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/workout.dart';
import '../models/workout_planning.dart';
import '../providers/workout_provider.dart';
import '../repositories/workout_planning_repository.dart';
import '../utils/goal_utils.dart';

/// Recurring, local-first weekly planning template. Workouts move directly
/// from their visible drag grip; deletion remains reversible.
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

  Future<void> _move(
    WeeklyWorkoutPlacement placement,
    int day,
    int index,
  ) async {
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
      builder:
          (_) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final item in workouts.where(
                  (item) => !scheduled.contains(item.canonicalId),
                ))
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
    await _repository.assignToDay(
      workoutId: workout.canonicalId,
      weekday: weekday,
    );
    if (!mounted) return;
    await context.read<WorkoutProvider>().loadWorkouts();
    await _load();
  }

  Future<void> _removePlacement(
    WeeklyWorkoutPlacement placement,
    int index,
  ) async {
    await _repository.removePlacement(placement.id);
    if (!mounted) return;
    await context.read<WorkoutProvider>().loadWorkouts();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.weeklyPlacementRemoved),
        action: SnackBarAction(
          label: context.l10n.undo,
          onPressed: () async {
            try {
              await _repository.assignToDay(
                workoutId: placement.workoutId,
                weekday: placement.weekday,
                index: index,
              );
              if (!mounted) return;
              await context.read<WorkoutProvider>().loadWorkouts();
              await _load();
            } on StateError {
              // The workout was explicitly planned again in the meantime.
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workoutById = {
      for (final workout in context.watch<WorkoutProvider>().workouts)
        workout.canonicalId: workout,
    };
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.weeklyPlanner)),
      body:
          _loading
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
                    onDrop:
                        (placement, insertIndex) =>
                            _move(placement, day, insertIndex),
                    onAdd: () => _add(day),
                    onRemove: _removePlacement,
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
  });
  final String dayLabel;
  final int day;
  final List<WeeklyWorkoutPlacement> placements;
  final Map<String, Workout> workoutById;
  final Future<void> Function(WeeklyWorkoutPlacement, int) onDrop;
  final VoidCallback onAdd;
  final Future<void> Function(WeeklyWorkoutPlacement, int) onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<WeeklyWorkoutPlacement>(
      onWillAcceptWithDetails:
          (details) => details.data.weekday != day || placements.length > 1,
      onAcceptWithDetails: (details) => onDrop(details.data, placements.length),
      builder:
          (context, candidates, _) => AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  candidates.isNotEmpty
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    candidates.isNotEmpty
                        ? scheme.primary
                        : scheme.outlineVariant.withValues(alpha: 0.45),
                width: candidates.isNotEmpty ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      dayLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: context.l10n.addWorkoutToDay,
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                if (placements.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      context.l10n.noWorkoutPlanned,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                else
                  for (var index = 0; index < placements.length; index++)
                    _PlacementChip(
                      placement: placements[index],
                      workout: workoutById[placements[index].workoutId],
                      onDropBefore: (value) => onDrop(value, index),
                      onRemove: () => onRemove(placements[index], index),
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
  });
  final WeeklyWorkoutPlacement placement;
  final Workout? workout;
  final Future<void> Function(WeeklyWorkoutPlacement) onDropBefore;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final value = workout;
    if (value == null) return const SizedBox.shrink();
    return DragTarget<WeeklyWorkoutPlacement>(
      onWillAcceptWithDetails: (details) => details.data.id != placement.id,
      onAcceptWithDetails: (details) => onDropBefore(details.data),
      builder:
          (context, candidates, _) => _ChipContent(
            workout: value,
            highlighted: candidates.isNotEmpty,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Draggable<WeeklyWorkoutPlacement>(
                  data: placement,
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: 260,
                      child: _ChipContent(workout: value, elevated: true),
                    ),
                  ),
                  childWhenDragging: const SizedBox(width: 48, height: 48),
                  child: Semantics(
                    label: context.l10n.moveWorkout,
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.drag_indicator_rounded),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.removeFromWeeklyPlan,
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
    );
  }
}

class _ChipContent extends StatelessWidget {
  const _ChipContent({
    required this.workout,
    this.trailing,
    this.elevated = false,
    this.highlighted = false,
  });
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
        boxShadow:
            elevated
                ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
                : null,
      ),
      child: Row(
        children: [
          GoalIcon(workout.primaryGoalCode, color: scheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              workout.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

String _dayLabel(BuildContext context, int day) =>
    [
      context.l10n.monday,
      context.l10n.tuesday,
      context.l10n.wednesday,
      context.l10n.thursday,
      context.l10n.friday,
      context.l10n.saturday,
      context.l10n.sunday,
    ][day - 1];
