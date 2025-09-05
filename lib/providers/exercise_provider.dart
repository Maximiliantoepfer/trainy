// lib/providers/exercise_provider.dart

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
    _exercises = await ExerciseDatabase.instance.getAllExercises();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addOrUpdateExercise(Exercise exercise) async {
    await ExerciseDatabase.instance.upsertExercise(exercise);
    final idx = _exercises.indexWhere((e) => e.id == exercise.id);
    if (idx >= 0) {
      _exercises[idx] = exercise;
    } else {
      _exercises.add(exercise);
      _exercises.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
    notifyListeners();
  }

  /// Kompatibler Alias für bestehenden Code
  Future<void> updateExercise(Exercise exercise) async =>
      addOrUpdateExercise(exercise);

  Future<void> updateLastValues(
    int exerciseId,
    Map<String, String> values,
  ) async {
    final idx = _exercises.indexWhere((e) => e.id == exerciseId);
    if (idx < 0) return;
    final updated = _exercises[idx].copyWith(lastValues: values);
    await ExerciseDatabase.instance.upsertExercise(updated);
    _exercises[idx] = updated;
    notifyListeners();
  }

  Future<void> deleteExercises(List<int> ids) async {
    await ExerciseDatabase.instance.deleteExercises(ids);
    _exercises.removeWhere((e) => ids.contains(e.id));
    notifyListeners();
  }
}
