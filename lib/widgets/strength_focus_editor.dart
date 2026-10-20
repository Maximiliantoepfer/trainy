import 'package:flutter/material.dart';
import '../l10n/strength_l10n.dart';
import '../models/training_program.dart';
import '../services/strength_planning.dart';

Future<ProgramSlot?> editStrengthFocus(
  BuildContext context,
  ProgramSlot slot,
) async {
  final name = TextEditingController(
    text: slot.label == 'custom' ? '' : context.strength(slot.label),
  );
  final form = GlobalKey<FormState>();
  var focus = StrengthPlanning.expand(slot.effectiveFocus);
  final result = await showModalBottomSheet<ProgramSlot>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (c) => StatefulBuilder(
          builder:
              (c, set) => SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      20 + MediaQuery.viewInsetsOf(c).bottom,
                    ),
                    child: Form(
                      key: form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            c.strength('focusQuestion'),
                            style: Theme.of(c).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: name,
                            decoration: InputDecoration(
                              labelText: c.strength('workoutName'),
                            ),
                            validator:
                                (v) =>
                                    v == null || v.trim().isEmpty
                                        ? c.strength('nameRequired')
                                        : null,
                          ),
                          const SizedBox(height: 16),
                          for (final group in [
                            'push',
                            'pull',
                            'legs',
                            'core',
                          ]) ...[
                            FilterChip(
                              label: Text(c.strength(group)),
                              selected: focus.containsAll(
                                StrengthPlanning.expand([group]),
                              ),
                              onSelected:
                                  (v) => set(() {
                                    final muscles = StrengthPlanning.expand([
                                      group,
                                    ]);
                                    v
                                        ? focus.addAll(muscles)
                                        : focus.removeAll(muscles);
                                  }),
                            ),
                            Text(
                              StrengthPlanning.expand([
                                group,
                              ]).map(c.strength).join(' · '),
                              style: Theme.of(c).textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final m in StrengthPlanning.muscles)
                                FilterChip(
                                  label: Text(c.strength(m)),
                                  selected: focus.contains(m),
                                  onSelected:
                                      (v) => set(() {
                                        v ? focus.add(m) : focus.remove(m);
                                      }),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed:
                                focus.isEmpty
                                    ? null
                                    : () {
                                      if (form.currentState!.validate()) {
                                        Navigator.pop(
                                          c,
                                          slot.copyWith(
                                            label: name.text.trim(),
                                            focus: focus.toList(),
                                            clearWorkout: true,
                                          ),
                                        );
                                      }
                                    },
                            child: Text(c.strength('save')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ),
  );
  // Keep the controller alive through the bottom sheet's reverse transition.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  name.dispose();
  return result;
}
