// lib/models/workout.dart

class Workout {
  int id;
  String name;
  String description;
  List<int> exerciseIds;

  Workout({
    required this.id,
    required this.name,
    this.description = '',
    this.exerciseIds = const [],
  });

  Workout copyWith({
    int? id,
    String? name,
    String? description,
    List<int>? exerciseIds,
  }) {
    return Workout(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      exerciseIds: exerciseIds ?? List<int>.from(this.exerciseIds),
    );
  }
}
