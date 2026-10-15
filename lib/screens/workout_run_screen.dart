import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../models/exercise.dart';
import '../models/workout_plan.dart';
import '../utils/exercise_localization.dart';
import '../providers/progress_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/active_workout_provider.dart';
import '../providers/cloud_sync_provider.dart';
import '../utils/duration_utils.dart';
import '../utils/goal_utils.dart';
import '../utils/utils.dart';
import 'workout_success_screen.dart';
import '../l10n/l10n.dart';
import '../services/workout_plan_database.dart';

class WorkoutRunScreen extends StatefulWidget {
  final Workout workout;
  final List<Exercise> exercises;
  final bool autoStart;
  final int? workoutVariantId;
  final int? profileId;
  final List<int?> workoutSlotIds;
  final Map<int, List<Exercise>> slotAlternatives;
  final Map<int, int> initialSlotSelections;
  final Map<int, int> initialGroupSelections;
  final List<WorkoutSessionPlanGroup> sessionPlanGroups;
  final List<Exercise> allExercises;
  final Set<int> initiallyEnabledOptionalSlotIds;

  const WorkoutRunScreen({
    super.key,
    required this.workout,
    required this.exercises,
    this.autoStart = false,
    this.workoutVariantId,
    this.profileId,
    this.workoutSlotIds = const [],
    this.slotAlternatives = const {},
    this.initialSlotSelections = const {},
    this.initialGroupSelections = const {},
    this.sessionPlanGroups = const [],
    this.allExercises = const [],
    this.initiallyEnabledOptionalSlotIds = const {},
  });

  @override
  State<WorkoutRunScreen> createState() => _WorkoutRunScreenState();
}

class _WorkoutRunScreenState extends State<WorkoutRunScreen> {
  bool _isRunning = false;
  late List<Exercise> _exercises;
  late List<int?> _workoutSlotIds;
  late Map<int, List<Exercise>> _slotAlternatives;
  late Map<int, int> _slotSelections;
  late Map<int, int> _groupSelections;
  late Map<int, Exercise> _allExercisesById;
  late Set<int> _enabledOptionalSlotIds;
  late List<WorkoutSessionPlanGroup> _sessionPlanGroups;
  final List<Exercise> _adHocExercises = [];

  @override
  void initState() {
    super.initState();
    _exercises = List<Exercise>.from(widget.exercises);
    _workoutSlotIds = List<int?>.from(widget.workoutSlotIds);
    while (_workoutSlotIds.length < _exercises.length) {
      _workoutSlotIds.add(null);
    }
    _slotAlternatives = {
      for (final entry in widget.slotAlternatives.entries)
        entry.key: List<Exercise>.from(entry.value),
    };
    _slotSelections = Map<int, int>.from(widget.initialSlotSelections);
    _groupSelections = Map<int, int>.from(widget.initialGroupSelections);
    _allExercisesById = {
      for (final exercise in [...widget.allExercises, ...widget.exercises])
        exercise.id: exercise,
    };
    _enabledOptionalSlotIds = Set<int>.from(
      widget.initiallyEnabledOptionalSlotIds,
    );
    _sessionPlanGroups = List<WorkoutSessionPlanGroup>.from(
      widget.sessionPlanGroups,
    );
    if (_sessionPlanGroups.isNotEmpty) {
      final plannedIds = _slotSelections.values.toSet();
      _adHocExercises.addAll(
        widget.exercises.where((exercise) => !plannedIds.contains(exercise.id)),
      );
      _rebuildExercisesFromPlan();
    }
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    } else {
      final active = context.read<ActiveWorkoutProvider>();
      if (active.isActive) {
        active.updateExercises(_exercises);
        _isRunning = true;
      }
    }
  }

  void _rebuildExercisesFromPlan() {
    final exercises = <Exercise>[];
    final slotIds = <int?>[];
    final alternativesBySlot = <int, List<Exercise>>{};
    for (final group in _sessionPlanGroups) {
      final selectedVariantId =
          _groupSelections[group.workoutGroupId] ??
          group.selectedGroupVariantId;
      WorkoutSessionPlanGroupVariant? variant;
      for (final value in group.variants) {
        if (value.id == selectedVariantId) {
          variant = value;
          break;
        }
      }
      if (variant == null) continue;
      for (final slot in variant.slots) {
        if (slot.isOptional && !_enabledOptionalSlotIds.contains(slot.id)) {
          continue;
        }
        final candidates = <Exercise>[];
        final candidateIds = [slot.exerciseId, ...slot.alternativeExerciseIds];
        for (final exerciseId in candidateIds) {
          final exercise = _allExercisesById[exerciseId];
          if (exercise != null &&
              !candidates.any((item) => item.id == exercise.id)) {
            candidates.add(exercise);
          }
        }
        if (candidates.isEmpty) continue;
        final selectedExerciseId = _slotSelections[slot.id];
        final current = candidates.firstWhere(
          (item) => item.id == selectedExerciseId,
          orElse: () => candidates.first,
        );
        exercises.add(current);
        slotIds.add(slot.id);
        _slotSelections[slot.id] = current.id;
        if (candidates.length > 1) alternativesBySlot[slot.id] = candidates;
      }
    }
    exercises.addAll(_adHocExercises);
    slotIds.addAll(List<int?>.filled(_adHocExercises.length, null));
    _exercises = exercises;
    _workoutSlotIds = slotIds;
    _slotAlternatives = alternativesBySlot;
  }

  Future<void> _selectGroupVariant(
    WorkoutSessionPlanGroup group,
    int groupVariantId,
  ) async {
    if (!group.variants.any((value) => value.id == groupVariantId)) return;
    final active = context.read<ActiveWorkoutProvider>();
    setState(() {
      _groupSelections[group.workoutGroupId] = groupVariantId;
      _rebuildExercisesFromPlan();
    });
    active
      ..updateExercises(_exercises)
      ..selectGroupVariant(group.workoutGroupId, groupVariantId);
    final sessionId = active.sessionId;
    if (sessionId != null) {
      await WorkoutPlanDatabase.instance.selectSessionGroupVariant(
        sessionId: sessionId,
        workoutGroupId: group.workoutGroupId,
        groupVariantId: groupVariantId,
      );
      for (final slotId in _workoutSlotIds.whereType<int>()) {
        final exerciseId = _slotSelections[slotId];
        if (exerciseId == null) continue;
        await WorkoutPlanDatabase.instance.selectSessionSlotExercise(
          sessionId: sessionId,
          workoutSlotId: slotId,
          exerciseId: exerciseId,
        );
      }
    }
  }

  Future<void> _switchGroupVariant(
    WorkoutSessionPlanGroup group,
    int direction,
  ) async {
    final currentId =
        _groupSelections[group.workoutGroupId] ?? group.selectedGroupVariantId;
    final currentIndex = group.variants.indexWhere(
      (value) => value.id == currentId,
    );
    if (group.variants.length < 2 || currentIndex < 0) return;
    final rawIndex = (currentIndex + direction) % group.variants.length;
    final nextIndex =
        rawIndex < 0 ? rawIndex + group.variants.length : rawIndex;
    await _selectGroupVariant(group, group.variants[nextIndex].id);
  }

  Future<void> _chooseGroupVariant(WorkoutSessionPlanGroup group) async {
    final selected =
        _groupSelections[group.workoutGroupId] ?? group.selectedGroupVariantId;
    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text(
                  group.name,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                for (final variant in group.variants)
                  RadioListTile<int>(
                    value: variant.id,
                    groupValue: selected,
                    title: Text(variant.name),
                    onChanged: (value) => Navigator.pop(sheetContext, value),
                  ),
              ],
            ),
          ),
    );
    if (result != null && mounted) {
      await _selectGroupVariant(group, result);
    }
  }

  Future<void> _editOptionalSlots(WorkoutSessionPlanGroup group) async {
    final selectedVariantId =
        _groupSelections[group.workoutGroupId] ?? group.selectedGroupVariantId;
    final variant = group.variants.firstWhere(
      (item) => item.id == selectedVariantId,
      orElse: () => group.variants.first,
    );
    final optionalSlots =
        variant.slots.where((slot) => slot.isOptional).toList();
    if (optionalSlots.isEmpty) return;
    final enabled = Set<int>.from(_enabledOptionalSlotIds);
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (sheetContext, setSheetState) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      Text(
                        sheetContext.l10n.optional,
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      ...optionalSlots.map((slot) {
                        final exercise = _allExercisesById[slot.exerciseId];
                        return CheckboxListTile(
                          value: enabled.contains(slot.id),
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            exercise == null
                                ? sheetContext.l10n.notAvailable
                                : displayExerciseName(sheetContext, exercise),
                          ),
                          onChanged:
                              (value) => setSheetState(() {
                                if (value == true) {
                                  enabled.add(slot.id);
                                } else {
                                  enabled.remove(slot.id);
                                }
                              }),
                        );
                      }),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, enabled),
                        child: Text(sheetContext.l10n.save),
                      ),
                    ],
                  ),
                ),
          ),
    );
    if (result == null || !mounted) return;
    final active = context.read<ActiveWorkoutProvider>();
    setState(() {
      _enabledOptionalSlotIds = result;
      _rebuildExercisesFromPlan();
    });
    active.updateExercises(_exercises);
    active.setEnabledOptionalSlotIds(_enabledOptionalSlotIds);
    final sessionId = active.sessionId;
    if (sessionId != null) {
      for (final slotId in _workoutSlotIds.whereType<int>()) {
        final exerciseId = _slotSelections[slotId];
        if (exerciseId == null) continue;
        await WorkoutPlanDatabase.instance.selectSessionSlotExercise(
          sessionId: sessionId,
          workoutSlotId: slotId,
          exerciseId: exerciseId,
        );
      }
    }
  }

  Future<void> _start() async {
    if (_isRunning) return;
    final active = context.read<ActiveWorkoutProvider>();
    if (!active.isActive) {
      final session = await WorkoutPlanDatabase.instance.createSession(
        workoutId: widget.workout.id,
        executedExerciseIds: _exercises.map((exercise) => exercise.id).toList(),
        workoutVariantId: widget.workoutVariantId,
        profileId: widget.profileId,
        groupSelections: _groupSelections,
        slotSelections: _slotSelections,
      );
      if (!mounted) return;
      active.start(
        workout: widget.workout,
        exercises: _exercises,
        sessionId: session.id,
        workoutVariantId: widget.workoutVariantId,
        profileId: widget.profileId,
        groupSelections: _groupSelections,
        slotSelections: _slotSelections,
        sessionPlanGroups: _sessionPlanGroups,
        planExercisePool: _allExercisesById.values.toList(),
        enabledOptionalSlotIds: _enabledOptionalSlotIds,
      );
    } else {
      active.updateExercises(_exercises);
      active.setEnabledOptionalSlotIds(_enabledOptionalSlotIds);
    }
    setState(() => _isRunning = true);
  }

  Future<void> _stopAndFinish() async {
    if (!_isRunning) return;
    final active = context.read<ActiveWorkoutProvider>();

    final hasAnySets = active.setsByExercise.values.any(
      (list) => list.isNotEmpty,
    );
    if (!mounted) return;

    final save = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(ctx.l10n.endWorkout),
            content: Text(
              hasAnySets ? ctx.l10n.saveRecordedSets : ctx.l10n.endWithoutSets,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.l10n.endWorkout),
              ),
            ],
          ),
    );

    if (save != true) return;
    setState(() => _isRunning = false);

    // Snapshot data before clearing
    final duration = active.elapsedTotalSeconds;
    final workoutId = widget.workout.id;
    final workoutName = widget.workout.name;
    final sessionId = active.sessionId;
    final setsByExerciseCopy = Map<int, List<Map<String, String>>>.fromEntries(
      active.setsByExercise.entries.map(
        (e) => MapEntry(
          e.key,
          e.value.map((m) => Map<String, String>.from(m)).toList(),
        ),
      ),
    );
    final totalSets = setsByExerciseCopy.values.fold<int>(
      0,
      (s, l) => s + l.length,
    );
    final exercisesDone =
        setsByExerciseCopy.values.where((v) => v.isNotEmpty).length;

    // Ensure displayed duration is at least the sum of exercise durations
    int sumExerciseDurations = 0;
    for (final sets in setsByExerciseCopy.values) {
      for (final s in sets) {
        final durStr = s['duration']?.trim();
        if (durStr != null && durStr.isNotEmpty) {
          sumExerciseDurations += int.tryParse(durStr) ?? 0;
        }
      }
    }
    final effectiveDuration = max(duration, sumExerciseDurations);

    // Update lastValues (fast, in-memory)
    final exerciseProvider = context.read<ExerciseProvider>();
    setsByExerciseCopy.forEach((exerciseId, sets) {
      if (sets.isEmpty) return;
      exerciseProvider.updateLastValues(exerciseId, _deriveLastValues(sets));
    });

    // Capture providers before navigation
    final progressProvider = context.read<ProgressProvider>();
    final cloudProvider = context.read<CloudSyncProvider>();

    // Clear and navigate immediately
    active.clear();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (_) => WorkoutSuccessScreen(
              workoutName: workoutName,
              durationSeconds: effectiveDuration,
              exerciseCount: exercisesDone,
              totalSets: totalSets,
            ),
      ),
    );

    // Save data in background (fire-and-forget)
    if (hasAnySets) {
      progressProvider
          .saveWorkoutEntries(
            workoutId: workoutId,
            durationSeconds: effectiveDuration,
            setsByExercise: setsByExerciseCopy,
            sessionId: sessionId,
          )
          .then((_) {
            if (sessionId != null) {
              WorkoutPlanDatabase.instance
                  .completeSession(sessionId)
                  .catchError((_) {});
            }
            if (cloudProvider.syncEnabled && cloudProvider.isSignedIn) {
              cloudProvider.backupNow().catchError((_) {});
            }
          })
          .catchError((_) {});
    }
  }

  Map<String, String> _deriveLastValues(List<Map<String, String>> sets) {
    String? lastReps, lastWeight, lastSets, lastDuration, lastDistance;
    for (final s in sets) {
      final reps = s['reps']?.trim();
      final weight = s['weight']?.trim();
      final setsVal = s['sets']?.trim();
      final dur = s['duration']?.trim();
      final dist = s['distance']?.trim();
      if (reps != null && reps.isNotEmpty) lastReps = reps;
      if (weight != null && weight.isNotEmpty) lastWeight = weight;
      if (setsVal != null && setsVal.isNotEmpty) lastSets = setsVal;
      if (dur != null && dur.isNotEmpty) lastDuration = dur;
      if (dist != null && dist.isNotEmpty) lastDistance = dist;
    }
    final map = <String, String>{};
    if (lastSets != null) map['sets'] = lastSets;
    if (lastReps != null) map['reps'] = lastReps;
    if (lastWeight != null) map['weight'] = lastWeight;
    if (lastDistance != null) map['distance'] = lastDistance;
    if (lastDuration != null) map['duration'] = lastDuration;
    return map;
  }

  Future<void> _addSet(BuildContext context, Exercise e) async {
    final tracksAny =
        e.trackSets ||
        e.trackReps ||
        e.trackWeight ||
        e.trackDuration ||
        e.trackDistance;
    if (!tracksAny) {
      await showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(displayExerciseName(context, e)),
              content: Text(ctx.l10n.noTrackingFieldsActive),
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

    if (e.trackSets) {
      await _addSetPerSet(context, e);
    } else {
      await _addSetSingle(context, e);
    }
  }

  /// Alter Modus: Einzelner Dialog für Übungen ohne Satz-Tracking
  Future<void> _addSetSingle(BuildContext context, Exercise e) async {
    final active = context.read<ActiveWorkoutProvider>();
    final existing = List<Map<String, String>>.from(
      active.setsByExercise[e.id] ?? const <Map<String, String>>[],
    );
    final sessionLast = existing.isNotEmpty ? existing.last : null;
    final last = sessionLast ?? e.lastValues;
    final defs = e.defaultValues;

    final repsCtrl = TextEditingController(
      text: last['reps'] ?? defs['reps'] ?? '',
    );
    final weightCtrl = TextEditingController(
      text: last['weight'] ?? defs['weight'] ?? '',
    );
    final distanceCtrl = TextEditingController(
      text: last['distance'] ?? defs['distance'] ?? '',
    );
    final durationParts = DurationFormatter.fromRaw(
      last['duration'] ?? defs['duration'],
    );
    final durHoursCtrl = TextEditingController(
      text: durationParts.hours > 0 ? '${durationParts.hours}' : '',
    );
    final durMinutesCtrl = TextEditingController(
      text: durationParts.minutes > 0 ? '${durationParts.minutes}' : '',
    );
    final durSecondsCtrl = TextEditingController(
      text: durationParts.seconds > 0 ? '${durationParts.seconds}' : '',
    );

    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(displayExerciseName(context, e)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (e.trackReps)
                    TextField(
                      controller: repsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: ctx.l10n.repetitions,
                      ),
                    ),
                  if (e.trackWeight)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextField(
                        controller: weightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: ctx.l10n.weightKilograms,
                        ),
                      ),
                    ),
                  if (e.trackDistance)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextField(
                        controller: distanceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: ctx.l10n.distanceKilometers,
                        ),
                      ),
                    ),
                  if (e.trackDuration)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ctx.l10n.duration,
                            style: Theme.of(ctx).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: durHoursCtrl,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    labelText: ctx.l10n.hours,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: durMinutesCtrl,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    labelText: ctx.l10n.minutes,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: durSecondsCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    labelText: ctx.l10n.seconds,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ctx.l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final entry = <String, String>{};
                  if (e.trackReps && repsCtrl.text.trim().isNotEmpty)
                    entry['reps'] = repsCtrl.text.trim();
                  if (e.trackWeight && weightCtrl.text.trim().isNotEmpty)
                    entry['weight'] = weightCtrl.text.trim();
                  if (e.trackDistance && distanceCtrl.text.trim().isNotEmpty)
                    entry['distance'] = distanceCtrl.text.trim();
                  if (e.trackDuration) {
                    final secs = DurationFormatter.totalSecondsFromTexts(
                      durHoursCtrl.text,
                      durMinutesCtrl.text,
                      durSecondsCtrl.text,
                    );
                    if (secs > 0) entry['duration'] = '$secs';
                  }
                  if (entry.isNotEmpty) {
                    context.read<ActiveWorkoutProvider>().updateLastSet(
                      e.id,
                      entry,
                    );
                    setState(() {});
                  }
                  Navigator.pop(ctx);
                },
                child: Text(ctx.l10n.save),
              ),
            ],
          ),
    );
  }

  /// Per-Set-Modus: Bottom Sheet für satzgenaues Tracking
  Future<void> _addSetPerSet(BuildContext context, Exercise e) async {
    final active = context.read<ActiveWorkoutProvider>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return _PerSetSheet(
          exercise: e,
          activeProvider: active,
          onChanged: () {
            if (mounted) setState(() {});
          },
        );
      },
    );
  }

  Future<void> _addExerciseToWorkout() async {
    final allExercises = context.read<ExerciseProvider>().exercises;
    final currentIds = _exercises.map((e) => e.id).toSet();
    final available =
        allExercises.where((e) => !currentIds.contains(e.id)).toList();

    if (available.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.allExercisesAlreadyInWorkout),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final rootContext = context;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, modalSetState) {
            final scheme = Theme.of(ctx).colorScheme;
            final filtered =
                searchQuery.isEmpty
                    ? available
                    : available
                        .where(
                          (e) =>
                              displayExerciseName(context, e)
                                  .toLowerCase()
                                  .contains(searchQuery.toLowerCase()) ||
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
            return SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      ctx.l10n.addExercise,
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: ctx.l10n.searchExercises,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon:
                            searchQuery.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed:
                                      () =>
                                          modalSetState(() => searchQuery = ''),
                                )
                                : null,
                      ),
                      onChanged: (v) => modalSetState(() => searchQuery = v),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (_, i) {
                        final e = filtered[i];
                        final alias = matchingAlias(e, searchQuery);
                        return Card(
                          child: ListTile(
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(displayExerciseName(context, e)),
                                ),
                                if (e.goal != null) ...[
                                  const SizedBox(width: 8),
                                  goalBadge(context, e.goal!, scheme),
                                ],
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  [
                                    if (e.trackSets) ctx.l10n.sets,
                                    if (e.trackReps) ctx.l10n.repetitions,
                                    if (e.trackWeight) ctx.l10n.weight,
                                    if (e.trackDistance) ctx.l10n.distance,
                                    if (e.trackDuration) ctx.l10n.duration,
                                  ].join(' · '),
                                ),
                                if (alias != null)
                                  Text(
                                    ctx.l10n.formerName(alias),
                                    style: Theme.of(
                                      ctx,
                                    ).textTheme.bodySmall?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: scheme.onSurfaceVariant.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Icon(
                              Icons.add_circle_outline_rounded,
                              color: scheme.primary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            onTap: () {
                              setState(() {
                                _exercises.add(e);
                                _workoutSlotIds.add(null);
                                _adHocExercises.add(e);
                              });
                              rootContext
                                  .read<ActiveWorkoutProvider>()
                                  .updateExercises(_exercises);
                              Navigator.pop(ctx);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _switchSlotExercise(int index, int direction) async {
    if (index < 0 || index >= _exercises.length) return;
    final slotId = _workoutSlotIds[index];
    if (slotId == null) return;
    final candidates = _slotAlternatives[slotId];
    if (candidates == null || candidates.length < 2) return;

    final current = _exercises[index];
    final currentIndex = candidates.indexWhere(
      (exercise) => exercise.id == current.id,
    );
    final nextIndex =
        (currentIndex < 0 ? 0 : currentIndex + direction) % candidates.length;
    final normalizedIndex =
        nextIndex < 0 ? nextIndex + candidates.length : nextIndex;
    final next = candidates[normalizedIndex];
    if (next.id == current.id ||
        _exercises.asMap().entries.any(
          (entry) => entry.key != index && entry.value.id == next.id,
        )) {
      return;
    }

    final active = context.read<ActiveWorkoutProvider>();
    setState(() {
      _exercises[index] = next;
      _slotSelections[slotId] = next.id;
    });
    active
      ..updateExercises(_exercises)
      ..selectSlotExercise(slotId, next.id);
    final sessionId = active.sessionId;
    if (sessionId != null) {
      await WorkoutPlanDatabase.instance.selectSessionSlotExercise(
        sessionId: sessionId,
        workoutSlotId: slotId,
        exerciseId: next.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = context.watch<ActiveWorkoutProvider>();
    final total = _exercises.length;
    final doneCount =
        active.setsByExercise.values.where((v) => v.isNotEmpty).length;
    final progress = total == 0 ? 0.0 : doneCount / total;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.name),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ValueListenableBuilder<int>(
                valueListenable: active.elapsedSeconds,
                builder:
                    (_, sec, __) => Text(
                      DurationFormatter.digital(sec),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: [const FontFeature.tabularFigures()],
                        color: active.isPaused ? scheme.onSurfaceVariant : null,
                      ),
                    ),
              ),
            ),
          ),
          if (_isRunning)
            IconButton(
              tooltip:
                  active.isPaused
                      ? context.l10n.continueWorkout
                      : context.l10n.pause,
              onPressed:
                  () => active.isPaused ? active.resume() : active.pause(),
              icon: Icon(
                active.isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                color: scheme.primary,
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (_, value, __) => LinearProgressIndicator(value: value),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_sessionPlanGroups.isNotEmpty)
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                itemCount: _sessionPlanGroups.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final group = _sessionPlanGroups[index];
                  final selectedId =
                      _groupSelections[group.workoutGroupId] ??
                      group.selectedGroupVariantId;
                  final selected = group.variants.firstWhere(
                    (variant) => variant.id == selectedId,
                    orElse: () => group.variants.first,
                  );
                  return _GroupVariantSwitcher(
                    groupName: group.name,
                    variantName: selected.name,
                    canSwitch: group.variants.length > 1,
                    onPrevious: () => _switchGroupVariant(group, -1),
                    onNext: () => _switchGroupVariant(group, 1),
                    onTap: () => _chooseGroupVariant(group),
                    hasOptionalSlots: selected.slots.any(
                      (slot) => slot.isOptional,
                    ),
                    onEditOptionals: () => _editOptionalSlots(group),
                  );
                },
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              itemCount: _exercises.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                // Ghost card: "Übung hinzufügen"
                if (i >= _exercises.length) {
                  return Opacity(
                    opacity: 0.5,
                    child: Card(
                      child: InkWell(
                        onTap: _addExerciseToWorkout,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.add_rounded, color: scheme.primary),
                              const SizedBox(width: 12),
                              Text(
                                context.l10n.addExercise,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
                final e = _exercises[i];
                final slotId = _workoutSlotIds[i];
                final alternatives =
                    slotId == null
                        ? const <Exercise>[]
                        : _slotAlternatives[slotId] ?? const <Exercise>[];
                final canSwitch = alternatives.length > 1;
                final sets = active.setsByExercise[e.id] ?? const [];
                final hasSets = sets.isNotEmpty;
                return GestureDetector(
                  onHorizontalDragEnd:
                      canSwitch
                          ? (details) {
                            final velocity = details.primaryVelocity ?? 0;
                            if (velocity.abs() < 180) return;
                            _switchSlotExercise(i, velocity < 0 ? 1 : -1);
                          }
                          : null,
                  child: Card(
                    color:
                        hasSets
                            ? scheme.tertiary.withValues(alpha: 0.08)
                            : null,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _addSet(context, e),
                      borderRadius: BorderRadius.circular(16),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            if (e.goal != null)
                              Container(
                                width: 4,
                                color: goalColor(e.goal!, scheme),
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
                                                  displayExerciseName(
                                                    context,
                                                    e,
                                                  ),
                                                  style:
                                                      Theme.of(
                                                        context,
                                                      ).textTheme.titleMedium,
                                                ),
                                              ),
                                              if (e.goal != null) ...[
                                                const SizedBox(width: 8),
                                                goalBadge(
                                                  context,
                                                  e.goal!,
                                                  scheme,
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          if (hasSets)
                                            Text(
                                              context.l10n.recordedSets(
                                                sets.length,
                                              ),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.copyWith(
                                                color: scheme.tertiary,
                                              ),
                                            )
                                          else
                                            Text(
                                              [
                                                if (e.trackSets)
                                                  context.l10n.sets,
                                                if (e.trackReps)
                                                  context.l10n.repetitions,
                                                if (e.trackWeight)
                                                  context.l10n.weight,
                                                if (e.trackDistance)
                                                  context.l10n.distance,
                                                if (e.trackDuration)
                                                  context.l10n.duration,
                                              ].join(' · '),
                                              style:
                                                  Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (canSwitch)
                                      Semantics(
                                        label: context.l10n.change,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: context.l10n.back,
                                              icon: const Icon(
                                                Icons.chevron_left_rounded,
                                              ),
                                              onPressed:
                                                  () => _switchSlotExercise(
                                                    i,
                                                    -1,
                                                  ),
                                            ),
                                            AnimatedSwitcher(
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              child:
                                                  hasSets
                                                      ? Icon(
                                                        Icons
                                                            .check_circle_rounded,
                                                        key: ValueKey(
                                                          'done_${e.id}',
                                                        ),
                                                        color: scheme.tertiary,
                                                      )
                                                      : Icon(
                                                        Icons
                                                            .swap_horiz_rounded,
                                                        key: ValueKey(
                                                          'swap_${e.id}',
                                                        ),
                                                        color: scheme.primary,
                                                      ),
                                            ),
                                            IconButton(
                                              tooltip: context.l10n.next,
                                              icon: const Icon(
                                                Icons.chevron_right_rounded,
                                              ),
                                              onPressed:
                                                  () =>
                                                      _switchSlotExercise(i, 1),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        child:
                                            hasSets
                                                ? Icon(
                                                  Icons.check_circle_rounded,
                                                  key: ValueKey('done_${e.id}'),
                                                  color: scheme.tertiary,
                                                )
                                                : Icon(
                                                  Icons
                                                      .add_circle_outline_rounded,
                                                  key: ValueKey('add_${e.id}'),
                                                  color: scheme.primary,
                                                ),
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
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child:
            _isRunning
                ? FloatingActionButton.extended(
                  key: const ValueKey('fab_stop'),
                  onPressed: _stopAndFinish,
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  icon: const Icon(Icons.stop_rounded),
                  label: Text(context.l10n.endWorkout),
                )
                : FloatingActionButton.extended(
                  key: const ValueKey('fab_start'),
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(context.l10n.start),
                ),
      ),
    );
  }
}

class _GroupVariantSwitcher extends StatelessWidget {
  const _GroupVariantSwitcher({
    required this.groupName,
    required this.variantName,
    required this.canSwitch,
    required this.onPrevious,
    required this.onNext,
    required this.onTap,
    required this.hasOptionalSlots,
    required this.onEditOptionals,
  });

  final String groupName;
  final String variantName;
  final bool canSwitch;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTap;
  final bool hasOptionalSlots;
  final VoidCallback onEditOptionals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onHorizontalDragEnd:
          canSwitch
              ? (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity.abs() < 180) return;
                if (velocity < 0) {
                  onNext();
                } else {
                  onPrevious();
                }
              }
              : null,
      child: Card(
        color: scheme.secondaryContainer.withValues(alpha: .55),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canSwitch)
                  IconButton(
                    tooltip: context.l10n.back,
                    onPressed: onPrevious,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groupName,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Text(
                        variantName,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSecondaryContainer.withValues(
                            alpha: .72,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (canSwitch)
                  IconButton(
                    tooltip: context.l10n.next,
                    onPressed: onNext,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                if (hasOptionalSlots)
                  IconButton(
                    tooltip: context.l10n.optional,
                    onPressed: onEditOptionals,
                    icon: const Icon(Icons.add_task_outlined),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-Set Bottom Sheet
// ---------------------------------------------------------------------------

class _PerSetSheet extends StatefulWidget {
  final Exercise exercise;
  final ActiveWorkoutProvider activeProvider;
  final VoidCallback onChanged;

  const _PerSetSheet({
    required this.exercise,
    required this.activeProvider,
    required this.onChanged,
  });

  @override
  State<_PerSetSheet> createState() => _PerSetSheetState();
}

class _PerSetSheetState extends State<_PerSetSheet> {
  late TextEditingController _repsCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _distanceCtrl;
  late TextEditingController _durHoursCtrl;
  late TextEditingController _durMinutesCtrl;
  late TextEditingController _durSecondsCtrl;

  List<Map<String, String>> get _sets =>
      widget.activeProvider.setsByExercise[widget.exercise.id] ?? [];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final e = widget.exercise;
    final sets = _sets;
    final Map<String, String> last;
    if (sets.isNotEmpty) {
      last = sets.last;
    } else if (e.lastValues.isNotEmpty) {
      last = e.lastValues;
    } else {
      last = e.defaultValues;
    }

    _repsCtrl = TextEditingController(text: last['reps'] ?? '');
    _weightCtrl = TextEditingController(text: last['weight'] ?? '');
    _distanceCtrl = TextEditingController(text: last['distance'] ?? '');
    final durParts = DurationFormatter.fromRaw(last['duration']);
    _durHoursCtrl = TextEditingController(
      text: durParts.hours > 0 ? '${durParts.hours}' : '',
    );
    _durMinutesCtrl = TextEditingController(
      text: durParts.minutes > 0 ? '${durParts.minutes}' : '',
    );
    _durSecondsCtrl = TextEditingController(
      text: durParts.seconds > 0 ? '${durParts.seconds}' : '',
    );
  }

  @override
  void dispose() {
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    _distanceCtrl.dispose();
    _durHoursCtrl.dispose();
    _durMinutesCtrl.dispose();
    _durSecondsCtrl.dispose();
    super.dispose();
  }

  void _saveCurrentSet() {
    final e = widget.exercise;
    final entry = <String, String>{};
    if (e.trackReps && _repsCtrl.text.trim().isNotEmpty) {
      entry['reps'] = _repsCtrl.text.trim();
    }
    if (e.trackWeight && _weightCtrl.text.trim().isNotEmpty) {
      entry['weight'] = _weightCtrl.text.trim();
    }
    if (e.trackDistance && _distanceCtrl.text.trim().isNotEmpty) {
      entry['distance'] = _distanceCtrl.text.trim();
    }
    if (e.trackDuration) {
      final secs = DurationFormatter.totalSecondsFromTexts(
        _durHoursCtrl.text,
        _durMinutesCtrl.text,
        _durSecondsCtrl.text,
      );
      if (secs > 0) entry['duration'] = '$secs';
    }

    if (entry.isNotEmpty) {
      widget.activeProvider.addSet(widget.exercise.id, entry);
      widget.onChanged();
      setState(() {});
      // Controllers keep their values for easy repeat entry
    }
  }

  void _removeSet(int index) {
    widget.activeProvider.removeSetAt(widget.exercise.id, index);
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final e = widget.exercise;
    final sets = _sets;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Text(
                displayExerciseName(context, e),
                style: textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                context.l10n.recordedSets(sets.length),
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),

            // Completed sets
            if (sets.isNotEmpty) ...[
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: sets.length,
                  itemBuilder:
                      (_, i) => _CompletedSetRow(
                        index: i,
                        data: sets[i],
                        exercise: e,
                        onRemove: () => _removeSet(i),
                      ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(height: 24),
              ),
            ] else
              const SizedBox(height: 16),

            // Input for next set
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                context.l10n.setNumber(sets.length + 1),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  if (e.trackReps)
                    TextField(
                      controller: _repsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.l10n.repetitions,
                      ),
                    ),
                  if (e.trackWeight)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextField(
                        controller: _weightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.l10n.weightKilograms,
                        ),
                      ),
                    ),
                  if (e.trackDistance)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextField(
                        controller: _distanceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.l10n.distanceKilometers,
                        ),
                      ),
                    ),
                  if (e.trackDuration)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _durHoursCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: context.l10n.hours,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _durMinutesCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: context.l10n.minutes,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _durSecondsCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: context.l10n.seconds,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.l10n.done),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _saveCurrentSet,
                        child: Text(context.l10n.saveSet),
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

class _CompletedSetRow extends StatelessWidget {
  final int index;
  final Map<String, String> data;
  final Exercise exercise;
  final VoidCallback onRemove;

  const _CompletedSetRow({
    required this.index,
    required this.data,
    required this.exercise,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final parts = <String>[];
    if (exercise.trackReps && data['reps'] != null)
      parts.add('${data['reps']} Wdh.');
    if (exercise.trackWeight && data['weight'] != null)
      parts.add('${data['weight']} kg');
    if (exercise.trackDistance && data['distance'] != null)
      parts.add('${data['distance']} km');
    if (exercise.trackDuration && data['duration'] != null) {
      parts.add(
        localizedDuration(context, int.tryParse(data['duration']!) ?? 0),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: scheme.tertiary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.tertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(parts.join(' / '), style: textTheme.bodyMedium)),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              icon: Icon(Icons.close_rounded, size: 18, color: scheme.error),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
