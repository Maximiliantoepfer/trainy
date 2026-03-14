// lib/models/workout.dart

class Workout {
  int id;
  String name;
  String description;
  List<int> exerciseIds;
  Set<int> assignedDays; // 1=Mo ... 7=So

  Workout({
    required this.id,
    required this.name,
    this.description = '',
    this.exerciseIds = const [],
    this.assignedDays = const {},
  });

  Workout copyWith({
    int? id,
    String? name,
    String? description,
    List<int>? exerciseIds,
    Set<int>? assignedDays,
  }) {
    return Workout(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      exerciseIds: exerciseIds ?? List<int>.from(this.exerciseIds),
      assignedDays: assignedDays ?? Set<int>.from(this.assignedDays),
    );
  }
}
