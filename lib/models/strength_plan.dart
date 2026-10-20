import 'workout_planning.dart';

class StrengthExerciseDraft {
  const StrengthExerciseDraft({
    required this.catalogId,
    required this.prescription,
    this.unilateral = false,
    this.optional = false,
  });
  final String catalogId;
  final StrengthPrescription prescription;
  final bool unilateral, optional;
  int get estimatedSeconds =>
      45 +
      prescription.sets *
          (((prescription.minReps + prescription.maxReps) / 2 * 3).ceil() *
              (unilateral ? 2 : 1)) +
      (prescription.sets - 1) * prescription.restSeconds;
  Map<String, dynamic> toJson() => {
    'catalogId': catalogId,
    'prescription': prescription.toJson(),
    'unilateral': unilateral,
    'optional': optional,
  };
  factory StrengthExerciseDraft.fromJson(Map<String, dynamic> j) =>
      StrengthExerciseDraft(
        catalogId: j['catalogId'] as String,
        prescription: StrengthPrescription.fromJson(
          Map<String, dynamic>.from(j['prescription']),
        ),
        unilateral: j['unilateral'] == true,
        optional: j['optional'] == true,
      );
}

class StrengthVariantDraft {
  const StrengthVariantDraft({
    required this.profileId,
    required this.name,
    required this.exercises,
    this.missing = const [],
    this.warmupSeconds = 300,
    this.acceptedReduced = false,
  });
  final String profileId, name;
  final List<StrengthExerciseDraft> exercises;
  final List<String> missing;
  final int warmupSeconds;
  final bool acceptedReduced;
  int get estimatedSeconds =>
      warmupSeconds + exercises.fold(0, (s, e) => s + e.estimatedSeconds);
  bool get ready =>
      exercises.isNotEmpty && (missing.isEmpty || acceptedReduced);
  StrengthVariantDraft copyWith({
    List<StrengthExerciseDraft>? exercises,
    bool? acceptedReduced,
  }) => StrengthVariantDraft(
    profileId: profileId,
    name: name,
    exercises: exercises ?? this.exercises,
    missing: missing,
    warmupSeconds: warmupSeconds,
    acceptedReduced: acceptedReduced ?? this.acceptedReduced,
  );
  Map<String, dynamic> toJson() => {
    'profileId': profileId,
    'name': name,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'missing': missing,
    'warmupSeconds': warmupSeconds,
    'acceptedReduced': acceptedReduced,
  };
  factory StrengthVariantDraft.fromJson(Map<String, dynamic> j) =>
      StrengthVariantDraft(
        profileId: j['profileId'] as String,
        name: j['name'] as String,
        exercises: [
          for (final e in j['exercises'] as List)
            StrengthExerciseDraft.fromJson(Map<String, dynamic>.from(e)),
        ],
        missing: List<String>.from(j['missing'] ?? const []),
        warmupSeconds: j['warmupSeconds'] as int? ?? 300,
        acceptedReduced: j['acceptedReduced'] == true,
      );
}

class StrengthWorkoutDraft {
  const StrengthWorkoutDraft({
    required this.id,
    required this.slotId,
    required this.name,
    required this.variants,
  });
  final String id, slotId, name;
  final List<StrengthVariantDraft> variants;
  bool get ready => variants.isNotEmpty && variants.every((v) => v.ready);
  StrengthWorkoutDraft copyWith({
    String? name,
    List<StrengthVariantDraft>? variants,
  }) => StrengthWorkoutDraft(
    id: id,
    slotId: slotId,
    name: name ?? this.name,
    variants: variants ?? this.variants,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'slotId': slotId,
    'name': name,
    'variants': variants.map((v) => v.toJson()).toList(),
  };
  factory StrengthWorkoutDraft.fromJson(Map<String, dynamic> j) =>
      StrengthWorkoutDraft(
        id: j['id'] as String,
        slotId: j['slotId'] as String,
        name: j['name'] as String,
        variants: [
          for (final v in j['variants'] as List)
            StrengthVariantDraft.fromJson(Map<String, dynamic>.from(v)),
        ],
      );
}

class StrengthPlanProposal {
  const StrengthPlanProposal({required this.workouts, this.version = 1});
  final List<StrengthWorkoutDraft> workouts;
  final int version;
  bool get ready => workouts.every((w) => w.ready);
  Map<String, dynamic> toJson() => {
    'version': version,
    'workouts': workouts.map((w) => w.toJson()).toList(),
  };
  factory StrengthPlanProposal.fromJson(Map<String, dynamic> j) =>
      StrengthPlanProposal(
        version: j['version'] as int? ?? 1,
        workouts: [
          for (final w in j['workouts'] as List)
            StrengthWorkoutDraft.fromJson(Map<String, dynamic>.from(w)),
        ],
      );
}
