import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';
import '../models/exercise.dart';
import 'catalog_localization.dart';

/// Resolves only bundled catalog entries dynamically. All user-authored names
/// and renamed catalog entries are intentionally displayed verbatim.
String displayExerciseName(BuildContext context, Exercise exercise) {
  if (exercise.catalogId != null && !exercise.isNameCustom) {
    return catalogName(context, exercise.catalogId, fallback: exercise.name);
  }
  final key = exercise.standardKey;
  if (key != null && !exercise.isNameCustom) {
    return context.l10n.standardExerciseName(key);
  }
  return exercise.name;
}

String displayExerciseDescription(BuildContext context, Exercise exercise) {
  if (exercise.catalogId != null && !exercise.isNameCustom) {
    return catalogDescription(
      context,
      exercise.catalogId,
      fallback: exercise.description,
    );
  }
  return exercise.description;
}
