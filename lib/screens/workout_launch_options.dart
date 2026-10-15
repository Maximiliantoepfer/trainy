class WorkoutLaunchOptions {
  const WorkoutLaunchOptions({
    this.profileId,
    this.variantId,
    this.includedOptionalSlotIds = const {},
  });

  final int? profileId;
  final int? variantId;
  final Set<int> includedOptionalSlotIds;
}
