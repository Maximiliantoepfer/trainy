import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';
import '../providers/exercise_provider.dart';

class WorkoutScreen extends StatefulWidget {
  final Workout workout;
  const WorkoutScreen({super.key, required this.workout});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late List<int> _exerciseIds;

  @override
  void initState() {
    super.initState();
    _exerciseIds = List<int>.from(widget.workout.exerciseIds);
  }

  Future<void> _persistOrder(BuildContext context) async {
    await context.read<WorkoutProvider>().setWorkoutExercises(
      widget.workout.id,
      _exerciseIds,
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final id = _exerciseIds.removeAt(oldIndex);
      _exerciseIds.insert(newIndex, id);
    });
    _persistOrder(context);
  }

  Future<void> _addExercisesBottomSheet() async {
    final exercises = context.read<ExerciseProvider>().exercises;
    final selected = Set<int>.from(_exerciseIds);

    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final trackSets = ValueNotifier<bool>(true);
    final trackReps = ValueNotifier<bool>(true);
    final trackWeight = ValueNotifier<bool>(true);
    final trackDuration = ValueNotifier<bool>(false);

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
          child: DefaultTabController(
            length: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'Übungen hinzufügen',
                        style: Theme.of(ctx).textTheme.headlineLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const TabBar(
                  tabs: [Tab(text: 'Vorhandene'), Tab(text: 'Neu erstellen')],
                ),
                SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.65,
                  child: TabBarView(
                    children: [
                      // Tab 1: vorhandene Exercises wählen
                      ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                        itemCount: exercises.length,
                        itemBuilder: (_, i) {
                          final e = exercises[i];
                          final subtitle = <String>[];
                          if (e.trackSets) subtitle.add('Sätze');
                          if (e.trackReps) subtitle.add('Wdh.');
                          if (e.trackWeight) subtitle.add('Gewicht');
                          if (e.trackDuration) subtitle.add('Dauer');
                          final isSelected = selected.contains(e.id);
                          return Card(
                            child: CheckboxListTile(
                              value: isSelected,
                              onChanged: (v) {
                                setState(() {
                                  if (v ?? false) {
                                    selected.add(e.id);
                                  } else {
                                    selected.remove(e.id);
                                  }
                                });
                              },
                              title: Text(
                                e.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle:
                                  subtitle.isEmpty
                                      ? null
                                      : Text(subtitle.join(' · ')),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          );
                        },
                      ),

                      // Tab 2: neue Exercise sofort erstellen
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Name *',
                                hintText: 'z. B. Plank',
                              ),
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
                                  label: const Text('Standard'),
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
                            FilledButton.icon(
                              onPressed: () async {
                                final name = nameCtrl.text.trim();
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Bitte einen Namen eingeben',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final id = await ctx
                                    .read<ExerciseProvider>()
                                    .addExercise(
                                      name: name,
                                      description: descCtrl.text.trim(),
                                      trackSets: trackSets.value,
                                      trackReps: trackReps.value,
                                      trackWeight: trackWeight.value,
                                      trackDuration: trackDuration.value,
                                    );
                                setState(() => selected.add(id));
                                if (mounted) {
                                  DefaultTabController.of(ctx).animateTo(0);
                                }
                              },
                              icon: const Icon(Icons.add),
                              label: const Text(
                                'Exercise erstellen & auswählen',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Abbrechen'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              // Merge: bestehende Reihenfolge + neu ausgewählte hinten anhängen,
                              // Duplikate entfernen, Reihenfolge bewahren.
                              final merged = [
                                ..._exerciseIds,
                                ...selected.where(
                                  (id) => !_exerciseIds.contains(id),
                                ),
                              ];
                              setState(() => _exerciseIds = merged);
                              await _persistOrder(context);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: const Text('Hinzufügen'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allExercises = context.watch<ExerciseProvider>().exercises;
    final byId = {for (final e in allExercises) e.id: e};

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.name),
        actions: [
          IconButton(
            tooltip: 'Workout umbenennen',
            icon: const Icon(Icons.edit),
            onPressed: () async {
              String newName = widget.workout.name;
              await showDialog(
                context: context,
                builder: (ctx) {
                  final ctrl = TextEditingController(text: newName);
                  return AlertDialog(
                    title: const Text('Workout umbenennen'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    content: TextField(
                      controller: ctrl,
                      decoration: const InputDecoration(
                        labelText: 'Workout-Name',
                      ),
                      autofocus: true,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Abbrechen'),
                      ),
                      FilledButton(
                        onPressed: () {
                          newName =
                              ctrl.text.trim().isEmpty
                                  ? widget.workout.name
                                  : ctrl.text.trim();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Speichern'),
                      ),
                    ],
                  );
                },
              );
              await context.read<WorkoutProvider>().updateWorkoutName(
                widget.workout.id,
                newName,
              );
              setState(() => widget.workout.name = newName);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            child:
                _exerciseIds.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_circle_outline, size: 72),
                          const SizedBox(height: 12),
                          Text(
                            'Noch keine Übungen',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Füge Übungen hinzu, um dein Workout zu starten.',
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _addExercisesBottomSheet,
                            icon: const Icon(Icons.add),
                            label: const Text('Übungen hinzufügen'),
                          ),
                        ],
                      ),
                    )
                    : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                      itemCount: _exerciseIds.length,
                      onReorder: _onReorder,
                      itemBuilder: (_, i) {
                        final id = _exerciseIds[i];
                        final e = byId[id];
                        return Card(
                          key: ValueKey('exercise_$id'),
                          child: ListTile(
                            leading: const Icon(Icons.drag_handle),
                            title: Text(
                              e?.name ?? 'Gelöschte Übung ($id)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle:
                                e == null
                                    ? const Text('Nicht mehr vorhanden')
                                    : Text(
                                      [
                                        if (e.trackSets) 'Sätze',
                                        if (e.trackReps) 'Wdh.',
                                        if (e.trackWeight) 'Gewicht',
                                        if (e.trackDuration) 'Dauer',
                                      ].join(' · '),
                                    ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                setState(() => _exerciseIds.removeAt(i));
                                await _persistOrder(context);
                              },
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton.tonalIcon(
            onPressed: _addExercisesBottomSheet,
            icon: const Icon(Icons.add),
            label: const Text('Weitere Übung hinzufügen'),
          ),
        ),
      ),
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
