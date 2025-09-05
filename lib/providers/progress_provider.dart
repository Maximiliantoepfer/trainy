// progress_provider.dart

import 'package:flutter/material.dart';

import '../models/workout_entry.dart';
import '../services/workout_entry_database.dart';
import '../services/settings_database.dart';

/// Verwaltet Fortschritt/Statistiken für den Progress-Screen.
/// Bietet `loadData()` und `entries`, damit progress_screen.dart sauber bauen kann.
class ProgressProvider extends ChangeNotifier {
  final List<WorkoutEntry> _entries = [];
  int _weeklyGoal = 2;
  bool _isLoading = false;
  bool _isSaving = false;

  // ----- Getter (vom Screen erwartet) -----
  List<WorkoutEntry> get entries => List.unmodifiable(_entries);
  int get weeklyGoal => _weeklyGoal;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;

  /// Initiales Laden von Wochenziel + Einträgen.
  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      _weeklyGoal = await SettingsDatabase.instance.getWeeklyGoal();
      final list = await WorkoutEntryDatabase.instance.getAllEntries();
      _entries
        ..clear()
        ..addAll(list);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Nur Einträge aktualisieren (z. B. nach Speichern).
  Future<void> refreshEntries() async {
    final list = await WorkoutEntryDatabase.instance.getAllEntries();
    _entries
      ..clear()
      ..addAll(list);
    notifyListeners();
  }

  /// Wochenziel setzen und speichern.
  Future<void> setWeeklyGoal(int value) async {
    _weeklyGoal = value;
    await SettingsDatabase.instance.setWeeklyGoal(value);
    notifyListeners();
  }

  /// Workout-Session speichern (vom Workout-Run aufrufbar).
  /// Aggregiert die Sätze pro Übung in ein kompaktes Resultat.
  Future<void> saveWorkoutEntries({
    required int workoutId,
    required int durationSeconds, // optional nutzbar, falls DB-Feld vorhanden
    required Map<int, List<Map<String, String>>> setsByExercise,
    DateTime? when,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      final date = when ?? DateTime.now();

      final Map<int, Map<String, dynamic>> results = {};
      for (final entry in setsByExercise.entries) {
        final int exerciseId = entry.key;
        final List<Map<String, String>> sets = entry.value;

        int totalDuration = 0;
        int? lastReps;
        double? lastWeight;

        for (final s in sets) {
          final repsStr = s['reps']?.trim();
          final weightStr = s['weight']?.trim();
          final durStr = s['duration']?.trim();

          if (repsStr != null && repsStr.isNotEmpty) {
            final r = int.tryParse(repsStr);
            if (r != null) lastReps = r;
          }
          if (weightStr != null && weightStr.isNotEmpty) {
            final w = double.tryParse(weightStr.replaceAll(',', '.'));
            if (w != null) lastWeight = w;
          }
          if (durStr != null && durStr.isNotEmpty) {
            final d = int.tryParse(durStr);
            if (d != null) totalDuration += d;
          }
        }

        final map = <String, dynamic>{'sets': sets.length};
        if (totalDuration > 0) map['duration'] = totalDuration;
        if (lastReps != null) map['reps'] = lastReps;
        if (lastWeight != null) map['weight'] = lastWeight;

        results[exerciseId] = map;
      }

      final entry = WorkoutEntry(
        id: DateTime.now().microsecondsSinceEpoch,
        workoutId: workoutId,
        date: date,
        results: results,
      );

      await WorkoutEntryDatabase.instance.insertEntry(entry);
      await refreshEntries();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Legacy-Kompatibilität: manche Alt-Stellen rufen das.
  Future<void> addWorkout({Duration? duration}) async {
    await refreshEntries();
  }
}
