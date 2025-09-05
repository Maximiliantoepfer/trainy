import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';
import '../providers/exercise_provider.dart';
import 'workout_run_screen.dart';

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
    final all = context.read<ExerciseProvider>().exercises;
    final selected = Set<int>.from(_exerciseIds);

    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final trackSets = ValueNotifier<bool>(true);
    final trackReps = ValueNotifier<bool>(true);
    final trackWeight = ValueNotifier<bool>(true);
    final trackDuration = ValueNotifier<bool>(false);

    final rootContext = context;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        // Helper: Neue Übung erstellen + direkt übernehmen + schließen
        Future<void> createAndAttach() async {
          final name = nameCtrl.text.trim();
          if (name.isEmpty) {
            await showDialog(
              context: ctx,
              builder:
                  (_) => AlertDialog(
                    title: const Text('Name fehlt'),
                    content: const Text('Bitte einen Namen eingeben'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
            );
            return;
          }

          final newId = await ctx.read<ExerciseProvider>().addExercise(
            name: name,
            description: descCtrl.text.trim(),
            trackSets: trackSets.value,
            trackReps: trackReps.value,
            trackWeight: trackWeight.value,
            trackDuration: trackDuration.value,
          );

          final merged = [
            ..._exerciseIds,
            if (!_exerciseIds.contains(newId)) newId,
          ];

          setState(() => _exerciseIds = merged);
          await _persistOrder(rootContext);

          if (rootContext.mounted) {
            Navigator.pop(ctx); // Sheet schließen
            ScaffoldMessenger.of(rootContext).showSnackBar(
              SnackBar(
                content: Text('„$name“ wurde erstellt und hinzugefügt'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }

        return StatefulBuilder(
          builder: (ctx, modalSetState) {
            return DefaultTabController(
              length: 2,
              child: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final controller = DefaultTabController.of(ctx)!;

                    return Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
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

                        TabBar(
                          tabs: const [
                            Tab(text: 'Vorhandene'),
                            Tab(text: 'Neu erstellen'),
                          ],
                          onTap: (_) => modalSetState(() {}),
                        ),

                        // Body (nimmt restliche Höhe ein)
                        Expanded(
                          child: TabBarView(
                            children: [
                              // Tab 1: vorhandene Exercises auswählen
                              ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  24,
                                ),
                                itemCount: all.length,
                                itemBuilder: (_, i) {
                                  final e = all[i];
                                  final subtitle = <String>[];
                                  if (e.trackSets) subtitle.add('Sätze');
                                  if (e.trackReps) subtitle.add('Wdh.');
                                  if (e.trackWeight) subtitle.add('Gewicht');
                                  if (e.trackDuration) subtitle.add('Dauer');
                                  return Card(
                                    child: CheckboxListTile(
                                      value: selected.contains(e.id),
                                      onChanged: (v) {
                                        modalSetState(() {
                                          if (v == true) {
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
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // Tab 2: neue Exercise erstellen
                              ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  24,
                                ),
                                children: [
                                  TextField(
                                    controller: nameCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Name *',
                                      hintText: 'z. B. Plank',
                                    ),
                                    autofocus: true,
                                    onChanged: (_) => modalSetState(() {}),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: descCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Beschreibung',
                                    ),
                                    minLines: 1,
                                    maxLines: 3,
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
                                          modalSetState(() {});
                                        },
                                      ),
                                      ChoiceChip(
                                        label: const Text('Körpergewicht'),
                                        selected: false,
                                        onSelected: (_) {
                                          trackSets.value = true;
                                          trackReps.value = true;
                                          trackWeight.value = false;
                                          trackDuration.value = false;
                                          modalSetState(() {});
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
                                          modalSetState(() {});
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
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Dynamische Bottom-CTA (achtet auf Keyboard)
                        AnimatedBuilder(
                          animation: controller.animation ?? controller,
                          builder: (_, __) {
                            final isCreateTab = controller.index == 1;
                            final canCreate = nameCtrl.text.trim().isNotEmpty;
                            final bottomInset =
                                MediaQuery.of(ctx).viewInsets.bottom;

                            return AnimatedPadding(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              padding: EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16 + bottomInset,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Abbrechen'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      switchInCurve: Curves.easeOut,
                                      switchOutCurve: Curves.easeIn,
                                      transitionBuilder:
                                          (child, anim) => ScaleTransition(
                                            scale: anim,
                                            child: child,
                                          ),
                                      child:
                                          isCreateTab
                                              ? FilledButton.icon(
                                                key: const ValueKey(
                                                  'create_and_add',
                                                ),
                                                onPressed:
                                                    canCreate
                                                        ? () async =>
                                                            createAndAttach()
                                                        : null,
                                                icon: const Icon(Icons.add),
                                                label: const Text(
                                                  'Erstellen & hinzufügen',
                                                ),
                                              )
                                              : FilledButton(
                                                key: const ValueKey(
                                                  'add_selected',
                                                ),
                                                onPressed: () async {
                                                  final merged = [
                                                    ..._exerciseIds,
                                                    ...selected.where(
                                                      (id) =>
                                                          !_exerciseIds
                                                              .contains(id),
                                                    ),
                                                  ];
                                                  setState(
                                                    () => _exerciseIds = merged,
                                                  );
                                                  await _persistOrder(
                                                    rootContext,
                                                  );

                                                  if (rootContext.mounted) {
                                                    Navigator.pop(
                                                      ctx,
                                                    ); // Sheet schließen
                                                    ScaffoldMessenger.of(
                                                      rootContext,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Übungen hinzugefügt',
                                                        ),
                                                        behavior:
                                                            SnackBarBehavior
                                                                .floating,
                                                      ),
                                                    );
                                                  }
                                                },
                                                child: const Text('Hinzufügen'),
                                              ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _rename() async {
    String newName = widget.workout.name;
    final ctrl = TextEditingController(text: widget.workout.name);
    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Workout umbenennen'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Workout-Name'),
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
          ),
    );
    await context.read<WorkoutProvider>().updateWorkoutName(
      widget.workout.id,
      newName,
    );
    setState(() => widget.workout.name = newName);
  }

  @override
  Widget build(BuildContext context) {
    final exercises = context.watch<ExerciseProvider>().exercises;
    final items =
        _exerciseIds
            .map(
              (id) =>
                  exercises
                      .where((e) => e.id == id)
                      .cast<Exercise?>()
                      .firstOrNull,
            )
            .toList();

    final canStart = _exerciseIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.name),
        actions: [
          IconButton(
            tooltip: 'Umbenennen',
            onPressed: _rename,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body:
          _exerciseIds.isEmpty
              ? _EmptyState(onAdd: _addExercisesBottomSheet)
              : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  110,
                ), // <- FIX: EdgeInsets (nicht EdgeBoxInsets)
                itemCount: _exerciseIds.length,
                onReorder: _onReorder,
                buildDefaultDragHandles: false,
                proxyDecorator:
                    (child, index, animation) =>
                        ScaleTransition(scale: animation, child: child),
                itemBuilder: (_, i) {
                  final id = _exerciseIds[i];
                  final e =
                      items[i]; // kann null sein, wenn zwischenzeitlich gelöscht
                  return Card(
                    key: ValueKey('exercise_$id'),
                    child: ListTile(
                      leading: ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle),
                      ),
                      title: Text(
                        e?.name ?? 'Gelöschte Übung ($id)',
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
      floatingActionButton:
          canStart
              ? FloatingActionButton.extended(
                onPressed: () {
                  final list =
                      _exerciseIds
                          .map(
                            (id) =>
                                exercises
                                    .where((e) => e.id == id)
                                    .cast<Exercise?>()
                                    .firstOrNull,
                          )
                          .whereType<Exercise>()
                          .toList();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => WorkoutRunScreen(
                            workout: widget.workout,
                            exercises: list,
                          ),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start'),
              )
              : null,
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Noch keine Übungen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Füge Übungen hinzu, um dein Workout zu starten.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Übungen hinzufügen'),
            ),
          ],
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
    super.key,
    required this.trackSets,
    required this.trackReps,
    required this.trackWeight,
    required this.trackDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _tile(context, 'Sätze zählen', 'z. B. 3 Sätze', trackSets),
        _tile(context, 'Wiederholungen', 'z. B. 10 pro Satz', trackReps),
        _tile(context, 'Gewicht', 'z. B. 50 kg', trackWeight),
        _tile(context, 'Dauer', 'z. B. 60 Sekunden', trackDuration),
      ],
    );
  }

  Widget _tile(
    BuildContext context,
    String title,
    String? subtitle,
    ValueNotifier<bool> state,
  ) {
    return ValueListenableBuilder<bool>(
      valueListenable: state,
      builder:
          (_, v, __) => Card(
            child: CheckboxListTile(
              value: v,
              onChanged: (val) => state.value = val ?? false,
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
          ),
    );
  }
}

// kleine Extension um firstOrNull zu bekommen
extension _IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
