import 'package:flutter/material.dart';

import '../utils/goal_utils.dart';
import '../l10n/l10n.dart';

class ExerciseEditorForm extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final ValueNotifier<bool> trackSets;
  final ValueNotifier<bool> trackReps;
  final ValueNotifier<bool> trackWeight;
  final ValueNotifier<bool> trackDuration;
  final ValueNotifier<bool> trackDistance;
  final ValueNotifier<String?> goal;
  final ValueNotifier<List<String>>? goalCodes;
  final VoidCallback? onChanged;
  final bool autofocusName;

  const ExerciseEditorForm({
    super.key,
    required this.nameCtrl,
    required this.descCtrl,
    required this.trackSets,
    required this.trackReps,
    required this.trackWeight,
    required this.trackDuration,
    required this.trackDistance,
    required this.goal,
    this.goalCodes,
    this.onChanged,
    this.autofocusName = false,
  });

  void _applyPreset(
    bool sets,
    bool reps,
    bool weight,
    bool dur, {
    bool dist = false,
  }) {
    trackSets.value = sets;
    trackReps.value = reps;
    trackWeight.value = weight;
    trackDuration.value = dur;
    trackDistance.value = dist;
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            labelText: l10n.exerciseName,
            hintText: l10n.standardExerciseName('kraft_bankdruecken'),
          ),
          autofocus: autofocusName,
          onChanged: (_) => onChanged?.call(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: descCtrl,
          decoration: InputDecoration(
            labelText: '${l10n.description} (${l10n.optional})',
          ),
          minLines: 1,
          maxLines: 3,
        ),

        // Trainingsziel
        const SizedBox(height: 20),
        Text(
          l10n.exerciseGoal,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        goalCodes == null
            ? ValueListenableBuilder<String?>(
              valueListenable: goal,
              builder:
                  (_, currentGoal, __) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final g in exerciseGoals)
                        ChoiceChip(
                          label: Text(goalLabel(context, g)),
                          selected: currentGoal == g,
                          avatar:
                              currentGoal == g ? null : GoalIcon(g, size: 16),
                          onSelected: (sel) {
                            goal.value = sel ? g : null;
                            onChanged?.call();
                          },
                        ),
                    ],
                  ),
            )
            : ValueListenableBuilder<List<String>>(
              valueListenable: goalCodes!,
              builder:
                  (_, currentGoals, __) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final g in exerciseGoals)
                        ChoiceChip(
                          label: Text(goalLabel(context, g)),
                          selected: currentGoals.contains(g),
                          avatar:
                              currentGoals.contains(g)
                                  ? null
                                  : GoalIcon(g, size: 16),
                          onSelected: (sel) {
                            final next = List<String>.from(currentGoals);
                            if (sel && next.length < 2) next.add(g);
                            if (!sel) next.remove(g);
                            goalCodes!.value = next;
                            goal.value = next.isEmpty ? null : next.first;
                            onChanged?.call();
                          },
                        ),
                    ],
                  ),
            ),

        // Tracking
        const SizedBox(height: 20),
        Text(
          l10n.tracking,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(l10n.standard),
              selected: false,
              onSelected: (_) => _applyPreset(true, true, true, false),
            ),
            ChoiceChip(
              label: Text(l10n.bodyweight),
              selected: false,
              onSelected: (_) => _applyPreset(true, true, false, false),
            ),
            ChoiceChip(
              label: Text(l10n.setsAndDuration),
              selected: false,
              onSelected: (_) => _applyPreset(true, false, false, true),
            ),
            ChoiceChip(
              label: Text(l10n.goalLabel('cardio')),
              selected: false,
              onSelected:
                  (_) => _applyPreset(false, false, false, true, dist: true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _toggleRow(context, l10n.sets, trackSets),
        _toggleRow(context, l10n.repetitions, trackReps),
        _toggleRow(context, l10n.weight, trackWeight),
        _toggleRow(context, l10n.distance, trackDistance),
        _toggleRow(context, l10n.duration, trackDuration),
      ],
    );
  }

  Widget _toggleRow(
    BuildContext context,
    String label,
    ValueNotifier<bool> state,
  ) {
    return ValueListenableBuilder<bool>(
      valueListenable: state,
      builder:
          (_, v, __) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Switch(
                  value: v,
                  onChanged: (val) {
                    state.value = val;
                    onChanged?.call();
                  },
                ),
              ],
            ),
          ),
    );
  }
}
