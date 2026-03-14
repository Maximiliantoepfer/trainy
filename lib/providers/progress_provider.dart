import 'package:flutter/material.dart';

import '../models/workout_entry.dart';
import '../services/workout_entry_database.dart';
import '../services/settings_database.dart';

/// Provider für den Progress-Screen (Laden/Speichern von Sessions).
class ProgressProvider extends ChangeNotifier {
  final List<WorkoutEntry> _entries = [];
  int _weeklyGoal = 2;
  bool _isLoading = false;
  bool _isSaving = false;
  Set<int> _trainingDays = {};

  List<WorkoutEntry> get entries => List.unmodifiable(_entries);
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

      // Aggregation: letzte Werte & Summen (simple Heuristik)
      final Map<int, Map<String, dynamic>> results = {};
      for (final entry in setsByExercise.entries) {
        final int exerciseId = entry.key;
        final List<Map<String, String>> sets = entry.value;

        int totalDuration = 0;
        int? lastReps;
        double? lastWeight;
        int? lastSets;

        for (final s in sets) {
          final repsStr = s['reps']?.trim();
          final weightStr = s['weight']?.trim();
          final setsStr = s['sets']?.trim();
          final durStr = s['duration']?.trim();

          if (repsStr?.isNotEmpty == true) {
            final v = int.tryParse(repsStr!);
            if (v != null) lastReps = v;
          }
          if (weightStr?.isNotEmpty == true) {
            final v = double.tryParse(weightStr!);
            if (v != null) lastWeight = v;
          }
          if (setsStr?.isNotEmpty == true) {
            final v = int.tryParse(setsStr!);
            if (v != null) lastSets = v;
          }
          if (durStr?.isNotEmpty == true) {
            final v = int.tryParse(durStr!);
            if (v != null) totalDuration += v;
          }
        }

        final map = <String, dynamic>{};
        if (lastSets != null) map['sets'] = lastSets!;
        if (lastReps != null) map['reps'] = lastReps!;
        if (lastWeight != null) map['weight'] = lastWeight!;
        if (totalDuration > 0) map['duration'] = totalDuration;

        results[exerciseId] = map;
      }

      final entry = WorkoutEntry(
        id: DateTime.now().millisecondsSinceEpoch,
        workoutId: workoutId,
        date: date,
        results: results,
      );

      await WorkoutEntryDatabase.instance.insertEntry(
        entry,
        sessionDurationSeconds: durationSeconds,
      );
      await refreshEntries();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
