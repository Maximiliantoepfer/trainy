import 'dart:async';
import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../models/exercise.dart';
import '../models/workout_plan.dart';
import '../repositories/activity_repository.dart';
import '../utils/uuid_v4.dart';
import '../services/exercise_database.dart';
import '../services/workout_database.dart';

/// Hält eine aktuell laufende Workout-Session unabhängig vom Screen am Leben.
///
/// - Zeit läuft durch, auch bei Screen-Wechseln (Berechnung über Startzeit)
/// - Sets werden im Speicher gehalten und können laufend ergänzt werden
/// - Ein sekündlicher Ticker aktualisiert Listener im Vordergrund
class ActiveWorkoutProvider extends ChangeNotifier {
  ActiveWorkoutProvider({ActivityRepository? activityRepository})
    : _activityRepository = activityRepository ?? ActivityRepository();

  final ActivityRepository _activityRepository;
  Workout? _workout;
  List<Exercise> _exercises = const [];
  DateTime? _startedAt;
  int _extraElapsed = 0; // Reserve, falls später Pausen etc. hinzukommen
  DateTime? _pausedAt;
  bool _isPaused = false;
  int? _sessionId;
  int? _profileId;
  int? _workoutVariantId;
  String? _activitySessionId;
  final Map<int, String> _activityItemIds = {};
  final Map<int, List<String>> _effortIdsByExercise = {};
  final List<Future<void> Function()> _pendingWrites = [];
  bool _drainingWrites = false;
  Completer<void>? _drainCompleter;
  Object? _persistenceError;
  final Map<int, int> _groupVariantSelections = {};
  final Map<int, int> _slotExerciseSelections = {};
  List<WorkoutSessionPlanGroup> _sessionPlanGroups = const [];
  List<Exercise> _planExercisePool = const [];
  Set<int> _enabledOptionalSlotIds = <int>{};

  final Map<int, List<Map<String, String>>> _setsByExercise = {};

  Timer? _ticker;
  final ValueNotifier<int> elapsedSeconds = ValueNotifier<int>(0);

  bool get isActive => _workout != null && _startedAt != null;
  bool get isPaused => _isPaused;
  Workout? get workout => _workout;
  List<Exercise> get exercises => _exercises;
  Map<int, List<Map<String, String>>> get setsByExercise => _setsByExercise;
  int? get sessionId => _sessionId;
  int? get profileId => _profileId;
  int? get workoutVariantId => _workoutVariantId;
  String? get activitySessionId => _activitySessionId;
  Object? get persistenceError => _persistenceError;
  bool get hasPendingWrites => _pendingWrites.isNotEmpty || _drainingWrites;
  Map<int, int> get groupVariantSelections =>
      Map.unmodifiable(_groupVariantSelections);
  Map<int, int> get slotExerciseSelections =>
      Map.unmodifiable(_slotExerciseSelections);
  List<WorkoutSessionPlanGroup> get sessionPlanGroups =>
      List.unmodifiable(_sessionPlanGroups);
  List<Exercise> get planExercisePool => List.unmodifiable(_planExercisePool);
  Set<int> get enabledOptionalSlotIds =>
      Set.unmodifiable(_enabledOptionalSlotIds);

  Future<void> restorePersistedWorkout() async {
    if (isActive) return;
    final snapshot = await _activityRepository.latestActiveWorkout();
    if (snapshot == null) return;
    final workouts = await WorkoutDatabase.instance.getAllWorkouts();
    Workout? workout;
    for (final candidate in workouts) {
      if (candidate.id == snapshot.localWorkoutId) {
        workout = candidate;
        break;
      }
    }
    if (workout == null) return;
    final allExercises = await ExerciseDatabase.instance.getAllExercises();
    final exercisesById = {
      for (final exercise in allExercises) exercise.id: exercise,
    };
    final itemIds = <int, String>{};
    final itemToExercise = <String, int>{};
    final exercises = <Exercise>[];
    for (final row in snapshot.items) {
      final localId = int.tryParse(row['source_local_id'] as String? ?? '');
      final itemId = row['id'] as String;
      final exercise = localId == null ? null : exercisesById[localId];
      if (localId == null || exercise == null) continue;
      exercises.add(exercise);
      itemIds[localId] = itemId;
      itemToExercise[itemId] = localId;
    }
    start(
      workout: workout,
      exercises: exercises,
      activitySessionId: snapshot.sessionId,
      activityItemIds: itemIds,
      profileId:
          snapshot.profileId?.startsWith('legacy-profile:') == true
              ? int.tryParse(snapshot.profileId!.split(':').last)
              : null,
      startedAt: snapshot.startedAt,
      planExercisePool: allExercises,
    );

    final valuesByEffort = <String, Map<String, String>>{};
    final effortExercise = <String, int>{};
    final effortOrder = <String, int>{};
    for (final row in snapshot.efforts) {
      final effortId = row['id'] as String;
      final exerciseId = itemToExercise[row['activity_item_id'] as String];
      if (exerciseId == null) continue;
      effortExercise[effortId] = exerciseId;
      effortOrder[effortId] = (row['sort_order'] as num).toInt();
      final metric = row['metric_code'] as String?;
      final value = row['entered_value'] as num?;
      if (metric == null || value == null) continue;
      final key = switch (metric) {
        'repetitions' => 'reps',
        'weight' => 'weight',
        'duration' => 'duration',
        'distance' => 'distance',
        _ => null,
      };
      if (key != null)
        valuesByEffort.putIfAbsent(effortId, () => {})[key] = _formatNumber(
          value,
        );
    }
    final effortIds =
        effortExercise.keys.toList()..sort(
          (a, b) => (effortOrder[a] ?? 0).compareTo(effortOrder[b] ?? 0),
        );
    for (final effortId in effortIds) {
      final exerciseId = effortExercise[effortId]!;
      _setsByExercise
          .putIfAbsent(exerciseId, () => [])
          .add(valuesByEffort[effortId] ?? <String, String>{});
      _effortIdsByExercise.putIfAbsent(exerciseId, () => []).add(effortId);
    }
    notifyListeners();
  }

  static String _formatNumber(num value) =>
      value == value.roundToDouble() ? '${value.toInt()}' : '$value';

  /// Startet eine neue Session (überschreibt ggf. die alte nach Rückfrage durch UI).
  void start({
    required Workout workout,
    required List<Exercise> exercises,
    int? sessionId,
    int? profileId,
    int? workoutVariantId,
    Map<int, int> groupSelections = const {},
    Map<int, int> slotSelections = const {},
    List<WorkoutSessionPlanGroup> sessionPlanGroups = const [],
    List<Exercise> planExercisePool = const [],
    Set<int> enabledOptionalSlotIds = const {},
    String? activitySessionId,
    Map<int, String> activityItemIds = const {},
    DateTime? startedAt,
  }) {
    _workout = workout;
    _exercises = List<Exercise>.from(exercises);
    _startedAt = startedAt ?? DateTime.now();
    _extraElapsed = 0;
    _setsByExercise.clear();
    _sessionId = sessionId;
    _profileId = profileId;
    _workoutVariantId = workoutVariantId;
    _activitySessionId = activitySessionId;
    _activityItemIds
      ..clear()
      ..addAll(activityItemIds);
    _effortIdsByExercise.clear();
    _pendingWrites.clear();
    _persistenceError = null;
    _groupVariantSelections
      ..clear()
      ..addAll(groupSelections);
    _slotExerciseSelections
      ..clear()
      ..addAll(slotSelections);
    _sessionPlanGroups = List<WorkoutSessionPlanGroup>.from(sessionPlanGroups);
    _planExercisePool = List<Exercise>.from(planExercisePool);
    _enabledOptionalSlotIds = Set<int>.from(enabledOptionalSlotIds);

    _startTicker();
    _notifyElapsed();
    notifyListeners();
  }

  /// Fügt (oder ersetzt) während einer aktiven Session eine Übungs-Liste hinzu.
  void updateExercises(List<Exercise> exercises) {
    _exercises = List<Exercise>.from(exercises);
    notifyListeners();
  }

  Future<void> ensurePersistedExercise(Exercise exercise) async {
    final sessionId = _activitySessionId;
    if (sessionId == null || _activityItemIds.containsKey(exercise.id)) return;
    final itemId = await _activityRepository.addActivityItem(
      sessionId: sessionId,
      displayNameSnapshot:
          exercise.alias?.trim().isNotEmpty == true
              ? exercise.alias!.trim()
              : exercise.name,
      catalogIdSnapshot: exercise.catalogId,
      sourceLocalId: '${exercise.id}',
      sortOrder: _activityItemIds.length,
    );
    _activityItemIds[exercise.id] = itemId;
  }

  void selectGroupVariant(int workoutGroupId, int groupVariantId) {
    _groupVariantSelections[workoutGroupId] = groupVariantId;
    notifyListeners();
  }

  void selectSlotExercise(int workoutSlotId, int exerciseId) {
    _slotExerciseSelections[workoutSlotId] = exerciseId;
    notifyListeners();
  }

  void setEnabledOptionalSlotIds(Set<int> value) {
    _enabledOptionalSlotIds = Set<int>.from(value);
    notifyListeners();
  }

  void addSet(int exerciseId, Map<String, String> entry) {
    _setsByExercise.putIfAbsent(exerciseId, () => []);
    _setsByExercise[exerciseId]!.add(Map<String, String>.from(entry));
    final effortId = UuidV4.generate();
    _effortIdsByExercise.putIfAbsent(exerciseId, () => []).add(effortId);
    _enqueueEffortWrite(exerciseId, effortId, entry);
    notifyListeners();
  }

  /// Aktualisiert den zuletzt erfassten Satz für eine Übung,
  /// oder fügt einen neuen hinzu, falls noch keiner existiert.
  void updateLastSet(int exerciseId, Map<String, String> entry) {
    final list = _setsByExercise[exerciseId];
    if (list != null && list.isNotEmpty) {
      list[list.length - 1] = Map<String, String>.from(entry);
      final effortIds = _effortIdsByExercise.putIfAbsent(exerciseId, () => []);
      final effortId =
          effortIds.isNotEmpty ? effortIds.last : UuidV4.generate();
      if (effortIds.isEmpty) effortIds.add(effortId);
      _enqueueEffortWrite(exerciseId, effortId, entry);
    } else {
      addSet(exerciseId, entry);
      return;
    }
    notifyListeners();
  }

  void removeLastSet(int exerciseId) {
    final list = _setsByExercise[exerciseId];
    if (list != null && list.isNotEmpty) {
      list.removeLast();
      final ids = _effortIdsByExercise[exerciseId];
      if (ids != null && ids.isNotEmpty) {
        _enqueueEffortDelete(ids.removeLast());
      }
      notifyListeners();
    }
  }

  void removeSetAt(int exerciseId, int index) {
    final list = _setsByExercise[exerciseId];
    if (list != null && index >= 0 && index < list.length) {
      list.removeAt(index);
      final ids = _effortIdsByExercise[exerciseId];
      if (ids != null && index < ids.length) {
        _enqueueEffortDelete(ids.removeAt(index));
      }
      notifyListeners();
    }
  }

  void _enqueueEffortWrite(
    int exerciseId,
    String effortId,
    Map<String, String> values,
  ) {
    final sessionId = _activitySessionId;
    final itemId = _activityItemIds[exerciseId];
    if (sessionId == null || itemId == null) return;
    final snapshot = Map<String, String>.from(values);
    _pendingWrites.add(
      () => _activityRepository.putEffort(
        effortId: effortId,
        sessionId: sessionId,
        activityItemId: itemId,
        sortOrder: _effortIdsByExercise[exerciseId]?.indexOf(effortId) ?? 0,
        metrics: _metricsFromEntry(snapshot),
      ),
    );
    _startDrain();
  }

  void _enqueueEffortDelete(String effortId) {
    if (_activitySessionId == null) return;
    _pendingWrites.add(() => _activityRepository.removeEffort(effortId));
    _startDrain();
  }

  static List<ActivityMetricInput> _metricsFromEntry(
    Map<String, String> entry,
  ) {
    final metrics = <ActivityMetricInput>[];
    void add(String key, String code, double multiplier, String unit) {
      final value = double.tryParse(entry[key]?.replaceAll(',', '.') ?? '');
      if (value == null) return;
      metrics.add(
        ActivityMetricInput(
          metricCode: code,
          canonicalValue: value * multiplier,
          enteredValue: value,
          enteredUnitCode: unit,
        ),
      );
    }

    add('reps', 'repetitions', 1, 'count');
    add('weight', 'weight', 1, 'kg');
    add('duration', 'duration', 1, 'second');
    add('distance', 'distance', 1000, 'kilometer');
    return metrics;
  }

  void _startDrain() {
    if (_drainingWrites || _persistenceError != null) return;
    _drainingWrites = true;
    _drainCompleter = Completer<void>();
    unawaited(_drainWrites());
  }

  Future<void> _drainWrites() async {
    while (_pendingWrites.isNotEmpty) {
      try {
        await _pendingWrites.first();
        _pendingWrites.removeAt(0);
      } catch (error) {
        _persistenceError = error;
        break;
      }
    }
    _drainingWrites = false;
    _drainCompleter?.complete();
    _drainCompleter = null;
    notifyListeners();
  }

  Future<void> retryPendingWrites() async {
    _persistenceError = null;
    _startDrain();
    await flushPendingWrites();
  }

  Future<void> flushPendingWrites() async {
    if (_persistenceError != null) throw _persistenceError!;
    if (_pendingWrites.isNotEmpty && !_drainingWrites) _startDrain();
    await _drainCompleter?.future;
    if (_persistenceError != null) throw _persistenceError!;
  }

  Future<void> completePersistedSession() async {
    final sessionId = _activitySessionId;
    if (sessionId == null) return;
    await flushPendingWrites();
    await _activityRepository.completeSession(sessionId);
  }

  void pause() {
    if (!isActive || _isPaused) return;
    _isPaused = true;
    _pausedAt = DateTime.now();
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void resume() {
    if (!isActive || !_isPaused || _pausedAt == null) return;
    _extraElapsed += _pausedAt!.difference(_startedAt!).inSeconds;
    _startedAt = DateTime.now();
    _isPaused = false;
    _pausedAt = null;
    _startTicker();
    notifyListeners();
  }

  int get elapsedTotalSeconds {
    if (_startedAt == null) return 0;
    if (_isPaused && _pausedAt != null) {
      return _pausedAt!.difference(_startedAt!).inSeconds + _extraElapsed;
    }
    return DateTime.now().difference(_startedAt!).inSeconds + _extraElapsed;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _notifyElapsed(),
    );
  }

  void _notifyElapsed() {
    elapsedSeconds.value = elapsedTotalSeconds;
  }

  /// Beendet die Session im Speicher, ohne zu persistieren (UI entscheidet was kommt).
  void clear() {
    final persistedSessionId = _activitySessionId;
    if (persistedSessionId != null) {
      unawaited(_activityRepository.discardSession(persistedSessionId));
    }
    _clearMemory();
  }

  /// Clears UI state after a successful persisted completion without marking
  /// the already completed canonical session as discarded.
  void clearCompleted() => _clearMemory();

  void _clearMemory() {
    _ticker?.cancel();
    _ticker = null;
    _workout = null;
    _exercises = const [];
    _startedAt = null;
    _extraElapsed = 0;
    _isPaused = false;
    _pausedAt = null;
    _setsByExercise.clear();
    _sessionId = null;
    _profileId = null;
    _workoutVariantId = null;
    _activitySessionId = null;
    _activityItemIds.clear();
    _effortIdsByExercise.clear();
    _pendingWrites.clear();
    _persistenceError = null;
    _groupVariantSelections.clear();
    _slotExerciseSelections.clear();
    _sessionPlanGroups = const [];
    _planExercisePool = const [];
    _enabledOptionalSlotIds = <int>{};
    elapsedSeconds.value = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    elapsedSeconds.dispose();
    super.dispose();
  }
}
