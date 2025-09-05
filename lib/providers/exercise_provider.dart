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
    if (_exercises.any((e) => e.id == exercise.id)) {
      await ExerciseDatabase.instance.updateExercise(exercise);
      final index = _exercises.indexWhere((e) => e.id == exercise.id);
      _exercises[index] = exercise;
    } else {
      await ExerciseDatabase.instance.insertExercise(exercise);
      _exercises.add(exercise);
    }
    notifyListeners();
  }

  /// Alias für kompatiblen Code (z. B. WorkoutScreen)
  Future<void> updateExercise(Exercise exercise) async {
    await addOrUpdateExercise(exercise);
  }

  Future<void> deleteExercises(List<int> ids) async {
    await ExerciseDatabase.instance.deleteExercises(ids);
    _exercises.removeWhere((e) => ids.contains(e.id));
    notifyListeners();
  }
}
