import 'dart:convert';

/// Immutable, bundled definition. Catalog records never contain user data.
class CatalogExercise {
  final String id;
  final String movementFamilyId;
  final String activityTypeCode;
  final List<String> primaryMuscleIds;
  final List<String> secondaryMuscleIds;
  final List<String> equipmentIds;
  final List<String> goalCodes;
  final CatalogTrackingProfile tracking;
  final String imageAssetPath;
  final String iconKey;
  final List<String> aliases;
  final int? essentialRank;
  final String? mediaId;

  const CatalogExercise({
    required this.id,
    required this.movementFamilyId,
    required this.activityTypeCode,
    required this.primaryMuscleIds,
    required this.secondaryMuscleIds,
    required this.equipmentIds,
    required this.goalCodes,
    required this.tracking,
    required this.imageAssetPath,
    required this.iconKey,
    required this.aliases,
    this.essentialRank,
    this.mediaId,
  });

  factory CatalogExercise.fromJson(Map<String, dynamic> json) =>
      CatalogExercise(
        id: json['id'] as String,
        movementFamilyId: json['movementFamilyId'] as String,
        activityTypeCode: json['activityTypeCode'] as String? ?? 'strength',
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
        iconKey: json['iconKey'] as String? ?? 'exercise',
        aliases: List<String>.from(json['aliases'] ?? const []),
        essentialRank: (json['essentialRank'] as num?)?.toInt(),
        mediaId: json['mediaId'] as String?,
      );
}

enum ExerciseSourceFilter { all, standard, custom }

/// Immutable query used by the unified standard/custom exercise library.
class CatalogQuery {
  const CatalogQuery({
    this.text = '',
    this.goalCode,
    this.profileId,
    this.availableEquipment,
    this.source = ExerciseSourceFilter.all,
  });

  final String text;
  final String? goalCode;
  final String? profileId;
  final Set<String>? availableEquipment;
  final ExerciseSourceFilter source;

  int get activeFilterCount =>
      (goalCode == null ? 0 : 1) +
      (profileId == null ? 0 : 1) +
      (source == ExerciseSourceFilter.all ? 0 : 1);

  CatalogQuery copyWith({
    String? text,
    String? goalCode,
    bool clearGoal = false,
    String? profileId,
    bool clearProfile = false,
    Set<String>? availableEquipment,
    bool clearEquipment = false,
    ExerciseSourceFilter? source,
  }) => CatalogQuery(
    text: text ?? this.text,
    goalCode: clearGoal ? null : (goalCode ?? this.goalCode),
    profileId: clearProfile ? null : (profileId ?? this.profileId),
    availableEquipment:
        clearEquipment ? null : (availableEquipment ?? this.availableEquipment),
    source: source ?? this.source,
  );
}

enum CatalogMediaLicense { owned, cc0, ccBy }

class CatalogMedia {
  const CatalogMedia({
    required this.id,
    required this.assetPath,
    required this.sha256,
    required this.license,
    this.author,
    this.sourceUrl,
  });

  final String id;
  final String assetPath;
  final String sha256;
  final CatalogMediaLicense license;
  final String? author;
  final String? sourceUrl;

  factory CatalogMedia.fromJson(Map<String, dynamic> json) => CatalogMedia(
    id: json['mediaId'] as String,
    assetPath: json['assetPath'] as String,
    sha256: json['sha256'] as String,
    license: switch (json['license']) {
      'owned' => CatalogMediaLicense.owned,
      'CC0' => CatalogMediaLicense.cc0,
      'CC-BY' => CatalogMediaLicense.ccBy,
      _ => throw FormatException('Unsupported catalog media license.'),
    },
    author: json['author'] as String?,
    sourceUrl: json['sourceUrl'] as String?,
  );
}

class CatalogTranslationMetadata {
  const CatalogTranslationMetadata({
    required this.method,
    required this.sourceHash,
  });

  final String method;
  final String sourceHash;

  factory CatalogTranslationMetadata.fromJson(Map<String, dynamic> json) =>
      CatalogTranslationMetadata(
        method: json['translationMethod'] as String? ?? 'manual',
        sourceHash: json['sourceHash'] as String? ?? '',
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
  final String? fallbackLocale;
  final CatalogTranslationMetadata? translation;

  const CatalogLocalizedContent({
    required this.name,
    required this.description,
    required this.instructions,
    required this.searchTerms,
    required this.reviewed,
    this.fallbackLocale,
    this.translation,
  });

  factory CatalogLocalizedContent.fromJson(Map<String, dynamic> json) =>
      CatalogLocalizedContent(
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        instructions: List<String>.from(json['instructions'] ?? const []),
        searchTerms: List<String>.from(json['searchTerms'] ?? const []),
        reviewed: json['reviewed'] == true,
        fallbackLocale: json['fallbackLocale'] as String?,
        translation:
            json['translationMethod'] == null
                ? null
                : CatalogTranslationMetadata.fromJson(json),
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
