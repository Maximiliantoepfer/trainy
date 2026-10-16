import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/catalog_exercise.dart';
import '../models/exercise.dart';
import '../models/training_profile.dart';
import '../models/workout.dart';
import '../models/workout_plan.dart';
import '../models/workout_planning.dart';
import '../providers/exercise_provider.dart';
import '../providers/workout_provider.dart';
import '../repositories/training_profile_repository.dart';
import '../repositories/workout_planning_repository.dart';
import '../services/catalog_repository.dart';
import '../utils/exercise_localization.dart';
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
    final result = await showModalBottomSheet<_ExercisePickerResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (_) => _ExercisePickerSheet(
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
  const WorkoutDetailScreen({super.key, required this.workout});

  final Workout workout;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final WorkoutPlanningRepository _repository = WorkoutPlanningRepository();
  List<WorkoutSetup> _setups = const [];
  final Set<String> _selectedSlotIds = <String>{};
  String? _setupId;
  bool _loading = true;
  Object? _error;

  WorkoutSetup? get _currentSetup {
    for (final setup in _setups) {
      if (setup.id == _setupId) return setup;
    }
    return _setups.isEmpty ? null : _setups.first;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final setups = await _repository.setupsForWorkout(
        widget.workout.canonicalId,
      );
      if (!mounted) return;
      setState(() {
        _setups = setups;
        _setupId =
            setups.any((setup) => setup.id == _setupId)
                ? _setupId
                : (setups.isEmpty ? null : setups.first.id);
        _selectedSlotIds.removeWhere(
          (id) =>
              !setups
                  .expand((setup) => setup.groups)
                  .expand((group) => group.selectedVariant.slots)
                  .any((slot) => slot.id == id),
        );
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addSetup() async {
    final usedProfileIds =
        _setups.map((setup) => setup.profile?.id).whereType<String>().toSet();
    final result = await showModalBottomSheet<_SetupDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SetupEditorSheet(excludedProfileIds: usedProfileIds),
    );
    if (result == null || !mounted) return;
    await _repository.createSetup(
      workoutId: widget.workout.canonicalId,
      name: result.name,
      profileId: result.profileId,
      copyFromSetupId: _setupId,
    );
    await _load();
  }

  Future<void> _addExercises() async {
    final setup = _currentSetup;
    if (setup == null) return;
    final workoutProvider = context.read<WorkoutProvider>();
    final result = await showModalBottomSheet<_ExercisePickerResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (_) => _ExercisePickerSheet(
            availableEquipment: setup.profile?.equipmentCodes,
          ),
    );
    if (result == null || !mounted) return;
    final provider = context.read<ExerciseProvider>();
    final locale = Localizations.localeOf(context).languageCode;
    final next = <int>{...result.exerciseIds};
    for (final catalogId in result.catalogIds) {
      final item = CatalogRepository.instance.localized(catalogId, locale);
      if (item != null) {
        next.add(await provider.addCatalogExercise(item));
      }
    }
    if (!mounted) return;
    await _repository.addExercisesToCore(
      setupId: setup.id,
      exerciseIds: next.toList(growable: false),
    );
    await workoutProvider.loadWorkouts();
    await _load();
  }

  Future<void> _groupSelectedSlots() async {
    final setup = _currentSetup;
    if (setup == null || _selectedSlotIds.isEmpty) return;
    final name = await showTextPromptDialog(
      context: context,
      title: context.l10n.groupSelectedExercises,
      label: context.l10n.groupName,
      submitLabel: context.l10n.save,
      cancelLabel: context.l10n.cancel,
      requiredMessage: context.l10n.nameRequired,
    );
    if (name == null || !mounted) return;
    await _repository.createGroupFromSlots(
      setupId: setup.id,
      name: name,
      slotIds: _selectedSlotIds,
    );
    if (mounted) {
      setState(_selectedSlotIds.clear);
      await _load();
    }
  }

  Future<void> _startSetup(WorkoutSetup setup) async {
    final plan = await _repository.launchPlanForSetup(setup.id);
    if (!mounted) return;
    final allExercises = context.read<ExerciseProvider>().exercises;
    final byId = {for (final exercise in allExercises) exercise.id: exercise};
    final exercises = plan.exerciseIds
        .map((id) => byId[id])
        .whereType<Exercise>()
        .toList(growable: false);
    if (exercises.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.addExercisesToStart)));
      return;
    }
    final sessionGroups = <WorkoutSessionPlanGroup>[];
    final groupSelections = <int, int>{};
    final slotSelections = <int, int>{};
    final slotAlternatives = <int, List<Exercise>>{};
    final slotIds = <int?>[];
    for (final group in setup.groups) {
      final groupId = _runtimeId(group.id);
      final variants = <WorkoutSessionPlanGroupVariant>[];
      for (final variant in group.variants) {
        final slots = <WorkoutSessionPlanSlot>[];
        for (final slot in variant.slots) {
          final slotId = _runtimeId(slot.id);
          slots.add(
            WorkoutSessionPlanSlot(
              id: slotId,
              exerciseId: slot.localExerciseId,
              isOptional: slot.isOptional,
              alternativeExerciseIds: slot.alternativeLocalExerciseIds,
            ),
          );
          if (variant.id == group.selectedVariantId) {
            slotSelections[slotId] = slot.localExerciseId;
            slotIds.add(slotId);
            final candidates = [
              byId[slot.localExerciseId],
              ...slot.alternativeLocalExerciseIds.map((id) => byId[id]),
            ].whereType<Exercise>().toList(growable: false);
            if (candidates.length > 1) slotAlternatives[slotId] = candidates;
          }
        }
        variants.add(
          WorkoutSessionPlanGroupVariant(
            id: _runtimeId(variant.id),
            name: variant.name,
            slots: slots,
          ),
        );
      }
      if (variants.isEmpty) continue;
      final selected = _runtimeId(group.selectedVariantId);
      groupSelections[groupId] = selected;
      sessionGroups.add(
        WorkoutSessionPlanGroup(
          workoutGroupId: groupId,
          name: group.name,
          selectedGroupVariantId: selected,
          variants: variants,
        ),
      );
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => WorkoutRunScreen(
              workout: widget.workout,
              exercises: exercises,
              autoStart: true,
              workoutSlotIds: slotIds,
              slotAlternatives: slotAlternatives,
              initialSlotSelections: slotSelections,
              initialGroupSelections: groupSelections,
              sessionPlanGroups: sessionGroups,
              allExercises: allExercises,
              canonicalWorkoutSetupId: setup.id,
              canonicalProfileId: setup.profile?.id,
              persistLegacyPlanSelections: false,
            ),
      ),
    );
  }

  Future<void> _launch() async {
    if (_setups.isEmpty) return;
    if (_setups.length == 1) return _startSetup(_setups.single);
    final setup = await showModalBottomSheet<WorkoutSetup>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text(
                  sheetContext.l10n.selectSetup,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                for (final value in _setups)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: GoalIcon(widget.workout.primaryGoalCode),
                    title: Text(value.name),
                    subtitle: Text(
                      '${value.profile?.name ?? sheetContext.l10n.withoutProfile} · ${sheetContext.l10n.setupExercisesCount(value.exerciseCount)}',
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(value),
                  ),
              ],
            ),
          ),
    );
    if (setup != null && mounted) await _startSetup(setup);
  }

  Future<void> _moveSlot(_SlotDrag drag, String groupId, int index) async {
    final setup = _currentSetup;
    if (setup == null || drag.setupId != setup.id) return;
    await _repository.moveSlotToGroup(
      slotId: drag.slotId,
      setupId: setup.id,
      targetGroupId: groupId,
      targetIndex: index,
    );
    if (mounted) await _load();
  }

  Future<void> _setSelectedOptional(bool optional) async {
    await _repository.setSlotsOptional(_selectedSlotIds, optional);
    if (mounted) {
      setState(_selectedSlotIds.clear);
      await _load();
    }
  }

  Future<void> _removeSelectedSlots() async {
    await _repository.removeSlots(_selectedSlotIds);
    if (mounted) {
      setState(_selectedSlotIds.clear);
      await _load();
    }
  }

  Future<void> _makeDefaultSetup() async {
    final setup = _currentSetup;
    if (setup == null || setup.isDefault) return;
    await _repository.setDefaultSetup(setup.id);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final setup = _currentSetup;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.name),
        actions: [
          IconButton(
            tooltip: l10n.addToWeeklyPlanner,
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => _showAddToWeekPlan(context),
          ),
        ],
      ),
      floatingActionButton:
          setup == null
              ? null
              : FloatingActionButton.extended(
                onPressed: _launch,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.getStarted),
              ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.retry),
                ),
              )
              : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                children: [
                  Card(
                    color: scheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: GoalIcon(
                              widget.workout.primaryGoalCode,
                              color: scheme.onPrimaryContainer,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.primaryGoal,
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                Text(
                                  goalLabel(
                                    context,
                                    widget.workout.primaryGoalCode,
                                  ),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                if (widget.workout.description.isNotEmpty)
                                  Text(widget.workout.description),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.setups,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addSetup,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(l10n.createSetup),
                      ),
                    ],
                  ),
                  if (_setups.isEmpty)
                    Text(l10n.noSetups)
                  else ...[
                    DropdownButtonFormField<String>(
                      value: setup?.id,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.selectSetup),
                      items: [
                        for (final value in _setups)
                          DropdownMenuItem(
                            value: value.id,
                            child: Text(
                              '${value.name} · ${value.profile?.name ?? l10n.withoutProfile}',
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() => _setupId = value),
                    ),
                    const SizedBox(height: 16),
                    if (setup != null)
                      _SetupContents(
                        setup: setup,
                        selectedSlotIds: _selectedSlotIds,
                        onToggleSlot:
                            (slot) => setState(() {
                              if (!_selectedSlotIds.add(slot.id)) {
                                _selectedSlotIds.remove(slot.id);
                              }
                            }),
                        onDrop: _moveSlot,
                        onAddExercises: _addExercises,
                        onGroupSelected: _groupSelectedSlots,
                        onSetOptional: _setSelectedOptional,
                        onRemoveSelected: _removeSelectedSlots,
                      ),
                    if (setup != null && !setup.isDefault)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _makeDefaultSetup,
                          icon: const Icon(Icons.star_outline_rounded),
                          label: Text(l10n.makeDefaultSetup),
                        ),
                      ),
                  ],
                ],
              ),
    );
  }

  Future<void> _showAddToWeekPlan(BuildContext context) async {
    final l10n = context.l10n;
    final workoutProvider = context.read<WorkoutProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final day = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: List.generate(
                7,
                (index) => ListTile(
                  title: Text(_weekdayLabel(sheetContext, index + 1)),
                  onTap: () => Navigator.pop(sheetContext, index + 1),
                ),
              ),
            ),
          ),
    );
    if (day == null) return;
    try {
      await _repository.assignToDay(
        workoutId: widget.workout.canonicalId,
        weekday: day,
      );
      if (!mounted || !context.mounted) return;
      await workoutProvider.loadWorkouts();
      messenger.showSnackBar(SnackBar(content: Text(l10n.planned)));
    } on StateError {
      if (mounted && context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.workoutAlreadyPlanned)),
        );
      }
    }
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

class _SetupContents extends StatelessWidget {
  const _SetupContents({
    required this.setup,
    required this.selectedSlotIds,
    required this.onToggleSlot,
    required this.onDrop,
    required this.onAddExercises,
    required this.onGroupSelected,
    required this.onSetOptional,
    required this.onRemoveSelected,
  });
  final WorkoutSetup setup;
  final Set<String> selectedSlotIds;
  final ValueChanged<WorkoutSetupSlot> onToggleSlot;
  final Future<void> Function(_SlotDrag, String, int) onDrop;
  final VoidCallback onAddExercises;
  final VoidCallback onGroupSelected;
  final Future<void> Function(bool) onSetOptional;
  final Future<void> Function() onRemoveSelected;

  @override
  Widget build(BuildContext context) {
    final groups = List<WorkoutSetupGroup>.from(setup.groups)
      ..sort((left, right) => _groupRank(left).compareTo(_groupRank(right)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (setup.profile != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Chip(
              avatar: const Icon(Icons.home_work_outlined, size: 18),
              label: Text(setup.profile!.name),
            ),
          ),
        if (selectedSlotIds.isNotEmpty)
          _SelectionToolbar(
            selectedCount: selectedSlotIds.length,
            onGroup: onGroupSelected,
            onCore: () => onSetOptional(false),
            onOptional: () => onSetOptional(true),
            onRemove: onRemoveSelected,
          ),
        for (final group in groups) ...[
          _WorkoutDropZone(
            setup: setup,
            group: group,
            selectedSlotIds: selectedSlotIds,
            onToggleSlot: onToggleSlot,
            onDrop: onDrop,
          ),
          const SizedBox(height: 16),
        ],
        OutlinedButton.icon(
          onPressed: onAddExercises,
          icon: const Icon(Icons.add_rounded),
          label: Text(context.l10n.addExercises),
        ),
      ],
    );
  }

  static int _groupRank(WorkoutSetupGroup group) => switch (group.kind) {
    WorkoutGroupKind.warmup => 0,
    WorkoutGroupKind.core => 1,
    WorkoutGroupKind.custom => 10 + group.sortOrder,
    WorkoutGroupKind.cooldown => 1000000,
  };
}

class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({
    required this.selectedCount,
    required this.onGroup,
    required this.onCore,
    required this.onOptional,
    required this.onRemove,
  });
  final int selectedCount;
  final VoidCallback onGroup;
  final VoidCallback onCore;
  final VoidCallback onOptional;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.selectedExercises(selectedCount)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: onGroup,
                icon: const Icon(Icons.folder_copy_outlined),
                label: Text(context.l10n.group),
              ),
              TextButton(onPressed: onCore, child: Text(context.l10n.makeCore)),
              TextButton(
                onPressed: onOptional,
                child: Text(context.l10n.makeOptional),
              ),
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(context.l10n.remove),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkoutDropZone extends StatelessWidget {
  const _WorkoutDropZone({
    required this.setup,
    required this.group,
    required this.selectedSlotIds,
    required this.onToggleSlot,
    required this.onDrop,
  });
  final WorkoutSetup setup;
  final WorkoutSetupGroup group;
  final Set<String> selectedSlotIds;
  final ValueChanged<WorkoutSetupSlot> onToggleSlot;
  final Future<void> Function(_SlotDrag, String, int) onDrop;

  @override
  Widget build(BuildContext context) {
    final slots = group.selectedVariant.slots;
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<_SlotDrag>(
      onWillAcceptWithDetails: (details) => details.data.setupId == setup.id,
      onAcceptWithDetails:
          (details) => onDrop(details.data, group.id, slots.length),
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
                        : scheme.outlineVariant.withValues(alpha: 0.5),
                width: candidates.isNotEmpty ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _groupLabel(context, group),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (slots.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      context.l10n.dropExercisesHere,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                for (var index = 0; index < slots.length; index++)
                  DragTarget<_SlotDrag>(
                    onWillAcceptWithDetails:
                        (details) =>
                            details.data.setupId == setup.id &&
                            details.data.slotId != slots[index].id,
                    onAcceptWithDetails:
                        (details) => onDrop(details.data, group.id, index),
                    builder:
                        (context, candidates, _) => _SlotTile(
                          setupId: setup.id,
                          slot: slots[index],
                          selected: selectedSlotIds.contains(slots[index].id),
                          highlighted: candidates.isNotEmpty,
                          onToggle: () => onToggleSlot(slots[index]),
                        ),
                  ),
              ],
            ),
          ),
    );
  }
}

class _SlotDrag {
  const _SlotDrag({required this.setupId, required this.slotId});
  final String setupId;
  final String slotId;
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.setupId,
    required this.slot,
    required this.selected,
    required this.highlighted,
    required this.onToggle,
  });
  final String setupId;
  final WorkoutSetupSlot slot;
  final bool selected;
  final bool highlighted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    Exercise? exercise;
    for (final value in context.watch<ExerciseProvider>().exercises) {
      if (value.id == slot.localExerciseId) {
        exercise = value;
        break;
      }
    }
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected || highlighted ? scheme.primaryContainer : null,
      child: ListTile(
        onLongPress: onToggle,
        leading: Icon(
          selected
              ? Icons.check_circle_rounded
              : (slot.isOptional
                  ? Icons.add_circle_outline_rounded
                  : Icons.check_circle_rounded),
        ),
        title: Text(
          exercise == null
              ? context.l10n.exerciseLabel
              : displayExerciseName(context, exercise),
        ),
        subtitle:
            slot.isOptional
                ? Text(context.l10n.optionalExercise)
                : Text(context.l10n.coreExercise),
        trailing: Draggable<_SlotDrag>(
          data: _SlotDrag(setupId: setupId, slotId: slot.id),
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 260,
              child: Card(
                child: ListTile(
                  title: Text(
                    exercise == null
                        ? context.l10n.exerciseLabel
                        : displayExerciseName(context, exercise),
                  ),
                ),
              ),
            ),
          ),
          childWhenDragging: const SizedBox(width: 48, height: 48),
          child: Semantics(
            label: context.l10n.dragExercise,
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.drag_indicator_rounded),
            ),
          ),
        ),
      ),
    );
  }
}

String _groupLabel(BuildContext context, WorkoutSetupGroup group) =>
    switch (group.kind) {
      WorkoutGroupKind.warmup => context.l10n.warmupGroup,
      WorkoutGroupKind.core => context.l10n.coreExercisesGroup,
      WorkoutGroupKind.cooldown => context.l10n.cooldownGroup,
      WorkoutGroupKind.custom => group.name,
    };

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

class _ExercisePickerResult {
  const _ExercisePickerResult(this.exerciseIds, this.catalogIds);
  final Set<int> exerciseIds;
  final Set<String> catalogIds;
}

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet({
    this.selectedExerciseIds = const {},
    this.selectedCatalogIds = const {},
    this.availableEquipment,
  });
  final Set<int> selectedExerciseIds;
  final Set<String> selectedCatalogIds;
  final Set<String>? availableEquipment;
  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  final _search = TextEditingController();
  late final Set<int> _selected = Set<int>.from(widget.selectedExerciseIds);
  late final Set<String> _catalog = Set<String>.from(widget.selectedCatalogIds);
  bool _showAll = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = CatalogRepository.normalizeSearchText(_search.text);
    final exercises =
        context.watch<ExerciseProvider>().exercises.where((exercise) {
          if (query.isEmpty) return true;
          return CatalogRepository.normalizeSearchText(
            '${displayExerciseName(context, exercise)} ${exercise.description}',
          ).contains(query);
        }).toList();
    final catalog = CatalogRepository.instance;
    final locale = Localizations.localeOf(context).languageCode;
    final allCatalogItems =
        catalog.isLoaded
            ? catalog
                .search(locale, CatalogQuery(text: _search.text))
                .take(80)
                .toList()
            : const <LocalizedCatalogExercise>[];
    final matchingCatalogItems =
        widget.availableEquipment == null || widget.availableEquipment!.isEmpty
            ? allCatalogItems
            : catalog
                .search(
                  locale,
                  CatalogQuery(
                    text: _search.text,
                    availableEquipment: widget.availableEquipment,
                  ),
                )
                .take(80)
                .toList();
    final catalogItems =
        _showAll || matchingCatalogItems.length == allCatalogItems.length
            ? allCatalogItems
            : [
              ...matchingCatalogItems,
              ...allCatalogItems.where(
                (item) =>
                    !matchingCatalogItems.any(
                      (match) => match.definition.id == item.definition.id,
                    ),
              ),
            ];
    final materialized = {
      for (final exercise in context.watch<ExerciseProvider>().exercises)
        if (exercise.catalogId != null) exercise.catalogId!,
    };
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(context.l10n.selectExercise),
        actions: [
          TextButton(
            onPressed:
                () => Navigator.pop(
                  context,
                  _ExercisePickerResult(_selected, _catalog),
                ),
            child: Text(context.l10n.apply),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: context.l10n.searchExercise,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (widget.availableEquipment != null &&
              widget.availableEquipment!.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextButton.icon(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  icon: Icon(
                    _showAll ? Icons.tune_rounded : Icons.filter_alt_outlined,
                  ),
                  label: Text(
                    _showAll
                        ? context.l10n.prioritizeProfileExercises
                        : context.l10n.showAllExercises,
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView(
              children: [
                for (final exercise in exercises)
                  CheckboxListTile(
                    value: _selected.contains(exercise.id),
                    title: Text(displayExerciseName(context, exercise)),
                    subtitle:
                        exercise.catalogId == null
                            ? Text(context.l10n.own)
                            : null,
                    onChanged:
                        (value) => setState(
                          () =>
                              value == true
                                  ? _selected.add(exercise.id)
                                  : _selected.remove(exercise.id),
                        ),
                  ),
                for (final item in catalogItems)
                  if (!materialized.contains(item.definition.id))
                    CheckboxListTile(
                      value: _catalog.contains(item.definition.id),
                      title: Text(item.content.name),
                      subtitle: Text(context.l10n.standard),
                      onChanged:
                          (value) => setState(
                            () =>
                                value == true
                                    ? _catalog.add(item.definition.id)
                                    : _catalog.remove(item.definition.id),
                          ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

int _runtimeId(String value) => value.hashCode & 0x3fffffff;

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
