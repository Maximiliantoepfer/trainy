// lib/screens/workout_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainy/models/exercise.dart';
import 'package:trainy/models/exercise_in_workout.dart';
import 'package:trainy/models/workout.dart';
import 'package:trainy/models/workout_entry.dart';
import 'package:trainy/providers/progress_provider.dart';
import 'package:trainy/providers/workout_provider.dart';
import 'package:trainy/providers/exercise_provider.dart';
import 'package:trainy/screens/edit_exercise_in_workout_screen.dart';
import 'package:trainy/services/workout_entry_database.dart';
import '../utils/utils.dart' as utils;

class WorkoutScreen extends StatefulWidget {
  final Workout workout;
  const WorkoutScreen({super.key, required this.workout});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late TextEditingController _nameController;
  bool _isEditing = false;
  bool _isSelectionMode = false;
  bool _isWorkoutRunning = false;
  DateTime? _startTime;
  final Set<int> _selectedExerciseIds = <int>{};
  final Set<int> _completedExerciseIds = <int>{};
  final Map<int, Map<String, String>> _exerciseResults = <int, Map<String, String>>{};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.workout.name);
    Future.microtask(() {
      final ep = Provider.of<ExerciseProvider>(context, listen: false);
      if (!ep.isLoading && ep.exercises.isEmpty) ep.loadExercises();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateWorkout() async {
    await Provider.of<WorkoutProvider>(context, listen: false).updateWorkout(widget.workout);
  }

  Future<void> _updateWorkoutName(String newName) async {
    setState(() => widget.workout.name = newName);
    await Provider.of<WorkoutProvider>(context, listen: false).updateWorkoutName(widget.workout.id, newName);
  }

  void _reindexExercises() {
    for (var i = 0; i < widget.workout.exercises.length; i++) {
      widget.workout.exercises[i] = widget.workout.exercises[i].copyWith(position: i);
    }
  }

  Exercise? _resolveExercise(ExerciseProvider ep, ExerciseInWorkout eiw) {
    final list = ep.exercises;
    if (list.isEmpty) return null;
    return list.firstWhere(
          (e) => e.id == eiw.exerciseId,
      orElse: () => list.first,
    );
  }

  Map<String, String> _initialValues(Exercise? base, ExerciseInWorkout eiw) {
    return {...(base?.defaultValues ?? const {}), ...eiw.customValues, ...(_exerciseResults[eiw.id] ?? const {})};
  }

  Future<void> _startWorkout() async {
    setState(() {
      _isWorkoutRunning = true;
      _startTime = DateTime.now();
      _completedExerciseIds.clear();
      _exerciseResults.clear();
    });
  }

  Future<void> _finishWorkout() async {
    if (_startTime == null) return;
    final duration = DateTime.now().difference(_startTime!);
    final ep = Provider.of<ExerciseProvider>(context, listen: false);

    for (final eiw in widget.workout.exercises) {
      final res = _exerciseResults[eiw.id];
      if (res == null) continue;

      final idx = widget.workout.exercises.indexWhere((x) => x.id == eiw.id);
      if (idx != -1) {
        widget.workout.exercises[idx] = eiw.copyWith(customValues: Map<String, String>.from(res));
      }

      final base = _resolveExercise(ep, eiw);
      if (base != null) {
        final updated = base.copyWith(defaultValues: {...base.defaultValues, ...res});
        await ep.updateExercise(updated);
      }
    }

    await _updateWorkout();

    final Map<int, Map<String, dynamic>> entryResults = {};
    for (final eiw in widget.workout.exercises) {
      final res = _exerciseResults[eiw.id];
      if (res != null) entryResults[eiw.exerciseId] = Map<String, dynamic>.from(res);
    }

    final entry = WorkoutEntry(
      id: DateTime.now().millisecondsSinceEpoch,
      workoutId: widget.workout.id,
      date: DateTime.now(),
      results: entryResults,
    );
    await WorkoutEntryDatabase.instance.insertEntry(entry);

    Provider.of<ProgressProvider>(context, listen: false).addWorkout(duration: duration);

    setState(() {
      _isWorkoutRunning = false;
      _startTime = null;
      _completedExerciseIds.clear();
      _exerciseResults.clear();
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout gespeichert! 🎉')));
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedExerciseIds.contains(id)) {
        _selectedExerciseIds.remove(id);
      } else {
        _selectedExerciseIds.add(id);
      }
      _isSelectionMode = _selectedExerciseIds.isNotEmpty;
    });
  }

  Future<void> _showTrackExerciseDialog(ExerciseInWorkout eiw) async {
    final ep = Provider.of<ExerciseProvider>(context, listen: false);
    final base = _resolveExercise(ep, eiw);
    final initial = _initialValues(base, eiw);

    final controllers = <String, TextEditingController>{
      for (final f in (base?.trackedFields ?? const <String>[])) f: TextEditingController(text: initial[f] ?? '')
    };

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final viewInsets = MediaQuery.of(context).viewInsets;
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text((base?.name ?? 'Übung'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...((base?.trackedFields ?? const <String>[]).map((field) {
                final unit = base?.units[field] ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: TextField(
                    controller: controllers[field],
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(labelText: '$field${unit.isEmpty ? '' : ' ($unit)'}'),
                  ),
                );
              })),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () {
                  final map = <String, String>{};
                  for (final e in controllers.entries) {
                    map[e.key] = e.value.text.trim();
                  }
                  Navigator.pop(context, map);
                },
                icon: const Icon(Icons.check),
                label: const Text('Speichern'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _exerciseResults[eiw.id] = result;
        _completedExerciseIds.add(eiw.id);
      });
    }
    for (final c in controllers.values) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final workout = widget.workout;
    final accentColor = Theme.of(context).colorScheme.primary;
    final textColor = utils.getTextColor(context);
    final exerciseProvider = context.watch<ExerciseProvider>();

    return Scaffold(
      appBar: AppBar(
        title: _isEditing
            ? TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(border: InputBorder.none, hintText: 'Workout-Namen eingeben'),
          onSubmitted: (val) {
            final trimmed = val.trim();
            if (trimmed.isNotEmpty) _updateWorkoutName(trimmed);
            setState(() => _isEditing = false);
          },
        )
            : Text(workout.name),
        actions: [
          if (!_isSelectionMode)
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
              onPressed: () {
                if (_isEditing) {
                  final trimmed = _nameController.text.trim();
                  if (trimmed.isNotEmpty) _updateWorkoutName(trimmed);
                }
                setState(() => _isEditing = !_isEditing);
              },
            ),
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                setState(() {
                  workout.exercises.removeWhere((e) => _selectedExerciseIds.contains(e.id));
                  _selectedExerciseIds.clear();
                  _isSelectionMode = false;
                  _reindexExercises();
                });
                await _updateWorkout();
              },
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isWorkoutRunning && _startTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Dauer: ${DateTime.now().difference(_startTime!).inMinutes.toString().padLeft(2, '0')}:${(DateTime.now().difference(_startTime!).inSeconds % 60).toString().padLeft(2, '0')}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          if (_isWorkoutRunning)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: LinearProgressIndicator(
                value: workout.exercises.isEmpty ? 0 : _completedExerciseIds.length / workout.exercises.length,
                backgroundColor: Colors.grey[300],
                color: accentColor,
              ),
            ),
          Expanded(
            child: workout.exercises.isEmpty
                ? const Center(child: Text('Keine Übungen hinzugefügt.'))
                : ReorderableListView.builder(
              itemCount: workout.exercises.length,
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) async {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = workout.exercises.removeAt(oldIndex);
                  workout.exercises.insert(newIndex, item);
                  _reindexExercises();
                });
                await _updateWorkout();
              },
              itemBuilder: (context, index) {
                final eiw = workout.exercises[index];
                final base = _resolveExercise(exerciseProvider, eiw);
                final isSelected = _selectedExerciseIds.contains(eiw.id);
                final isCompleted = _completedExerciseIds.contains(eiw.id);

                return Container(
                  key: ValueKey(eiw.id),
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? accentColor : Colors.transparent, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            if (_isSelectionMode) {
                              _toggleSelection(eiw.id);
                            } else if (_isWorkoutRunning) {
                              await _showTrackExerciseDialog(eiw);
                            } else {
                              final updated = await Navigator.push<ExerciseInWorkout>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditExerciseInWorkoutScreen(exerciseInWorkout: eiw),
                                ),
                              );
                              if (updated != null) {
                                setState(() {
                                  final idx = workout.exercises.indexWhere((e) => e.id == eiw.id);
                                  if (idx != -1) workout.exercises[idx] = updated;
                                });
                                await _updateWorkout();
                              }
                            }
                          },
                          onLongPress: () {
                            setState(() {
                              _isSelectionMode = true;
                              _selectedExerciseIds.add(eiw.id);
                            });
                          },
                          child: Row(
                            children: [
                              Icon(
                                isCompleted ? Icons.check_circle : (base?.icon ?? Icons.fitness_center),
                                color: isCompleted ? Colors.green : accentColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      base?.name ?? 'Übung #${eiw.exerciseId}',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    if ((base?.description.isNotEmpty ?? false))
                                      Text(base!.description, style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              if (_isSelectionMode)
                                Checkbox(value: isSelected, onChanged: (_) => _toggleSelection(eiw.id)),
                            ],
                          ),
                        ),
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: !_isWorkoutRunning
          ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add_exercise',
            icon: const Icon(Icons.add),
            label: const Text('Übung hinzufügen'),
            onPressed: () async {
              final ep = context.read<ExerciseProvider>();
              final all = ep.exercises;
              final already = workout.exercises.map((e) => e.exerciseId).toSet();
              final available = all.where((e) => !already.contains(e.id)).toList();
              if (available.isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Keine weiteren Übungen verfügbar.')));
                return;
              }

              final selected = await showModalBottomSheet<Exercise?>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) {
                  final TextEditingController searchController = TextEditingController();
                  List<Exercise> filtered = List.of(available);

                  void runFilter(String query) {
                    query = query.toLowerCase();
                    filtered = available
                        .where((e) =>
                    e.name.toLowerCase().contains(query) || e.description.toLowerCase().contains(query))
                        .toList();
                    // ignore: invalid_use_of_protected_member
                    (context as Element).markNeedsBuild();
                  }

                  return Padding(
                    padding: EdgeInsets.only(
                      top: 24,
                      left: 16,
                      right: 16,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Übung hinzufügen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: searchController,
                          decoration: const InputDecoration(
                            hintText: 'Suche nach Übung...',
                            prefixIcon: Icon(Icons.search),
                            filled: true,
                            border: OutlineInputBorder(borderSide: BorderSide.none),
                          ),
                          onChanged: runFilter,
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: filtered.isEmpty
                              ? const Center(child: Text('Keine passenden Übungen gefunden.'))
                              : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final ex = filtered[index];
                              return ListTile(
                                leading: Icon(ex.icon, color: Theme.of(context).colorScheme.primary),
                                title: Text(ex.name),
                                subtitle: Text(ex.description),
                                onTap: () => Navigator.pop(context, ex),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );

              if (selected != null) {
                final newExercise = ExerciseInWorkout(
                  id: DateTime.now().millisecondsSinceEpoch,
                  workoutId: workout.id,
                  exerciseId: selected.id,
                  position: workout.exercises.length,
                  customValues: const {},
                );
                setState(() {
                  workout.exercises.add(newExercise);
                  _reindexExercises();
                });
                await _updateWorkout();
              }
            },
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'start_stop',
            icon: Icon(_isWorkoutRunning ? Icons.stop : Icons.play_arrow),
            label: Text(_isWorkoutRunning ? 'Beenden' : 'Starten'),
            onPressed: _isWorkoutRunning ? _finishWorkout : _startWorkout,
          ),
        ],
      )
          : FloatingActionButton.extended(
        heroTag: 'stop_only',
        icon: const Icon(Icons.stop),
        label: const Text('Beenden'),
        onPressed: _finishWorkout,
      ),
    );
  }
}
