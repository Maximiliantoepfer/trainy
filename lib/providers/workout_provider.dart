// lib/providers/workout_provider.dart

import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../services/workout_database.dart';

class WorkoutProvider extends ChangeNotifier {
  List<Workout> _workouts = [];
  bool _isLoading = false;

  List<Workout> get workouts => _workouts;
  bool get isLoading => _isLoading;

  Future<void> loadWorkouts() async {
    _isLoading = true;
    notifyListeners();
    _workouts = await WorkoutDatabase.instance.getAllWorkouts();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addOrUpdateWorkout(Workout workout) async {
    await WorkoutDatabase.instance.upsertWorkout(workout);
    final idx = _workouts.indexWhere((w) => w.id == workout.id);
    if (idx >= 0) {
      _workouts[idx] = workout;
    } else {
      _workouts.add(workout);
      _workouts.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
    notifyListeners();
  }

  Future<void> updateWorkoutName(int workoutId, String newName) async {
    await WorkoutDatabase.instance.updateWorkoutName(workoutId, newName);
    final w = _workouts.firstWhere((w) => w.id == workoutId);
    w.name = newName;
    notifyListeners();
  }

  Future<void> updateWorkoutExercises(
    int workoutId,
    List<int> exerciseIds,
  ) async {
    await WorkoutDatabase.instance.updateWorkoutExercises(
      workoutId,
      exerciseIds,
    );
    final w = _workouts.firstWhere((w) => w.id == workoutId);
    w.exerciseIds = List<int>.from(exerciseIds);
    notifyListeners();
  }

  Future<void> deleteWorkout(int workoutId) async {
    await WorkoutDatabase.instance.deleteWorkout(workoutId);
    _workouts.removeWhere((w) => w.id == workoutId);
    notifyListeners();
  }
}
