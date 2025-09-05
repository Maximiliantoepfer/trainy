// lib/screens/edit_exercise_in_workout_screen.dart
// Refaktoriere: Bearbeitung der Werte einer *globalen* Exercise für diese Session

import 'package:flutter/material.dart';
import '../models/exercise.dart';

class EditExerciseInWorkoutScreen extends StatefulWidget {
  final Exercise exercise;
  final Map<String, String> initialValues;

  const EditExerciseInWorkoutScreen({
    super.key,
    required this.exercise,
    required this.initialValues,
  });

  @override
  State<EditExerciseInWorkoutScreen> createState() =>
      _EditExerciseInWorkoutScreenState();
}

class _EditExerciseInWorkoutScreenState
    extends State<EditExerciseInWorkoutScreen> {
  late Map<String, String> _values;

  @override
  void initState() {
    super.initState();
    _values = Map<String, String>.from(widget.initialValues);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.exercise.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            ...widget.exercise.trackedFields.map((field) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: TextEditingController(text: _values[field] ?? ''),
                  decoration: InputDecoration(
                    labelText: field,
                    suffixText: widget.exercise.units[field],
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => _values[field] = v,
                ),
              );
            }),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Übernehmen'),
            onPressed: () => Navigator.pop(context, _values),
          ),
        ),
      ),
    );
  }
}
