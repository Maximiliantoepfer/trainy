import 'dart:convert';

/// Immutable, bundled definition. Catalog records never contain user data.
class CatalogExercise {
  final String id;
  final String movementFamilyId;
  final List<String> primaryMuscleIds;
  final List<String> secondaryMuscleIds;
  final List<String> equipmentIds;
  final List<String> goalCodes;
  final CatalogTrackingProfile tracking;
  final String imageAssetPath;
  final List<String> aliases;

  const CatalogExercise({
    required this.id,
    required this.movementFamilyId,
    required this.primaryMuscleIds,
    required this.secondaryMuscleIds,
    required this.equipmentIds,
    required this.goalCodes,
    required this.tracking,
    required this.imageAssetPath,
    required this.aliases,
  });

  factory CatalogExercise.fromJson(Map<String, dynamic> json) =>
      CatalogExercise(
        id: json['id'] as String,
        movementFamilyId: json['movementFamilyId'] as String,
        primaryMuscleIds: List<String>.from(
          json['primaryMuscleIds'] ?? const [],
        ),
        secondaryMuscleIds: List<String>.from(
          json['secondaryMuscleIds'] ?? const [],
        ),
        equipmentIds: List<String>.from(json['equipmentIds'] ?? const []),
        goalCodes: List<String>.from(json['goalCodes'] ?? const []),
        tracking: CatalogTrackingProfile.fromJson(
          Map<String, dynamic>.from(json['tracking'] ?? const {}),
        ),
        imageAssetPath: json['imageAssetPath'] as String,
        aliases: List<String>.from(json['aliases'] ?? const []),
      );
}

class CatalogTrackingProfile {
  final bool sets;
  final bool reps;
  final bool weight;
  final bool duration;
  final bool distance;

  const CatalogTrackingProfile({
    required this.sets,
    required this.reps,
    required this.weight,
    required this.duration,
    required this.distance,
  });

  factory CatalogTrackingProfile.fromJson(Map<String, dynamic> json) =>
      CatalogTrackingProfile(
        sets: json['sets'] == true,
        reps: json['reps'] == true,
        weight: json['weight'] == true,
        duration: json['duration'] == true,
        distance: json['distance'] == true,
      );

  String toTrackedFieldsJson() => jsonEncode({
    'sets': sets,
    'reps': reps,
    'weight': weight,
    'duration': duration,
    'distance': distance,
  });
}

class CatalogLocalizedContent {
  final String name;
  final String description;
  final List<String> instructions;
  final List<String> searchTerms;
  final bool reviewed;

  const CatalogLocalizedContent({
    required this.name,
    required this.description,
    required this.instructions,
    required this.searchTerms,
    required this.reviewed,
  });

  factory CatalogLocalizedContent.fromJson(Map<String, dynamic> json) =>
      CatalogLocalizedContent(
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        instructions: List<String>.from(json['instructions'] ?? const []),
        searchTerms: List<String>.from(json['searchTerms'] ?? const []),
        reviewed: json['reviewed'] == true,
      );
}

class LocalizedCatalogExercise {
  final CatalogExercise definition;
  final CatalogLocalizedContent content;

  const LocalizedCatalogExercise({
    required this.definition,
    required this.content,
  });
}
