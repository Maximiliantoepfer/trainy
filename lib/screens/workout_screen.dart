import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../models/exercise.dart';
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
import '../utils/utils.dart';
import '../services/workout_plan_database.dart';
import '../models/workout_plan.dart';
import 'workout_launch_options.dart';
import 'workout_plan_editor_screen.dart';
import 'workout_run_screen.dart';
import '../l10n/l10n.dart';

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
    var selected = List<String>.from(_goalCodes);
    final result = await showDialog<List<String>>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  title: Text(ctx.l10n.goals),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final goal in exerciseGoals)
                        CheckboxListTile(
                          value: selected.contains(goal),
                          title: Text(goalLabel(ctx, goal)),
                          onChanged:
                              (checked) => setDialogState(() {
                                if (checked == true && selected.length < 2) {
                                  selected.add(goal);
                                } else if (checked != true) {
                                  selected.remove(goal);
                                }
                              }),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(ctx.l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, selected),
                      child: Text(ctx.l10n.save),
                    ),
                  ],
                ),
          ),
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
    int? profileId = profiles.isEmpty ? null : profiles.first.id;
    int? variantId;
    for (final variant in variants) {
      if (variant.isDefault) {
        variantId = variant.id;
        break;
      }
    }
    variantId ??= variants.isEmpty ? null : variants.first.id;
    var slots =
        variantId == null
            ? <WorkoutSlot>[]
            : await database.slotsForVariant(variantId);
    var includedOptionalSlotIds =
        slots.where((slot) => slot.isOptional).map((slot) => slot.id).toSet();
    final exerciseNames = {
      for (final exercise in context.read<ExerciseProvider>().exercises)
        exercise.id: displayExerciseName(context, exercise),
    };
    return showModalBottomSheet<WorkoutLaunchOptions>(
      context: context,
      showDragHandle: true,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setSheetState) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            ctx.l10n.start,
                            style: Theme.of(ctx).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (profiles.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(ctx.l10n.trainingProfile),
                          ),
                          for (final profile in profiles)
                            RadioListTile<int>(
                              value: profile.id,
                              groupValue: profileId,
                              title: Text(profile.name),
                              onChanged:
                                  (value) =>
                                      setSheetState(() => profileId = value),
                            ),
                        ] else
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(ctx.l10n.noProfiles),
                          ),
                        if (variants.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(ctx.l10n.workoutVariant),
                          ),
                          for (final variant in variants)
                            RadioListTile<int>(
                              value: variant.id,
                              groupValue: variantId,
                              title: Text(variant.name),
                              onChanged: (value) async {
                                if (value == null) return;
                                final nextSlots = await database
                                    .slotsForVariant(value);
                                if (!ctx.mounted) return;
                                setSheetState(() {
                                  variantId = value;
                                  slots = nextSlots;
                                  includedOptionalSlotIds =
                                      nextSlots
                                          .where((slot) => slot.isOptional)
                                          .map((slot) => slot.id)
                                          .toSet();
                                });
                              },
                            ),
                        ],
                        if (slots.any((slot) => slot.isOptional)) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(ctx.l10n.optional),
                          ),
                          for (final slot in slots.where(
                            (slot) => slot.isOptional,
                          ))
                            CheckboxListTile(
                              value: includedOptionalSlotIds.contains(slot.id),
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                exerciseNames[slot.exerciseId] ??
                                    ctx.l10n.notAvailable,
                              ),
                              onChanged:
                                  (selected) => setSheetState(() {
                                    if (selected == true) {
                                      includedOptionalSlotIds.add(slot.id);
                                    } else {
                                      includedOptionalSlotIds.remove(slot.id);
                                    }
                                  }),
                            ),
                        ],
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                () => Navigator.pop(
                                  ctx,
                                  WorkoutLaunchOptions(
                                    profileId: profileId,
                                    variantId: variantId,
                                    includedOptionalSlotIds: Set<int>.from(
                                      includedOptionalSlotIds,
                                    ),
                                  ),
                                ),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(ctx.l10n.start),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Future<void> _createVariant() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(ctx.l10n.createVariant),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: ctx.l10n.variantName),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ctx.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: Text(ctx.l10n.create),
              ),
            ],
          ),
    );
    if (name == null || name.isEmpty) return;
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

  Future<void> _persistOrder(BuildContext context) async {
    await context.read<WorkoutProvider>().setWorkoutExercises(
      widget.workout.id,
      _exerciseIds,
    );
    // trigger cloud backup soon (debounced)
    try {
      context.read<CloudSyncProvider>().scheduleBackupSoon();
    } catch (_) {}
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final id = _exerciseIds.removeAt(oldIndex);
      _exerciseIds.insert(newIndex, id);
    });
    _persistOrder(context);
  }

  Future<void> _openExerciseEditor(Exercise exercise) async {
    final saved = await showExerciseEditorSheet(
      context,
      existing: exercise,
      warnOnEdit: true,
    );
    if (saved && mounted) {
      setState(() {});
    }
  }

  Future<void> _addExercisesBottomSheet() async {
    final all = context.read<ExerciseProvider>().exercises;
    final selected = Set<int>.from(_exerciseIds);

    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final trackSets = ValueNotifier<bool>(true);
    final trackReps = ValueNotifier<bool>(true);
    final trackWeight = ValueNotifier<bool>(true);
    final trackDuration = ValueNotifier<bool>(false);
    final trackDistance = ValueNotifier<bool>(false);
    final goal = ValueNotifier<String?>(null);

    final rootContext = context;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        Future<void> createAndAttach() async {
          final name = nameCtrl.text.trim();
          if (name.isEmpty) {
            await showDialog(
              context: ctx,
              builder:
                  (_) => AlertDialog(
                    title: Text(ctx.l10n.nameMissing),
                    content: Text(ctx.l10n.enterName),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(ctx.l10n.ok),
                      ),
                    ],
                  ),
            );
            return;
          }

          final newId = await ctx.read<ExerciseProvider>().addExercise(
            name: name,
            description: descCtrl.text.trim(),
            trackSets: trackSets.value,
            trackReps: trackReps.value,
            trackWeight: trackWeight.value,
            trackDuration: trackDuration.value,
            trackDistance: trackDistance.value,
            goal: goal.value,
          );

          final merged = [
            ..._exerciseIds,
            if (!_exerciseIds.contains(newId)) newId,
          ];

          setState(() => _exerciseIds = merged);
          await _persistOrder(rootContext);

          if (rootContext.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(rootContext).showSnackBar(
              SnackBar(
                content: Text(rootContext.l10n.workoutCreatedAndAdded(name)),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }

        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, modalSetState) {
            return DefaultTabController(
              length: 2,
              child: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final controller = DefaultTabController.of(ctx);
                    final scheme = Theme.of(ctx).colorScheme;
                    final filteredAll =
                        searchQuery.isEmpty
                            ? all
                            : all
                                .where(
                                  (e) =>
                                      displayExerciseName(
                                        context,
                                        e,
                                      ).toLowerCase().contains(
                                        searchQuery.toLowerCase(),
                                      ) ||
                                      e.name.toLowerCase().contains(
                                        searchQuery.toLowerCase(),
                                      ) ||
                                      e.mergedAliases.any(
                                        (a) => a.toLowerCase().contains(
                                          searchQuery.toLowerCase(),
                                        ),
                                      ),
                                )
                                .toList();

                    return Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(
                                ctx.l10n.addExercises,
                                style: Theme.of(ctx).textTheme.titleLarge,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest.withOpacity(
                                0.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TabBar(
                              indicator: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              indicatorPadding: const EdgeInsets.all(3),
                              dividerColor: Colors.transparent,
                              labelColor: scheme.onPrimary,
                              unselectedLabelColor: scheme.onSurfaceVariant,
                              labelStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              unselectedLabelStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              tabs: [
                                Tab(text: ctx.l10n.addExistingExercises),
                                Tab(text: ctx.l10n.createNewExercise),
                              ],
                              onTap: (_) => modalSetState(() {}),
                            ),
                          ),
                        ),

                        Expanded(
                          child: TabBarView(
                            children: [
                              // Tab 1: vorhandene Exercises auswählen
                              Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      16,
                                      16,
                                      8,
                                    ),
                                    child: TextField(
                                      decoration: InputDecoration(
                                        hintText: ctx.l10n.searchExercises,
                                        prefixIcon: const Icon(
                                          Icons.search_rounded,
                                        ),
                                        suffixIcon:
                                            searchQuery.isNotEmpty
                                                ? IconButton(
                                                  icon: const Icon(Icons.close),
                                                  onPressed:
                                                      () => modalSetState(
                                                        () => searchQuery = '',
                                                      ),
                                                )
                                                : null,
                                      ),
                                      onChanged:
                                          (v) => modalSetState(
                                            () => searchQuery = v,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        8,
                                        16,
                                        24,
                                      ),
                                      itemCount: filteredAll.length,
                                      separatorBuilder:
                                          (_, __) => const SizedBox(height: 8),
                                      itemBuilder: (_, i) {
                                        final e = filteredAll[i];
                                        final subtitle = <String>[];
                                        if (e.trackSets)
                                          subtitle.add(ctx.l10n.sets);
                                        if (e.trackReps)
                                          subtitle.add(ctx.l10n.repetitions);
                                        if (e.trackWeight)
                                          subtitle.add(ctx.l10n.weight);
                                        if (e.trackDistance)
                                          subtitle.add(ctx.l10n.distance);
                                        if (e.trackDuration)
                                          subtitle.add(ctx.l10n.duration);
                                        final subtitleText = subtitle.join(
                                          ' · ',
                                        );
                                        final alias = matchingAlias(
                                          e,
                                          searchQuery,
                                        );
                                        final cScheme =
                                            Theme.of(context).colorScheme;
                                        return Card(
                                          child: CheckboxListTile(
                                            value: selected.contains(e.id),
                                            onChanged: (v) {
                                              modalSetState(() {
                                                if (v == true) {
                                                  selected.add(e.id);
                                                } else {
                                                  selected.remove(e.id);
                                                }
                                              });
                                            },
                                            title: Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    displayExerciseName(
                                                      context,
                                                      e,
                                                    ),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                  ),
                                                ),
                                                if (e.goal != null) ...[
                                                  const SizedBox(width: 8),
                                                  goalBadge(
                                                    context,
                                                    e.goal!,
                                                    cScheme,
                                                  ),
                                                ],
                                              ],
                                            ),
                                            subtitle:
                                                (subtitleText.isEmpty &&
                                                        alias == null)
                                                    ? null
                                                    : Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        if (subtitleText
                                                            .isNotEmpty)
                                                          Text(subtitleText),
                                                        if (alias != null)
                                                          Text(
                                                            ctx.l10n.formerName(
                                                              alias,
                                                            ),
                                                            style: Theme.of(
                                                                  context,
                                                                )
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  fontStyle:
                                                                      FontStyle
                                                                          .italic,
                                                                  color: cScheme
                                                                      .onSurfaceVariant
                                                                      .withValues(
                                                                        alpha:
                                                                            0.6,
                                                                      ),
                                                                ),
                                                          ),
                                                      ],
                                                    ),
                                            controlAffinity:
                                                ListTileControlAffinity.leading,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              // Tab 2: neue Exercise erstellen
                              ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  24,
                                ),
                                children: [
                                  ExerciseEditorForm(
                                    nameCtrl: nameCtrl,
                                    descCtrl: descCtrl,
                                    trackSets: trackSets,
                                    trackReps: trackReps,
                                    trackWeight: trackWeight,
                                    trackDuration: trackDuration,
                                    trackDistance: trackDistance,
                                    goal: goal,
                                    autofocusName: true,
                                    onChanged: () => modalSetState(() {}),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Dynamische Bottom-CTA (achtet auf Keyboard)
                        AnimatedBuilder(
                          animation: controller.animation ?? controller,
                          builder: (_, __) {
                            final isCreateTab = controller.index == 1;
                            final canCreate = nameCtrl.text.trim().isNotEmpty;
                            final bottomInset =
                                MediaQuery.of(ctx).viewInsets.bottom;

                            return AnimatedPadding(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              padding: EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16 + bottomInset,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 48,
                                      child: OutlinedButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: Text(ctx.l10n.cancel),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: SizedBox(
                                      height: 48,
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        switchInCurve: Curves.easeOut,
                                        switchOutCurve: Curves.easeIn,
                                        transitionBuilder:
                                            (child, anim) => FadeTransition(
                                              opacity: anim,
                                              child: child,
                                            ),
                                        child:
                                            isCreateTab
                                                ? FilledButton.icon(
                                                  key: const ValueKey(
                                                    'create_and_add',
                                                  ),
                                                  onPressed:
                                                      canCreate
                                                          ? () async =>
                                                              createAndAttach()
                                                          : null,
                                                  icon: const Icon(Icons.add),
                                                  label: Text(ctx.l10n.create),
                                                )
                                                : FilledButton(
                                                  key: const ValueKey(
                                                    'add_selected',
                                                  ),
                                                  onPressed: () async {
                                                    final merged = [
                                                      ..._exerciseIds,
                                                      ...selected.where(
                                                        (id) =>
                                                            !_exerciseIds
                                                                .contains(id),
                                                      ),
                                                    ];
                                                    setState(
                                                      () =>
                                                          _exerciseIds = merged,
                                                    );
                                                    await _persistOrder(
                                                      rootContext,
                                                    );

                                                    if (rootContext.mounted) {
                                                      Navigator.pop(ctx);
                                                      ScaffoldMessenger.of(
                                                        rootContext,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            rootContext
                                                                .l10n
                                                                .exercisesAdded,
                                                          ),
                                                          behavior:
                                                              SnackBarBehavior
                                                                  .floating,
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  child: Text(ctx.l10n.add),
                                                ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _rename() async {
    String newName = widget.workout.name;
    final ctrl = TextEditingController(text: widget.workout.name);
    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(ctx.l10n.renameWorkout),
            content: TextField(
              controller: ctrl,
              decoration: InputDecoration(labelText: ctx.l10n.workoutName),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ctx.l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  newName =
                      ctrl.text.trim().isNotEmpty
                          ? ctrl.text.trim()
                          : widget.workout.name;
                  Navigator.pop(ctx);
                },
                child: Text(ctx.l10n.save),
              ),
            ],
          ),
    );
    await context.read<WorkoutProvider>().updateWorkoutName(
      widget.workout.id,
      newName,
    );
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
                        await _persistOrder(context);
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
                                                  .withOpacity(0.4),
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
          if (_exerciseIds.isEmpty && !isThisActive)
            return const SizedBox.shrink();
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
