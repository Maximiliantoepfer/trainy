// lib/screens/edit_exercise_in_workout_screen.dart

import 'package:flutter/material.dart';
import 'package:trainy/models/exercise_in_workout.dart';

class EditExerciseInWorkoutScreen extends StatefulWidget {
  final ExerciseInWorkout exercise;

  const EditExerciseInWorkoutScreen({super.key, required this.exercise});

  @override
  State<EditExerciseInWorkoutScreen> createState() =>
      _EditExerciseInWorkoutScreenState();
}

class _EditExerciseInWorkoutScreenState
    extends State<EditExerciseInWorkoutScreen> {
  late Map<String, String> defaultValues;
  late Map<String, String> units;
  late List<String> trackedFields;

  final unitOptions = <String, List<String>>{
    'Sätze': ['x'],
    'Wiederholungen': ['x'],
    'Gewicht': ['kg', 'lbs'],
    'Dauer': ['sec', 'min'],
  };

  @override
  void initState() {
    super.initState();
    trackedFields = List.from(widget.exercise.trackedFields);
    defaultValues = Map.from(widget.exercise.defaultValues);
    units = Map.from(widget.exercise.units);

    units.updateAll((key, value) {
      if (!unitOptions.containsKey(key) || !unitOptions[key]!.contains(value)) {
        return unitOptions[key]?.first ?? '';
      }
      return value;
    });
  }

  void toggleField(String field) {
    setState(() {
      if (trackedFields.contains(field)) {
        trackedFields.remove(field);
        defaultValues.remove(field);
        units.remove(field);
      } else {
        trackedFields.add(field);
        defaultValues[field] = '';
        units[field] = unitOptions[field]?.first ?? '';
      }
    });
  }

  Widget buildFieldInput(String field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Letzter Wert',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              onChanged: (val) => defaultValues[field] = val,
              controller: TextEditingController(text: defaultValues[field]),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Einheit',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              value:
                  unitOptions[field]!.contains(units[field])
                      ? units[field]
                      : unitOptions[field]!.first,
              items:
                  unitOptions[field]!
                      .map(
                        (unit) =>
                            DropdownMenuItem(value: unit, child: Text(unit)),
                      )
                      .toList(),
              onChanged:
                  (val) => setState(() {
                    if (val != null) units[field] = val;
                  }),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.exercise.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              'Getrackte Felder:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ...unitOptions.keys.map(
              (field) => Column(
                children: [
                  CheckboxListTile(
                    title: Text(field),
                    value: trackedFields.contains(field),
                    onChanged: (_) => toggleField(field),
                  ),
                  if (trackedFields.contains(field)) buildFieldInput(field),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final updated = ExerciseInWorkout(
                  id: widget.exercise.id,
                  workoutId: widget.exercise.workoutId,
                  exerciseId: widget.exercise.exerciseId,
                  name: widget.exercise.name,
                  description: widget.exercise.description,
                  trackedFields: trackedFields,
                  defaultValues: Map<String, String>.from(defaultValues),
                  units: Map<String, String>.from(units),
                  icon: widget.exercise.icon,
                  position: widget.exercise.position,
                );
                Navigator.pop(context, updated);
              },
              child: Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }
}
