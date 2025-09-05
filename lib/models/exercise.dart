class Exercise {
  final int id;
  final String name;
  final String description;

  // Welche Felder werden getrackt?
  final bool trackSets;
  final bool trackReps;
  final bool trackWeight;
  final bool trackDuration;

  /// Vom/der Nutzer:in gesetzte Defaults (Strings, z. B. "10", "50")
  final Map<String, String> defaultValues;

  /// Zuletzt verwendete Werte (werden beim nächsten Tracking als Prefill genutzt)
  final Map<String, String> lastValues;

  /// Einheiten je Feld (optional), z. B. {"weight": "kg"}
  final Map<String, String> units;

  /// Optionales Icon (Material codePoint)
  final int? icon;

  const Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.trackSets,
    required this.trackReps,
    required this.trackWeight,
    required this.trackDuration,
    required this.defaultValues,
    required this.lastValues,
    required this.units,
    required this.icon,
  });

  Exercise copyWith({
    int? id,
    String? name,
    String? description,
    bool? trackSets,
    bool? trackReps,
    bool? trackWeight,
    bool? trackDuration,
    Map<String, String>? defaultValues,
    Map<String, String>? lastValues,
    Map<String, String>? units,
    int? icon,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      trackSets: trackSets ?? this.trackSets,
      trackReps: trackReps ?? this.trackReps,
      trackWeight: trackWeight ?? this.trackWeight,
      trackDuration: trackDuration ?? this.trackDuration,
      defaultValues: defaultValues ?? this.defaultValues,
      lastValues: lastValues ?? this.lastValues,
      units: units ?? this.units,
      icon: icon ?? this.icon,
    );
  }
}
