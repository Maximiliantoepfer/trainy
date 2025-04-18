import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainy/models/workout.dart';
import 'package:trainy/providers/workout_provider.dart';
import 'package:trainy/screens/workout_screen.dart';
import 'package:trainy/widgets/workout_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Workouts beim Start laden
    Future.microtask(
      () => Provider.of<WorkoutProvider>(context, listen: false).loadWorkouts(),
    );
  }

  Future<void> _createWorkout(BuildContext context) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final newWorkout = Workout(
      id: id,
      name: 'Neues Workout',
      description: '',
      exercises: [],
    );

    final provider = Provider.of<WorkoutProvider>(context, listen: false);
    await provider.addWorkout(newWorkout);

    // Nach dem Hinzufügen direkt zum Workout navigieren
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutScreen(workout: newWorkout),
      ),
    );

    // Nach Rückkehr ggf. erneut laden (optional)
    await provider.loadWorkouts();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, workoutProvider, child) {
        final workouts = workoutProvider.workouts;

        return Scaffold(
          appBar: AppBar(title: Text('Workouts')),
          body:
              workoutProvider.isLoading
                  ? Center(child: CircularProgressIndicator())
                  : workouts.isEmpty
                  ? Center(child: Text('Keine Workouts gefunden.'))
                  : ListView.builder(
                    itemCount: workouts.length,
                    itemBuilder: (context, index) {
                      final workout = workouts[index];
                      return WorkoutCard(
                        workout: workout,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => WorkoutScreen(workout: workout),
                            ),
                          );
                          await workoutProvider.loadWorkouts();
                        },
                      );
                    },
                  ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Theme.of(context).colorScheme.primary,
            onPressed: () => _createWorkout(context),
            child: Icon(Icons.add),
          ),
        );
      },
    );
  }
}
