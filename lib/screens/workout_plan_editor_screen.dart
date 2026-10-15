import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_plan.dart';
import '../services/workout_plan_database.dart';
import '../utils/exercise_localization.dart';
import '../widgets/modal_form_dialogs.dart';

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

  Future<String?> _askForName({required String title, required String label}) {
    return showTextPromptDialog(
      context: context,
      title: title,
      label: label,
      submitLabel: context.l10n.create,
      cancelLabel: context.l10n.cancel,
      requiredMessage: context.l10n.nameRequired,
    );
  }

  Future<void> _addWorkoutVariant() async {
    final name = await _askForName(
      title: context.l10n.createVariant,
      label: context.l10n.variantName,
    );
    if (!mounted) return;
    if (name == null) return;
    final result = await _database.createVariantFromDefault(
      workoutId: widget.workout.id,
      name: name,
    );
    if (!mounted) return;
    await _load(selectWorkoutVariantId: result.id);
  }

  Future<void> _addGroup() async {
    final name = await _askForName(
      title: context.l10n.addGroup,
      label: context.l10n.groupName,
    );
    if (!mounted) return;
    if (name == null) return;
    await _database.createGroup(workoutId: widget.workout.id, name: name);
    if (!mounted) return;
    await _load();
  }

  Future<void> _addGroupVariant(
    WorkoutGroup group,
    WorkoutGroupVariant source,
  ) async {
    final value = await showDialog<_NewGroupVariant>(
      context: context,
      builder:
          (_) => _GroupVariantDialog(
            profiles: _profiles,
            initialProfileId: source.profileId,
          ),
    );
    if (!mounted) return;
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
    if (!mounted) return;
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
          (_) => _ExerciseSelectionSheet(
            title: context.l10n.planExercises,
            exercises: widget.exercises,
            initiallySelected: selected,
            heightFactor: .78,
          ),
    );
    if (!mounted || result == null) return;
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
    if (!mounted) return;
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
    if (!mounted) return;
    final selected = existing.map((item) => item.exerciseId).toSet();
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (_) => _ExerciseSelectionSheet(
            title: context.l10n.alternatives,
            exercises: widget.exercises,
            initiallySelected: selected,
            excludedExerciseId: slot.exerciseId,
            heightFactor: .7,
          ),
    );
    if (!mounted || result == null) return;
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

class _GroupVariantDialog extends StatefulWidget {
  const _GroupVariantDialog({
    required this.profiles,
    required this.initialProfileId,
  });

  final List<TrainingProfile> profiles;
  final int? initialProfileId;

  @override
  State<_GroupVariantDialog> createState() => _GroupVariantDialogState();
}

class _GroupVariantDialogState extends State<_GroupVariantDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  int? _profileId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _profileId = widget.initialProfileId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(
      context,
    ).pop(_NewGroupVariant(_nameController.text.trim(), _profileId));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.addGroupVariant),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const ValueKey('groupVariantName'),
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(labelText: context.l10n.variantName),
              validator:
                  (value) =>
                      (value?.trim().isEmpty ?? true)
                          ? context.l10n.nameRequired
                          : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (widget.profiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _profileId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.trainingProfile,
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(context.l10n.system),
                  ),
                  ...widget.profiles.map(
                    (profile) => DropdownMenuItem<int?>(
                      value: profile.id,
                      child: Text(profile.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _profileId = value),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('groupVariantSubmit'),
          onPressed: _submit,
          child: Text(context.l10n.create),
        ),
      ],
    );
  }
}

class _ExerciseSelectionSheet extends StatefulWidget {
  const _ExerciseSelectionSheet({
    required this.title,
    required this.exercises,
    required this.initiallySelected,
    required this.heightFactor,
    this.excludedExerciseId,
  });

  final String title;
  final List<Exercise> exercises;
  final Set<int> initiallySelected;
  final double heightFactor;
  final int? excludedExerciseId;

  @override
  State<_ExerciseSelectionSheet> createState() =>
      _ExerciseSelectionSheetState();
}

class _ExerciseSelectionSheetState extends State<_ExerciseSelectionSheet> {
  late final Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<int>.from(widget.initiallySelected);
  }

  @override
  Widget build(BuildContext context) {
    final exercises =
        widget.exercises
            .where((item) => item.id != widget.excludedExerciseId)
            .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * widget.heightFactor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: exercises.length,
                itemBuilder: (context, index) {
                  final exercise = exercises[index];
                  return CheckboxListTile(
                    value: _selected.contains(exercise.id),
                    title: Text(displayExerciseName(context, exercise)),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selected.add(exercise.id);
                        } else {
                          _selected.remove(exercise.id);
                        }
                      });
                    },
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
                      () => Navigator.of(context).pop(Set<int>.from(_selected)),
                  child: Text(context.l10n.save),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
