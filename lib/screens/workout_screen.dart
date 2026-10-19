import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../models/exercise.dart';
import '../models/catalog_exercise.dart';
import '../utils/exercise_localization.dart';
import '../providers/workout_provider.dart';
import '../providers/cloud_sync_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/active_workout_provider.dart';
import '../providers/progress_provider.dart';
import '../widgets/active_workout_banner.dart';
import '../widgets/exercise_editor_form.dart';
import '../widgets/exercise_editor_sheet.dart';
import '../utils/goal_utils.dart';
import '../services/workout_plan_database.dart';
import '../services/catalog_repository.dart';
import '../models/workout_plan.dart';
import 'workout_launch_options.dart';
import 'workout_plan_editor_screen.dart';
import 'workout_run_screen.dart';
import '../l10n/l10n.dart';
import '../widgets/modal_form_dialogs.dart';

const Duration _kWorkoutAnim = Duration(milliseconds: 200);

class WorkoutScreen extends StatefulWidget {
  final Workout workout;
  const WorkoutScreen({super.key, required this.workout});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late List<int> _exerciseIds;
  late Set<int> _assignedDays;
  late List<String> _goalCodes;

  @override
  void initState() {
    super.initState();
    _exerciseIds = List<int>.from(widget.workout.exerciseIds);
    _assignedDays = Set<int>.from(widget.workout.assignedDays);
    _goalCodes = List<String>.from(widget.workout.goalCodes);
  }

  Future<void> _editWorkoutGoals() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _GoalSelectionDialog(initialGoals: _goalCodes),
    );
    if (result == null || !mounted) return;
    await context.read<WorkoutProvider>().setWorkoutGoalCodes(
      widget.workout.id,
      result,
    );
    setState(() => _goalCodes = result);
  }

  Future<void> _launchWorkout() async {
    final active = context.read<ActiveWorkoutProvider>();
    final exercises = context.read<ExerciseProvider>().exercises;
    final exercisesById = {
      for (final exercise in exercises) exercise.id: exercise,
    };
    final list =
        _exerciseIds
            .map(
              (id) =>
                  exercises
                      .where((exercise) => exercise.id == id)
                      .cast<Exercise?>()
                      .firstOrNull,
            )
            .whereType<Exercise>()
            .toList();
    final isThisActive =
        active.isActive && active.workout?.id == widget.workout.id;
    if (isThisActive) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => WorkoutRunScreen(
                workout: widget.workout,
                exercises: active.exercises,
                autoStart: false,
                workoutVariantId: active.workoutVariantId,
                profileId: active.profileId,
                initialSlotSelections: active.slotExerciseSelections,
                initialGroupSelections: active.groupVariantSelections,
                sessionPlanGroups: active.sessionPlanGroups,
                allExercises: active.planExercisePool,
                initiallyEnabledOptionalSlotIds: active.enabledOptionalSlotIds,
              ),
        ),
      );
      return;
    }
    final options = await _chooseLaunchOptions();
    if (options == null || !mounted) return;
    var selectedExercises = list;
    var workoutSlotIds = <int?>[];
    final slotAlternatives = <int, List<Exercise>>{};
    final slotSelections = <int, int>{};
    var groupSelections = <int, int>{};
    var sessionPlanGroups = <WorkoutSessionPlanGroup>[];
    if (options.variantId != null) {
      final database = WorkoutPlanDatabase.instance;
      final slots = await database.slotsForVariant(options.variantId!);
      groupSelections = await database.groupSelectionsForVariant(
        options.variantId!,
      );
      final selectedSlots =
          slots
              .where(
                (slot) =>
                    !slot.isOptional ||
                    options.includedOptionalSlotIds.contains(slot.id),
              )
              .toList();
      final selected = <Exercise>[];
      for (final slot in selectedSlots) {
        final candidates = <Exercise>[];
        final seenIds = <int>{};
        void addCandidate(int exerciseId) {
          final exercise = exercisesById[exerciseId];
          if (exercise != null && seenIds.add(exercise.id)) {
            candidates.add(exercise);
          }
        }

        addCandidate(slot.exerciseId);
        final alternatives = await database.alternativesForSlot(slot.id);
        for (final alternative in alternatives) {
          if (alternative.profileId == null ||
              alternative.profileId == options.profileId) {
            addCandidate(alternative.exerciseId);
          }
        }
        if (candidates.isEmpty) continue;
        selected.add(candidates.first);
        workoutSlotIds.add(slot.id);
        slotSelections[slot.id] = candidates.first.id;
        if (candidates.length > 1) slotAlternatives[slot.id] = candidates;
      }
      // A pre-release variant may not have been configured yet.  Starting the
      // established flat workout is safer than silently starting an empty one.
      if (selected.isNotEmpty || selectedSlots.isNotEmpty) {
        selectedExercises = selected;
      }

      final groups = await database.groupsForWorkout(widget.workout.id);
      final plans = <WorkoutSessionPlanGroup>[];
      for (final group in groups) {
        final variants = await database.groupVariantsForGroup(group.id);
        final allowedVariants =
            variants
                .where(
                  (variant) =>
                      variant.profileId == null ||
                      variant.profileId == options.profileId ||
                      variant.id == groupSelections[group.id],
                )
                .toList();
        final planVariants = <WorkoutSessionPlanGroupVariant>[];
        for (final variant in allowedVariants) {
          final variantSlots = await database.slotsForGroupVariant(variant.id);
          final planSlots = <WorkoutSessionPlanSlot>[];
          for (final variantSlot in variantSlots) {
            final alternatives = await database.alternativesForSlot(
              variantSlot.id,
            );
            planSlots.add(
              WorkoutSessionPlanSlot(
                id: variantSlot.id,
                exerciseId: variantSlot.exerciseId,
                isOptional: variantSlot.isOptional,
                alternativeExerciseIds:
                    alternatives
                        .where(
                          (alternative) =>
                              alternative.profileId == null ||
                              alternative.profileId == options.profileId,
                        )
                        .map((alternative) => alternative.exerciseId)
                        .toList(),
              ),
            );
          }
          planVariants.add(
            WorkoutSessionPlanGroupVariant(
              id: variant.id,
              name: variant.name,
              slots: planSlots,
            ),
          );
        }
        if (planVariants.isEmpty) continue;
        plans.add(
          WorkoutSessionPlanGroup(
            workoutGroupId: group.id,
            name: group.name,
            selectedGroupVariantId:
                groupSelections[group.id] ?? planVariants.first.id,
            variants: planVariants,
          ),
        );
      }
      sessionPlanGroups = plans;
    }
    if (!mounted) return;
    if (active.isActive) active.clear();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => WorkoutRunScreen(
              workout: widget.workout,
              exercises: selectedExercises,
              autoStart: true,
              workoutVariantId: options.variantId,
              profileId: options.profileId,
              workoutSlotIds: workoutSlotIds,
              slotAlternatives: slotAlternatives,
              initialSlotSelections: slotSelections,
              initialGroupSelections: groupSelections,
              sessionPlanGroups: sessionPlanGroups,
              allExercises: exercises,
              initiallyEnabledOptionalSlotIds: options.includedOptionalSlotIds,
            ),
      ),
    );
  }

  Future<WorkoutLaunchOptions?> _chooseLaunchOptions() async {
    final database = WorkoutPlanDatabase.instance;
    await database.bootstrapLegacyPlan(
      workoutId: widget.workout.id,
      exerciseIds: _exerciseIds,
    );
    final profiles = await database.profiles();
    final variants = await database.variantsForWorkout(widget.workout.id);
    if (!mounted) return null;
    int? variantId;
    for (final variant in variants) {
      if (variant.isDefault) {
        variantId = variant.id;
        break;
      }
    }
    variantId ??= variants.isEmpty ? null : variants.first.id;
    final slotsByVariant = <int, List<WorkoutSlot>>{};
    for (final variant in variants) {
      slotsByVariant[variant.id] = await database.slotsForVariant(variant.id);
    }
    if (!mounted) return null;
    final exerciseNames = {
      for (final exercise in context.read<ExerciseProvider>().exercises)
        exercise.id: displayExerciseName(context, exercise),
    };
    return showModalBottomSheet<WorkoutLaunchOptions>(
      context: context,
      showDragHandle: true,
      builder:
          (_) => _WorkoutLaunchOptionsSheet(
            profiles: profiles,
            variants: variants,
            slotsByVariant: slotsByVariant,
            exerciseNames: exerciseNames,
            initialVariantId: variantId,
          ),
    );
  }

  Future<void> _createVariant() async {
    final name = await showTextPromptDialog(
      context: context,
      title: context.l10n.createVariant,
      label: context.l10n.variantName,
      submitLabel: context.l10n.create,
      cancelLabel: context.l10n.cancel,
      requiredMessage: context.l10n.nameRequired,
    );
    if (!mounted || name == null) return;
    final database = WorkoutPlanDatabase.instance;
    await database.bootstrapLegacyPlan(
      workoutId: widget.workout.id,
      exerciseIds: _exerciseIds,
    );
    await database.createVariantFromDefault(
      workoutId: widget.workout.id,
      name: name,
    );
  }

  Future<void> _openPlanEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => WorkoutPlanEditorScreen(
              workout: widget.workout,
              exercises: context.read<ExerciseProvider>().exercises,
            ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _toggleDay(int day) {
    final adding = !_assignedDays.contains(day);
    setState(() {
      if (adding) {
        _assignedDays = Set<int>.from(_assignedDays)..add(day);
      } else {
        _assignedDays = Set<int>.from(_assignedDays)..remove(day);
      }
    });
    context.read<WorkoutProvider>().setWorkoutDays(
      widget.workout.id,
      _assignedDays,
    );
    // Auto-Sync: Tag zu globalen Trainingstagen hinzufügen
    if (adding) {
      final progress = context.read<ProgressProvider>();
      final currentDays =
          progress.trainingDays.isEmpty
              ? progress.effectiveTrainingDays
              : progress.trainingDays;
      if (!currentDays.contains(day)) {
        progress.setTrainingDays(Set<int>.from(currentDays)..add(day));
      }
    }
    try {
      context.read<CloudSyncProvider>().scheduleBackupSoon();
    } catch (_) {}
  }

  Future<void> _persistOrder() async {
    final workoutProvider = context.read<WorkoutProvider>();
    CloudSyncProvider? cloudProvider;
    try {
      cloudProvider = context.read<CloudSyncProvider>();
    } catch (_) {}
    await workoutProvider.setWorkoutExercises(widget.workout.id, _exerciseIds);
    // trigger cloud backup soon (debounced)
    try {
      cloudProvider?.scheduleBackupSoon();
    } catch (_) {}
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final id = _exerciseIds.removeAt(oldIndex);
      _exerciseIds.insert(newIndex, id);
    });
    _persistOrder();
  }

  Future<void> _openExerciseEditor(Exercise exercise) async {
    final saved = await showExerciseEditorSheet(
      context,
      existing: exercise,
      warnOnEdit: true,
    );
    if (saved != null && mounted) {
      setState(() {});
    }
  }

  Future<void> _addExercisesBottomSheet() async {
    final provider = context.read<ExerciseProvider>();
    final localeCode = Localizations.localeOf(context).languageCode;
    final result = await showModalBottomSheet<_AddExercisesResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder:
          (_) => _AddExercisesSheet(
            exercises: provider.exercises,
            selectedIds: _exerciseIds.toSet(),
          ),
    );
    if (!mounted || result == null) return;

    var createdName = '';
    final selectedIds = Set<int>.from(result.selectedIds);
    for (final catalogId in result.selectedCatalogIds) {
      final item = CatalogRepository.instance.localized(catalogId, localeCode);
      if (item == null) continue;
      selectedIds.add(await provider.addCatalogExercise(item));
    }
    if (result.draft case final draft?) {
      final newId = await provider.addExercise(
        name: draft.name,
        description: draft.description,
        trackSets: draft.trackSets,
        trackReps: draft.trackReps,
        trackWeight: draft.trackWeight,
        trackDuration: draft.trackDuration,
        trackDistance: draft.trackDistance,
        goal: draft.goal,
      );
      if (!mounted) return;
      selectedIds.add(newId);
      createdName = draft.name;
    }

    setState(() {
      _exerciseIds = [
        ..._exerciseIds,
        ...selectedIds.where((id) => !_exerciseIds.contains(id)),
      ];
    });
    await _persistOrder();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          createdName.isEmpty
              ? context.l10n.exercisesAdded
              : context.l10n.workoutCreatedAndAdded(createdName),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _rename() async {
    final newName = await showTextPromptDialog(
      context: context,
      title: context.l10n.renameWorkout,
      label: context.l10n.workoutName,
      submitLabel: context.l10n.save,
      cancelLabel: context.l10n.cancel,
      requiredMessage: context.l10n.nameRequired,
      initialValue: widget.workout.name,
    );
    if (!mounted || newName == null || newName == widget.workout.name) return;
    await context.read<WorkoutProvider>().updateWorkoutName(
      widget.workout.id,
      newName,
    );
    if (!mounted) return;
    setState(() => widget.workout.name = newName);
    try {
      context.read<CloudSyncProvider>().scheduleBackupSoon();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final exercises = context.watch<ExerciseProvider>().exercises;
    final active = context.watch<ActiveWorkoutProvider>();
    final items =
        _exerciseIds
            .map(
              (id) =>
                  exercises
                      .where((e) => e.id == id)
                      .cast<Exercise?>()
                      .firstOrNull,
            )
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _rename,
          child: Text(widget.workout.name, overflow: TextOverflow.ellipsis),
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.editWorkoutPlan,
            icon: const Icon(Icons.account_tree_outlined),
            onPressed: _openPlanEditor,
          ),
          IconButton(
            tooltip: context.l10n.createVariant,
            icon: const Icon(Icons.tune_rounded),
            onPressed: _createVariant,
          ),
          IconButton(
            tooltip: context.l10n.goals,
            icon: const Icon(Icons.sell_outlined),
            onPressed: _editWorkoutGoals,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            48 + (_goalCodes.isNotEmpty ? 30 : 0) + (active.isActive ? 56 : 0),
          ),
          child: Column(
            children: [
              _DayAssignmentRow(
                assignedDays: _assignedDays,
                onToggle: _toggleDay,
              ),
              if (_goalCodes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    spacing: 6,
                    children:
                        _goalCodes
                            .map(
                              (goal) => goalBadge(
                                context,
                                goal,
                                Theme.of(context).colorScheme,
                              ),
                            )
                            .toList(),
                  ),
                ),
              if (active.isActive) const ActiveWorkoutBanner(),
            ],
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: _kWorkoutAnim,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          );
          return FadeTransition(
            opacity: curved,
            child: SizeTransition(sizeFactor: curved, child: child),
          );
        },
        child:
            _exerciseIds.isEmpty
                ? _EmptyState(
                  key: const ValueKey('workout-empty'),
                  onAdd: _addExercisesBottomSheet,
                )
                : ReorderableListView.builder(
                  key: const ValueKey('workout-list'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                  itemCount: _exerciseIds.length,
                  onReorder: _onReorder,
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, animation) {
                    HapticFeedback.mediumImpact();
                    return AnimatedBuilder(
                      animation: animation,
                      builder:
                          (_, __) => Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(16),
                            shadowColor: Colors.black26,
                            child: child,
                          ),
                    );
                  },
                  itemBuilder: (_, i) {
                    final id = _exerciseIds[i];
                    final e = items[i];
                    final scheme = Theme.of(context).colorScheme;
                    return Dismissible(
                      key: ValueKey('dismiss_$id'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.l10n.remove,
                              style: TextStyle(
                                color: scheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.remove_circle_outline_rounded,
                              color: scheme.onSecondaryContainer,
                            ),
                          ],
                        ),
                      ),
                      onDismissed: (_) async {
                        setState(() => _exerciseIds.removeAt(i));
                        await _persistOrder();
                      },
                      child: ReorderableDelayedDragStartListener(
                        index: i,
                        child: AnimatedSize(
                          key: ValueKey('exercise_$id'),
                          duration: _kWorkoutAnim,
                          curve: Curves.easeOut,
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap:
                                  e != null
                                      ? () => _openExerciseEditor(e)
                                      : null,
                              borderRadius: BorderRadius.circular(16),
                              child: IntrinsicHeight(
                                child: Row(
                                  children: [
                                    if (e?.goal != null)
                                      Container(
                                        width: 4,
                                        color: goalColor(e!.goal!, scheme),
                                      ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          e != null
                                                              ? displayExerciseName(
                                                                context,
                                                                e,
                                                              )
                                                              : context.l10n
                                                                  .deletedExercise(
                                                                    id,
                                                                  ),
                                                          style: Theme.of(
                                                                context,
                                                              )
                                                              .textTheme
                                                              .titleMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                      ),
                                                      if (e?.goal != null) ...[
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        goalBadge(
                                                          context,
                                                          e!.goal!,
                                                          scheme,
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    e == null
                                                        ? context
                                                            .l10n
                                                            .notAvailable
                                                        : [
                                                          if (e.trackSets)
                                                            context.l10n.sets,
                                                          if (e.trackReps)
                                                            context
                                                                .l10n
                                                                .repetitions,
                                                          if (e.trackWeight)
                                                            context.l10n.weight,
                                                          if (e.trackDistance)
                                                            context
                                                                .l10n
                                                                .distance,
                                                          if (e.trackDuration)
                                                            context
                                                                .l10n
                                                                .duration,
                                                        ].join(' · '),
                                                    style:
                                                        Theme.of(
                                                          context,
                                                        ).textTheme.bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              color: scheme.onSurfaceVariant
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      ),
      floatingActionButton: Builder(
        builder: (ctx) {
          final active = ctx.watch<ActiveWorkoutProvider>();
          final isThisActive =
              active.isActive && active.workout?.id == widget.workout.id;
          if (_exerciseIds.isEmpty && !isThisActive) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: _launchWorkout,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              isThisActive ? ctx.l10n.continueWorkout : ctx.l10n.start,
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton.tonalIcon(
            onPressed: _addExercisesBottomSheet,
            icon: const Icon(Icons.add),
            label: Text(context.l10n.additionalExercises),
          ),
        ),
      ),
    );
  }
}

class _WorkoutLaunchOptionsSheet extends StatefulWidget {
  const _WorkoutLaunchOptionsSheet({
    required this.profiles,
    required this.variants,
    required this.slotsByVariant,
    required this.exerciseNames,
    required this.initialVariantId,
  });

  final List<TrainingProfile> profiles;
  final List<WorkoutVariant> variants;
  final Map<int, List<WorkoutSlot>> slotsByVariant;
  final Map<int, String> exerciseNames;
  final int? initialVariantId;

  @override
  State<_WorkoutLaunchOptionsSheet> createState() =>
      _WorkoutLaunchOptionsSheetState();
}

class _WorkoutLaunchOptionsSheetState
    extends State<_WorkoutLaunchOptionsSheet> {
  int? _profileId;
  int? _variantId;
  late Set<int> _includedOptionalSlotIds;

  List<WorkoutSlot> get _slots =>
      _variantId == null
          ? const []
          : widget.slotsByVariant[_variantId] ?? const [];

  @override
  void initState() {
    super.initState();
    _profileId = widget.profiles.isEmpty ? null : widget.profiles.first.id;
    _variantId = widget.initialVariantId;
    _includedOptionalSlotIds =
        _slots.where((slot) => slot.isOptional).map((slot) => slot.id).toSet();
  }

  void _selectVariant(int value) {
    setState(() {
      _variantId = value;
      _includedOptionalSlotIds =
          _slots
              .where((slot) => slot.isOptional)
              .map((slot) => slot.id)
              .toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final optionalSlots = _slots.where((slot) => slot.isOptional).toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.l10n.start,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              if (widget.profiles.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(context.l10n.trainingProfile),
                ),
                for (final profile in widget.profiles)
                  RadioListTile<int>(
                    value: profile.id,
                    groupValue: _profileId,
                    title: Text(profile.name),
                    onChanged: (value) => setState(() => _profileId = value),
                  ),
              ] else
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(context.l10n.noProfiles),
                ),
              if (widget.variants.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(context.l10n.workoutVariant),
                ),
                for (final variant in widget.variants)
                  RadioListTile<int>(
                    value: variant.id,
                    groupValue: _variantId,
                    title: Text(variant.name),
                    onChanged:
                        (value) => value == null ? null : _selectVariant(value),
                  ),
              ],
              if (optionalSlots.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(context.l10n.optional),
                ),
                for (final slot in optionalSlots)
                  CheckboxListTile(
                    value: _includedOptionalSlotIds.contains(slot.id),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      widget.exerciseNames[slot.exerciseId] ??
                          context.l10n.notAvailable,
                    ),
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _includedOptionalSlotIds.add(slot.id);
                        } else {
                          _includedOptionalSlotIds.remove(slot.id);
                        }
                      });
                    },
                  ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      () => Navigator.of(context).pop(
                        WorkoutLaunchOptions(
                          profileId: _profileId,
                          variantId: _variantId,
                          includedOptionalSlotIds: Set<int>.from(
                            _includedOptionalSlotIds,
                          ),
                        ),
                      ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(context.l10n.start),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalSelectionDialog extends StatefulWidget {
  const _GoalSelectionDialog({required this.initialGoals});

  final List<String> initialGoals;

  @override
  State<_GoalSelectionDialog> createState() => _GoalSelectionDialogState();
}

class _GoalSelectionDialogState extends State<_GoalSelectionDialog> {
  static const _domains = {'strength', 'cardio', 'mobility'};
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialGoals.toSet();
    if (_selected.remove('endurance')) _selected.add('cardio');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.goals),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final goal in exerciseGoals)
            CheckboxListTile(
              value: _selected.contains(goal),
              title: Text(goalLabel(context, goal)),
              onChanged: (checked) {
                setState(() {
                  if (checked == true && _selected.length < 2) {
                    if (goal == 'endurance' &&
                        !_selected.any(_domains.contains)) {
                      _selected
                        ..add('cardio')
                        ..add('endurance');
                    } else {
                      _selected.add(goal);
                    }
                  } else if (checked != true) {
                    _selected.remove(goal);
                    if (_domains.contains(goal) &&
                        !_selected.any(_domains.contains)) {
                      _selected.remove('endurance');
                    }
                  }
                });
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed:
              _selected.any(_domains.contains)
                  ? () => Navigator.of(
                    context,
                  ).pop(_selected.toList(growable: false))
                  : null,
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}

@immutable
class _QuickExerciseDraft {
  const _QuickExerciseDraft({
    required this.name,
    required this.description,
    required this.trackSets,
    required this.trackReps,
    required this.trackWeight,
    required this.trackDuration,
    required this.trackDistance,
    required this.goal,
  });

  final String name;
  final String description;
  final bool trackSets;
  final bool trackReps;
  final bool trackWeight;
  final bool trackDuration;
  final bool trackDistance;
  final String? goal;
}

@immutable
class _AddExercisesResult {
  const _AddExercisesResult({
    required this.selectedIds,
    this.selectedCatalogIds = const {},
    this.draft,
  });

  final Set<int> selectedIds;
  final Set<String> selectedCatalogIds;
  final _QuickExerciseDraft? draft;
}

class _AddExercisesSheet extends StatefulWidget {
  const _AddExercisesSheet({
    required this.exercises,
    required this.selectedIds,
  });

  final List<Exercise> exercises;
  final Set<int> selectedIds;

  @override
  State<_AddExercisesSheet> createState() => _AddExercisesSheetState();
}

class _AddExercisesSheetState extends State<_AddExercisesSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _searchController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final ValueNotifier<bool> _trackSets;
  late final ValueNotifier<bool> _trackReps;
  late final ValueNotifier<bool> _trackWeight;
  late final ValueNotifier<bool> _trackDuration;
  late final ValueNotifier<bool> _trackDistance;
  late final ValueNotifier<String?> _goal;
  late final Set<int> _selectedIds;
  final Set<String> _selectedCatalogIds = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
    _searchController = TextEditingController();
    _nameController = TextEditingController()..addListener(_handleFormChanged);
    _descriptionController = TextEditingController();
    _trackSets = ValueNotifier(true);
    _trackReps = ValueNotifier(true);
    _trackWeight = ValueNotifier(true);
    _trackDuration = ValueNotifier(false);
    _trackDistance = ValueNotifier(false);
    _goal = ValueNotifier(null);
    _selectedIds = Set<int>.from(widget.selectedIds);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _searchController.dispose();
    _nameController
      ..removeListener(_handleFormChanged)
      ..dispose();
    _descriptionController.dispose();
    _trackSets.dispose();
    _trackReps.dispose();
    _trackWeight.dispose();
    _trackDuration.dispose();
    _trackDistance.dispose();
    _goal.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

  void _handleFormChanged() {
    if (mounted) setState(() {});
  }

  void _submitExisting() {
    Navigator.of(context).pop(
      _AddExercisesResult(
        selectedIds: Set.unmodifiable(_selectedIds),
        selectedCatalogIds: Set.unmodifiable(_selectedCatalogIds),
      ),
    );
  }

  void _submitNew() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      _AddExercisesResult(
        selectedIds: Set<int>.from(_selectedIds),
        selectedCatalogIds: Set<String>.from(_selectedCatalogIds),
        draft: _QuickExerciseDraft(
          name: name,
          description: _descriptionController.text.trim(),
          trackSets: _trackSets.value,
          trackReps: _trackReps.value,
          trackWeight: _trackWeight.value,
          trackDuration: _trackDuration.value,
          trackDistance: _trackDistance.value,
          goal: _goal.value,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = _query.toLowerCase();
    final filtered =
        query.isEmpty
            ? widget.exercises
            : widget.exercises
                .where(
                  (exercise) =>
                      displayExerciseName(
                        context,
                        exercise,
                      ).toLowerCase().contains(query) ||
                      exercise.name.toLowerCase().contains(query) ||
                      exercise.mergedAliases.any(
                        (alias) => alias.toLowerCase().contains(query),
                      ),
                )
                .toList();
    final materializedCatalogIds =
        widget.exercises
            .map((exercise) => exercise.catalogId)
            .whereType<String>()
            .toSet();
    final catalogFiltered =
        CatalogRepository.instance
            .search(
              Localizations.localeOf(context).languageCode,
              CatalogQuery(text: _query),
            )
            .where(
              (item) => !materializedCatalogIds.contains(item.definition.id),
            )
            .toList();
    final isCreateTab = _tabController.index == 1;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.l10n.addExercises,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(3),
                  dividerColor: Colors.transparent,
                  labelColor: scheme.onPrimary,
                  unselectedLabelColor: scheme.onSurfaceVariant,
                  tabs: [
                    Tab(text: context.l10n.addExistingExercises),
                    Tab(text: context.l10n.createNewExercise),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: context.l10n.searchExercises,
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon:
                                _query.isEmpty
                                    ? null
                                    : IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _query = '');
                                      },
                                    ),
                          ),
                          onChanged: (value) => setState(() => _query = value),
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: filtered.length + catalogFiltered.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            if (index >= filtered.length) {
                              final item =
                                  catalogFiltered[index - filtered.length];
                              return Card(
                                clipBehavior: Clip.antiAlias,
                                child: CheckboxListTile(
                                  value: _selectedCatalogIds.contains(
                                    item.definition.id,
                                  ),
                                  onChanged: (selected) {
                                    setState(() {
                                      if (selected == true) {
                                        _selectedCatalogIds.add(
                                          item.definition.id,
                                        );
                                      } else {
                                        _selectedCatalogIds.remove(
                                          item.definition.id,
                                        );
                                      }
                                    });
                                  },
                                  secondary: SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.asset(
                                        item.definition.imageAssetPath,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  title: Text(item.content.name),
                                  subtitle: Text(
                                    item.content.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                ),
                              );
                            }
                            final exercise = filtered[index];
                            final metrics = <String>[
                              if (exercise.trackSets) context.l10n.sets,
                              if (exercise.trackReps) context.l10n.repetitions,
                              if (exercise.trackWeight) context.l10n.weight,
                              if (exercise.trackDistance) context.l10n.distance,
                              if (exercise.trackDuration) context.l10n.duration,
                            ];
                            return Card(
                              child: CheckboxListTile(
                                value: _selectedIds.contains(exercise.id),
                                onChanged: (selected) {
                                  setState(() {
                                    if (selected == true) {
                                      _selectedIds.add(exercise.id);
                                    } else {
                                      _selectedIds.remove(exercise.id);
                                    }
                                  });
                                },
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        displayExerciseName(context, exercise),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium?.copyWith(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    if (exercise.goal != null) ...[
                                      const SizedBox(width: 8),
                                      goalBadge(
                                        context,
                                        exercise.goal!,
                                        scheme,
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle:
                                    metrics.isEmpty
                                        ? null
                                        : Text(metrics.join(' · ')),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      ExerciseEditorForm(
                        nameCtrl: _nameController,
                        descCtrl: _descriptionController,
                        trackSets: _trackSets,
                        trackReps: _trackReps,
                        trackWeight: _trackWeight,
                        trackDuration: _trackDuration,
                        trackDistance: _trackDistance,
                        goal: _goal,
                        autofocusName: true,
                        onChanged: _handleFormChanged,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.l10n.cancel),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child:
                          isCreateTab
                              ? FilledButton.icon(
                                key: const ValueKey('create_and_add'),
                                onPressed:
                                    _nameController.text.trim().isEmpty
                                        ? null
                                        : _submitNew,
                                icon: const Icon(Icons.add),
                                label: Text(context.l10n.create),
                              )
                              : FilledButton(
                                key: const ValueKey('add_selected'),
                                onPressed: _submitExisting,
                                child: Text(context.l10n.add),
                              ),
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.noExercises,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(context.l10n.addExercisesToStart),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.addExercises),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayAssignmentRow extends StatelessWidget {
  final Set<int> assignedDays;
  final void Function(int day) onToggle;
  const _DayAssignmentRow({required this.assignedDays, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final day = i + 1;
          final selected = assignedDays.contains(day);
          return GestureDetector(
            onTap: () => onToggle(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 32,
              decoration: BoxDecoration(
                color:
                    selected
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border:
                    selected
                        ? Border.all(color: scheme.primary, width: 1.5)
                        : null,
              ),
              alignment: Alignment.center,
              child: Text(
                [
                  context.l10n.monday,
                  context.l10n.tuesday,
                  context.l10n.wednesday,
                  context.l10n.thursday,
                  context.l10n.friday,
                  context.l10n.saturday,
                  context.l10n.sunday,
                ][i],
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// kleine Extension um firstOrNull zu bekommen
extension _IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
