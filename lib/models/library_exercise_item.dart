import 'catalog_exercise.dart';
import 'exercise.dart';

/// One row in the unified exercise library.
///
/// A materialized catalog item contains both references and is still rendered
/// exactly once. A custom item contains only [exercise].
class LibraryExerciseItem {
  const LibraryExerciseItem.custom(this.exercise) : catalog = null;

  const LibraryExerciseItem.catalog(this.catalog, {this.exercise});

  final Exercise? exercise;
  final LocalizedCatalogExercise? catalog;

  bool get isStandard => catalog != null || exercise?.catalogId != null;
  List<String> get goalCodes =>
      catalog?.definition.goalCodes ?? exercise?.goalCodes ?? const [];
}
