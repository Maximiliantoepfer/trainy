class Exercise {
  final int id;
  final String name;
  final String description;

  // Welche Felder werden getrackt?
  final bool trackSets;
  final bool trackReps;
  final bool trackWeight;
  final bool trackDuration;
  final bool trackDistance;

  /// Vom/der Nutzer:in gesetzte Defaults (Strings, z. B. "10", "50")
  final Map<String, String> defaultValues;

  /// Zuletzt verwendete Werte (werden beim nächsten Tracking als Prefill genutzt)
  final Map<String, String> lastValues;

  /// Einheiten je Feld (optional), z. B. {"weight": "kg"}
  final Map<String, String> units;

  /// Optionales Icon (Material codePoint)
  final int? icon;

  /// Trainingsziel (z. B. "Kraft", "Ausdauer", "Cardio", "Mobilität")
  final String? goal;

  /// Namen zusammengeführter Übungen (in-memory, aus merge_history geladen).
  final List<String> mergedAliases;

  const Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.trackSets,
    required this.trackReps,
    required this.trackWeight,
    required this.trackDuration,
    required this.trackDistance,
    required this.defaultValues,
    required this.lastValues,
    required this.units,
    required this.icon,
    this.goal,
    this.mergedAliases = const [],
  });

  Exercise copyWith({
    int? id,
    String? name,
    String? description,
    bool? trackSets,
    bool? trackReps,
    bool? trackWeight,
    bool? trackDuration,
    bool? trackDistance,
    Map<String, String>? defaultValues,
    Map<String, String>? lastValues,
    Map<String, String>? units,
    int? icon,
    String? goal,
    List<String>? mergedAliases,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      trackSets: trackSets ?? this.trackSets,
      trackReps: trackReps ?? this.trackReps,
      trackWeight: trackWeight ?? this.trackWeight,
      trackDuration: trackDuration ?? this.trackDuration,
      trackDistance: trackDistance ?? this.trackDistance,
      defaultValues: defaultValues ?? this.defaultValues,
      lastValues: lastValues ?? this.lastValues,
      units: units ?? this.units,
      icon: icon ?? this.icon,
      goal: goal ?? this.goal,
      mergedAliases: mergedAliases ?? this.mergedAliases,
    );
  }
}
