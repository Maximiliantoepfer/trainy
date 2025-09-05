import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../services/exercise_database.dart';

class ExerciseProvider extends ChangeNotifier {
  List<Exercise> _exercises = [];
  bool _isLoading = false;

  List<Exercise> get exercises => _exercises;
  bool get isLoading => _isLoading;

  Future<void> loadExercises() async {
    _isLoading = true;
    notifyListeners();
    try {
      _exercises = await ExerciseDatabase.instance.getAllExercises();
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
    Map<String, String>? defaultValues,
    Map<String, String>? lastValues,
    Map<String, String>? units,
    int? icon,
  }) async {
    final exerciseId = await ExerciseDatabase.instance.addOrUpdateExercise(
      id: id,
      name: name,
      description: description,
      trackSets: trackSets,
      trackReps: trackReps,
      trackWeight: trackWeight,
      trackDuration: trackDuration,
      defaultValues: defaultValues,
      lastValues: lastValues,
      units: units,
      icon: icon,
    );

    final newExercise = Exercise(
      id: exerciseId,
      name: name,
      description: description,
      trackSets: trackSets,
      trackReps: trackReps,
      trackWeight: trackWeight,
      trackDuration: trackDuration,
      defaultValues: defaultValues ?? const {},
      lastValues: lastValues ?? const {},
      units: units ?? const {},
      icon: icon,
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
    Map<String, String>? defaultValues,
    Map<String, String>? lastValues,
    Map<String, String>? units,
    int? icon,
  }) {
    return addOrUpdateExercise(
      id: id,
      name: name,
      description: description,
      trackSets: trackSets,
      trackReps: trackReps,
      trackWeight: trackWeight,
      trackDuration: trackDuration,
      defaultValues: defaultValues,
      lastValues: lastValues,
      units: units,
      icon: icon,
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
  }) {
    return addOrUpdateExercise(
      name: name,
      description: description,
      trackSets: trackSets,
      trackReps: trackReps,
      trackWeight: trackWeight,
      trackDuration: trackDuration,
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
    await ExerciseDatabase.instance.deleteExercise(exerciseId);
    _exercises.removeWhere((x) => x.id == exerciseId);
    notifyListeners();
  }
}
