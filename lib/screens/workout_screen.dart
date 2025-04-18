import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainy/models/exercise.dart';
import 'package:trainy/models/exercise_in_workout.dart';
import 'package:trainy/models/workout.dart';
import 'package:trainy/models/workout_entry.dart';
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
    setState(() {
      widget.workout.name = newName;
    });
    await Provider.of<WorkoutProvider>(
      context,
      listen: false,
    ).updateWorkoutName(widget.workout.id, newName);
  }

  Future<void> _startWorkout() async {
    setState(() {
      _isWorkoutRunning = true;
      _startTime = DateTime.now();
    });
  }

  Future<void> _finishWorkout() async {
    if (_startTime == null) return;

    final endTime = DateTime.now();
    final duration = endTime.difference(_startTime!);

    final entry = WorkoutEntry(
      id: DateTime.now().millisecondsSinceEpoch,
      workoutId: widget.workout.id,
      date: endTime,
      results: {
        'durationInMinutes': duration.inMinutes,
        'exercises': widget.workout.exercises.map((e) => e.name).toList(),
      },
    );

    await WorkoutEntryDatabase.instance.insertEntry(entry);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Workout abgeschlossen! 👍')));

    setState(() {
      _isWorkoutRunning = false;
      _startTime = null;
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedExerciseIds.contains(id)) {
        _selectedExerciseIds.remove(id);
        if (_selectedExerciseIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedExerciseIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _showExerciseSelectionDialog() async {
    final allTemplates = await ExerciseDatabase.instance.getAllExercises();
    final selectedIds =
        widget.workout.exercises.map((e) => e.exerciseId).toSet();
    final searchController = TextEditingController();
    List<Exercise> filteredTemplates = List.from(allTemplates);

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              void _applySearch(String query) {
                setDialogState(() {
                  filteredTemplates =
                      allTemplates
                          .where(
                            (e) =>
                                e.name.toLowerCase().contains(
                                  query.toLowerCase(),
                                ) ||
                                e.description.toLowerCase().contains(
                                  query.toLowerCase(),
                                ),
                          )
                          .toList();
                });
              }

              return AlertDialog(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Übungen hinzufügen'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Suchen...',
                        border: InputBorder.none,
                      ),
                      onChanged: _applySearch,
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: ListView.builder(
                    itemCount: filteredTemplates.length,
                    itemBuilder: (context, index) {
                      final template = filteredTemplates[index];
                      final isSelected = selectedIds.contains(template.id);
                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(
                          template.name,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (template.description.isNotEmpty)
                              Text(template.description),
                            if (template.trackedFields.isNotEmpty)
                              Text(
                                "Felder: ${template.trackedFields.join(', ')}",
                              ),
                          ],
                        ),
                        secondary: Icon(template.icon),
                        onChanged: (selected) {
                          setState(() {
                            setDialogState(() {
                              if (selected == true && !isSelected) {
                                final newId =
                                    DateTime.now().millisecondsSinceEpoch;
                                final position =
                                    widget.workout.exercises.length;
                                widget.workout.exercises.add(
                                  ExerciseInWorkout(
                                    id: newId,
                                    workoutId: widget.workout.id,
                                    exerciseId: template.id,
                                    name: template.name,
                                    description: template.description,
                                    trackedFields: List.from(
                                      template.trackedFields,
                                    ),
                                    defaultValues: Map.from(
                                      template.defaultValues,
                                    ),
                                    units: Map.from(template.units),
                                    icon: template.icon,
                                    position: position,
                                  ),
                                );
                              } else if (selected == false && isSelected) {
                                widget.workout.exercises.removeWhere(
                                  (e) => e.exerciseId == template.id,
                                );
                              }
                            });
                          });
                        },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await _updateWorkout();
                      Navigator.pop(context);
                    },
                    child: Text('Fertig'),
                  ),
                ],
              );
            },
          ),
    );
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
                    icon: Icon(Icons.delete),
                    onPressed: () async {
                      setState(() {
                        workout.exercises.removeWhere(
                          (e) => _selectedExerciseIds.contains(e.id),
                        );
                        _selectedExerciseIds.clear();
                        _isSelectionMode = false;
                      });
                      await _updateWorkout();
                    },
                  ),
                ]
                : null,
      ),
      body: Column(
        children: [
          if (_isWorkoutRunning)
            Container(
              width: double.infinity,
              color: Colors.green.withOpacity(0.1),
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer, color: Colors.green.shade800),
                      const SizedBox(width: 8),
                      Text(
                        'Workout läuft seit ${_startTime?.hour.toString().padLeft(2, '0')}:${_startTime?.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _finishWorkout,
                    icon: Icon(Icons.stop),
                    label: Text("Abschließen"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child:
                workout.exercises.isEmpty
                    ? Center(child: Text('Keine Übungen hinzugefügt.'))
                    : ReorderableListView.builder(
                      itemCount: workout.exercises.length,
                      buildDefaultDragHandles: true,
                      onReorder: (oldIndex, newIndex) async {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final item = workout.exercises.removeAt(oldIndex);
                          workout.exercises.insert(newIndex, item);
                        });
                        await _updateWorkout();
                      },
                      itemBuilder: (context, index) {
                        final exercise = workout.exercises[index];
                        final isSelected = _selectedExerciseIds.contains(
                          exercise.id,
                        );
                        return ListTile(
                          key: ValueKey(exercise.id),
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: Icon(exercise.icon, color: textColor),
                          ),
                          title: Text(exercise.name),
                          subtitle: Text(exercise.description),
                          trailing:
                              _isSelectionMode
                                  ? Checkbox(
                                    value: isSelected,
                                    onChanged:
                                        (_) => _toggleSelection(exercise.id),
                                  )
                                  : null,
                          onLongPress: () => _toggleSelection(exercise.id),
                          onTap: () async {
                            if (_isSelectionMode) {
                              _toggleSelection(exercise.id);
                            } else {
                              final updated = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => EditExerciseInWorkoutScreen(
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
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton:
          !_isSelectionMode
              ? FloatingActionButton(
                onPressed: _isWorkoutRunning ? null : _startWorkout,
                backgroundColor: _isWorkoutRunning ? Colors.grey : accentColor,
                child: Icon(_isWorkoutRunning ? Icons.timer : Icons.play_arrow),
              )
              : null,
      bottomNavigationBar:
          !_isWorkoutRunning
              ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ElevatedButton.icon(
                    onPressed: _showExerciseSelectionDialog,
                    icon: Icon(Icons.add),
                    label: Text("Übung hinzufügen"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              )
              : null,
    );
  }
}
