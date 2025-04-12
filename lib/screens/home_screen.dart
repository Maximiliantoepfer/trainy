import 'package:flutter/material.dart';
import '../widgets/workout_card.dart'; // Erstelle diese Datei im nächsten Schritt
import '../models/workout.dart';

class HomeScreen extends StatelessWidget {
  // Temporäre Daten für Workouts
  final List<Workout> workouts = [
    Workout(id: 1, name: 'Beintraining', exercises: []),
    Workout(id: 2, name: 'Oberkörpertraining', exercises: []),
    // Füge hier weitere Workouts hinzu
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('trainy')),
      body: ListView.builder(
        itemCount: workouts.length,
        itemBuilder: (context, index) {
          return WorkoutCard(workout: workouts[index]);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Funktion zum Erstellen eines neuen Workouts
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
