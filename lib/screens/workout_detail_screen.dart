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
import '../widgets/library_exercise_thumbnail.dart';
import '../providers/workout_provider.dart';
import '../providers/training_profile_provider.dart';
import '../utils/uuid_v4.dart';
import '../utils/exercise_localization.dart';
import '../repositories/training_profile_repository.dart';
import '../repositories/workout_planning_repository.dart';
import '../services/catalog_repository.dart';
import '../utils/goal_utils.dart';
import '../widgets/modal_form_dialogs.dart';
import '../widgets/training_profile_settings_card.dart';
import 'workout_run_screen.dart';

/// Guided three-step workflow used for all newly created workouts.
class WorkoutEditorScreen extends StatefulWidget {
  const WorkoutEditorScreen({super.key, this.profileStore});
  final TrainingProfileStore? profileStore;

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
  late final TrainingProfileStore _profileStore =
      widget.profileStore ??
      context.read<TrainingProfileProvider?>() ??
      TrainingProfileRepository();
  bool _profilesLoading = true;
  bool _profileEditorOpen = false;
  bool _pickerOpen = false;
  Object? _profileError;
  Object? _saveError;
  List<ExerciseSelectionRef> _selection = [];
  final _creationId = UuidV4.generate();
  bool _preferenceLoaded = false;
  bool _allowExit = false;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    if (_profileStore is Listenable) {
      (_profileStore as Listenable).addListener(_profilesChanged);
    }
  }

  void _profilesChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProfiles();
    });
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _profilesLoading = true;
      _profileError = null;
    });
    try {
      final profiles = await _profileStore.profiles();
      final preferred =
          !_preferenceLoaded ? await _profileStore.selectedProfileId() : null;
      if (mounted) {
        setState(() {
          _profiles = profiles;
          if (!_preferenceLoaded) {
            _profileId =
                profiles.any((p) => p.id == preferred) ? preferred : null;
            _preferenceLoaded = true;
          } else if (!profiles.any((p) => p.id == _profileId)) {
            _profileId = null;
          }
          if (_profileId != null) {
            _setupName.text =
                profiles.firstWhere((p) => p.id == _profileId).name;
          }
        });
      }
    } catch (error, stack) {
      debugPrint('Loading workout profiles failed: $error');
      debugPrintStack(stackTrace: stack);
      if (mounted) setState(() => _profileError = error);
    } finally {
      if (mounted) setState(() => _profilesLoading = false);
    }
  }

  void _selectProfile(String? id) => setState(() {
    _profileId = id;
    _setupName.text =
        id == null
            ? context.l10n.defaultSetup
            : _profiles.firstWhere((profile) => profile.id == id).name;
  });

  Future<void> _chooseProfile() async {
    if (_profileEditorOpen) return;
    setState(() => _profileEditorOpen = true);
    try {
      final value = await showModalBottomSheet<_SetupDraft>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder:
            (_) => _SetupEditorSheet(
              excludedProfileIds: const {},
              store: _profileStore,
            ),
      );
      if (!mounted || value == null) return;
      final profiles = await _profileStore.profiles();
      if (!mounted) return;
      setState(() => _profiles = profiles);
      _selectProfile(value.profileId);
    } catch (error) {
      if (mounted) setState(() => _profileError = error);
    } finally {
      if (mounted) setState(() => _profileEditorOpen = false);
    }
  }

  @override
  void dispose() {
    if (_profileStore is Listenable) {
      (_profileStore as Listenable).removeListener(_profilesChanged);
    }
    _name.dispose();
    _description.dispose();
    _setupName.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_saving) return;
    if (_step == 0 && !(_formKey.currentState?.validate() ?? false)) return;
    if (_step >= 1 &&
        !_profiles.any((p) => p.id == _profileId && !p.isArchived)) {
      setState(() => _step = 1);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.profileRequired)));
      return;
    }
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final exerciseProvider = context.read<ExerciseProvider>();
      final locale = Localizations.localeOf(context).languageCode;
      final exercises = await ExercisePickerResult.ordered(
        _selection,
      ).materialize(exerciseProvider, locale);
      if (!mounted || !context.mounted) return;
      final workout = await context.read<WorkoutProvider>().createWorkout(
        name: _name.text,
        description: _description.text,
        primaryGoal: _goal,
        setupName: _setupName.text,
        profileId: _profileId,
        exerciseIds: exercises.map((e) => e.id).toList(growable: false),
        creationId: _creationId,
      );
      if (mounted) {
        _allowExit = true;
        Navigator.of(context).pop(workout);
      }
    } catch (error, stack) {
      debugPrint('Creating workout failed: $error');
      debugPrintStack(stackTrace: stack);
      if (mounted) setState(() => _saveError = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _selectExercises() async {
    if (_pickerOpen) return;
    _pickerOpen = true;
    try {
      final result = await showModalBottomSheet<ExercisePickerResult>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder:
            (_) => WorkoutExercisePicker(
              selectedReferences: _selection,
              availableEquipment:
                  _profiles
                      .where((p) => p.id == _profileId)
                      .firstOrNull
                      ?.equipmentCodes,
            ),
      );
      if (result != null && mounted) {
        setState(() {
          _selection = result.references.toList();
        });
      }
    } finally {
      _pickerOpen = false;
    }
  }

  Future<void> _back() async {
    if (_saving) return;
    if (_step > 0) {
      setState(() => _step--);
      return;
    }
    final dirty =
        _name.text.trim().isNotEmpty ||
        _description.text.isNotEmpty ||
        _selection.isNotEmpty;
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder:
            (c) => AlertDialog(
              title: Text(c.l10n.discardWorkoutDraft),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(c.l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(c.l10n.discard),
                ),
              ],
            ),
      );
      if (discard != true || !mounted) return;
    }
    _allowExit = true;
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return PopScope(
      canPop: _allowExit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _saving ? null : _back),
          title: Text(
            _step > 0 && _name.text.trim().isNotEmpty
                ? _name.text.trim()
                : l10n.newWorkout,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(36),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                  duration:
                      MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                  child: Padding(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
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
                        loading: _profilesLoading,
                        error: _profileError,
                        onRetry: _loadProfiles,
                        onCreate:
                            _profileEditorOpen || _profilesLoading
                                ? null
                                : _chooseProfile,
                        onProfileChanged: _selectProfile,
                      ),
                      _ => _ExercisesStep(
                        selection: _selection,
                        profileName:
                            _profiles
                                .where((p) => p.id == _profileId)
                                .firstOrNull
                                ?.name ??
                            '',
                        goal: _goal,
                        onSelect: _selectExercises,
                        onRemove:
                            (index) =>
                                setState(() => _selection.removeAt(index)),
                        onReorder:
                            (from, to) => setState(() {
                              if (to > from) to--;
                              _selection.insert(to, _selection.removeAt(from));
                            }),
                      ),
                    },
                  ),
                ),
              ),
              if (_saveError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.localSaveFailed,
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : _back,
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
                                : Text(
                                  _saveError != null && _step == 2
                                      ? l10n.retry
                                      : _step == 2
                                      ? l10n.saveWorkout
                                      : l10n.next,
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    this.profileStore,
  });
  final WorkoutPlanningRepository? repository;
  final TrainingProfileStore? profileStore;

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
  late final TrainingProfileStore _profileStore =
      widget.profileStore ??
      context.read<TrainingProfileProvider?>() ??
      TrainingProfileRepository();

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
    if (_profileStore is Listenable) {
      (_profileStore as Listenable).addListener(_profileChanged);
    }
  }

  void _profileChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    if (_profileStore is Listenable) {
      (_profileStore as Listenable).removeListener(_profileChanged);
    }
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
            store: _profileStore,
            setups: _setups,
            selectedSetupId: _setupId,
            excludedProfileIds:
                _setups.map((s) => s.profile?.id).whereType<String>().toSet(),
          ),
    );
    if (!mounted || result == null) return;
    if (result.setupId != null) {
      if (result.makeDefault) {
        await _mutate(() => _repository.setDefaultSetup(result.setupId!));
      }
      if (mounted) {
        setState(() {
          _setupId = result.setupId;
          _selectedSlotIds.clear();
        });
      }
      return;
    }
    final copyId = _currentSetup?.id;
    final mode = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (c) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    c.l10n.configureWorkoutProfile,
                    style: Theme.of(c).textTheme.titleMedium,
                  ),
                ),
                if (_currentSetup?.profile == null && copyId != null)
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: Text(c.l10n.linkWorkoutProfile),
                    onTap: () => Navigator.pop(c, 'link'),
                  ),
                ListTile(
                  leading: const Icon(Icons.copy_outlined),
                  title: Text(c.l10n.copyWorkoutExercises),
                  onTap: () => Navigator.pop(c, 'copy'),
                ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text(c.l10n.emptyWorkoutProfile),
                  onTap: () => Navigator.pop(c, 'empty'),
                ),
              ],
            ),
          ),
    );
    if (!mounted || mode == null) return;
    final creationId = UuidV4.generate();
    await _mutate(() async {
      if (mode == 'link') {
        await _repository.bindProfileToSetup(
          setupId: copyId!,
          profileId: result.profileId!,
        );
        return;
      }
      final created = await _repository.createSetup(
        workoutId: widget.workout.canonicalId,
        name: result.name,
        profileId: result.profileId,
        copyFromSetupId: copyId,
        contents: mode == 'empty' ? SetupContents.empty : SetupContents.copy,
        creationId: creationId,
      );
      if (mounted) {
        setState(() {
          _setupId = created.id;
          _selectedSlotIds.clear();
        });
      }
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
    final selected = _currentSetup;
    if (selected == null || selected.exerciseCount == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.noExercisesToStart)));
      return;
    }
    if (!mounted) return;
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
      if ({
        'Standard',
        'Standard-Setup',
        'Default setup',
        'Default',
      }.contains(setup.name)) {
        return context.l10n.selectSetup;
      }
      return setup.name;
    }
    return profile;
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
                    Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        key: const ValueKey('workoutProfileChooser'),
                        leading: const Icon(Icons.home_work_outlined),
                        title: Text(
                          setup == null ? l10n.selectSetup : _setupLabel(setup),
                        ),
                        trailing: const Icon(Icons.expand_more_rounded),
                        onTap: _busy ? null : _addSetup,
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
                      label: Text(
                        setup?.profile == null
                            ? l10n.start
                            : l10n.startWithProfile(setup!.profile!.name),
                      ),
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
        const SizedBox(height: 20),
        TextFormField(
          key: const ValueKey('workoutName'),
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
          key: const ValueKey('workoutDescription'),
          controller: description,
          minLines: 2,
          maxLines: 4,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            labelText: context.l10n.optionalDescription,
            alignLabelWithHint: true,
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.primaryGoal,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Tooltip(
              message: context.l10n.choosePrimaryGoal,
              triggerMode: TooltipTriggerMode.tap,
              child: Semantics(
                label: context.l10n.choosePrimaryGoal,
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.info_outline, size: 20),
                ),
              ),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final singleColumn =
                constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(16) > 24;
            final width =
                singleColumn
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final value in WorkoutPrimaryGoal.values)
                  SizedBox(
                    width: width,
                    child: _GoalChoice(
                      value: value,
                      selected: value == goal,
                      horizontal: singleColumn,
                      onTap: () => onGoalChanged(value),
                    ),
                  ),
              ],
            );
          },
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
    this.horizontal = false,
  });
  final WorkoutPrimaryGoal value;
  final bool selected;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: goalLabel(context, value.code),
      child: InkWell(
        key: ValueKey('workoutGoal_${value.code}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration:
              MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                selected
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Flex(
            direction: horizontal ? Axis.horizontal : Axis.vertical,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GoalIcon(
                value.code,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              SizedBox(height: horizontal ? 0 : 8, width: horizontal ? 12 : 0),
              Flexible(
                flex: horizontal ? 1 : 0,
                child: Text(
                  goalLabel(context, value.code),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
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
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onCreate,
  });
  final List<TrainingProfileRecord> profiles;
  final String? profileId;
  final ValueChanged<String?> onProfileChanged;
  final bool loading;
  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.workoutSetup,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Tooltip(
            message: context.l10n.chooseSetupProfile,
            triggerMode: TooltipTriggerMode.tap,
            child: Semantics(
              label: context.l10n.chooseSetupProfile,
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.info_outline, size: 20),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      if (loading) const LinearProgressIndicator(),
      if (error != null) _ProfileLoadRetry(onRetry: onRetry),
      Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          key: const ValueKey('createWorkoutProfile'),
          leading: const Icon(Icons.home_work_outlined),
          title: Text(
            profiles.where((p) => p.id == profileId).firstOrNull?.name ??
                context.l10n.selectSetup,
          ),
          trailing: const Icon(Icons.expand_more_rounded),
          onTap: onCreate,
        ),
      ),
    ],
  );
}

class _ExercisesStep extends StatelessWidget {
  const _ExercisesStep({
    required this.selection,
    required this.profileName,
    required this.goal,
    required this.onSelect,
    required this.onRemove,
    required this.onReorder,
  });
  final List<ExerciseSelectionRef> selection;
  final String profileName;
  final WorkoutPrimaryGoal goal;
  final VoidCallback onSelect;
  final ValueChanged<int> onRemove;
  final ReorderCallback onReorder;

  @override
  Widget build(BuildContext context) {
    final local = context.watch<ExerciseProvider>().exercises;
    final locale = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GoalIcon(goal.code, color: Theme.of(context).colorScheme.primary),
            Text(goalLabel(context, goal.code)),
            Text(profileName, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child:
              selection.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.format_list_bulleted_rounded,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(context.l10n.noExercisesToStart),
                      ],
                    ),
                  )
                  : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: selection.length,
                    onReorder: onReorder,
                    itemBuilder: (c, i) {
                      final ref = selection[i];
                      final exercise =
                          local
                              .where((e) => e.id == ref.exerciseId)
                              .firstOrNull;
                      final catalog =
                          ref.catalogId == null
                              ? null
                              : CatalogRepository.instance.localized(
                                ref.catalogId!,
                                locale,
                              );
                      return Card(
                        key: ValueKey(ref.key),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: LibraryExerciseThumbnail(
                            assetPath: catalog?.definition.imageAssetPath,
                            personalPath: exercise?.imagePaths.firstOrNull,
                          ),
                          title: Text(
                            catalog?.content.name ??
                                (exercise == null
                                    ? context.l10n.exercise
                                    : displayExerciseName(context, exercise)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: context.l10n.remove,
                                onPressed: () => onRemove(i),
                                icon: const Icon(Icons.close),
                              ),
                              ReorderableDragStartListener(
                                index: i,
                                child: Semantics(
                                  label: context.l10n.dragExercise,
                                  child: const SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Icon(Icons.drag_indicator),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onSelect,
          icon: const Icon(Icons.add),
          label: Text(context.l10n.addExercises),
        ),
      ],
    );
  }
}

class _SetupDraft {
  const _SetupDraft(
    this.name,
    this.profileId, {
    this.setupId,
    this.makeDefault = false,
  });
  final String name;
  final String? profileId;
  final String? setupId;
  final bool makeDefault;
}

class _SetupEditorSheet extends StatefulWidget {
  const _SetupEditorSheet({
    required this.excludedProfileIds,
    required this.store,
    this.setups = const [],
    this.selectedSetupId,
  });
  final Set<String> excludedProfileIds;
  final TrainingProfileStore store;
  final List<WorkoutSetup> setups;
  final String? selectedSetupId;
  @override
  State<_SetupEditorSheet> createState() => _SetupEditorSheetState();
}

class _SetupEditorSheetState extends State<_SetupEditorSheet> {
  List<TrainingProfileRecord> _profiles = const [];
  bool _loading = true;
  bool _creating = false;
  Object? _error;
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
      final values = await widget.store.profiles();
      if (mounted) setState(() => _profiles = values);
    } catch (error, stack) {
      debugPrint('Loading profiles failed: $error');
      debugPrintStack(stackTrace: stack);
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final value = await showTrainingProfileEditor(
        context,
        store: widget.store,
        sortOrder: _profiles.length,
      );
      if (!mounted || value == null) return;
      Navigator.pop(context, _SetupDraft(value.name, value.id));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            context.l10n.selectSetup,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) _ProfileLoadRetry(onRetry: _load),
          for (final setup in widget.setups)
            ListTile(
              leading: Icon(
                setup.id == widget.selectedSetupId
                    ? Icons.check_circle
                    : Icons.home_work_outlined,
              ),
              title: Text(
                _profiles
                        .where((p) => p.id == setup.profile?.id)
                        .firstOrNull
                        ?.name ??
                    setup.profile?.name ??
                    ({
                          'Standard',
                          'Default',
                          'Standard-Setup',
                          'Default setup',
                        }.contains(setup.name)
                        ? context.l10n.withoutProfile
                        : setup.name),
              ),
              subtitle: Text(
                '${context.l10n.setupExercisesCount(setup.exerciseCount)}${setup.profile?.isArchived == true ? ' · ${context.l10n.profileArchived}' : ''}',
              ),
              onTap:
                  () => Navigator.pop(
                    context,
                    _SetupDraft(
                      setup.name,
                      setup.profile?.id,
                      setupId: setup.id,
                    ),
                  ),
              trailing:
                  setup.profile == null && setup.isDefault
                      ? null
                      : PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'default') {
                            Navigator.pop(
                              context,
                              _SetupDraft(
                                setup.name,
                                setup.profile?.id,
                                setupId: setup.id,
                                makeDefault: true,
                              ),
                            );
                          } else if (setup.profile != null) {
                            final p =
                                _profiles
                                    .where((p) => p.id == setup.profile!.id)
                                    .firstOrNull ??
                                setup.profile!;
                            await showTrainingProfileEditor(
                              context,
                              store: widget.store,
                              existing: p,
                            );
                            if (mounted) await _load();
                          }
                        },
                        itemBuilder:
                            (c) => [
                              if (setup.profile != null)
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(c.l10n.edit),
                                ),
                              if (!setup.isDefault)
                                PopupMenuItem(
                                  value: 'default',
                                  child: Text(c.l10n.makeDefaultSetup),
                                ),
                            ],
                      ),
            ),
          if (widget.setups.isNotEmpty &&
              _profiles.any((p) => !widget.excludedProfileIds.contains(p.id)))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                context.l10n.moreWorkoutProfiles,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          for (final profile in _profiles.where(
            (value) => !widget.excludedProfileIds.contains(value.id),
          ))
            ListTile(
              leading: const Icon(Icons.home_work_outlined),
              title: Text(profile.name),
              trailing: IconButton(
                tooltip: context.l10n.edit,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  await showTrainingProfileEditor(
                    context,
                    store: widget.store,
                    existing: profile,
                  );
                  if (mounted) await _load();
                },
              ),
              onTap:
                  () => Navigator.pop(
                    context,
                    _SetupDraft(profile.name, profile.id),
                  ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('createWorkoutProfile'),
            onPressed: _creating || _loading ? null : _create,
            icon: const Icon(Icons.add),
            label: Text(context.l10n.addTrainingProfile),
          ),
        ],
      ),
    ),
  );
}

class _ProfileLoadRetry extends StatelessWidget {
  const _ProfileLoadRetry({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.profileLoadFailed,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(context.l10n.retry),
        ),
      ],
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
