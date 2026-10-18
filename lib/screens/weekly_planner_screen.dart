import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
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
  const WeeklyPlannerScreen({super.key, this.repository});
  final WorkoutPlanningRepository? repository;

  @override
  State<WeeklyPlannerScreen> createState() => _WeeklyPlannerScreenState();
}

class _WeeklyPlannerScreenState extends State<WeeklyPlannerScreen> {
  late final WorkoutPlanningRepository _repository =
      widget.repository ?? WorkoutPlanningRepository();
  List<WeeklyWorkoutPlacement> _placements = const [];
  bool _loading = true;
  Object? _error;
  bool _busy = false;
  final _scroll = ScrollController();
  Timer? _scrollTimer;
  double _scrollSpeed = 0;

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _dragAt(Offset position) {
    final height = MediaQuery.sizeOf(context).height;
    _scrollSpeed =
        position.dy < 120
            ? -12
            : position.dy > height - 110
            ? 12
            : 0;
    _scrollTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scroll.hasClients || _scrollSpeed == 0) return;
      _scroll.jumpTo(
        (_scroll.offset + _scrollSpeed).clamp(
          0.0,
          _scroll.position.maxScrollExtent,
        ),
      );
    });
  }

  void _endDrag() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _scrollSpeed = 0;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool propagateError = false}) async {
    try {
      final placements = await _repository.weeklyPlacements();
      if (!mounted) return;
      setState(() {
        _placements = placements;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
      if (propagateError) rethrow;
    }
  }

  Future<void> _change(
    Future<void> Function() action, {
    VoidCallback? onSuccess,
  }) async {
    if (_busy) return;
    var committed = false;
    Future<void> attempt() async {
      if (!mounted || _busy) return;
      setState(() => _busy = true);
      try {
        if (!committed) {
          await action();
          committed = true;
        }
        if (!mounted) return;
        await context.read<WorkoutProvider>().loadWorkouts();
        await _load(propagateError: true);
        if (mounted) onSuccess?.call();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.workoutEditFailed),
              action: SnackBarAction(
                label: context.l10n.retry,
                onPressed: attempt,
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    await attempt();
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
    if (day != placement.weekday &&
        _forDay(day).any((p) => p.workoutId == placement.workoutId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.workoutAlreadyPlanned)),
      );
      return;
    }
    await _change(
      () => _repository.movePlacement(
        placementId: placement.id,
        targetWeekday: day,
        targetIndex:
            day == placement.weekday &&
                    _forDay(day).indexWhere((p) => p.id == placement.id) < index
                ? index - 1
                : index,
      ),
      onSuccess: HapticFeedback.selectionClick,
    );
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
                if (workouts
                    .where((item) => !scheduled.contains(item.canonicalId))
                    .isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      workouts.isEmpty
                          ? context.l10n.noWorkoutsToPlan
                          : context.l10n.allWorkoutsPlanned,
                    ),
                  ),
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
    await _change(
      () => _repository.assignToDay(
        workoutId: workout.canonicalId,
        weekday: weekday,
      ),
    );
  }

  Future<void> _removePlacement(
    WeeklyWorkoutPlacement placement,
    int index,
  ) async {
    await _change(
      () => _repository.removePlacement(placement.id),
      onSuccess:
          () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.weeklyPlacementRemoved),
              action: SnackBarAction(
                label: context.l10n.undo,
                onPressed:
                    () => _change(() async {
                      if (_forDay(
                        placement.weekday,
                      ).any((p) => p.workoutId == placement.workoutId)) {
                        return;
                      }
                      await _repository.assignToDay(
                        workoutId: placement.workoutId,
                        weekday: placement.weekday,
                        index: index,
                      );
                    }),
              ),
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
      appBar: AppBar(
        title: Text(context.l10n.weeklyPlanner),
        actions: [
          IconButton(
            tooltip: context.l10n.info,
            icon: const Icon(Icons.info_outline),
            onPressed:
                () => showDialog<void>(
                  context: context,
                  builder:
                      (c) => AlertDialog(
                        content: Text(c.l10n.weeklyRecurrence),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: Text(c.l10n.close),
                          ),
                        ],
                      ),
                ),
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: TextButton(
                  onPressed: _load,
                  child: Text(context.l10n.retry),
                ),
              )
              : AbsorbPointer(
                absorbing: _busy,
                child: ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                      onDragUpdate: _dragAt,
                      onDragEnd: _endDrag,
                      onAccessibleMove:
                          (placement, targetDay, targetIndex) =>
                              _move(placement, targetDay, targetIndex),
                    );
                  },
                ),
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
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onAccessibleMove,
  });
  final String dayLabel;
  final int day;
  final List<WeeklyWorkoutPlacement> placements;
  final Map<String, Workout> workoutById;
  final Future<void> Function(WeeklyWorkoutPlacement, int) onDrop;
  final VoidCallback onAdd;
  final Future<void> Function(WeeklyWorkoutPlacement, int) onRemove;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final void Function(WeeklyWorkoutPlacement, int, int) onAccessibleMove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<WeeklyWorkoutPlacement>(
      onWillAcceptWithDetails:
          (details) => details.data.weekday != day || placements.length > 1,
      onAcceptWithDetails: (details) => onDrop(details.data, placements.length),
      builder:
          (context, candidates, _) => AnimatedContainer(
            duration:
                MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color:
                  candidates.isNotEmpty
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    candidates.isNotEmpty ? scheme.primary : Colors.transparent,
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
                if (placements.isNotEmpty)
                  for (var index = 0; index < placements.length; index++)
                    _PlacementChip(
                      placement: placements[index],
                      workout: workoutById[placements[index].workoutId],
                      onDropBefore: (value) => onDrop(value, index),
                      onRemove: () => onRemove(placements[index], index),
                      onDragUpdate: onDragUpdate,
                      onDragEnd: onDragEnd,
                      semanticActions: {
                        for (var target = 1; target <= 7; target++)
                          if (target != day)
                            CustomSemanticsAction(
                              label:
                                  '${context.l10n.moveWorkout}: ${_dayLabel(context, target)}',
                            ): () => onAccessibleMove(
                                  placements[index],
                                  target,
                                  0,
                                ),
                        if (index > 0)
                          CustomSemanticsAction(label: context.l10n.moveUp):
                              () => onDrop(placements[index], index - 1),
                        if (index < placements.length - 1)
                          CustomSemanticsAction(label: context.l10n.moveDown):
                              () => onDrop(placements[index], index + 2),
                      },
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
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.semanticActions,
  });
  final WeeklyWorkoutPlacement placement;
  final Workout? workout;
  final Future<void> Function(WeeklyWorkoutPlacement) onDropBefore;
  final Future<void> Function() onRemove;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final Map<CustomSemanticsAction, VoidCallback> semanticActions;

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
                  onDragUpdate:
                      (details) => onDragUpdate(details.globalPosition),
                  onDragEnd: (_) => onDragEnd(),
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
                    customSemanticsActions: semanticActions,
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
      duration:
          MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
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
