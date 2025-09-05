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

  Future<int> addExercise({
    required String name,
    String description = '',
    bool trackSets = true,
    bool trackReps = true,
    bool trackWeight = true,
    bool trackDuration = false,
    Map<String, String> defaultValues = const {},
    Map<String, String> units = const {},
    int? iconCodePoint,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final tracked = <String>[];
    if (trackSets) tracked.add('sets');
    if (trackReps) tracked.add('reps');
    if (trackWeight) tracked.add('weight');
    if (trackDuration) tracked.add('duration');

    final exercise = Exercise(
      id: id,
      name: name.trim(),
      description: description.trim(),
      trackedFields:
          tracked.isEmpty ? const ['sets', 'reps', 'weight'] : tracked,
      defaultValues: defaultValues,
      lastValues: const {},
      units: units,
      icon: iconCodePoint,
    );

    await ExerciseDatabase.instance.upsertExercise(exercise);

    _exercises.add(exercise);
    _exercises.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    notifyListeners();

    return id;
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
