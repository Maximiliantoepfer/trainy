import 'exercise.dart';

class Workout {
  final int id;
  final String name;
  final String description;
  final List<Exercise> exercises;

  Workout({
    required this.id,
    required this.name,
    required this.exercises,
    this.description = '',
  });

  @override
  String toString() {
    return 'Workout{id: $id, name: $name, exercises: $exercises}';
  }
}
