// lib/models/workout.dart

import 'exercise_in_workout.dart';

class Workout {
  int id;
  String name;
  String description;
  List<ExerciseInWorkout> exercises;

  Workout({
    required this.id,
    required this.name,
    this.description = '',
    this.exercises = const [],
  });
}
