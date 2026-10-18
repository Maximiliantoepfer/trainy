import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../models/workout_planning.dart';
import '../repositories/workout_planning_repository.dart';

/// UI state for canonical workout planning. Widgets never write the legacy
/// integer tables directly; the repository owns the temporary runner bridge.
class WorkoutProvider extends ChangeNotifier {
  WorkoutProvider({WorkoutPlanningRepository? repository})
    : _repository = repository ?? WorkoutPlanningRepository();

  final WorkoutPlanningRepository _repository;
  List<Workout> _workouts = const [];
  bool _isLoading = false;
  Object? _error;

  List<Workout> get workouts => List.unmodifiable(_workouts);
  bool get isLoading => _isLoading;
  Object? get error => _error;

  Future<void> loadWorkouts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _workouts = await _repository.workouts();
    } catch (error) {
      _error = error;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Workout> createWorkout({
    required String name,
    String description = '',
    WorkoutPrimaryGoal primaryGoal = WorkoutPrimaryGoal.strength,
    String setupName = 'Standard',
    String? profileId,
    List<int> exerciseIds = const [],
    String? creationId,
  }) async {
    final workout = await _repository.createWorkout(
      WorkoutEditorDraft(
        name: name,
        description: description,
        primaryGoal: primaryGoal,
        setupName: setupName,
        profileId: profileId,
        exerciseIds: exerciseIds,
        creationId: creationId,
      ),
    );
    _workouts = [
      ..._workouts.where((value) => value.canonicalId != workout.canonicalId),
      workout,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
    return workout;
  }

  Future<void> updateWorkoutName(int workoutId, String name) async {
    final workout = _find(workoutId);
    await _repository.updateBasics(workout: workout, name: name);
    _replace(workout.copyWith(name: name.trim()));
  }

  Future<void> updateWorkoutBasics({
    required Workout workout,
    required String name,
    String? description,
    WorkoutPrimaryGoal? primaryGoal,
  }) async {
    await _repository.updateBasics(
      workout: workout,
      name: name,
      description: description,
      primaryGoal: primaryGoal,
    );
    _replace(
      workout.copyWith(
        name: name.trim(),
        description: description,
        primaryGoalCode: primaryGoal?.code,
      ),
    );
  }

  Future<void> setWorkoutExercises(int workoutId, List<int> exerciseIds) async {
    final workout = _find(workoutId);
    await _repository.replaceDefaultExercises(
      workoutId: workout.canonicalId,
      exerciseIds: exerciseIds,
    );
    _replace(workout.copyWith(exerciseIds: exerciseIds));
  }

  Future<void> setWorkoutDays(int workoutId, Set<int> days) async {
    final workout = _find(workoutId);
    await _repository.replaceWorkoutDays(
      workoutId: workout.canonicalId,
      weekdays: days,
    );
    await loadWorkouts();
  }

  /// Compatibility command for callers that still hand over multiple labels.
  /// A workout now has one visible primary goal, selected deterministically.
  Future<void> setWorkoutGoalCodes(int workoutId, List<String> values) async {
    const priority = ['strength', 'endurance', 'cardio', 'mobility'];
    final goal = priority.firstWhere(values.contains, orElse: () => 'strength');
    final workout = _find(workoutId);
    await _repository.updateBasics(
      workout: workout,
      name: workout.name,
      primaryGoal: WorkoutPrimaryGoal.fromCode(goal),
    );
    _replace(workout.copyWith(primaryGoalCode: goal));
  }

  List<Workout> workoutsForDay(int dayOfWeek) =>
      _workouts
          .where((workout) => workout.assignedDays.contains(dayOfWeek))
          .toList()
        ..sort((a, b) {
          final order = (a.scheduleOrderByDay[dayOfWeek] ?? 0).compareTo(
            b.scheduleOrderByDay[dayOfWeek] ?? 0,
          );
          return order != 0 ? order : a.name.compareTo(b.name);
        });

  Future<void> deleteWorkout(int workoutId) async {
    final workout = _find(workoutId);
    await _repository.archiveWorkout(workout);
    _workouts = _workouts.where((value) => value.id != workoutId).toList();
    notifyListeners();
  }

  Workout _find(int workoutId) => _workouts.firstWhere(
    (workout) => workout.id == workoutId,
    orElse: () => throw StateError('Workout no longer exists.'),
  );

  void _replace(Workout next) {
    _workouts = _workouts
        .map((workout) => workout.id == next.id ? next : workout)
        .toList(growable: false);
    notifyListeners();
  }
}
