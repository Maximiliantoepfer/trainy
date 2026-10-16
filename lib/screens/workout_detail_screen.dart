import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/exercise.dart';
import '../models/training_profile.dart';
import '../models/workout.dart';
import '../models/workout_plan.dart';
import '../models/workout_planning.dart';
import '../providers/exercise_provider.dart';
import '../providers/active_workout_provider.dart';
import '../widgets/workout_group_editor.dart';
import '../widgets/workout_exercise_picker.dart';
import '../providers/workout_provider.dart';
import '../repositories/training_profile_repository.dart';
import '../repositories/workout_planning_repository.dart';
import '../services/catalog_repository.dart';
import '../utils/goal_utils.dart';
import '../widgets/modal_form_dialogs.dart';
import 'workout_run_screen.dart';

/// Guided three-step workflow used for all newly created workouts.
class WorkoutEditorScreen extends StatefulWidget {
  const WorkoutEditorScreen({super.key});

  @override
  State<WorkoutEditorScreen> createState() => _WorkoutEditorScreenState();
}

class _WorkoutEditorScreenState extends State<WorkoutEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _setupName = TextEditingController(text: 'Standard');
  int _step = 0;
  bool _saving = false;
  WorkoutPrimaryGoal _goal = WorkoutPrimaryGoal.strength;
  String? _profileId;
  List<TrainingProfileRecord> _profiles = const [];
  Set<int> _exerciseIds = <int>{};
  Set<String> _catalogIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    try {
      final profiles = await TrainingProfileRepository().profiles();
      if (mounted) setState(() => _profiles = profiles);
    } catch (_) {
      // A profile is optional, so setup creation remains completely local.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _setupName.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_step == 0 && !(_formKey.currentState?.validate() ?? false)) return;
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    setState(() => _saving = true);
    try {
      final exerciseProvider = context.read<ExerciseProvider>();
      final locale = Localizations.localeOf(context).languageCode;
      final ids = <int>{..._exerciseIds};
      for (final catalogId in _catalogIds) {
        final item = CatalogRepository.instance.localized(catalogId, locale);
        if (item != null) {
          ids.add(await exerciseProvider.addCatalogExercise(item));
        }
      }
      if (!mounted || !context.mounted) return;
      final workout = await context.read<WorkoutProvider>().createWorkout(
        name: _name.text,
        description: _description.text,
        primaryGoal: _goal,
        setupName: _setupName.text,
        profileId: _profileId,
        exerciseIds: ids.toList(growable: false),
      );
      if (mounted) {
        Navigator.of(context).pop(workout);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _selectExercises() async {
    final result = await showModalBottomSheet<ExercisePickerResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (_) => WorkoutExercisePicker(
            selectedExerciseIds: _exerciseIds,
            selectedCatalogIds: _catalogIds,
          ),
    );
    if (result != null && mounted) {
      setState(() {
        _exerciseIds = result.exerciseIds;
        _catalogIds = result.catalogIds;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newWorkout),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              children: [
                LinearProgressIndicator(value: (_step + 1) / 3),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.stepOf(_step + 1, 3),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  key: ValueKey(_step),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: switch (_step) {
                    0 => _BasicsStep(
                      formKey: _formKey,
                      name: _name,
                      description: _description,
                      goal: _goal,
                      onGoalChanged: (goal) => setState(() => _goal = goal),
                    ),
                    1 => _SetupStep(
                      profiles: _profiles,
                      profileId: _profileId,
                      onProfileChanged:
                          (id) => setState(() {
                            _profileId = id;
                            _setupName.text =
                                id == null
                                    ? context.l10n.defaultSetup
                                    : _profiles
                                        .firstWhere(
                                          (profile) => profile.id == id,
                                        )
                                        .name;
                          }),
                    ),
                    _ => _ExercisesStep(
                      count: _exerciseIds.length + _catalogIds.length,
                      onSelect: _selectExercises,
                    ),
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _saving ? null : () => setState(() => _step--),
                        child: Text(l10n.back),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _continue,
                      child:
                          _saving
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(_step == 2 ? l10n.saveWorkout : l10n.next),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({
    super.key,
    required this.workout,
    this.repository,
  });
  final WorkoutPlanningRepository? repository;

  final Workout workout;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late final WorkoutPlanningRepository _repository =
      widget.repository ?? WorkoutPlanningRepository();
  final ScrollController _scroll = ScrollController();
  List<WorkoutSetup> _setups = const [];
  final Set<String> _selectedSlotIds = {};
  String? _setupId;
  bool _loading = true;
  bool _busy = false;
  Object? _error;

  WorkoutSetup? get _currentSetup =>
      _setups.where((s) => s.id == _setupId).firstOrNull ?? _setups.firstOrNull;
  Workout get _workout =>
      context
          .read<WorkoutProvider>()
          .workouts
          .where((w) => w.id == widget.workout.id)
          .firstOrNull ??
      widget.workout;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool propagateErrors = false}) async {
    try {
      final setups = await _repository.setupsForWorkout(
        widget.workout.canonicalId,
      );
      if (!mounted) return;
      setState(() {
        _setups = setups;
        _setupId = _currentSetup?.id;
        _loading = false;
        _error = null;
        final valid =
            _currentSetup?.groups
                .expand((g) => g.selectedVariant.slots)
                .map((s) => s.id)
                .toSet() ??
            <String>{};
        _selectedSlotIds.retainAll(valid);
      });
    } catch (error, stack) {
      debugPrint('Loading workout: $error\n$stack');
      if (propagateErrors) rethrow;
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _mutate(
    Future<void> Function() operation, {
    bool clearSelection = false,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    var committed = false;
    try {
      await operation();
      committed = true;
      if (!mounted) return;
      if (clearSelection) {
        setState(_selectedSlotIds.clear);
      }
      await _load(propagateErrors: true);
      if (!mounted) return;
      await context.read<WorkoutProvider>().loadWorkouts();
    } catch (error, stack) {
      debugPrint('Editing workout: $error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.workoutEditFailed),
            action: SnackBarAction(
              label: context.l10n.retry,
              onPressed:
                  () => _mutate(
                    // A failed refresh must never replay a committed creation.
                    committed ? () async {} : operation,
                    clearSelection: clearSelection,
                  ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename() async {
    final provider = context.read<WorkoutProvider>();
    final value = await showTextPromptDialog(
      context: context,
      title: context.l10n.renameWorkout,
      label: context.l10n.workoutName,
      initialValue: _workout.name,
      submitLabel: context.l10n.save,
      cancelLabel: context.l10n.cancel,
      requiredMessage: context.l10n.nameRequired,
    );
    if (!mounted || value == null) return;
    await _mutate(() => provider.updateWorkoutName(widget.workout.id, value));
  }

  Future<void> _addSetup() async {
    final result = await showModalBottomSheet<_SetupDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (_) => _SetupEditorSheet(
            excludedProfileIds:
                _setups.map((s) => s.profile?.id).whereType<String>().toSet(),
          ),
    );
    if (!mounted || result == null) return;
    final copyId = _currentSetup?.id;
    await _mutate(() async {
      await _repository.createSetup(
        workoutId: widget.workout.canonicalId,
        name: result.name,
        profileId: result.profileId,
        copyFromSetupId: copyId,
      );
    });
  }

  Future<void> _addExercises([String? groupId]) async {
    final setup = _currentSetup;
    if (setup == null) return;
    final provider = context.read<ExerciseProvider>();
    final locale = Localizations.localeOf(context).languageCode;
    final result = await showModalBottomSheet<ExercisePickerResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => WorkoutExercisePicker(
            availableEquipment: setup.profile?.equipmentCodes,
          ),
    );
    if (!mounted || result == null) return;
    await _mutate(() async {
      final exercises = await result.materialize(provider, locale);
      await _repository.addExercisesToCore(
        setupId: setup.id,
        groupId: groupId,
        exerciseIds: exercises.map((e) => e.id),
      );
    });
  }

  List<String> get _orderedSelection => [
    for (final group in _currentSetup?.groups ?? <WorkoutSetupGroup>[])
      for (final slot in group.selectedVariant.slots)
        if (_selectedSlotIds.contains(slot.id)) slot.id,
  ];

  Future<void> _groupSelected() async {
    final setup = _currentSetup;
    final ids = _orderedSelection;
    if (setup == null || ids.isEmpty) return;
    final name = await showTextPromptDialog(
      context: context,
      title: context.l10n.groupSelectedExercises,
      label: context.l10n.groupName,
      submitLabel: context.l10n.save,
      cancelLabel: context.l10n.cancel,
      requiredMessage: context.l10n.nameRequired,
    );
    if (!mounted || name == null) return;
    await _mutate(
      () => _repository.createGroupFromSlots(
        setupId: setup.id,
        name: name,
        slotIds: ids,
      ),
      clearSelection: true,
    );
  }

  Future<void> _chooseStatus() async {
    final setup = _currentSetup;
    final ids = _orderedSelection;
    if (setup == null || ids.isEmpty) return;
    final optional = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder:
          (c) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(c.l10n.requiredExercise),
                  onTap: () => Navigator.pop(c, false),
                ),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: Text(c.l10n.optionalExercise),
                  onTap: () => Navigator.pop(c, true),
                ),
              ],
            ),
          ),
    );
    if (!mounted || optional == null) return;
    await _mutate(
      () => _repository.setSlotsOptional(ids, optional, setupId: setup.id),
      clearSelection: true,
    );
  }

  Future<void> _removeSelected() async {
    final setup = _currentSetup;
    if (setup == null) return;
    final ids = _orderedSelection;
    await _mutate(
      () => _repository.removeSlots(ids, setupId: setup.id),
      clearSelection: true,
    );
  }

  Future<void> _startSetup(WorkoutSetup setup) async {
    final plan = await _repository.launchPlanForSetup(setup.id);
    if (!mounted) return;
    final all = context.read<ExerciseProvider>().exercises;
    final byId = {for (final exercise in all) exercise.id: exercise};
    final exercises =
        plan.exerciseIds.map((id) => byId[id]).whereType<Exercise>().toList();
    if (exercises.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.addExercisesToStart)));
      return;
    }
    // Runtime bridge IDs are assigned without hash collisions and frozen in the session snapshot.
    var nextId = 0;
    final runtimeIds = <String, int>{};
    int runtimeId(String id) => runtimeIds.putIfAbsent(id, () => ++nextId);
    final sessionGroups = <WorkoutSessionPlanGroup>[];
    final groupSelections = <int, int>{};
    final slotSelections = <int, int>{};
    final slotIds = <int?>[];
    for (final group in plan.setup.groups) {
      final variants = <WorkoutSessionPlanGroupVariant>[];
      for (final variant in group.variants) {
        final slots = <WorkoutSessionPlanSlot>[];
        for (final slot in variant.slots) {
          final id = runtimeId(slot.id);
          slots.add(
            WorkoutSessionPlanSlot(
              id: id,
              exerciseId: slot.localExerciseId,
              isOptional: slot.isOptional,
              alternativeExerciseIds: slot.alternativeLocalExerciseIds,
            ),
          );
          if (variant.id == group.selectedVariantId) {
            slotSelections[id] = slot.localExerciseId;
            slotIds.add(id);
          }
        }
        variants.add(
          WorkoutSessionPlanGroupVariant(
            id: runtimeId(variant.id),
            name: variant.name,
            slots: slots,
          ),
        );
      }
      final groupId = runtimeId(group.id);
      final selected = runtimeId(group.selectedVariantId);
      groupSelections[groupId] = selected;
      sessionGroups.add(
        WorkoutSessionPlanGroup(
          workoutGroupId: groupId,
          sourceId: group.id,
          name: group.name,
          kind: group.kind,
          selectedGroupVariantId: selected,
          variants: variants,
        ),
      );
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => WorkoutRunScreen(
              workout: _workout,
              exercises: exercises,
              autoStart: true,
              workoutSlotIds: slotIds,
              initialSlotSelections: slotSelections,
              initialGroupSelections: groupSelections,
              sessionPlanGroups: sessionGroups,
              allExercises: all,
              canonicalWorkoutSetupId: setup.id,
              canonicalProfileId: setup.profile?.id,
              persistLegacyPlanSelections: false,
            ),
      ),
    );
  }

  Future<void> _launch() async {
    if (_busy || _setups.isEmpty) return;
    final active = context.read<ActiveWorkoutProvider>();
    if (active.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.finishActiveWorkoutFirst)),
      );
      return;
    }
    WorkoutSetup? selected;
    if (_setups.length == 1) {
      selected = _setups.single;
    } else {
      selected = await showModalBottomSheet<WorkoutSetup>(
        context: context,
        showDragHandle: true,
        builder:
            (c) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final setup in _setups)
                    ListTile(
                      leading: Icon(
                        setup.isDefault
                            ? Icons.star_rounded
                            : Icons.fitness_center,
                      ),
                      title: Text(_setupLabel(setup)),
                      subtitle: Text(
                        c.l10n.setupExercisesCount(setup.exerciseCount),
                      ),
                      onTap: () => Navigator.pop(c, setup),
                    ),
                ],
              ),
            ),
      );
    }
    if (!mounted || selected == null) return;
    try {
      await _startSetup(selected);
    } catch (error, stack) {
      debugPrint('Starting workout: $error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.workoutEditFailed)));
      }
    }
  }

  String _setupLabel(WorkoutSetup setup) {
    final profile = setup.profile?.name;
    if (profile == null) {
      return '${setup.name} · ${context.l10n.withoutProfile}';
    }
    return profile == setup.name ? profile : '${setup.name} · $profile';
  }

  Future<void> _addToWeek() async {
    final day = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder:
          (c) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (var i = 1; i <= 7; i++)
                  ListTile(
                    title: Text(_weekdayLabel(c, i)),
                    onTap: () => Navigator.pop(c, i),
                  ),
              ],
            ),
          ),
    );
    if (!mounted || day == null) return;
    await _mutate(() async {
      await _repository.assignToDay(
        workoutId: widget.workout.canonicalId,
        weekday: day,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<WorkoutProvider>();
    final workout = _workout;
    final setup = _currentSetup;
    final selecting = _selectedSlotIds.isNotEmpty;
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selecting) setState(_selectedSlotIds.clear);
      },
      child: Scaffold(
        appBar: AppBar(
          leading:
              selecting
                  ? IconButton(
                    tooltip: l10n.cancel,
                    onPressed: () => setState(_selectedSlotIds.clear),
                    icon: const Icon(Icons.close),
                  )
                  : null,
          title:
              selecting
                  ? Text(l10n.selectedExercises(_selectedSlotIds.length))
                  : InkWell(
                    onTap: _busy ? null : _rename,
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            workout.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.edit_outlined, size: 18),
                      ],
                    ),
                  ),
          actions:
              selecting
                  ? []
                  : [
                    IconButton(
                      tooltip: l10n.addToWeeklyPlanner,
                      onPressed: _busy ? null : _addToWeek,
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ],
        ),
        body:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                  child: TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retry),
                  ),
                )
                : ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          GoalIcon(
                            workout.primaryGoalCode,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            goalLabel(context, workout.primaryGoalCode),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const Spacer(),
                          if (_busy)
                            const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: setup?.id,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: l10n.selectSetup,
                            ),
                            items: [
                              for (final value in _setups)
                                DropdownMenuItem(
                                  value: value.id,
                                  child: Text(
                                    _setupLabel(value),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged:
                                _busy
                                    ? null
                                    : (id) => setState(() {
                                      _setupId = id;
                                      _selectedSlotIds.clear();
                                    }),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.createSetup,
                          onPressed: _busy ? null : _addSetup,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    if (setup != null && !setup.isDefault)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed:
                              _busy
                                  ? null
                                  : () => _mutate(
                                    () => _repository.setDefaultSetup(setup.id),
                                  ),
                          icon: const Icon(Icons.star_outline, size: 18),
                          label: Text(l10n.makeDefaultSetup),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (setup != null)
                      WorkoutGroupEditor(
                        setup: setup,
                        exercises: context.watch<ExerciseProvider>().exercises,
                        selectedIds: _selectedSlotIds,
                        busy: _busy,
                        scrollController: _scroll,
                        onToggle:
                            (id) => setState(() {
                              if (!_selectedSlotIds.add(id)) {
                                _selectedSlotIds.remove(id);
                              }
                            }),
                        onAdd: _addExercises,
                        onMove:
                            (slot, group, index) => _mutate(
                              () => _repository.moveSlotToGroup(
                                slotId: slot,
                                setupId: setup.id,
                                targetGroupId: group,
                                targetIndex: index,
                              ),
                            ),
                        onReorderGroups:
                            (ids) => _mutate(
                              () => _repository.reorderGroups(
                                workout.canonicalId,
                                ids,
                              ),
                            ),
                      ),
                  ],
                ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child:
                selecting
                    ? LayoutBuilder(
                      builder: (context, constraints) {
                        final compact =
                            constraints.maxWidth >= 320 &&
                            MediaQuery.textScalerOf(context).scale(14) <= 18;
                        Widget action(
                          IconData icon,
                          String label,
                          VoidCallback callback,
                        ) {
                          if (!compact) {
                            return TextButton.icon(
                              onPressed: _busy ? null : callback,
                              icon: Icon(icon),
                              label: Text(label),
                            );
                          }
                          return Expanded(
                            child: TextButton(
                              onPressed: _busy ? null : callback,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon),
                                  const SizedBox(height: 4),
                                  Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.labelMedium,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final buttons = [
                          action(
                            Icons.folder_copy_outlined,
                            l10n.group,
                            _groupSelected,
                          ),
                          action(
                            Icons.tune,
                            l10n.exerciseRequirement,
                            _chooseStatus,
                          ),
                          action(
                            Icons.delete_outline,
                            l10n.remove,
                            _removeSelected,
                          ),
                        ];
                        if (compact) return Row(children: buttons);
                        return Wrap(
                          alignment: WrapAlignment.spaceEvenly,
                          children: buttons,
                        );
                      },
                    )
                    : FilledButton.icon(
                      onPressed: _busy || setup == null ? null : _launch,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l10n.start),
                    ),
          ),
        ),
      ),
    );
  }
}

class _BasicsStep extends StatelessWidget {
  const _BasicsStep({
    required this.formKey,
    required this.name,
    required this.description,
    required this.goal,
    required this.onGoalChanged,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final TextEditingController description;
  final WorkoutPrimaryGoal goal;
  final ValueChanged<WorkoutPrimaryGoal> onGoalChanged;

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: ListView(
      children: [
        Text(
          context.l10n.workoutBasics,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(context.l10n.choosePrimaryGoal),
        const SizedBox(height: 20),
        TextFormField(
          controller: name,
          autofocus: true,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: context.l10n.workoutName),
          validator:
              (value) =>
                  value == null || value.trim().isEmpty
                      ? context.l10n.nameRequired
                      : null,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: description,
          maxLines: 3,
          decoration: InputDecoration(labelText: context.l10n.description),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final value in WorkoutPrimaryGoal.values)
              _GoalChoice(
                value: value,
                selected: value == goal,
                onTap: () => onGoalChanged(value),
              ),
          ],
        ),
      ],
    ),
  );
}

class _GoalChoice extends StatelessWidget {
  const _GoalChoice({
    required this.value,
    required this.selected,
    required this.onTap,
  });
  final WorkoutPrimaryGoal value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: goalLabel(context, value.code),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 148,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                selected
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border:
                selected ? Border.all(color: scheme.primary, width: 2) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GoalIcon(
                value.code,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                goalLabel(context, value.code),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.profiles,
    required this.profileId,
    required this.onProfileChanged,
  });
  final List<TrainingProfileRecord> profiles;
  final String? profileId;
  final ValueChanged<String?> onProfileChanged;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Text(
        context.l10n.workoutSetup,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      Text(context.l10n.chooseSetupProfile),
      const SizedBox(height: 24),
      DropdownButtonFormField<String?>(
        value: profileId,
        isExpanded: true,
        decoration: InputDecoration(labelText: context.l10n.trainingProfile),
        items: [
          DropdownMenuItem(
            value: null,
            child: Text(context.l10n.withoutProfile),
          ),
          for (final profile in profiles)
            DropdownMenuItem(value: profile.id, child: Text(profile.name)),
        ],
        onChanged: onProfileChanged,
      ),
    ],
  );
}

class _ExercisesStep extends StatelessWidget {
  const _ExercisesStep({required this.count, required this.onSelect});
  final int count;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.format_list_bulleted_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.workoutExercises,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.setupExercisesCount(count),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onSelect,
            icon: const Icon(Icons.add_rounded),
            label: Text(context.l10n.addExercise),
          ),
        ],
      ),
    ),
  );
}

class _SetupDraft {
  const _SetupDraft(this.name, this.profileId);
  final String name;
  final String? profileId;
}

class _SetupEditorSheet extends StatefulWidget {
  const _SetupEditorSheet({required this.excludedProfileIds});
  final Set<String> excludedProfileIds;
  @override
  State<_SetupEditorSheet> createState() => _SetupEditorSheetState();
}

class _SetupEditorSheetState extends State<_SetupEditorSheet> {
  List<TrainingProfileRecord> _profiles = const [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await TrainingProfileRepository().profiles();
    if (mounted) setState(() => _profiles = values);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.chooseSetupProfile,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(context.l10n.withoutProfile),
            subtitle: Text(context.l10n.defaultSetup),
            onTap:
                () => Navigator.pop(
                  context,
                  _SetupDraft(context.l10n.defaultSetup, null),
                ),
          ),
          for (final profile in _profiles.where(
            (value) => !widget.excludedProfileIds.contains(value.id),
          ))
            ListTile(
              leading: const Icon(Icons.home_work_outlined),
              title: Text(profile.name),
              subtitle: Text(context.l10n.profileSetup),
              onTap:
                  () => Navigator.pop(
                    context,
                    _SetupDraft(profile.name, profile.id),
                  ),
            ),
        ],
      ),
    ),
  );
}

String _weekdayLabel(BuildContext context, int day) =>
    [
      context.l10n.monday,
      context.l10n.tuesday,
      context.l10n.wednesday,
      context.l10n.thursday,
      context.l10n.friday,
      context.l10n.saturday,
      context.l10n.sunday,
    ][day - 1];
