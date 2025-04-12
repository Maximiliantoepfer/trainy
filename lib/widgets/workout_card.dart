import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../screens/workout_screen.dart';

class WorkoutCard extends StatelessWidget {
  final Workout workout;

  WorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(workout.name),
        // Hier können weitere Details des Workouts angezeigt werden
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WorkoutScreen(workout: workout),
            ),
          );
        },
        // Hier können weitere Details des Workouts angezeigt werden
      ),
    );
  }
}
