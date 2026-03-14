import 'package:flutter/material.dart';

const List<String> exerciseGoals = ['Kraft', 'Ausdauer', 'Cardio', 'Mobilität'];

Color goalColor(String goal, ColorScheme scheme) {
  switch (goal) {
    case 'Kraft':
      return scheme.primary;
    case 'Ausdauer':
      return scheme.tertiary;
    case 'Cardio':
      return const Color(0xFFFF7043);
    case 'Mobilität':
      return const Color(0xFF7E57C2);
    default:
      return scheme.onSurfaceVariant;
  }
}

IconData goalIcon(String goal) {
  switch (goal) {
    case 'Kraft':
      return Icons.fitness_center_rounded;
    case 'Ausdauer':
      return Icons.directions_run_rounded;
    case 'Cardio':
      return Icons.favorite_rounded;
    case 'Mobilität':
      return Icons.self_improvement_rounded;
    default:
      return Icons.label_rounded;
  }
}

Widget goalBadge(String goal, ColorScheme scheme) {
  final color = goalColor(goal, scheme);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      goal,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}
