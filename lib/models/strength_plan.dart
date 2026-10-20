import 'workout_planning.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

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
          (prescription.durationSeconds ??
              (((prescription.minReps + prescription.maxReps) / 2 * 3).ceil() *
                  (unilateral ? 2 : 1))) +
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
    this.warmup = const [],
    this.cooldown = const [],
    this.budgetSeconds,
    this.acceptedExtraTime = false,
  });
  final String profileId, name;
  final List<StrengthExerciseDraft> exercises;
  final List<StrengthExerciseDraft> warmup, cooldown;
  final int? budgetSeconds;
  final bool acceptedExtraTime;
  final List<String> missing;
  final int warmupSeconds;
  final bool acceptedReduced;
  int get estimatedSeconds =>
      warmupSeconds +
      exercises.fold<int>(0, (s, e) => s + e.estimatedSeconds) +
      [...warmup, ...cooldown].fold<int>(
        0,
        (s, e) =>
            s +
            (e.prescription.durationSeconds == null
                ? e.estimatedSeconds
                : e.prescription.sets * e.prescription.durationSeconds! +
                    (e.prescription.sets - 1) * e.prescription.restSeconds),
      );
  bool get ready =>
      exercises.isNotEmpty &&
      (missing.isEmpty || acceptedReduced) &&
      (!overBudget || acceptedExtraTime);
  bool get overBudget =>
      budgetSeconds != null && estimatedSeconds > budgetSeconds!;
  StrengthVariantDraft copyWith({
    List<StrengthExerciseDraft>? exercises,
    List<StrengthExerciseDraft>? warmup,
    List<StrengthExerciseDraft>? cooldown,
    bool? acceptedReduced,
    bool? acceptedExtraTime,
  }) => StrengthVariantDraft(
    profileId: profileId,
    name: name,
    exercises: exercises ?? this.exercises,
    missing: missing,
    warmupSeconds: warmupSeconds,
    acceptedReduced: acceptedReduced ?? this.acceptedReduced,
    warmup: warmup ?? this.warmup,
    cooldown: cooldown ?? this.cooldown,
    budgetSeconds: budgetSeconds,
    acceptedExtraTime: acceptedExtraTime ?? this.acceptedExtraTime,
  );
  Map<String, dynamic> toJson() => {
    'profileId': profileId,
    'name': name,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'missing': missing,
    'warmupSeconds': warmupSeconds,
    'acceptedReduced': acceptedReduced,
    'warmup': warmup.map((e) => e.toJson()).toList(),
    'cooldown': cooldown.map((e) => e.toJson()).toList(),
    'budgetSeconds': budgetSeconds,
    'acceptedExtraTime': acceptedExtraTime,
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
        warmup: [
          for (final e in j['warmup'] ?? [])
            StrengthExerciseDraft.fromJson(Map<String, dynamic>.from(e)),
        ],
        cooldown: [
          for (final e in j['cooldown'] ?? [])
            StrengthExerciseDraft.fromJson(Map<String, dynamic>.from(e)),
        ],
        budgetSeconds: j['budgetSeconds'] as int?,
        acceptedExtraTime: j['acceptedExtraTime'] == true,
      );
}

class StrengthWorkoutDraft {
  const StrengthWorkoutDraft({
    required this.id,
    required this.slotId,
    required this.name,
    required this.variants,
    this.reviewedFingerprint,
  });
  final String id, slotId, name;
  final List<StrengthVariantDraft> variants;
  final String? reviewedFingerprint;
  String get fingerprint =>
      sha256
          .convert(
            utf8.encode(
              jsonEncode({
                'name': name,
                'variants': variants.map((v) => v.toJson()).toList(),
              }),
            ),
          )
          .toString();
  bool get reviewed => reviewedFingerprint == fingerprint;
  StrengthWorkoutDraft confirmReview() => StrengthWorkoutDraft(
    id: id,
    slotId: slotId,
    name: name,
    variants: variants,
    reviewedFingerprint: fingerprint,
  );
  bool get ready => variants.isNotEmpty && variants.every((v) => v.ready);
  StrengthWorkoutDraft copyWith({
    String? name,
    List<StrengthVariantDraft>? variants,
  }) => StrengthWorkoutDraft(
    id: id,
    slotId: slotId,
    name: name ?? this.name,
    variants: variants ?? this.variants,
    reviewedFingerprint: reviewedFingerprint,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'slotId': slotId,
    'name': name,
    'variants': variants.map((v) => v.toJson()).toList(),
    'reviewedFingerprint': reviewedFingerprint,
  };
  factory StrengthWorkoutDraft.fromJson(Map<String, dynamic> j) =>
      StrengthWorkoutDraft(
        id: j['id'] as String,
        slotId: j['slotId'] as String,
        name: j['name'] as String,
        reviewedFingerprint: j['reviewedFingerprint'] as String?,
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
  bool get reviewed => workouts.every(
    (w) =>
        w.reviewed ||
        workouts.any(
          (other) => other.reviewed && other.fingerprint == w.fingerprint,
        ),
  );
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
