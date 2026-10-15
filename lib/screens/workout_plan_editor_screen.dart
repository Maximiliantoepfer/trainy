import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_plan.dart';
import '../services/workout_plan_database.dart';
import '../utils/exercise_localization.dart';

/// Local editor for reusable workout groups, their variations and direct
/// exercise alternatives. It changes plan data only; completed sessions keep
/// their own snapshot and are therefore never rewritten here.
class WorkoutPlanEditorScreen extends StatefulWidget {
  const WorkoutPlanEditorScreen({
    super.key,
    required this.workout,
    required this.exercises,
  });

  final Workout workout;
  final List<Exercise> exercises;

  @override
  State<WorkoutPlanEditorScreen> createState() =>
      _WorkoutPlanEditorScreenState();
}

class _WorkoutPlanEditorScreenState extends State<WorkoutPlanEditorScreen> {
  final _database = WorkoutPlanDatabase.instance;
  var _loading = true;
  List<WorkoutVariant> _workoutVariants = const [];
  List<WorkoutGroup> _groups = const [];
  Map<int, List<WorkoutGroupVariant>> _groupVariants = const {};
  Map<int, int> _selections = const {};
  Map<int, List<WorkoutSlot>> _slotsByGroupVariant = const {};
  List<TrainingProfile> _profiles = const [];
  int? _selectedWorkoutVariantId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? selectWorkoutVariantId}) async {
    setState(() => _loading = true);
    await _database.bootstrapLegacyPlan(
      workoutId: widget.workout.id,
      exerciseIds: widget.workout.exerciseIds,
    );
    final variants = await _database.variantsForWorkout(widget.workout.id);
    final selected =
        selectWorkoutVariantId ??
        _selectedWorkoutVariantId ??
        variants
            .where((item) => item.isDefault)
            .map((item) => item.id)
            .firstOrNull ??
        (variants.isEmpty ? null : variants.first.id);
    final groups = await _database.groupsForWorkout(widget.workout.id);
    final selections =
        selected == null
            ? <int, int>{}
            : await _database.groupSelectionsForVariant(selected);
    final groupVariants = <int, List<WorkoutGroupVariant>>{};
    final slots = <int, List<WorkoutSlot>>{};
    for (final group in groups) {
      final values = await _database.groupVariantsForGroup(group.id);
      groupVariants[group.id] = values;
      for (final value in values) {
        slots[value.id] = await _database.slotsForGroupVariant(value.id);
      }
    }
    final profiles = await _database.profiles();
    if (!mounted) return;
    setState(() {
      _workoutVariants = variants;
      _groups = groups;
      _groupVariants = groupVariants;
      _selections = selections;
      _slotsByGroupVariant = slots;
      _profiles = profiles;
      _selectedWorkoutVariantId = selected;
      _loading = false;
    });
  }

  Future<String?> _askForName({
    required String title,
    required String label,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: label),
              onSubmitted:
                  (value) => Navigator.pop(dialogContext, value.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(dialogContext.l10n.cancel),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.pop(dialogContext, controller.text.trim()),
                child: Text(dialogContext.l10n.create),
              ),
            ],
          ),
    );
    controller.dispose();
    return result?.trim().isEmpty ?? true ? null : result!.trim();
  }

  Future<void> _addWorkoutVariant() async {
    final name = await _askForName(
      title: context.l10n.createVariant,
      label: context.l10n.variantName,
    );
    if (name == null) return;
    final result = await _database.createVariantFromDefault(
      workoutId: widget.workout.id,
      name: name,
    );
    await _load(selectWorkoutVariantId: result.id);
  }

  Future<void> _addGroup() async {
    final name = await _askForName(
      title: context.l10n.addGroup,
      label: context.l10n.groupName,
    );
    if (name == null) return;
    await _database.createGroup(workoutId: widget.workout.id, name: name);
    await _load();
  }

  Future<void> _addGroupVariant(
    WorkoutGroup group,
    WorkoutGroupVariant source,
  ) async {
    final controller = TextEditingController();
    int? profileId = source.profileId;
    final value = await showDialog<_NewGroupVariant>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setDialogState) => AlertDialog(
                  title: Text(dialogContext.l10n.addGroupVariant),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: dialogContext.l10n.variantName,
                        ),
                      ),
                      if (_profiles.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int?>(
                          value: profileId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: dialogContext.l10n.trainingProfile,
                          ),
                          items: [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text(dialogContext.l10n.system),
                            ),
                            ..._profiles.map(
                              (profile) => DropdownMenuItem<int?>(
                                value: profile.id,
                                child: Text(profile.name),
                              ),
                            ),
                          ],
                          onChanged:
                              (value) =>
                                  setDialogState(() => profileId = value),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(dialogContext.l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () {
                        final name = controller.text.trim();
                        if (name.isNotEmpty) {
                          Navigator.pop(
                            dialogContext,
                            _NewGroupVariant(name, profileId),
                          );
                        }
                      },
                      child: Text(dialogContext.l10n.create),
                    ),
                  ],
                ),
          ),
    );
    controller.dispose();
    if (value == null || _selectedWorkoutVariantId == null) return;
    final created = await _database.createGroupVariant(
      groupId: group.id,
      name: value.name,
      profileId: value.profileId,
      copyFromGroupVariantId: source.id,
    );
    await _database.selectGroupVariantForWorkoutVariant(
      workoutVariantId: _selectedWorkoutVariantId!,
      workoutGroupId: group.id,
      groupVariantId: created.id,
    );
    await _load();
  }

  Future<void> _selectGroupVariant(
    WorkoutGroup group,
    int groupVariantId,
  ) async {
    final workoutVariantId = _selectedWorkoutVariantId;
    if (workoutVariantId == null) return;
    await _database.selectGroupVariantForWorkoutVariant(
      workoutVariantId: workoutVariantId,
      workoutGroupId: group.id,
      groupVariantId: groupVariantId,
    );
    await _load();
  }

  Future<void> _editGroupSlots(WorkoutGroupVariant groupVariant) async {
    final existing = _slotsByGroupVariant[groupVariant.id] ?? const [];
    final selected = existing.map((slot) => slot.exerciseId).toSet();
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (sheetContext, setSheetState) => SafeArea(
                  child: SizedBox(
                    height: MediaQuery.of(sheetContext).size.height * .78,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              sheetContext.l10n.planExercises,
                              style:
                                  Theme.of(sheetContext).textTheme.titleLarge,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: widget.exercises.length,
                            itemBuilder: (context, index) {
                              final exercise = widget.exercises[index];
                              return CheckboxListTile(
                                value: selected.contains(exercise.id),
                                title: Text(
                                  displayExerciseName(sheetContext, exercise),
                                ),
                                onChanged:
                                    (checked) => setSheetState(() {
                                      if (checked == true) {
                                        selected.add(exercise.id);
                                      } else {
                                        selected.remove(exercise.id);
                                      }
                                    }),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed:
                                  () => Navigator.pop(
                                    sheetContext,
                                    Set<int>.from(selected),
                                  ),
                              child: Text(sheetContext.l10n.save),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
    if (result == null) return;
    final existingByExercise = {
      for (final slot in existing) slot.exerciseId: slot,
    };
    final base = DateTime.now().microsecondsSinceEpoch;
    var added = 0;
    final values = <WorkoutSlot>[];
    for (final exercise in widget.exercises) {
      if (!result.contains(exercise.id)) continue;
      final old = existingByExercise[exercise.id];
      values.add(
        WorkoutSlot(
          id: old?.id ?? base + added++,
          groupVariantId: groupVariant.id,
          exerciseId: exercise.id,
          movementFamilyId: old?.movementFamilyId,
          isOptional: old?.isOptional ?? false,
          sort: values.length,
        ),
      );
    }
    await _database.replaceGroupVariantSlots(
      groupVariantId: groupVariant.id,
      slots: values,
    );
    await _load();
  }

  Future<void> _toggleSlotKind(WorkoutSlot slot) async {
    final values = List<WorkoutSlot>.from(
      _slotsByGroupVariant[slot.groupVariantId] ?? const [],
    );
    final index = values.indexWhere((item) => item.id == slot.id);
    if (index < 0) return;
    values[index] = WorkoutSlot(
      id: slot.id,
      groupVariantId: slot.groupVariantId,
      exerciseId: slot.exerciseId,
      movementFamilyId: slot.movementFamilyId,
      isOptional: !slot.isOptional,
      sort: slot.sort,
    );
    await _database.replaceGroupVariantSlots(
      groupVariantId: slot.groupVariantId,
      slots: values,
    );
    await _load();
  }

  Future<void> _editAlternatives(WorkoutSlot slot) async {
    final existing = await _database.alternativesForSlot(slot.id);
    final selected = existing.map((item) => item.exerciseId).toSet();
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (sheetContext, setSheetState) => SafeArea(
                  child: SizedBox(
                    height: MediaQuery.of(sheetContext).size.height * .7,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              sheetContext.l10n.alternatives,
                              style:
                                  Theme.of(sheetContext).textTheme.titleLarge,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: widget.exercises.length,
                            itemBuilder: (context, index) {
                              final exercise = widget.exercises[index];
                              if (exercise.id == slot.exerciseId) {
                                return const SizedBox.shrink();
                              }
                              return CheckboxListTile(
                                value: selected.contains(exercise.id),
                                title: Text(
                                  displayExerciseName(sheetContext, exercise),
                                ),
                                onChanged:
                                    (checked) => setSheetState(() {
                                      if (checked == true) {
                                        selected.add(exercise.id);
                                      } else {
                                        selected.remove(exercise.id);
                                      }
                                    }),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed:
                                  () => Navigator.pop(
                                    sheetContext,
                                    Set<int>.from(selected),
                                  ),
                              child: Text(sheetContext.l10n.save),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
    if (result == null) return;
    await _database.replaceSlotAlternatives(
      workoutSlotId: slot.id,
      exerciseIds:
          widget.exercises
              .where((exercise) => result.contains(exercise.id))
              .map((exercise) => exercise.id)
              .toList(),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.editWorkoutPlan),
        actions: [
          IconButton(
            tooltip: context.l10n.createVariant,
            onPressed: _addWorkoutVariant,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          IconButton(
            tooltip: context.l10n.addGroup,
            onPressed: _addGroup,
            icon: const Icon(Icons.account_tree_outlined),
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  if (_workoutVariants.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: _selectedWorkoutVariantId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.l10n.workoutVariant,
                      ),
                      items:
                          _workoutVariants
                              .map(
                                (variant) => DropdownMenuItem(
                                  value: variant.id,
                                  child: Text(variant.name),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) _load(selectWorkoutVariantId: value);
                      },
                    ),
                  const SizedBox(height: 16),
                  for (final group in _groups) ...[
                    _GroupCard(
                      group: group,
                      variants: _groupVariants[group.id] ?? const [],
                      selectedVariantId: _selections[group.id],
                      slots:
                          _slotsByGroupVariant[_selections[group.id]] ??
                          const [],
                      exerciseById: {
                        for (final exercise in widget.exercises)
                          exercise.id: exercise,
                      },
                      onSelected: (id) => _selectGroupVariant(group, id),
                      onAddVariant: (source) => _addGroupVariant(group, source),
                      onEditSlots: _editGroupSlots,
                      onToggleSlotKind: _toggleSlotKind,
                      onEditAlternatives: _editAlternatives,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 56),
                      child: Center(
                        child: FilledButton.icon(
                          onPressed: _addGroup,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(context.l10n.addGroup),
                        ),
                      ),
                    ),
                ],
              ),
    );
  }
}

class _NewGroupVariant {
  const _NewGroupVariant(this.name, this.profileId);
  final String name;
  final int? profileId;
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.variants,
    required this.selectedVariantId,
    required this.slots,
    required this.exerciseById,
    required this.onSelected,
    required this.onAddVariant,
    required this.onEditSlots,
    required this.onToggleSlotKind,
    required this.onEditAlternatives,
  });

  final WorkoutGroup group;
  final List<WorkoutGroupVariant> variants;
  final int? selectedVariantId;
  final List<WorkoutSlot> slots;
  final Map<int, Exercise> exerciseById;
  final ValueChanged<int> onSelected;
  final ValueChanged<WorkoutGroupVariant> onAddVariant;
  final ValueChanged<WorkoutGroupVariant> onEditSlots;
  final ValueChanged<WorkoutSlot> onToggleSlotKind;
  final ValueChanged<WorkoutSlot> onEditAlternatives;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected =
        variants.where((item) => item.id == selectedVariantId).firstOrNull;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    group.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.addGroupVariant,
                  onPressed:
                      selected == null ? null : () => onAddVariant(selected),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            if (variants.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: selectedVariantId ?? variants.first.id,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.groupVariant,
                ),
                items:
                    variants
                        .map(
                          (variant) => DropdownMenuItem(
                            value: variant.id,
                            child: Text(variant.name),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) onSelected(value);
                },
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed:
                    selected == null ? null : () => onEditSlots(selected),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(context.l10n.planExercises),
              ),
            ),
            if (slots.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  context.l10n.noGroupExercises,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              for (final slot in slots)
                _SlotRow(
                  slot: slot,
                  exercise: exerciseById[slot.exerciseId],
                  onToggleKind: () => onToggleSlotKind(slot),
                  onEditAlternatives: () => onEditAlternatives(slot),
                ),
          ],
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.slot,
    required this.exercise,
    required this.onToggleKind,
    required this.onEditAlternatives,
  });

  final WorkoutSlot slot;
  final Exercise? exercise;
  final VoidCallback onToggleKind;
  final VoidCallback onEditAlternatives;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(
          exercise == null
              ? context.l10n.notAvailable
              : displayExerciseName(context, exercise!),
        ),
        subtitle: Text(
          slot.isOptional ? context.l10n.optional : context.l10n.core,
        ),
        leading: Icon(
          slot.isOptional
              ? Icons.add_task_outlined
              : Icons.star_outline_rounded,
          color: slot.isOptional ? scheme.onSurfaceVariant : scheme.primary,
        ),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              tooltip: context.l10n.alternatives,
              onPressed: onEditAlternatives,
              icon: const Icon(Icons.swap_horiz_rounded),
            ),
            IconButton(
              tooltip:
                  slot.isOptional ? context.l10n.core : context.l10n.optional,
              onPressed: onToggleKind,
              icon: Icon(
                slot.isOptional
                    ? Icons.star_outline_rounded
                    : Icons.add_task_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
