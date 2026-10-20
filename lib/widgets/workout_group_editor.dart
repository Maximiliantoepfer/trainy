import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import '../l10n/l10n.dart';
import '../models/exercise.dart';
import '../models/workout_planning.dart';
import '../utils/exercise_localization.dart';
import '../utils/workout_group_localization.dart';

class WorkoutGroupEditor extends StatefulWidget {
  const WorkoutGroupEditor({
    super.key,
    required this.setup,
    required this.exercises,
    required this.selectedIds,
    required this.onToggle,
    required this.onMove,
    required this.onReorderGroups,
    required this.onAdd,
    required this.scrollController,
    this.busy = false,
    this.onEditPrescription,
  });
  final WorkoutSetup setup;
  final List<Exercise> exercises;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  /// The insertion index is measured after removing the dragged slot.
  final Future<void> Function(String slotId, String groupId, int index) onMove;
  final Future<void> Function(List<String>) onReorderGroups;
  final ValueChanged<String?> onAdd;
  final ScrollController scrollController;
  final bool busy;
  final ValueChanged<WorkoutSetupSlot>? onEditPrescription;
  @override
  State<WorkoutGroupEditor> createState() => _WorkoutGroupEditorState();
}

class _EditorDrag {
  const _EditorDrag(this.setupId, {this.slotId, this.groupId});
  final String setupId;
  final String? slotId;
  final String? groupId;
}

class _WorkoutGroupEditorState extends State<WorkoutGroupEditor> {
  bool _slotDragging = false;
  bool _groupDragging = false;
  Timer? _scrollTimer;
  double _scrollDelta = 0;
  @override
  void dispose() {
    _scrollTimer?.cancel();
    super.dispose();
  }

  void _updateDrag(DragUpdateDetails details) {
    final height = MediaQuery.sizeOf(context).height;
    _scrollDelta =
        details.globalPosition.dy < 140
            ? -9
            : details.globalPosition.dy > height - 160
            ? 9
            : 0;
    _scrollTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final controller = widget.scrollController;
      if (_scrollDelta == 0 || !controller.hasClients) return;
      controller.jumpTo(
        (controller.offset + _scrollDelta).clamp(
          0,
          controller.position.maxScrollExtent,
        ),
      );
    });
  }

  void _endDrag() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _scrollDelta = 0;
    if (mounted) {
      setState(() {
        _slotDragging = false;
        _groupDragging = false;
      });
    }
  }

  bool _accept(_EditorDrag drag) =>
      !widget.busy && drag.setupId == widget.setup.id;

  Widget _handle(_EditorDrag data, String label, Widget feedback) => Semantics(
    label: label,
    customSemanticsActions: widget.busy ? null : _moveActions(data),
    child: Draggable<_EditorDrag>(
      data: data,
      maxSimultaneousDrags: widget.busy ? 0 : 1,
      onDragStarted: () {
        HapticFeedback.selectionClick();
        setState(() {
          _slotDragging = data.slotId != null;
          _groupDragging = data.groupId != null;
        });
      },
      onDragUpdate: _updateDrag,
      onDragEnd: (_) => _endDrag(),
      onDragCompleted: _endDrag,
      onDraggableCanceled: (_, __) => _endDrag(),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: (MediaQuery.sizeOf(context).width - 32).clamp(0, 600),
          child: feedback,
        ),
      ),
      childWhenDragging: const SizedBox.square(dimension: 48),
      child: Tooltip(
        message: label,
        child: const SizedBox.square(
          dimension: 48,
          child: Icon(Icons.drag_indicator),
        ),
      ),
    ),
  );

  Map<CustomSemanticsAction, VoidCallback> _moveActions(_EditorDrag data) {
    final actions = <CustomSemanticsAction, VoidCallback>{};
    if (data.groupId != null) {
      final ids =
          widget.setup.groups
              .where(
                (g) =>
                    g.kind != WorkoutGroupKind.warmup &&
                    g.kind != WorkoutGroupKind.cooldown,
              )
              .map((g) => g.id)
              .toList();
      final index = ids.indexOf(data.groupId!);
      void move(int to) {
        final order = [...ids]..removeAt(index);
        order.insert(to, data.groupId!);
        widget.onReorderGroups(order);
      }

      if (index > 0) {
        actions[CustomSemanticsAction(label: context.l10n.moveUp)] =
            () => move(index - 1);
      }
      if (index >= 0 && index < ids.length - 1) {
        actions[CustomSemanticsAction(label: context.l10n.moveDown)] =
            () => move(index + 1);
      }
    } else if (data.slotId != null) {
      final groups = widget.setup.groups;
      final groupIndex = groups.indexWhere(
        (g) => g.selectedVariant.slots.any((s) => s.id == data.slotId),
      );
      if (groupIndex < 0) return actions;
      final group = groups[groupIndex];
      final index = group.selectedVariant.slots.indexWhere(
        (s) => s.id == data.slotId,
      );
      if (index > 0 || groupIndex > 0) {
        actions[CustomSemanticsAction(label: context.l10n.moveUp)] =
            () => widget.onMove(
              data.slotId!,
              index > 0 ? group.id : groups[groupIndex - 1].id,
              index > 0
                  ? index - 1
                  : groups[groupIndex - 1].selectedVariant.slots.length,
            );
      }
      if (index < group.selectedVariant.slots.length - 1 ||
          groupIndex < groups.length - 1) {
        actions[CustomSemanticsAction(label: context.l10n.moveDown)] =
            () => widget.onMove(
              data.slotId!,
              index < group.selectedVariant.slots.length - 1
                  ? group.id
                  : groups[groupIndex + 1].id,
              index < group.selectedVariant.slots.length - 1 ? index + 1 : 0,
            );
      }
    }
    return actions;
  }

  Future<void> _move(
    _EditorDrag drag,
    WorkoutSetupGroup group,
    int boundary,
  ) async {
    if (drag.slotId == null) return;
    final slots = group.selectedVariant.slots;
    final oldIndex = slots.indexWhere((s) => s.id == drag.slotId);
    final index =
        oldIndex >= 0 && oldIndex < boundary ? boundary - 1 : boundary;
    _endDrag();
    await widget.onMove(drag.slotId!, group.id, index);
  }

  Future<void> _moveGroup(_EditorDrag drag, String? beforeId) async {
    final ids =
        widget.setup.groups
            .where(
              (g) =>
                  g.kind != WorkoutGroupKind.warmup &&
                  g.kind != WorkoutGroupKind.cooldown,
            )
            .map((g) => g.id)
            .toList();
    if (drag.groupId == null ||
        drag.groupId == beforeId ||
        !ids.remove(drag.groupId)) {
      return;
    }
    final position = beforeId == null ? ids.length : ids.indexOf(beforeId);
    if (position < 0) return;
    ids.insert(position, drag.groupId!);
    _endDrag();
    await widget.onReorderGroups(ids);
  }

  Widget _insertion({
    required bool group,
    required Future<void> Function(_EditorDrag) drop,
  }) => DragTarget<_EditorDrag>(
    onWillAcceptWithDetails:
        (d) =>
            _accept(d.data) &&
            (group ? d.data.groupId != null : d.data.slotId != null),
    onAcceptWithDetails: (d) => drop(d.data),
    builder:
        (_, candidates, rejected) => SizedBox(
          height: group ? (_groupDragging ? 28 : 12) : (_slotDragging ? 22 : 2),
          child: Center(
            child: Container(
              height: candidates.isEmpty ? 0 : 3,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
  );

  @override
  Widget build(BuildContext context) {
    final groups = widget.setup.groups;
    final hasCustom = groups.any((g) => g.kind == WorkoutGroupKind.custom);
    final visible =
        groups
            .where(
              (g) =>
                  g.kind != WorkoutGroupKind.core ||
                  g.selectedVariant.slots.isNotEmpty ||
                  !hasCustom ||
                  _slotDragging,
            )
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in visible) ...[
          if (group.kind != WorkoutGroupKind.warmup)
            _insertion(
              group: true,
              drop:
                  (drag) => _moveGroup(
                    drag,
                    group.kind == WorkoutGroupKind.cooldown ? null : group.id,
                  ),
            ),
          _group(context, group),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: widget.busy ? null : () => widget.onAdd(null),
          icon: const Icon(Icons.add),
          label: Text(context.l10n.addExercises),
        ),
      ],
    );
  }

  Widget _group(BuildContext context, WorkoutSetupGroup group) {
    final scheme = Theme.of(context).colorScheme;
    final slots = group.selectedVariant.slots;
    final label = workoutGroupLabel(context, group.kind, group.name);
    final movable =
        group.kind != WorkoutGroupKind.warmup &&
        group.kind != WorkoutGroupKind.cooldown;
    return DragTarget<_EditorDrag>(
      key: ValueKey('group-target:${group.id}'),
      onWillAcceptWithDetails: (d) => _accept(d.data) && d.data.slotId != null,
      onAcceptWithDetails: (d) => _move(d.data, group, slots.length),
      builder:
          (_, candidates, rejected) => AnimatedContainer(
            key: ValueKey('group:${group.id}'),
            duration:
                MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
            width: double.infinity,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    candidates.isNotEmpty
                        ? scheme.primary
                        : scheme.outlineVariant.withValues(alpha: .35),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (movable)
                      _handle(
                        _EditorDrag(widget.setup.id, groupId: group.id),
                        context.l10n.dragGroup,
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(label),
                          ),
                        ),
                      ),
                    if (!movable) const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.addExercises,
                      onPressed:
                          widget.busy ? null : () => widget.onAdd(group.id),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                for (var index = 0; index < slots.length; index++) ...[
                  _insertion(
                    group: false,
                    drop: (drag) => _move(drag, group, index),
                  ),
                  _slot(context, slots[index]),
                ],
                if (slots.isNotEmpty && _slotDragging)
                  _insertion(
                    group: false,
                    drop: (drag) => _move(drag, group, slots.length),
                  ),
              ],
            ),
          ),
    );
  }

  Widget _slot(BuildContext context, WorkoutSetupSlot slot) {
    final exercise =
        widget.exercises.where((e) => e.id == slot.localExerciseId).firstOrNull;
    final title =
        exercise == null
            ? context.l10n.exerciseLabel
            : displayExerciseName(context, exercise);
    final selected = widget.selectedIds.contains(slot.id);
    return Card(
      key: ValueKey('slot:${slot.id}'),
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 0,
      color:
          selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
      child: Semantics(
        selected: selected,
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 12, right: 4),
          onLongPress: widget.busy ? null : () => widget.onToggle(slot.id),
          onTap:
              widget.busy
                  ? null
                  : widget.selectedIds.isEmpty
                  ? (widget.onEditPrescription == null
                      ? null
                      : () => widget.onEditPrescription!(slot))
                  : () => widget.onToggle(slot.id),
          leading:
              widget.selectedIds.isEmpty
                  ? null
                  : Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                  ),
          title: Text(title),
          subtitle:
              slot.isOptional || slot.prescription != null
                  ? Text(
                    [
                      if (slot.prescription != null)
                        '${slot.prescription!.label} · ${slot.prescription!.restSeconds} s',
                      if (slot.isOptional) context.l10n.optionalExercise,
                    ].join(' · '),
                  )
                  : null,
          trailing: _handle(
            _EditorDrag(widget.setup.id, slotId: slot.id),
            context.l10n.dragExercise,
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(title),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
