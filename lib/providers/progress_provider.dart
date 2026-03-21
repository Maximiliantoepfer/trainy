import 'dart:math';

import 'package:flutter/material.dart';

import '../models/workout_entry.dart';
import '../models/pinned_chart.dart';
import '../services/workout_entry_database.dart';
import '../services/settings_database.dart';
import '../services/pinned_chart_database.dart';

/// Provider für den Progress-Screen (Laden/Speichern von Sessions).
class ProgressProvider extends ChangeNotifier {
  final List<WorkoutEntry> _entries = [];
  List<PinnedChart> _pinnedCharts = [];
  int _weeklyGoal = 2;
  bool _isLoading = false;
  bool _isSaving = false;
  Set<int> _trainingDays = {};

  List<WorkoutEntry> get entries => List.unmodifiable(_entries);
  List<PinnedChart> get pinnedCharts => List.unmodifiable(_pinnedCharts);
  int get weeklyGoal => _weeklyGoal;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Set<int> get trainingDays => _trainingDays;

  /// Returns explicitly set training days, or a heuristic fallback based on weeklyGoal.
  Set<int> get effectiveTrainingDays {
    if (_trainingDays.isNotEmpty) return _trainingDays;
    return _heuristicDays(_weeklyGoal);
  }

  static Set<int> _heuristicDays(int goal) {
    switch (goal.clamp(1, 7)) {
      case 1: return const {3};
      case 2: return const {2, 5};
      case 3: return const {1, 3, 5};
      case 4: return const {1, 2, 4, 5};
      case 5: return const {1, 2, 3, 4, 5};
      case 6: return const {1, 2, 3, 4, 5, 6};
      case 7: return const {1, 2, 3, 4, 5, 6, 7};
      default: return const {1, 3, 5};
    }
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      _weeklyGoal = await SettingsDatabase.instance.getWeeklyGoal();
      final tdStr = await SettingsDatabase.instance.getTrainingDays();
      _trainingDays = tdStr.isEmpty
          ? {}
          : tdStr.split(',').map((s) => int.tryParse(s.trim()) ?? 0).where((d) => d >= 1 && d <= 7).toSet();
      final list = await WorkoutEntryDatabase.instance.getAggregatedEntries();
      _entries
        ..clear()
        ..addAll(list);
      _pinnedCharts = await PinnedChartDatabase.instance.getAll();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshEntries() async {
    final list = await WorkoutEntryDatabase.instance.getAggregatedEntries();
    _entries
      ..clear()
      ..addAll(list);
    notifyListeners();
  }

  /// Löscht einen Workout-Eintrag aus DB und In-Memory-Liste.
  Future<void> deleteEntry(WorkoutEntry entry) async {
    await WorkoutEntryDatabase.instance.deleteEntry(
      workoutId: entry.workoutId,
      timestamp: entry.date.millisecondsSinceEpoch,
    );
    _entries.removeWhere((e) =>
      e.workoutId == entry.workoutId &&
      e.date.millisecondsSinceEpoch == entry.date.millisecondsSinceEpoch,
    );
    notifyListeners();
  }

  Future<void> setWeeklyGoal(int value) async {
    _weeklyGoal = value;
    await SettingsDatabase.instance.setWeeklyGoal(value);
    notifyListeners();
  }

  Future<void> setTrainingDays(Set<int> days) async {
    _trainingDays = days;
    final str = (days.toList()..sort()).join(',');
    await SettingsDatabase.instance.setTrainingDays(str);
    // Sync weeklyGoal to match selected days count
    if (days.isNotEmpty) {
      _weeklyGoal = days.length;
      await SettingsDatabase.instance.setWeeklyGoal(days.length);
    }
    notifyListeners();
  }

  /// Prüft ob eine bestimmte Übung+Metrik-Kombination bereits gepinnt ist.
  bool isPinned(int exerciseId, String metric) =>
      _pinnedCharts.any((pc) => pc.exerciseId == exerciseId && pc.metric == metric);

  /// Pinnt eine Übung+Metrik-Kombination.
  Future<void> pinChart(int exerciseId, String metric) async {
    if (isPinned(exerciseId, metric)) return;
    final chart = await PinnedChartDatabase.instance.add(exerciseId, metric);
    _pinnedCharts = [..._pinnedCharts, chart];
    notifyListeners();
  }

  /// Entfernt einen gepinnten Chart.
  Future<void> unpinChart(int id) async {
    await PinnedChartDatabase.instance.remove(id);
    _pinnedCharts = _pinnedCharts.where((pc) => pc.id != id).toList();
    notifyListeners();
  }

  /// Sortiert die gepinnten Charts um.
  Future<void> reorderPinnedCharts(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex--;
    final list = List<PinnedChart>.from(_pinnedCharts);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    _pinnedCharts = list;
    notifyListeners();
    await PinnedChartDatabase.instance.reorder(list.map((c) => c.id).toList());
  }

  /// Speichert eine Workout-Session (aufgerufen vom `WorkoutRunScreen`).
  /// `setsByExercise`: exerciseId → Liste von Sets (Felder reps/weight/sets/duration als Strings).
  Future<void> saveWorkoutEntries({
    required int workoutId,
    required int durationSeconds,
    required Map<int, List<Map<String, String>>> setsByExercise,
    DateTime? when,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      final date = when ?? DateTime.now();

      // Aggregation: Per-Set-Modus (kein 'sets'-Key) oder alter Modus
      final Map<int, Map<String, dynamic>> results = {};
      for (final entry in setsByExercise.entries) {
        final int exerciseId = entry.key;
        final List<Map<String, String>> sets = entry.value;

        // Erkennung: hat irgendein Set den 'sets'-Key? → alter Modus
        final isOldMode = sets.any((s) => s.containsKey('sets'));

        int totalDuration = 0;
        int? lastReps;
        double? maxWeight;
        int? lastSets;
        double totalDistance = 0;

        final perSetList = <Map<String, dynamic>>[];

        for (final s in sets) {
          final repsStr = s['reps']?.trim();
          final weightStr = s['weight']?.trim();
          final setsStr = s['sets']?.trim();
          final durStr = s['duration']?.trim();

          final setMap = <String, dynamic>{};

          if (repsStr?.isNotEmpty == true) {
            final v = int.tryParse(repsStr!);
            if (v != null) {
              lastReps = v;
              setMap['reps'] = v;
            }
          }
          if (weightStr?.isNotEmpty == true) {
            final v = double.tryParse(weightStr!);
            if (v != null) {
              if (maxWeight == null || v > maxWeight) maxWeight = v;
              setMap['weight'] = v;
            }
          }
          if (setsStr?.isNotEmpty == true) {
            final v = int.tryParse(setsStr!);
            if (v != null) lastSets = v;
          }
          if (durStr?.isNotEmpty == true) {
            final v = int.tryParse(durStr!);
            if (v != null) {
              totalDuration += v;
              setMap['duration'] = v;
            }
          }
          final distStr = s['distance']?.trim();
          if (distStr?.isNotEmpty == true) {
            final v = double.tryParse(distStr!);
            if (v != null) {
              totalDistance += v;
              setMap['distance'] = v;
            }
          }

          if (setMap.isNotEmpty) perSetList.add(setMap);
        }

        final map = <String, dynamic>{};

        // Per-Set-Modus: perSet-Array + abgeleitete Aggregate
        if (!isOldMode && perSetList.isNotEmpty) {
          map['perSet'] = perSetList;
          map['sets'] = perSetList.length;
        }

        // Alter Modus: manueller 'sets'-Wert
        if (isOldMode && lastSets != null) {
          map['sets'] = lastSets;
        }

        if (lastReps != null) map['reps'] = lastReps!;
        if (maxWeight != null) map['weight'] = maxWeight!;
        if (totalDuration > 0) map['duration'] = totalDuration;
        if (totalDistance > 0) map['distance'] = totalDistance;

        results[exerciseId] = map;
      }

      // Ensure session duration is at least the sum of exercise durations
      int sumOfExerciseDurations = 0;
      for (final r in results.values) {
        final d = r['duration'];
        if (d is int) sumOfExerciseDurations += d;
      }
      final effectiveDuration = max(durationSeconds, sumOfExerciseDurations);

      final entry = WorkoutEntry(
        id: DateTime.now().millisecondsSinceEpoch,
        workoutId: workoutId,
        date: date,
        results: results,
      );

      await WorkoutEntryDatabase.instance.insertEntry(
        entry,
        sessionDurationSeconds: effectiveDuration,
      );
      await refreshEntries();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
