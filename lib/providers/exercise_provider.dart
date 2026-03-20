import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../services/exercise_database.dart';
import '../services/workout_entry_database.dart';

class ExerciseProvider extends ChangeNotifier {
  List<Exercise> _exercises = [];
  bool _isLoading = false;

  List<Exercise> get exercises => _exercises;
  bool get isLoading => _isLoading;

  Future<void> loadExercises() async {
    _isLoading = true;
    notifyListeners();
    try {
      await ExerciseDatabase.instance.ensureStandardExercises();
      await ExerciseDatabase.instance.deduplicateExercises();
      final exercises = await ExerciseDatabase.instance.getAllExercises();
      final aliasMap = await ExerciseDatabase.instance.getAllMergeAliases();
      _exercises = exercises.map((e) {
        final aliases = aliasMap[e.id];
        return aliases != null ? e.copyWith(mergedAliases: aliases) : e;
      }).toList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Kompatible API (wird z. B. aus Screens/Dialogs aufgerufen).
  Future<int> addOrUpdateExercise({
    int? id,
    required String name,
    String description = '',
    required bool trackSets,
    required bool trackReps,
    required bool trackWeight,
    required bool trackDuration,
    bool trackDistance = false,
    Map<String, String>? defaultValues,
    Map<String, String>? lastValues,
    Map<String, String>? units,
    int? icon,
    String? goal,
  }) async {
    final exerciseId = await ExerciseDatabase.instance.addOrUpdateExercise(
      id: id,
      name: name,
      description: description,
      trackSets: trackSets,
      trackReps: trackReps,
      trackWeight: trackWeight,
      trackDuration: trackDuration,
      trackDistance: trackDistance,
      defaultValues: defaultValues,
      lastValues: lastValues,
      units: units,
      icon: icon,
      goal: goal,
    );

    // Dedup: DB hat bestehende ID zurückgegeben → Übung existiert schon
    if (id == null && _exercises.any((e) => e.id == exerciseId)) {
      return exerciseId;
    }

    final newExercise = Exercise(
      id: exerciseId,
      name: name,
      description: description,
      trackSets: trackSets,
      trackReps: trackReps,
      trackWeight: trackWeight,
      trackDuration: trackDuration,
      trackDistance: trackDistance,
      defaultValues: defaultValues ?? const {},
      lastValues: lastValues ?? const {},
      units: units ?? const {},
      icon: icon,
      goal: goal,
    );

    final idx = _exercises.indexWhere((e) => e.id == exerciseId);
    if (idx >= 0) {
      _exercises[idx] = newExercise;
    } else {
      _exercises.add(newExercise);
      _exercises.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
    notifyListeners();

    return exerciseId;
  }

  /// Alias für ältere Aufrufer
  Future<int> updateExercise({
    required int id,
    required String name,
    String description = '',
    required bool trackSets,
    required bool trackReps,
    required bool trackWeight,
    required bool trackDuration,
    bool trackDistance = false,
    Map<String, String>? defaultValues,
    Map<String, String>? lastValues,
    Map<String, String>? units,
    int? icon,
    String? goal,
  }) {
    return addOrUpdateExercise(
      id: id,
      name: name,
      description: description,
      trackSets: trackSets,
      trackReps: trackReps,
      trackWeight: trackWeight,
      trackDuration: trackDuration,
      trackDistance: trackDistance,
      defaultValues: defaultValues,
      lastValues: lastValues,
      units: units,
      icon: icon,
      goal: goal,
    );
  }

  /// Für Quick-Create aus dem Workout-Sheet (beibehalten für Kompatibilität)
  Future<int> addExercise({
    required String name,
    String description = '',
    required bool trackSets,
    required bool trackReps,
    required bool trackWeight,
    required bool trackDuration,
    bool trackDistance = false,
    String? goal,
  }) {
    return addOrUpdateExercise(
      name: name,
      description: description,
      trackSets: trackSets,
      trackReps: trackReps,
      trackWeight: trackWeight,
      trackDuration: trackDuration,
      trackDistance: trackDistance,
      goal: goal,
    );
  }

  /// Last Values nach einer Session setzen (für Prefill im nächsten Dialog)
  Future<void> updateLastValues(
    int exerciseId,
    Map<String, String> lastValues,
  ) async {
    await ExerciseDatabase.instance.updateLastValues(exerciseId, lastValues);
    final idx = _exercises.indexWhere((x) => x.id == exerciseId);
    if (idx >= 0) {
      _exercises[idx] = _exercises[idx].copyWith(
        lastValues: Map<String, String>.from(lastValues),
      );
      notifyListeners();
    }
  }

  Future<void> deleteExercise(int exerciseId) async {
    await WorkoutEntryDatabase.instance.deleteEntriesForExercise(exerciseId);
    await ExerciseDatabase.instance.deleteExercise(exerciseId);
    _exercises.removeWhere((x) => x.id == exerciseId);
    notifyListeners();
  }

  /// Führt sourceId in targetId zusammen.
  /// Alle Fortschrittsdaten und Workout-Zuordnungen werden übertragen.
  Future<MergeResult> mergeExercise(int sourceId, int targetId) async {
    final sourceName = _exercises.firstWhere((e) => e.id == sourceId).name;
    final result = await ExerciseDatabase.instance.mergeExercises(sourceId, targetId);
    _exercises.removeWhere((e) => e.id == sourceId);
    final targetIdx = _exercises.indexWhere((e) => e.id == targetId);
    if (targetIdx >= 0) {
      final target = _exercises[targetIdx];
      _exercises[targetIdx] = target.copyWith(
        mergedAliases: [...target.mergedAliases, sourceName],
      );
    }
    notifyListeners();
    return result;
  }

  /// Zählt Fortschrittseinträge für eine Übung (für Merge-Bestätigung).
  Future<int> countEntriesForExercise(int exerciseId) async {
    return ExerciseDatabase.instance.countEntriesForExercise(exerciseId);
  }

  /// Gibt Namen aller Übungen zurück, die in [exerciseId] zusammengeführt wurden.
  Future<List<String>> getMergeHistory(int exerciseId) async {
    return ExerciseDatabase.instance.getMergeHistory(exerciseId);
  }

  /// Gibt vollständige Merge-History-Einträge zurück.
  Future<List<Map<String, dynamic>>> getMergeHistoryFull(int exerciseId) =>
      ExerciseDatabase.instance.getMergeHistoryFull(exerciseId);

  /// Entfernt einen Merge-History-Eintrag.
  Future<void> deleteMergeHistoryEntry(int id) =>
      ExerciseDatabase.instance.deleteMergeHistoryEntry(id);
}
