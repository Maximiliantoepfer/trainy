import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainy/providers/theme_provider.dart';
import 'package:trainy/screens/settings_screen.dart';
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
      appBar: AppBar(
        title: Text('trainy'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: workouts.length,
        itemBuilder: (context, index) {
          return WorkoutCard(workout: workouts[index]);
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Provider.of<ThemeProvider>(context).getAccentColor(),
        onPressed: () {
          // Funktion zum Erstellen eines neuen Workouts
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
