import 'dart:async';
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
import 'workout_success_screen.dart';
import '../l10n/l10n.dart';
import '../services/workout_plan_database.dart';
import '../services/catalog_repository.dart';
import '../repositories/training_profile_repository.dart';
import '../widgets/workout_exercise_picker.dart';
import '../utils/workout_group_localization.dart';
import '../repositories/activity_repository.dart';
import '../widgets/modal_form_dialogs.dart';

class WorkoutRunScreen extends StatefulWidget {
  final Workout workout;
  final List<Exercise> exercises;
  final bool autoStart;
  final int? workoutVariantId;
  final int? profileId;
  final String? canonicalWorkoutSetupId;
  final String? canonicalProfileId;
  final bool persistLegacyPlanSelections;
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
    this.canonicalWorkoutSetupId,
    this.canonicalProfileId,
    this.persistLegacyPlanSelections = true,
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
  bool _isStarting = false;
  bool _pickingExercise = false;
  late List<Exercise> _exercises;
  late List<int?> _workoutSlotIds;
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
        _isRunning = true;
      }
    }
  }

  void _rebuildExercisesFromPlan() {
    final exercises = <Exercise>[];
    final slotIds = <int?>[];
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
        final exercise = _allExercisesById[slot.exerciseId];
        if (exercise == null) continue;
        final selectedExerciseId = _slotSelections[slot.id];
        final current = _allExercisesById[selectedExerciseId] ?? exercise;
        exercises.add(current);
        slotIds.add(slot.id);
        _slotSelections[slot.id] = current.id;
      }
    }
    exercises.addAll(_adHocExercises);
    slotIds.addAll(List<int?>.filled(_adHocExercises.length, null));
    _exercises = exercises;
    _workoutSlotIds = slotIds;
  }

  Future<void> _selectGroupVariant(
    WorkoutSessionPlanGroup group,
    int groupVariantId,
  ) async {
    if (!group.variants.any((value) => value.id == groupVariantId)) return;
    final active = context.read<ActiveWorkoutProvider>();
    final current = group.variants.firstWhere(
      (v) =>
          v.id ==
          (_groupSelections[group.workoutGroupId] ??
              group.selectedGroupVariantId),
    );
    if (current.slots.any(
      (s) =>
          active
              .setsByExercise[_slotSelections[s.id] ?? s.exerciseId]
              ?.isNotEmpty ==
          true,
    )) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.swapLockedAfterSets)));
      return;
    }
    try {
      for (final slot
          in group.variants.firstWhere((v) => v.id == groupVariantId).slots) {
        if (slot.isOptional && !_enabledOptionalSlotIds.contains(slot.id)) {
          continue;
        }
        final exercise =
            _allExercisesById[_slotSelections[slot.id] ?? slot.exerciseId];
        if (exercise != null) await active.ensurePersistedExercise(exercise);
      }
    } catch (error, stack) {
      _showEditError(error, stack);
      return;
    }
    if (!mounted) return;
    setState(() {
      _groupSelections[group.workoutGroupId] = groupVariantId;
      _rebuildExercisesFromPlan();
    });
    active
      ..updateExercises(_exercises)
      ..selectGroupVariant(group.workoutGroupId, groupVariantId);
    for (final slot in _slotSelections.entries) {
      active.selectSlotExercise(slot.key, slot.value);
    }
    final sessionId = active.sessionId;
    if (sessionId != null && widget.persistLegacyPlanSelections) {
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
                  workoutGroupLabel(sheetContext, group.kind, group.name),
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
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      showDragHandle: true,
      builder:
          (_) => _OptionalSlotsSheet(
            slots: optionalSlots,
            exercisesById: _allExercisesById,
            initiallyEnabled: _enabledOptionalSlotIds,
          ),
    );
    if (result == null || !mounted) return;
    final active = context.read<ActiveWorkoutProvider>();
    // Recorded efforts stay visible and tied to their original exercise.
    final retained = {...result};
    for (final slot in optionalSlots) {
      final id = _slotSelections[slot.id] ?? slot.exerciseId;
      if (active.setsByExercise[id]?.isNotEmpty == true) retained.add(slot.id);
    }
    try {
      for (final slot in optionalSlots.where((s) => retained.contains(s.id))) {
        final exercise =
            _allExercisesById[_slotSelections[slot.id] ?? slot.exerciseId];
        if (exercise != null) await active.ensurePersistedExercise(exercise);
      }
    } catch (error, stack) {
      _showEditError(error, stack);
      return;
    }
    if (!mounted) return;
    setState(() {
      _enabledOptionalSlotIds = retained;
      _rebuildExercisesFromPlan();
    });
    active.updateExercises(_exercises);
    active.setEnabledOptionalSlotIds(_enabledOptionalSlotIds);
    for (final slot in _slotSelections.entries) {
      active.selectSlotExercise(slot.key, slot.value);
    }
    final sessionId = active.sessionId;
    if (sessionId != null && widget.persistLegacyPlanSelections) {
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
    if (_isRunning || _isStarting) return;
    setState(() => _isStarting = true);
    final active = context.read<ActiveWorkoutProvider>();
    String? stagedActivitySessionId;
    try {
      if (!active.isActive) {
        final goals = _validatedSessionGoals(widget.workout.goalCodes);
        final itemSnapshots = [
          for (final exercise in _exercises)
            ActivityItemSnapshotInput(
              localExerciseId: exercise.id,
              displayName: displayExerciseName(context, exercise),
              catalogId: exercise.catalogId,
            ),
        ];
        final selectedProfile =
            widget.canonicalProfileId ??
            (widget.profileId != null
                ? 'legacy-profile:${widget.profileId}'
                : null);
        final persisted = await ActivityRepository().startWorkoutActivity(
          localWorkoutId: widget.workout.id,
          workoutId: widget.workout.canonicalId,
          workoutVariantId: widget.canonicalWorkoutSetupId,
          nameSnapshot: widget.workout.name,
          activityType: _activityTypeForGoals(goals),
          tags: goals,
          profileId: selectedProfile,
          items: itemSnapshots,
          groups: _sessionPlanGroups,
          selectionSnapshot: _selectionSnapshot,
        );
        stagedActivitySessionId = persisted.sessionId;
        final session =
            widget.persistLegacyPlanSelections
                ? await WorkoutPlanDatabase.instance.createSession(
                  workoutId: widget.workout.id,
                  executedExerciseIds:
                      _exercises.map((exercise) => exercise.id).toList(),
                  workoutVariantId: widget.workoutVariantId,
                  profileId: widget.profileId,
                  groupSelections: _groupSelections,
                  slotSelections: _slotSelections,
                )
                : null;
        if (!mounted) {
          await ActivityRepository().discardSession(persisted.sessionId);
          return;
        }
        active.start(
          workout: widget.workout,
          exercises: _exercises,
          sessionId: session?.id,
          workoutVariantId: widget.workoutVariantId,
          profileId: widget.profileId,
          groupSelections: _groupSelections,
          slotSelections: _slotSelections,
          sessionPlanGroups: _sessionPlanGroups,
          planExercisePool: _allExercisesById.values.toList(),
          enabledOptionalSlotIds: _enabledOptionalSlotIds,
          activitySessionId: persisted.sessionId,
          activityItemIds: persisted.activityItemIds,
          canonicalProfileId: selectedProfile,
          canonicalSetupId: widget.canonicalWorkoutSetupId,
        );
        stagedActivitySessionId = null;
      } else {
        active.updateExercises(_exercises);
        active.setEnabledOptionalSlotIds(_enabledOptionalSlotIds);
      }
      if (mounted) setState(() => _isRunning = true);
    } catch (error, stackTrace) {
      if (stagedActivitySessionId != null) {
        try {
          await ActivityRepository().discardSession(stagedActivitySessionId);
        } catch (cleanupError, cleanupStackTrace) {
          debugPrint('Could not discard staged activity: $cleanupError');
          debugPrintStack(stackTrace: cleanupStackTrace);
        }
      }
      debugPrint('Could not start workout: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
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

    if (save != true || !mounted) return;
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

    Future<void> finalizeLocally() async {
      await active.completePersistedSession();
      if (sessionId != null) {
        await WorkoutPlanDatabase.instance.completeSession(sessionId);
      }
      active.clearCompleted();
      if (hasAnySets) {
        unawaited(
          progressProvider
              .saveWorkoutEntries(
                workoutId: workoutId,
                durationSeconds: effectiveDuration,
                setsByExercise: setsByExerciseCopy,
                sessionId: sessionId,
              )
              .then((_) {
                if (cloudProvider.syncEnabled && cloudProvider.isSignedIn) {
                  return cloudProvider.backupNow();
                }
              })
              .catchError((_) {}),
        );
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (_) => WorkoutSuccessScreen(
              workoutName: workoutName,
              durationSeconds: effectiveDuration,
              exerciseCount: exercisesDone,
              totalSets: totalSets,
              finalizeLocally: finalizeLocally,
            ),
      ),
    );
  }

  static List<String> _validatedSessionGoals(Iterable<String> values) {
    const domains = {'strength', 'cardio', 'mobility'};
    final result = <String>[];
    for (final value in values) {
      if ({...domains, 'endurance'}.contains(value) &&
          !result.contains(value)) {
        result.add(value);
      }
      if (result.length == 2) break;
    }
    if (!result.any(domains.contains)) result.insert(0, 'strength');
    if (result.length > 2) result.removeLast();
    return result;
  }

  static String _activityTypeForGoals(List<String> goals) {
    if (goals.contains('cardio')) return 'cardio';
    if (goals.contains('mobility')) return 'mobility';
    return 'strength';
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

    final entry = await showExerciseValueDialog(
      context: context,
      exercise: e,
      title: displayExerciseName(context, e),
      initialValues: {...defs, ...last},
    );
    if (!mounted || entry == null || entry.isEmpty) return;
    active.updateLastSet(e.id, entry);
    setState(() {});
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

  Future<Exercise?> _pickExercise({Exercise? replacing}) async {
    if (_pickingExercise) return null;
    _pickingExercise = true;
    try {
      return await _showExercisePicker(replacing: replacing);
    } finally {
      _pickingExercise = false;
    }
  }

  Future<Exercise?> _showExercisePicker({Exercise? replacing}) async {
    final provider = context.read<ExerciseProvider>();
    final locale = Localizations.localeOf(context).languageCode;
    final profileId =
        widget.canonicalProfileId ??
        context.read<ActiveWorkoutProvider>().canonicalProfileId;
    Set<String>? equipment;
    try {
      final profiles = await TrainingProfileRepository().profiles();
      equipment =
          profiles.where((p) => p.id == profileId).firstOrNull?.equipmentCodes;
    } catch (error, stack) {
      debugPrint('Optional picker profile: $error\n$stack');
    }
    if (!mounted) return null;
    final result = await showModalBottomSheet<ExercisePickerResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => WorkoutExercisePicker(
            single: true,
            availableEquipment: equipment,
            preferredFamily:
                CatalogRepository.instance
                    .byId(replacing?.catalogId)
                    ?.movementFamilyId,
            excludedIds:
                _exercises
                    .where((e) => e.id != replacing?.id)
                    .map((e) => e.id)
                    .toSet(),
          ),
    );
    if (!mounted || result == null) return null;
    final values = await result.materialize(provider, locale);
    return values.firstOrNull;
  }

  Future<void> _addExerciseToWorkout() async {
    try {
      final exercise = await _pickExercise();
      if (!mounted || exercise == null) return;
      final active = context.read<ActiveWorkoutProvider>();
      await active.ensurePersistedExercise(exercise);
      if (!mounted) return;
      setState(() {
        _allExercisesById[exercise.id] = exercise;
        _adHocExercises.add(exercise);
        _exercises.add(exercise);
        _workoutSlotIds.add(null);
      });
      active.updateExercises(_exercises);
    } catch (error, stack) {
      _showEditError(error, stack);
    }
  }

  Future<void> _chooseSessionReplacement(int index) async {
    if (index < 0 || index >= _exercises.length) return;
    final slotId = _workoutSlotIds[index];
    if (slotId == null) return;
    final active = context.read<ActiveWorkoutProvider>();
    final current = _exercises[index];
    if (active.setsByExercise[current.id]?.isNotEmpty == true) return;
    try {
      final next = await _pickExercise(replacing: current);
      if (!mounted || next == null || next.id == current.id) return;
      await active.ensurePersistedExercise(next);
      if (!mounted) return;
      setState(() {
        _allExercisesById[next.id] = next;
        _exercises[index] = next;
        _slotSelections[slotId] = next.id;
      });
      active.updateExercises(_exercises);
      active.selectSlotExercise(slotId, next.id);
    } catch (error, stack) {
      _showEditError(error, stack);
    }
  }

  void _showEditError(Object error, StackTrace stack) {
    debugPrint('Session edit: $error\n$stack');
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.workoutEditFailed)));
    }
  }

  Map<String, Object?> get _selectionSnapshot => {
    'exercises': _exercises.map((e) => e.id).toList(),
    'groups': {for (final e in _groupSelections.entries) '${e.key}': e.value},
    'slots': {for (final e in _slotSelections.entries) '${e.key}': e.value},
    'optional': _enabledOptionalSlotIds.toList(),
  };

  List<Object> get _trainingRows {
    final rows = <Object>[];
    final used = <int>{};
    for (final group in _sessionPlanGroups) {
      final selected = group.variants.firstWhere(
        (v) =>
            v.id ==
            (_groupSelections[group.workoutGroupId] ??
                group.selectedGroupVariantId),
      );
      if (selected.slots.isEmpty &&
          !group.variants.any((v) => v.slots.isNotEmpty)) {
        continue;
      }
      rows.add(group);
      final ids = selected.slots.map((s) => s.id).toSet();
      for (var i = 0; i < _exercises.length; i++) {
        if (ids.contains(_workoutSlotIds[i])) {
          rows.add(i);
          used.add(i);
        }
      }
    }
    rows.addAll([
      for (var i = 0; i < _exercises.length; i++)
        if (!used.contains(i)) i,
    ]);
    return rows;
  }

  Widget _groupHeader(WorkoutSessionPlanGroup group) {
    final selected = group.variants.firstWhere(
      (v) =>
          v.id ==
          (_groupSelections[group.workoutGroupId] ??
              group.selectedGroupVariantId),
    );
    return GestureDetector(
      onHorizontalDragEnd:
          group.variants.length < 2
              ? null
              : (details) {
                final speed = details.primaryVelocity ?? 0;
                if (speed.abs() > 180) {
                  _switchGroupVariant(group, speed < 0 ? 1 : -1);
                }
              },
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                workoutGroupLabel(context, group.kind, group.name),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (group.variants.length > 1) ...[
              IconButton(
                tooltip: context.l10n.back,
                onPressed: () => _switchGroupVariant(group, -1),
                icon: const Icon(Icons.chevron_left),
              ),
              Flexible(
                child: TextButton(
                  onPressed: () => _chooseGroupVariant(group),
                  child: Text(selected.name),
                ),
              ),
              IconButton(
                tooltip: context.l10n.next,
                onPressed: () => _switchGroupVariant(group, 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
            if (selected.slots.any((s) => s.isOptional))
              IconButton(
                tooltip: context.l10n.optional,
                onPressed: () => _editOptionalSlots(group),
                icon: const Icon(Icons.add_task_outlined),
              ),
          ],
        ),
      ),
    );
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
          if (active.persistenceError != null)
            MaterialBanner(
              content: Text(context.l10n.workoutAutosaveFailed),
              leading: Icon(Icons.cloud_off_rounded, color: scheme.error),
              actions: [
                TextButton(
                  onPressed: active.retryPendingWrites,
                  child: Text(context.l10n.retry),
                ),
              ],
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              itemCount: _trainingRows.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, rowIndex) {
                final rows = _trainingRows;
                final row = rowIndex < rows.length ? rows[rowIndex] : null;
                if (row is WorkoutSessionPlanGroup) return _groupHeader(row);
                final i = row is int ? row : _exercises.length;
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
                final sets = active.setsByExercise[e.id] ?? const [];
                final hasSets = sets.isNotEmpty;
                return Card(
                  color:
                      hasSets ? scheme.tertiary.withValues(alpha: 0.08) : null,
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
                                                displayExerciseName(context, e),
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
                                  if (slotId != null && !hasSets)
                                    IconButton(
                                      tooltip:
                                          context.l10n.switchExerciseForSession,
                                      icon: const Icon(
                                        Icons.swap_horiz_rounded,
                                      ),
                                      onPressed:
                                          () => _chooseSessionReplacement(i),
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
                                                semanticLabel:
                                                    context
                                                        .l10n
                                                        .swapLockedAfterSets,
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
                  onPressed: _isStarting ? null : _start,
                  icon:
                      _isStarting
                          ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.play_arrow_rounded),
                  label: Text(context.l10n.start),
                ),
      ),
    );
  }
}

class _OptionalSlotsSheet extends StatefulWidget {
  const _OptionalSlotsSheet({
    required this.slots,
    required this.exercisesById,
    required this.initiallyEnabled,
  });

  final List<WorkoutSessionPlanSlot> slots;
  final Map<int, Exercise> exercisesById;
  final Set<int> initiallyEnabled;

  @override
  State<_OptionalSlotsSheet> createState() => _OptionalSlotsSheetState();
}

class _OptionalSlotsSheetState extends State<_OptionalSlotsSheet> {
  late final Set<int> _enabled;

  String _exerciseName(BuildContext context, WorkoutSessionPlanSlot slot) {
    final exercise = widget.exercisesById[slot.exerciseId];
    return exercise == null
        ? context.l10n.notAvailable
        : displayExerciseName(context, exercise);
  }

  @override
  void initState() {
    super.initState();
    _enabled = Set<int>.from(widget.initiallyEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            context.l10n.optional,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final slot in widget.slots)
            CheckboxListTile(
              value: _enabled.contains(slot.id),
              contentPadding: EdgeInsets.zero,
              title: Text(_exerciseName(context, slot)),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _enabled.add(slot.id);
                  } else {
                    _enabled.remove(slot.id);
                  }
                });
              },
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(Set<int>.from(_enabled)),
            child: Text(context.l10n.save),
          ),
        ],
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
    if (exercise.trackReps && data['reps'] != null) {
      parts.add('${data['reps']} Wdh.');
    }
    if (exercise.trackWeight && data['weight'] != null) {
      parts.add('${data['weight']} kg');
    }
    if (exercise.trackDistance && data['distance'] != null) {
      parts.add('${data['distance']} km');
    }
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
