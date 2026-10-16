// lib/models/workout.dart

class Workout {
  int id;
  String canonicalId;
  String name;
  String description;
  List<int> exerciseIds;
  Set<int> assignedDays; // 1=Mo ... 7=So
  String primaryGoalCode;
  Map<int, int> scheduleOrderByDay;

  Workout({
    required this.id,
    String? canonicalId,
    required this.name,
    this.description = '',
    this.exerciseIds = const [],
    this.assignedDays = const {},
    String primaryGoalCode = 'strength',
    List<String>? goalCodes,
    this.scheduleOrderByDay = const {},
  }) : canonicalId = canonicalId ?? 'legacy-workout:$id',
       primaryGoalCode = _primaryGoal(primaryGoalCode, goalCodes);

  /// Compatibility view for statistics and older call sites. A workout has
  /// exactly one visible goal; endurance remains cardio + endurance in stats.
  List<String> get goalCodes =>
      primaryGoalCode == 'endurance'
          ? const ['cardio', 'endurance']
          : [primaryGoalCode];

  Workout copyWith({
    int? id,
    String? canonicalId,
    String? name,
    String? description,
    List<int>? exerciseIds,
    Set<int>? assignedDays,
    String? primaryGoalCode,
    List<String>? goalCodes,
    Map<int, int>? scheduleOrderByDay,
  }) {
    return Workout(
      id: id ?? this.id,
      canonicalId: canonicalId ?? this.canonicalId,
      name: name ?? this.name,
      description: description ?? this.description,
      exerciseIds: exerciseIds ?? List<int>.from(this.exerciseIds),
      assignedDays: assignedDays ?? Set<int>.from(this.assignedDays),
      primaryGoalCode: _primaryGoal(
        primaryGoalCode ?? this.primaryGoalCode,
        goalCodes,
      ),
      scheduleOrderByDay:
          scheduleOrderByDay ?? Map<int, int>.from(this.scheduleOrderByDay),
    );
  }

  static String _primaryGoal(String fallback, List<String>? values) {
    if (values == null) return fallback;
    for (final goal in const ['strength', 'endurance', 'cardio', 'mobility']) {
      if (values.contains(goal)) return goal;
    }
    return fallback;
  }
}
