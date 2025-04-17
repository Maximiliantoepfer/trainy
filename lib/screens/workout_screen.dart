// lib/screens/workout_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainy/models/exercise.dart';
import 'package:trainy/models/exercise_in_workout.dart';
import 'package:trainy/providers/theme_provider.dart';
import 'package:trainy/services/exercise_database.dart';
import 'package:trainy/services/workout_database.dart';
import '../models/workout.dart';
import '../utils/utils.dart';

class WorkoutScreen extends StatefulWidget {
  final Workout workout;

  WorkoutScreen({required this.workout});

  @override
  _WorkoutScreenState createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late TextEditingController _nameController;
  bool _isEditing = false;
  bool _isSelectionMode = false;
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

  Future<void> _saveWorkout() async {
    await WorkoutDatabase.instance.insertWorkout(widget.workout);
  }

  Future<void> _updateWorkoutName(String newName) async {
    setState(() {
      widget.workout.name = newName;
    });
    await WorkoutDatabase.instance.updateWorkoutName(
      widget.workout.id,
      newName,
    );
  }

  void _showExerciseSelectionDialog() async {
    final allTemplates = await ExerciseDatabase.instance.getAllExercises();
    final selectedIds =
        widget.workout.exercises.map((e) => e.exerciseId).toSet();
    final TextEditingController searchController = TextEditingController();
    List<Exercise> filteredTemplates = List.from(allTemplates);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
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
                              final position = widget.workout.exercises.length;
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
                    await _saveWorkout();
                    Navigator.pop(context);
                  },
                  child: Text('Fertig'),
                ),
              ],
            );
          },
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final workout = widget.workout;
    return Scaffold(
      appBar: AppBar(
        title:
            _isEditing
                ? TextField(
                  controller: _nameController,
                  autofocus: true,
                  style: TextStyle(color: getTextColor(context)),
                  onEditingComplete: () async {
                    await _updateWorkoutName(_nameController.text);
                    setState(() => _isEditing = false);
                  },
                )
                : GestureDetector(
                  onTap: () => setState(() => _isEditing = true),
                  child: Text(
                    workout.name,
                    style: TextStyle(color: getTextColor(context)),
                  ),
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
                      await _saveWorkout();
                    },
                  ),
                ]
                : null,
      ),
      body:
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
                  await _saveWorkout();
                },
                itemBuilder: (context, index) {
                  final exercise = workout.exercises[index];
                  final isSelected = _selectedExerciseIds.contains(exercise.id);
                  return ListTile(
                    key: ValueKey(exercise.id),
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: Icon(exercise.icon, color: getTextColor(context)),
                    ),
                    title: Text(exercise.name),
                    subtitle: Text(exercise.description),
                    trailing:
                        _isSelectionMode
                            ? Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleSelection(exercise.id),
                            )
                            : null,
                    onLongPress: () => _toggleSelection(exercise.id),
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleSelection(exercise.id);
                      }
                    },
                  );
                },
              ),
      floatingActionButton:
          !_isSelectionMode
              ? FloatingActionButton(
                onPressed: _showExerciseSelectionDialog,
                child: Icon(Icons.add),
                backgroundColor:
                    Provider.of<ThemeProvider>(context).getAccentColor(),
              )
              : null,
    );
  }
}
