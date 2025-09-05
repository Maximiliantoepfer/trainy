import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/exercise_provider.dart';
import '../models/exercise.dart';

class ExerciseScreen extends StatelessWidget {
  const ExerciseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExerciseProvider>();
    final items = provider.exercises;

    return Scaffold(
      appBar: AppBar(title: const Text('Übungen')),
      body:
          provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final e = items[i];
                  final subtitle = <String>[];
                  if (e.trackSets) subtitle.add('Sätze');
                  if (e.trackReps) subtitle.add('Wdh.');
                  if (e.trackWeight) subtitle.add('Gewicht');
                  if (e.trackDuration) subtitle.add('Dauer');

                  return Card(
                    child: ListTile(
                      title: Text(
                        e.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle:
                          subtitle.isEmpty ? null : Text(subtitle.join(' · ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap:
                          () =>
                              _showAddOrEditExerciseSheet(context, initial: e),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditExerciseSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Übung'),
      ),
    );
  }

  Future<void> _showAddOrEditExerciseSheet(
    BuildContext context, {
    Exercise? initial,
  }) async {
    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    final descCtrl = TextEditingController(text: initial?.description ?? '');
    final trackSets = ValueNotifier<bool>(initial?.trackSets ?? true);
    final trackReps = ValueNotifier<bool>(initial?.trackReps ?? true);
    final trackWeight = ValueNotifier<bool>(initial?.trackWeight ?? true);
    final trackDuration = ValueNotifier<bool>(initial?.trackDuration ?? false);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final viewInsets = MediaQuery.of(ctx).viewInsets;
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  initial == null ? 'Übung hinzufügen' : 'Übung bearbeiten',
                  style: Theme.of(ctx).textTheme.headlineLarge,
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name der Übung *',
                    hintText: 'z. B. Bankdrücken',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Beschreibung (optional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Sätze + Wdh. + Gewicht (Standard)'),
                      selected: false,
                      onSelected: (_) {
                        trackSets.value = true;
                        trackReps.value = true;
                        trackWeight.value = true;
                        trackDuration.value = false;
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Sätze + Dauer'),
                      selected: false,
                      onSelected: (_) {
                        trackSets.value = true;
                        trackReps.value = false;
                        trackWeight.value = false;
                        trackDuration.value = true;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                _TrackChecklist(
                  trackSets: trackSets,
                  trackReps: trackReps,
                  trackWeight: trackWeight,
                  trackDuration: trackDuration,
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Bitte einen Namen eingeben'),
                              ),
                            );
                            return;
                          }
                          final provider = ctx.read<ExerciseProvider>();

                          if (initial == null) {
                            await provider.addExercise(
                              name: name,
                              description: descCtrl.text.trim(),
                              trackSets: trackSets.value,
                              trackReps: trackReps.value,
                              trackWeight: trackWeight.value,
                              trackDuration: trackDuration.value,
                            );
                          } else {
                            final tracked = <String>[
                              if (trackSets.value) 'sets',
                              if (trackReps.value) 'reps',
                              if (trackWeight.value) 'weight',
                              if (trackDuration.value) 'duration',
                            ];
                            await provider.addOrUpdateExercise(
                              initial.copyWith(
                                name: name,
                                description: descCtrl.text.trim(),
                                trackedFields: tracked,
                              ),
                            );
                          }

                          if (ctx.mounted)
                            Navigator.of(ctx).pop(); // <— schließt sicher
                        },
                        child: Text(
                          initial == null ? 'Hinzufügen' : 'Speichern',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TrackChecklist extends StatelessWidget {
  final ValueNotifier<bool> trackSets;
  final ValueNotifier<bool> trackReps;
  final ValueNotifier<bool> trackWeight;
  final ValueNotifier<bool> trackDuration;

  const _TrackChecklist({
    required this.trackSets,
    required this.trackReps,
    required this.trackWeight,
    required this.trackDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _check(context, 'Sätze', trackSets),
        _check(context, 'Wiederholungen', trackReps),
        _check(context, 'Gewicht', trackWeight),
        _check(
          context,
          'Dauer',
          trackDuration,
          subtitle: 'Alternative zu Wiederholungen',
        ),
      ],
    );
  }

  Widget _check(
    BuildContext ctx,
    String title,
    ValueNotifier<bool> state, {
    String? subtitle,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: state,
      builder:
          (_, value, __) => CheckboxListTile(
            value: value,
            onChanged: (v) => state.value = v ?? false,
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: subtitle == null ? null : Text(subtitle),
            controlAffinity: ListTileControlAffinity.leading,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
    );
  }
}
