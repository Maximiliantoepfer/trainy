// lib/screens/edit_exercise_in_workout_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exercise_in_workout.dart';
import '../models/exercise.dart';
import '../providers/exercise_provider.dart';

class EditExerciseInWorkoutScreen extends StatefulWidget {
  final ExerciseInWorkout exerciseInWorkout;

  const EditExerciseInWorkoutScreen({
    super.key,
    required this.exerciseInWorkout,
  });

  @override
  State<EditExerciseInWorkoutScreen> createState() => _EditExerciseInWorkoutScreenState();
}

class _EditExerciseInWorkoutScreenState extends State<EditExerciseInWorkoutScreen> {
  late Map<String, String> _customValues;

  @override
  void initState() {
    super.initState();
    _customValues = Map<String, String>.from(widget.exerciseInWorkout.customValues);
    // Safety: wenn Exercises noch nicht geladen sind, lade sie
    Future.microtask(() {
      final ep = Provider.of<ExerciseProvider>(context, listen: false);
      if (!ep.isLoading && ep.exercises.isEmpty) ep.loadExercises();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ep = context.watch<ExerciseProvider>();
    final exercises = ep.exercises;
    final Exercise? exercise = exercises.isEmpty
        ? null
        : exercises.firstWhere(
          (e) => e.id == widget.exerciseInWorkout.exerciseId,
      orElse: () => exercises.first,
    );

    if (exercise == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("${exercise.name} bearbeiten")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Vorgabewerte für dieses Workout", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ...exercise.trackedFields.map((field) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: '$field (${exercise.units[field] ?? ""})',
                    border: const OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: _customValues[field] ?? ''),
                  onChanged: (v) => _customValues[field] = v,
                ),
              );
            }),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text("Speichern"),
              onPressed: () {
                final updated = widget.exerciseInWorkout.copyWith(customValues: _customValues);
                Navigator.pop(context, updated);
              },
            ),
          ],
        ),
      ),
    );
  }
}
