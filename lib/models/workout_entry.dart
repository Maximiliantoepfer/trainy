// lib/models/workout_entry.dart

class WorkoutEntry {
  final int id;
  final int workoutId;
  final DateTime date;

  /// Ergebnisse: exerciseId -> {fieldName: value}
  final Map<int, Map<String, dynamic>> results;

  /// Session-Timer-Dauer in Sekunden (nullable für ältere Einträge).
  final int? durationSeconds;

  const WorkoutEntry({
    required this.id,
    required this.workoutId,
    required this.date,
    required this.results,
    this.durationSeconds,
  });

  @override
  String toString() =>
      'WorkoutEntry{id: $id, workoutId: $workoutId, date: $date, results: $results}';
}
