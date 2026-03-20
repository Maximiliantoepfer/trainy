import 'package:flutter/material.dart';

import '../models/exercise.dart';

/// Nutze konsistent das ColorScheme statt fixer Farben.
Color textOnSurface(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;

/// Gibt den ersten Merge-Alias zurück, der auf [query] passt, oder null.
/// Gibt null zurück wenn der Name selbst matcht (Alias-Hint nur bei Alias-Treffer).
String? matchingAlias(Exercise exercise, String query) {
  if (query.isEmpty || exercise.mergedAliases.isEmpty) return null;
  final q = query.toLowerCase();
  if (exercise.name.toLowerCase().contains(q)) return null;
  for (final alias in exercise.mergedAliases) {
    if (alias.toLowerCase().contains(q)) return alias;
  }
  return null;
}
