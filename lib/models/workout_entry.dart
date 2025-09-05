// lib/models/workout_entry.dart

class WorkoutEntry {
  final int id;
  final int workoutId;
  final DateTime date;

  /// Ergebnisse: exerciseId -> {fieldName: value}
  final Map<int, Map<String, dynamic>> results;

  const WorkoutEntry({
    required this.id,
    required this.workoutId,
    required this.date,
    required this.results,
  });

  @override
  String toString() =>
      'WorkoutEntry{id: $id, workoutId: $workoutId, date: $date, results: $results}';
}
