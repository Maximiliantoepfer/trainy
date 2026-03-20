import 'package:flutter/material.dart';

import '../utils/goal_utils.dart';

class ExerciseEditorForm extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final ValueNotifier<bool> trackSets;
  final ValueNotifier<bool> trackReps;
  final ValueNotifier<bool> trackWeight;
  final ValueNotifier<bool> trackDuration;
  final ValueNotifier<bool> trackDistance;
  final ValueNotifier<String?> goal;
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
    this.onChanged,
    this.autofocusName = false,
  });

  void _applyPreset(bool sets, bool reps, bool weight, bool dur, {bool dist = false}) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'z. B. Bankdrücken',
          ),
          autofocus: autofocusName,
          onChanged: (_) => onChanged?.call(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: descCtrl,
          decoration: const InputDecoration(
            labelText: 'Beschreibung (optional)',
          ),
          minLines: 1,
          maxLines: 3,
        ),

        // Trainingsziel
        const SizedBox(height: 20),
        Text(
          'Trainingsziel',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<String?>(
          valueListenable: goal,
          builder: (_, currentGoal, __) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in exerciseGoals)
                ChoiceChip(
                  label: Text(g),
                  selected: currentGoal == g,
                  avatar: currentGoal == g
                      ? null
                      : Icon(goalIcon(g), size: 16),
                  onSelected: (sel) {
                    goal.value = sel ? g : null;
                    onChanged?.call();
                  },
                ),
            ],
          ),
        ),

        // Tracking
        const SizedBox(height: 20),
        Text(
          'Tracking',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Standard'),
              selected: false,
              onSelected: (_) => _applyPreset(true, true, true, false),
            ),
            ChoiceChip(
              label: const Text('Körpergewicht'),
              selected: false,
              onSelected: (_) => _applyPreset(true, true, false, false),
            ),
            ChoiceChip(
              label: const Text('Sätze + Dauer'),
              selected: false,
              onSelected: (_) => _applyPreset(true, false, false, true),
            ),
            ChoiceChip(
              label: const Text('Cardio'),
              selected: false,
              onSelected: (_) => _applyPreset(false, false, false, true, dist: true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _toggleRow(context, 'Sätze', trackSets),
        _toggleRow(context, 'Wiederholungen', trackReps),
        _toggleRow(context, 'Gewicht', trackWeight),
        _toggleRow(context, 'Entfernung', trackDistance),
        _toggleRow(context, 'Dauer', trackDuration),
      ],
    );
  }

  Widget _toggleRow(BuildContext context, String label, ValueNotifier<bool> state) {
    return ValueListenableBuilder<bool>(
      valueListenable: state,
      builder: (_, v, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
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
