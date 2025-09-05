class WorkoutEntry {
  final int id;
  final int workoutId;
  final DateTime date;
  final Map<int, Map<String, dynamic>> results; // exerciseId → Felder

  WorkoutEntry({
    required this.id,
    required this.workoutId,
    required this.date,
    required this.results,
  });

  @override
  String toString() {
    return 'WorkoutEntry{id: $id, workoutId: $workoutId, date: $date, results: $results}';
  }
}
