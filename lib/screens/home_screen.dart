import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../providers/workout_provider.dart';
import '../widgets/workout_card.dart';
import 'workout_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _selectedWorkoutId;

  @override
  void initState() {
    super.initState();
    // Beim ersten Öffnen Workouts laden
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkoutProvider>().loadWorkouts();
    });
  }

  Future<void> _createWorkout(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final provider = context.read<WorkoutProvider>();

    String? name = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Neues Workout'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Workout-Namen eingeben',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Bitte Namen eingeben';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(ctx).pop(controller.text.trim());
                  }
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(ctx).pop(controller.text.trim());
                  }
                },
                child: const Text('Speichern'),
              ),
            ],
          ),
    );

    if (name == null) return;

    final w = await provider.createWorkout(name: name);
    if (!mounted) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => WorkoutScreen(workout: w)));
    await provider.loadWorkouts();
  }

  Future<void> _confirmAndDelete(Workout workout) async {
    final provider = context.read<WorkoutProvider>();
    final scheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Workout löschen?'),
            content: Text(
              '„${workout.name}“ wird endgültig gelöscht. Fortfahren?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(Colors.red),
                  foregroundColor: MaterialStateProperty.all<Color>(
                    Colors.white,
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Löschen'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    await provider.deleteWorkout(workout.id);
    if (!mounted) return;

    setState(() => _selectedWorkoutId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('„${workout.name}“ gelöscht'),
        backgroundColor: scheme.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openWorkout(Workout workout) async {
    if (_selectedWorkoutId != null) {
      // Wenn Auswahl aktiv: erst Auswahl aufheben statt navigieren
      setState(() => _selectedWorkoutId = null);
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => WorkoutScreen(workout: workout)));
    if (!mounted) return;
    await context.read<WorkoutProvider>().loadWorkouts();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final workouts = provider.workouts;

    return WillPopScope(
      onWillPop: () async {
        if (_selectedWorkoutId != null) {
          setState(() => _selectedWorkoutId = null);
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workouts'),
          actions: [
            IconButton(
              onPressed: () => _createWorkout(context),
              icon: const Icon(Icons.add),
              tooltip: 'Neues Workout',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _createWorkout(context),
          child: const Icon(Icons.add),
        ),
        body:
            provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : workouts.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: workouts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final w = workouts[i];
                    final selected = w.id == _selectedWorkoutId;

                    return WorkoutCard(
                      workout: w,
                      selected: selected,
                      onTap: () => _openWorkout(w),
                      onLongPress: () {
                        setState(
                          () => _selectedWorkoutId = selected ? null : w.id,
                        );
                      },
                      onPrimaryActionTap: () {
                        if (selected) {
                          _confirmAndDelete(w);
                        } else {
                          _openWorkout(w);
                        }
                      },
                    );
                  },
                ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center, size: 52),
            const SizedBox(height: 16),
            Text('Noch keine Workouts', style: text.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Erstelle dein erstes Workout mit dem Plus-Button.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
