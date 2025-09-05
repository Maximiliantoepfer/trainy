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

  List<WorkoutEntry> get entries => List.unmodifiable(_entries);
  int get weeklyGoal => _weeklyGoal;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      _weeklyGoal = await SettingsDatabase.instance.getWeeklyGoal();
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
