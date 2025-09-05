import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trainy/models/workout.dart';
import 'package:trainy/providers/workout_provider.dart';
import 'package:trainy/screens/workout_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _createWorkout(BuildContext context) async {
    // Neues, leeres Workout anlegen
    final w = Workout(
      id: DateTime.now().millisecondsSinceEpoch,
      name: 'Neues Workout',
      description: '',
      exerciseIds: const [],
    );

    final provider = context.read<WorkoutProvider>();
    // WICHTIG: In deinem Provider heißt die Methode addOrUpdateWorkout (nicht upsertWorkout)
    await provider.addOrUpdateWorkout(w);

    // Direkt öffnen
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => WorkoutScreen(workout: w)));

    // Liste neu laden (falls nötig)
    await provider.loadWorkouts();
  }

  @override
  Widget build(BuildContext context) {
    final workouts = context.watch<WorkoutProvider>().workouts;

    return Scaffold(
      appBar: AppBar(title: const Text('Trainy')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: workouts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final w = workouts[i];
          return Card(
            child: ListTile(
              title: Text(w.name),
              subtitle: Text(
                w.description.isEmpty ? 'Keine Beschreibung' : w.description,
              ),
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkoutScreen(workout: w),
                    ),
                  ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createWorkout(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
