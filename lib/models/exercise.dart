class Exercise {
  final int id;
  final String name;
  final String description;
  final List<String>
  trackedFields; // z.B. ['Sätze', 'Wiederholungen', 'Gewicht']

  Exercise({
    required this.id,
    required this.name,
    required this.trackedFields,
    this.description = '',
  });

  @override
  String toString() {
    return 'Exercise{id: $id, name: $name, description: $description, trackedFields: $trackedFields}';
  }
}
