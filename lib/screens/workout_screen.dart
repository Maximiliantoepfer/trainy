import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trainy/models/workout.dart';
import 'package:trainy/models/exercise.dart';
import 'package:trainy/providers/workout_provider.dart';
import 'package:trainy/providers/exercise_provider.dart';

class WorkoutScreen extends StatefulWidget {
  final Workout workout;
  const WorkoutScreen({super.key, required this.workout});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late List<int> _exerciseIds;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _exerciseIds = List<int>.from(widget.workout.exerciseIds);
  }

  Future<void> _persistOrder(BuildContext context) async {
    // WICHTIG: In deinem Provider heißt die Methode updateWorkoutExercises (nicht setWorkoutExercises)
    await context.read<WorkoutProvider>().updateWorkoutExercises(
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
    final current = Set.of(_exerciseIds);
    final selected = Set<int>.from(_exerciseIds);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder:
                (ctx, setS) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 4,
                      width: 48,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      'Übungen hinzufügen',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: exercises.length,
                        itemBuilder: (_, i) {
                          final e = exercises[i];
                          final checked = selected.contains(e.id);
                          return CheckboxListTile(
                            value: checked,
                            onChanged:
                                (v) => setS(() {
                                  if (v == true) {
                                    selected.add(e.id);
                                  } else {
                                    selected.remove(e.id);
                                  }
                                }),
                            title: Text(e.name),
                            subtitle:
                                e.trackedFields.isNotEmpty
                                    ? Text(e.trackedFields.join(' · '))
                                    : null,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx, selected.toList(growable: false));
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Übernehmen'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
          ),
        );
      },
    ).then((result) async {
      if (result is List<int>) {
        final newIds = <int>[];
        // vorhandene IDs in aktueller Reihenfolge behalten
        for (final id in _exerciseIds) {
          if (result.contains(id)) newIds.add(id);
        }
        // neue IDs hinten anhängen
        for (final id in result) {
          if (!current.contains(id)) newIds.add(id);
        }
        setState(() => _exerciseIds = newIds);
        await _persistOrder(context);
      }
    });
  }

  Future<void> _removeExercise(int id) async {
    setState(() {
      _exerciseIds.remove(id);
    });
    await _persistOrder(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final allExercises = context.watch<ExerciseProvider>().exercises;

    Exercise? byId(int id) {
      try {
        return allExercises.firstWhere((e) => e.id == id);
      } catch (_) {
        return null;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.name),
        actions: [
          IconButton(
            onPressed: _addExercisesBottomSheet,
            icon: const Icon(Icons.add),
            tooltip: 'Übung hinzufügen',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child:
                _exerciseIds.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fitness_center, size: 42),
                          const SizedBox(height: 8),
                          const Text('Noch keine Übungen im Workout'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _addExercisesBottomSheet,
                            icon: const Icon(Icons.add),
                            label: const Text('Übung hinzufügen'),
                          ),
                        ],
                      ),
                    )
                    : ReorderableListView.builder(
                      proxyDecorator:
                          (child, index, animation) => Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(16),
                            child: child,
                          ),
                      onReorder: _running ? (_, __) {} : _onReorder,
                      itemCount: _exerciseIds.length,
                      itemBuilder: (ctx, i) {
                        final id = _exerciseIds[i];
                        final e = byId(id);
                        return ListTile(
                          key: ValueKey(id),
                          leading: ReorderableDragStartListener(
                            index: i,
                            enabled: !_running,
                            child: Icon(
                              Icons.drag_handle,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          title: Text(e?.name ?? 'Unbekannte Übung (#$id)'),
                          subtitle:
                              (e?.trackedFields.isNotEmpty ?? false)
                                  ? Text(e!.trackedFields.join(' · '))
                                  : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Entfernen',
                            onPressed:
                                _running ? null : () => _removeExercise(id),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        );
                      },
                    ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          _exerciseIds.isEmpty
              ? null
              : (_running
                  ? FloatingActionButton(
                    heroTag: 'stop',
                    onPressed: () => setState(() => _running = false),
                    child: const Icon(Icons.stop),
                  )
                  : FloatingActionButton(
                    heroTag: 'play',
                    onPressed: () => setState(() => _running = true),
                    child: const Icon(Icons.play_arrow),
                  )),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
          child:
              _exerciseIds.isEmpty
                  ? null
                  : FilledButton.tonalIcon(
                    onPressed: _addExercisesBottomSheet,
                    icon: const Icon(Icons.add),
                    label: const Text('Weitere Übung hinzufügen'),
                  ),
        ),
      ),
    );
  }
}
