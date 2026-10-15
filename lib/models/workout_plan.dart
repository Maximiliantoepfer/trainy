class TrainingProfile {
  const TrainingProfile({
    required this.id,
    required this.name,
    this.equipmentCodes = const [],
    this.isArchived = false,
    this.sort = 0,
  });

  final int id;
  final String name;
  final List<String> equipmentCodes;
  final bool isArchived;
  final int sort;
}

class WorkoutVariant {
  const WorkoutVariant({
    required this.id,
    required this.workoutId,
    required this.name,
    this.profileId,
    this.sort = 0,
    this.isDefault = false,
  });

  final int id;
  final int workoutId;
  final String name;
  final int? profileId;
  final int sort;
  final bool isDefault;
}

class WorkoutGroup {
  const WorkoutGroup({
    required this.id,
    required this.workoutId,
    required this.name,
    this.muscleGroupCode,
    this.sort = 0,
  });

  final int id;
  final int workoutId;
  final String name;
  final String? muscleGroupCode;
  final int sort;
}

class WorkoutGroupVariant {
  const WorkoutGroupVariant({
    required this.id,
    required this.workoutGroupId,
    required this.name,
    this.profileId,
    this.sort = 0,
  });

  final int id;
  final int workoutGroupId;
  final String name;
  final int? profileId;
  final int sort;
}

class WorkoutSlot {
  const WorkoutSlot({
    required this.id,
    required this.groupVariantId,
    required this.exerciseId,
    this.movementFamilyId,
    this.isOptional = false,
    this.sort = 0,
  });

  final int id;
  final int groupVariantId;
  final int exerciseId;
  final String? movementFamilyId;
  final bool isOptional;
  final int sort;
}

class WorkoutSlotAlternative {
  const WorkoutSlotAlternative({
    required this.id,
    required this.workoutSlotId,
    required this.exerciseId,
    this.profileId,
    this.sort = 0,
  });

  final int id;
  final int workoutSlotId;
  final int exerciseId;
  final int? profileId;
  final int sort;
}

class WorkoutSessionSnapshot {
  const WorkoutSessionSnapshot({
    required this.id,
    required this.workoutId,
    required this.startedAt,
    required this.snapshotJson,
    this.workoutVariantId,
    this.profileId,
    this.completedAt,
  });

  final int id;
  final int workoutId;
  final int? workoutVariantId;
  final int? profileId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String snapshotJson;
}

/// Immutable plan data passed into a running workout. It contains only local
/// IDs and user-entered group names; exercises are resolved from the local
/// database before the session starts.
class WorkoutSessionPlanGroup {
  const WorkoutSessionPlanGroup({
    required this.workoutGroupId,
    required this.name,
    required this.selectedGroupVariantId,
    required this.variants,
  });

  final int workoutGroupId;
  final String name;
  final int selectedGroupVariantId;
  final List<WorkoutSessionPlanGroupVariant> variants;
}

class WorkoutSessionPlanGroupVariant {
  const WorkoutSessionPlanGroupVariant({
    required this.id,
    required this.name,
    required this.slots,
  });

  final int id;
  final String name;
  final List<WorkoutSessionPlanSlot> slots;
}

class WorkoutSessionPlanSlot {
  const WorkoutSessionPlanSlot({
    required this.id,
    required this.exerciseId,
    required this.isOptional,
    this.alternativeExerciseIds = const [],
  });

  final int id;
  final int exerciseId;
  final bool isOptional;
  final List<int> alternativeExerciseIds;
}
