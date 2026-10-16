import 'package:flutter/widgets.dart';
import '../l10n/l10n.dart';
import '../models/workout_planning.dart';

String workoutGroupLabel(
  BuildContext context,
  WorkoutGroupKind kind,
  String name,
) => switch (kind) {
  WorkoutGroupKind.warmup => context.l10n.warmupGroup,
  WorkoutGroupKind.core => context.l10n.coreExercisesGroup,
  WorkoutGroupKind.cooldown => context.l10n.cooldownGroup,
  WorkoutGroupKind.custom => name,
};
