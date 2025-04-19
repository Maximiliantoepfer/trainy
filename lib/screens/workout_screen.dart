// workout_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainy/models/exercise.dart';
import 'package:trainy/models/exercise_in_workout.dart';
import 'package:trainy/models/workout.dart';
import 'package:trainy/models/workout_entry.dart';
import 'package:trainy/providers/progress_provider.dart';
import 'package:trainy/providers/theme_provider.dart';
import 'package:trainy/providers/workout_provider.dart';
import 'package:trainy/screens/edit_exercise_in_workout_screen.dart';
import 'package:trainy/services/exercise_database.dart';
import 'package:trainy/services/workout_entry_database.dart';
import '../utils/utils.dart';

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
  final Set<int> _selectedExerciseIds = {};
  final Set<int> _completedExerciseIds = {};
  final Map<int, Map<String, String>> _exerciseResults = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.workout.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateWorkout() async {
    await Provider.of<WorkoutProvider>(
      context,
      listen: false,
    ).updateWorkout(widget.workout);
  }

  Future<void> _updateWorkoutName(String newName) async {
    setState(() => widget.workout.name = newName);
    await Provider.of<WorkoutProvider>(
      context,
      listen: false,
    ).updateWorkoutName(widget.workout.id, newName);
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

    for (final e in widget.workout.exercises) {
      if (_exerciseResults.containsKey(e.id)) {
        e.defaultValues.addAll(_exerciseResults[e.id]!);
      }
    }
    await _updateWorkout();

    // 🧠 Strukturierte Daten pro Übung vorbereiten
    final trackedExercises =
        widget.workout.exercises
            .where((e) => _exerciseResults.containsKey(e.id))
            .map(
              (e) => {
                'id': e.exerciseId,
                'name': e.name,
                'fields': _exerciseResults[e.id],
              },
            )
            .toList();

    final entry = WorkoutEntry(
      id: DateTime.now().millisecondsSinceEpoch,
      workoutId: widget.workout.id,
      date: DateTime.now(),
      results: {
        'durationInMinutes': duration.inMinutes,
        'exercises': trackedExercises,
      },
    );

    await WorkoutEntryDatabase.instance.insertEntry(entry);

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  "Workout abgeschlossen!",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  "Gut gemacht 💪",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
    );

    setState(() {
      _isWorkoutRunning = false;
      _startTime = null;
    });
    Provider.of<ProgressProvider>(context, listen: false).refreshEntries();
  }

  void _toggleSelection(int id) {
    setState(() {
      _selectedExerciseIds.contains(id)
          ? _selectedExerciseIds.remove(id)
          : _selectedExerciseIds.add(id);
      _isSelectionMode = _selectedExerciseIds.isNotEmpty;
    });
  }

  Future<void> _showTrackExerciseDialog(ExerciseInWorkout exercise) async {
    final values = Map<String, String>.from(
      _exerciseResults[exercise.id] ?? exercise.defaultValues,
    );

    final controllerMap = {
      for (final field in exercise.trackedFields)
        field: TextEditingController(text: values[field] ?? ''),
    };

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  exercise.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ...exercise.trackedFields.map(
                  (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: controllerMap[field],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '$field (${exercise.units[field] ?? ""})',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text("Speichern"),
                  onPressed: () {
                    setState(() {
                      final result = {
                        for (final entry in controllerMap.entries)
                          entry.key: entry.value.text.trim(),
                      };
                      _exerciseResults[exercise.id] = result;
                      exercise.defaultValues.addAll(result);
                      _completedExerciseIds.add(exercise.id);
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _reindexExercises() {
    for (var i = 0; i < widget.workout.exercises.length; i++) {
      widget.workout.exercises[i] = widget.workout.exercises[i].copyWith(
        position: i,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final workout = widget.workout;
    final accentColor = Theme.of(context).colorScheme.primary;
    final textColor = getTextColor(context);

    return Scaffold(
      appBar: AppBar(
        title:
            _isEditing
                ? TextField(
                  controller: _nameController,
                  autofocus: true,
                  style: TextStyle(color: textColor),
                  onEditingComplete: () async {
                    await _updateWorkoutName(_nameController.text);
                    setState(() => _isEditing = false);
                  },
                )
                : GestureDetector(
                  onTap: () => setState(() => _isEditing = true),
                  child: Text(workout.name, style: TextStyle(color: textColor)),
                ),
        actions:
            _isSelectionMode
                ? [
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: "Ausgewählte löschen",
                    onPressed: () async {
                      setState(() {
                        workout.exercises.removeWhere(
                          (e) => _selectedExerciseIds.contains(e.id),
                        );
                        _selectedExerciseIds.clear();
                        _isSelectionMode = false;
                        _reindexExercises(); // ✅ Positionen nach dem Löschen aktualisieren
                      });
                      await _updateWorkout();
                    },
                  ),
                ]
                : null,
      ),
      body: Column(
        children: [
          if (_isWorkoutRunning && _startTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Dauer: ${DateTime.now().difference(_startTime!).inMinutes.toString().padLeft(2, '0')}:${(DateTime.now().difference(_startTime!).inSeconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (_isWorkoutRunning)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: LinearProgressIndicator(
                value:
                    workout.exercises.isEmpty
                        ? 0
                        : _completedExerciseIds.length /
                            workout.exercises.length,
                backgroundColor: Colors.grey[300],
                color: accentColor,
              ),
            ),
          Expanded(
            child:
                workout.exercises.isEmpty
                    ? const Center(child: Text('Keine Übungen hinzugefügt.'))
                    : ReorderableListView.builder(
                      itemCount: workout.exercises.length,
                      buildDefaultDragHandles:
                          false, // <-- damit wir eigenen Handle nutzen
                      onReorder: (oldIndex, newIndex) async {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final item = workout.exercises.removeAt(oldIndex);
                          workout.exercises.insert(newIndex, item);
                          _reindexExercises(); // ✅ Positionen neu setzen
                        });
                        await _updateWorkout();
                      },
                      itemBuilder: (context, index) {
                        final exercise = workout.exercises[index];
                        final isSelected = _selectedExerciseIds.contains(
                          exercise.id,
                        );
                        final isCompleted = _completedExerciseIds.contains(
                          exercise.id,
                        );

                        return Container(
                          key: ValueKey(exercise.id),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceVariant.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  isSelected ? accentColor : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    if (_isSelectionMode) {
                                      _toggleSelection(exercise.id);
                                    } else if (_isWorkoutRunning) {
                                      await _showTrackExerciseDialog(exercise);
                                    } else {
                                      final updated = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  EditExerciseInWorkoutScreen(
                                                    exercise: exercise,
                                                  ),
                                        ),
                                      );
                                      if (updated != null &&
                                          updated is ExerciseInWorkout) {
                                        setState(() {
                                          workout.exercises[index] = updated;
                                        });
                                        await _updateWorkout();
                                      }
                                    }
                                  },
                                  onLongPress: () {
                                    // ✅ Starte Auswahlmodus + markiere Element
                                    setState(() {
                                      _isSelectionMode = true;
                                      _selectedExerciseIds.add(exercise.id);
                                    });
                                  },

                                  child: Row(
                                    children: [
                                      Icon(
                                        isCompleted
                                            ? Icons.check_circle
                                            : exercise.icon,
                                        color:
                                            isCompleted
                                                ? Colors.green
                                                : accentColor,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              exercise.name,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                decoration:
                                                    isCompleted
                                                        ? TextDecoration
                                                            .lineThrough
                                                        : null,
                                              ),
                                            ),
                                            if (exercise.description.isNotEmpty)
                                              Text(
                                                exercise.description,
                                                style:
                                                    Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (_isSelectionMode)
                                        Checkbox(
                                          value: isSelected,
                                          onChanged:
                                              (_) =>
                                                  _toggleSelection(exercise.id),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              // 🟢 Drag Handle
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
      floatingActionButton:
          !_isSelectionMode
              ? FloatingActionButton.extended(
                onPressed: _isWorkoutRunning ? _finishWorkout : _startWorkout,
                label: Text(_isWorkoutRunning ? "Beenden" : "Starten"),
                icon: Icon(_isWorkoutRunning ? Icons.stop : Icons.play_arrow),
                backgroundColor: _isWorkoutRunning ? Colors.red : accentColor,
              )
              : null,
    );
  }
}
