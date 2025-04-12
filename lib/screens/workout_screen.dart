import 'package:flutter/material.dart';
import '../models/workout.dart';

class WorkoutScreen extends StatelessWidget {
  final Workout workout;

  WorkoutScreen({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(workout.name)),
      body: Center(
        child: Text('Übungen für ${workout.name} werden hier angezeigt.'),
      ),
    );
  }
}
