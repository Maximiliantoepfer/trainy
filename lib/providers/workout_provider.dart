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
    try {
      _workouts = await WorkoutDatabase.instance.getAllWorkouts();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  Future<Workout> createWorkout({required String name}) async {
    final w = Workout(
      id: DateTime.now().millisecondsSinceEpoch,
      name: name,
      description: '',
      exerciseIds: const [],
    );
    await addOrUpdateWorkout(w);
    return w;
  }

  Future<void> updateWorkoutName(int workoutId, String newName) async {
    await WorkoutDatabase.instance.updateWorkoutName(workoutId, newName);
    final idx = _workouts.indexWhere((w) => w.id == workoutId);
    if (idx >= 0) {
      _workouts[idx] = _workouts[idx].copyWith(name: newName);
      notifyListeners();
    }
  }

  Future<void> setWorkoutExercises(int workoutId, List<int> exerciseIds) async {
    await WorkoutDatabase.instance.setWorkoutExercises(workoutId, exerciseIds);
    final idx = _workouts.indexWhere((w) => w.id == workoutId);
    if (idx >= 0) {
      _workouts[idx] = _workouts[idx].copyWith(
        exerciseIds: List<int>.from(exerciseIds),
      );
      notifyListeners();
    }
  }

  Future<void> deleteWorkout(int workoutId) async {
    await WorkoutDatabase.instance.deleteWorkout(workoutId);
    _workouts.removeWhere((w) => w.id == workoutId);
    notifyListeners();
  }
}
