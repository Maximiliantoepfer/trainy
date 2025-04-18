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

  Future<void> addWorkout(Workout workout) async {
    await WorkoutDatabase.instance.insertWorkout(workout);
    _workouts.add(workout);
    notifyListeners();
  }

  Future<void> updateWorkout(Workout workout) async {
    await WorkoutDatabase.instance.insertWorkout(workout);
    final index = _workouts.indexWhere((w) => w.id == workout.id);
    if (index != -1) {
      _workouts[index] = workout;
      notifyListeners();
    }
  }

  Future<void> updateWorkoutName(int workoutId, String newName) async {
    await WorkoutDatabase.instance.updateWorkoutName(workoutId, newName);
    final workout = _workouts.firstWhere((w) => w.id == workoutId);
    workout.name = newName;
    notifyListeners();
  }

  Future<void> deleteWorkout(int workoutId) async {
    await WorkoutDatabase.instance.deleteWorkout(workoutId);
    _workouts.removeWhere((w) => w.id == workoutId);
    notifyListeners();
  }
}
