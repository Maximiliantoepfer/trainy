import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

const List<String> exerciseGoals = [
  'strength',
  'endurance',
  'cardio',
  'mobility',
];
const List<String> goalPriority = [
  'strength',
  'cardio',
  'endurance',
  'mobility',
];

String? prioritizedGoal(Iterable<String> values) {
  final normalized = values.map(normalizeGoal).toSet();
  for (final code in goalPriority) {
    if (normalized.contains(code)) return code;
  }
  return null;
}

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

/// A semantic icon for a training goal.
///
/// Strength deliberately uses the app's established muscle-arm asset. A
/// dumbbell is kept for neutral exercise and equipment navigation elsewhere
/// in the UI, so the two concepts stay visually distinct.
class GoalIcon extends StatelessWidget {
  const GoalIcon(this.goal, {super.key, this.size = 24, this.color});

  final String goal;
  final double? size;
  final Color? color;

  static const AssetImage _strengthAsset = AssetImage(
    'assets/icons/muskel.png',
  );

  @override
  Widget build(BuildContext context) {
    if (normalizeGoal(goal) == 'strength') {
      return ImageIcon(_strengthAsset, size: size, color: color);
    }
    return Icon(_materialGoalIcon(goal), size: size, color: color);
  }
}

IconData _materialGoalIcon(String goal) {
  switch (normalizeGoal(goal)) {
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
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GoalIcon(goal, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          goalLabel(context, goal),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}
