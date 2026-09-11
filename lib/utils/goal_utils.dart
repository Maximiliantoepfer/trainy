import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

const List<String> exerciseGoals = ['strength', 'endurance', 'cardio', 'mobility'];

String normalizeGoal(String? goal) => switch (goal) {
      'Kraft' => 'strength',
      'Ausdauer' => 'endurance',
      'Mobilität' => 'mobility',
      'Cardio' => 'cardio',
      'strength' || 'endurance' || 'cardio' || 'mobility' => goal!,
      _ => 'other',
    };

String goalLabel(BuildContext context, String goal) =>
    context.l10n.goalLabel(normalizeGoal(goal));

Color goalColor(String goal, ColorScheme scheme) {
  switch (normalizeGoal(goal)) {
    case 'strength':
      return scheme.primary;
    case 'endurance':
      return scheme.tertiary;
    case 'cardio':
      return const Color(0xFFFF7043);
    case 'mobility':
      return const Color(0xFF7E57C2);
    default:
      return scheme.onSurfaceVariant;
  }
}

IconData goalIcon(String goal) {
  switch (normalizeGoal(goal)) {
    case 'strength':
      return Icons.fitness_center_rounded;
    case 'endurance':
      return Icons.directions_run_rounded;
    case 'cardio':
      return Icons.favorite_rounded;
    case 'mobility':
      return Icons.self_improvement_rounded;
    default:
      return Icons.label_rounded;
  }
}

Widget goalBadge(BuildContext context, String goal, ColorScheme scheme) {
  final color = goalColor(goal, scheme);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      goalLabel(context, goal),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}
