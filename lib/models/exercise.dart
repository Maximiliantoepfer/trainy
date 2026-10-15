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

  /// Stable key for a bundled catalog exercise. Null means user-created.
  final String? standardKey;

  /// Immutable catalog ID (for example `free:Barbell_Squat`). A null value
  /// identifies a personal exercise. `standardKey` remains only for migration
  /// from the old 36-item seed.
  final String? catalogId;

  /// A personal display addition over a standard record. It is never
  /// translated automatically.
  final String? alias;
  final String notes;
  final List<String> goalCodes;
  final List<String> imagePaths;
  final bool isArchived;

  /// A catalog exercise retains its localized name until the user changes it.
  final bool isNameCustom;

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
    this.standardKey,
    this.catalogId,
    this.alias,
    this.notes = '',
    this.goalCodes = const [],
    this.imagePaths = const [],
    this.isArchived = false,
    this.isNameCustom = true,
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
    String? standardKey,
    String? catalogId,
    String? alias,
    String? notes,
    List<String>? goalCodes,
    List<String>? imagePaths,
    bool? isArchived,
    bool? isNameCustom,
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
      standardKey: standardKey ?? this.standardKey,
      catalogId: catalogId ?? this.catalogId,
      alias: alias ?? this.alias,
      notes: notes ?? this.notes,
      goalCodes: goalCodes ?? this.goalCodes,
      imagePaths: imagePaths ?? this.imagePaths,
      isArchived: isArchived ?? this.isArchived,
      isNameCustom: isNameCustom ?? this.isNameCustom,
      mergedAliases: mergedAliases ?? this.mergedAliases,
    );
  }
}

class DuplicateSuggestion {
  const DuplicateSuggestion({
    required this.id,
    required this.sourceExerciseId,
    required this.confidence,
    this.targetExerciseId,
    this.targetCatalogId,
  });

  final int id;
  final int sourceExerciseId;
  final int? targetExerciseId;
  final String? targetCatalogId;
  final String confidence;
}
