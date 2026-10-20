import 'package:flutter/foundation.dart';

import 'training_profile.dart';

enum WorkoutPrimaryGoal {
  strength('strength'),
  endurance('endurance'),
  cardio('cardio'),
  mobility('mobility');

  const WorkoutPrimaryGoal(this.code);

  final String code;

  static WorkoutPrimaryGoal fromCode(String? value) => values.firstWhere(
    (goal) => goal.code == value,
    orElse: () => WorkoutPrimaryGoal.strength,
  );

  /// Statistics still treat endurance as cardio with an endurance focus.
  List<String> get statisticTags => switch (this) {
    WorkoutPrimaryGoal.endurance => const ['cardio', 'endurance'],
    _ => [code],
  };
}

/// Stable, localized-in-the-view group semantics.  The database stores the
/// code rather than a translated label so a workout looks correct after a
/// language change as well.
enum WorkoutGroupKind {
  warmup('warmup'),
  core('core'),
  cooldown('cooldown'),
  custom('custom');

  const WorkoutGroupKind(this.code);

  final String code;

  static WorkoutGroupKind fromCode(String? value) => values.firstWhere(
    (kind) => kind.code == value,
    orElse: () => WorkoutGroupKind.custom,
  );
}

@immutable
class WorkoutSetupSlot {
  const WorkoutSetupSlot({
    required this.id,
    required this.exerciseId,
    required this.localExerciseId,
    required this.isOptional,
    required this.sortOrder,
    this.movementFamilyId,
    this.alternativeLocalExerciseIds = const [],
    this.prescription,
  });

  final String id;
  final String exerciseId;
  final int localExerciseId;
  final bool isOptional;
  final int sortOrder;
  final String? movementFamilyId;
  final List<int> alternativeLocalExerciseIds;
  final StrengthPrescription? prescription;
}

@immutable
class StrengthPrescription {
  const StrengthPrescription({
    required this.sets,
    this.minReps = 8,
    this.maxReps = 12,
    this.restSeconds = 90,
    this.source = 'manual',
  });
  final int sets, minReps, maxReps;
  final int restSeconds;
  final String source;
  Map<String, dynamic> toJson() => {
    'sets': sets,
    'minReps': minReps,
    'maxReps': maxReps,
    'restSeconds': restSeconds,
    'source': source,
  };
  factory StrengthPrescription.fromJson(Map<String, dynamic> j) =>
      StrengthPrescription(
        sets: j['sets'] as int,
        minReps: j['minReps'] as int,
        maxReps: j['maxReps'] as int,
        restSeconds: j['restSeconds'] as int? ?? 90,
        source: j['source'] as String? ?? 'manual',
      );
  String get label => '$sets × $minReps–$maxReps';
  Map<String, String> get prefill => {'sets': '$sets', 'reps': '$minReps'};
  void validate() {
    if (sets < 1 ||
        sets > 50 ||
        minReps < 1 ||
        maxReps < minReps ||
        maxReps > 200 ||
        restSeconds < 0 ||
        restSeconds > 600) {
      throw const FormatException('Invalid prescription');
    }
  }
}

@immutable
class WorkoutSetupGroupVariant {
  const WorkoutSetupGroupVariant({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.slots,
    this.profileId,
  });

  final String id;
  final String name;
  final String? profileId;
  final int sortOrder;
  final List<WorkoutSetupSlot> slots;
}

@immutable
class WorkoutSetupGroup {
  const WorkoutSetupGroup({
    required this.id,
    required this.name,
    required this.kind,
    required this.sortOrder,
    required this.selectedVariantId,
    required this.variants,
    this.muscleGroupCode,
  });

  final String id;
  final String name;
  final WorkoutGroupKind kind;
  final String? muscleGroupCode;
  final int sortOrder;
  final String selectedVariantId;
  final List<WorkoutSetupGroupVariant> variants;

  WorkoutSetupGroupVariant get selectedVariant => variants.firstWhere(
    (variant) => variant.id == selectedVariantId,
    orElse: () => variants.first,
  );
}

@immutable
class WorkoutSetup {
  const WorkoutSetup({
    required this.id,
    required this.workoutId,
    required this.name,
    required this.sortOrder,
    required this.isDefault,
    required this.groups,
    this.profile,
  });

  final String id;
  final String workoutId;
  final String name;
  final TrainingProfileRecord? profile;
  final int sortOrder;
  final bool isDefault;
  final List<WorkoutSetupGroup> groups;

  int get exerciseCount => groups.fold(
    0,
    (total, group) => total + group.selectedVariant.slots.length,
  );
}

@immutable
class WeeklyWorkoutPlacement {
  const WeeklyWorkoutPlacement({
    required this.id,
    required this.workoutId,
    required this.weekday,
    required this.sortOrder,
  });

  final String id;
  final String workoutId;
  final int weekday;
  final int sortOrder;
}

@immutable
class WorkoutEditorDraft {
  const WorkoutEditorDraft({
    required this.name,
    required this.primaryGoal,
    required this.setupName,
    this.description = '',
    this.profileId,
    this.exerciseIds = const [],
    this.creationId,
    this.prescriptions = const {},
    this.optionalExerciseIds = const {},
  });

  final String name;
  final String description;
  final WorkoutPrimaryGoal primaryGoal;
  final String setupName;
  final String? profileId;
  final List<int> exerciseIds;
  final String? creationId;
  final Map<int, StrengthPrescription> prescriptions;
  final Set<int> optionalExerciseIds;
}

enum SetupContents { copy, empty }

@immutable
class WorkoutLaunchPlan {
  const WorkoutLaunchPlan({
    required this.setup,
    required this.exerciseIds,
    required this.optionalSlotIds,
  });

  final WorkoutSetup setup;
  final List<int> exerciseIds;
  final Set<String> optionalSlotIds;
}

@immutable
class CalendarDaySummary {
  const CalendarDaySummary({
    required this.date,
    required this.plannedWorkoutIds,
    required this.primaryGoal,
    required this.completedCount,
  });

  final DateTime date;
  final List<String> plannedWorkoutIds;
  final WorkoutPrimaryGoal? primaryGoal;
  final int completedCount;

  int get additionalWorkoutCount =>
      plannedWorkoutIds.length > 1 ? plannedWorkoutIds.length - 1 : 0;
}
