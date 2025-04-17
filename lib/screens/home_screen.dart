// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:trainy/models/workout.dart';
import 'package:trainy/screens/workout_screen.dart';
import 'package:trainy/services/workout_database.dart';
import 'package:trainy/widgets/workout_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Workout> workouts = [];

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    final data = await WorkoutDatabase.instance.getAllWorkouts();
    setState(() {
      workouts = data;
    });
  }

  Future<void> _createWorkout() async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final newWorkout = Workout(
      id: id,
      name: 'Neues Workout',
      description: '',
      exercises: [],
    );
    await WorkoutDatabase.instance.insertWorkout(newWorkout);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutScreen(workout: newWorkout),
      ),
    ).then((_) => _loadWorkouts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Workouts')),
      body:
          workouts.isEmpty
              ? Center(child: Text('Keine Workouts gefunden.'))
              : ListView.builder(
                itemCount: workouts.length,
                itemBuilder: (context, index) {
                  return WorkoutCard(
                    workout: workouts[index],
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  WorkoutScreen(workout: workouts[index]),
                        ),
                      );
                      _loadWorkouts();
                    },
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        onPressed: _createWorkout,
        child: Icon(Icons.add),
      ),
    );
  }
}
