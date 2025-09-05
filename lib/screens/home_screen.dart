import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../providers/workout_provider.dart';
import 'workout_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _createWorkout(BuildContext context) async {
    final provider = context.read<WorkoutProvider>();

    String name = 'Neues Workout';
    await showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: name);
        return AlertDialog(
          title: const Text('Workout erstellen'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Workout-Name'),
            autofocus: true,
            onSubmitted: (_) => Navigator.of(ctx).pop(),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                name =
                    ctrl.text.trim().isEmpty
                        ? 'Neues Workout'
                        : ctrl.text.trim();
                Navigator.pop(ctx);
              },
              child: const Text('Erstellen'),
            ),
          ],
        );
      },
    );

    final w = await provider.createWorkout(name: name);

    if (context.mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => WorkoutScreen(workout: w)));
      await provider.loadWorkouts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final workouts = provider.workouts;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body:
          provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: workouts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final w = workouts[i];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.fitness_center,
                        color: accent,
                      ), // <— Akzentfarbe
                      title: Text(
                        w.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle:
                          w.exerciseIds.isEmpty
                              ? const Text('Noch keine Übungen')
                              : Text('${w.exerciseIds.length} Übung(en)'),
                      trailing: IconButton(
                        tooltip: 'Umbenennen',
                        icon: const Icon(Icons.edit),
                        onPressed: () => _renameWorkout(context, w),
                      ),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WorkoutScreen(workout: w),
                          ),
                        );
                        await provider.loadWorkouts();
                      },
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createWorkout(context),
        icon: const Icon(Icons.add),
        label: const Text('Workout'),
      ),
    );
  }

  Future<void> _renameWorkout(BuildContext context, Workout workout) async {
    String newName = workout.name;
    await showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: newName);
        return AlertDialog(
          title: const Text('Workout umbenennen'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Workout-Name'),
            autofocus: true,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                newName =
                    ctrl.text.trim().isEmpty ? workout.name : ctrl.text.trim();
                Navigator.pop(ctx);
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );

    await context.read<WorkoutProvider>().updateWorkoutName(
      workout.id,
      newName,
    );
  }
}
