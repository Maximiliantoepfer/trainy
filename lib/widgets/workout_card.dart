import 'package:flutter/material.dart';
import 'package:trainy/utils/utils.dart';
import '../models/workout.dart';
import '../screens/workout_screen.dart';

class WorkoutCard extends StatelessWidget {
  final Workout workout;

  WorkoutCard({required this.workout, required Future<Null> Function() onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: ListTile(
        title: Text(
          workout.name,
          style: TextStyle(color: getTextColor(context)),
        ),
        subtitle: Text(
          workout.description,
          style: TextStyle(color: getTextColor(context)),
        ),
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
