import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainy/models/workout.dart';
import 'package:trainy/providers/workout_provider.dart';
import 'package:trainy/screens/workout_screen.dart';
import 'package:trainy/widgets/app_title.dart';
import 'package:trainy/widgets/workout_card.dart';
import 'package:trainy/widgets/weekly_activity_chart.dart';
import 'package:trainy/providers/progress_provider.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<int> _selectedWorkoutIds = {};
  bool get _selectionMode => _selectedWorkoutIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<WorkoutProvider>(context, listen: false).loadWorkouts();
      Provider.of<ProgressProvider>(context, listen: false).loadData();
    });
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

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutScreen(workout: newWorkout),
      ),
    );

    await provider.loadWorkouts();
  }

  void _toggleSelection(Workout workout) {
    setState(() {
      if (_selectedWorkoutIds.contains(workout.id)) {
        _selectedWorkoutIds.remove(workout.id);
      } else {
        _selectedWorkoutIds.add(workout.id);
      }
    });
  }

  Future<void> _deleteSelected(BuildContext context) async {
    final provider = Provider.of<WorkoutProvider>(context, listen: false);
    for (var id in _selectedWorkoutIds) {
      await provider.deleteWorkout(id);
    }
    setState(() {
      _selectedWorkoutIds.clear();
    });
    await provider.loadWorkouts();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<WorkoutProvider, ProgressProvider>(
      builder: (context, workoutProvider, progressProvider, child) {
        final workouts = workoutProvider.workouts;

        final now = DateTime.now();
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final formatter = DateFormat('yyyy-MM-dd');
        final trainedDays =
            progressProvider.entries
                .where(
                  (e) =>
                      e.date.isAfter(monday.subtract(const Duration(days: 1))),
                )
                .map((e) => formatter.format(e.date))
                .toSet();
        final trainingsDieseWoche = trainedDays.length;

        return Scaffold(
          // Keine klassische AppBar mehr!
          body:
              workoutProvider.isLoading || progressProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : workouts.isEmpty
                  ? const Center(child: Text('Keine Workouts gefunden.'))
                  : SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        /// Falls Auswahl aktiv ist, zeige statische Auswahl-Leiste
                        if (_selectionMode)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_selectedWorkoutIds.length} ausgewählt',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder:
                                            (ctx) => AlertDialog(
                                              title: const Text(
                                                'Ausgewählte löschen?',
                                              ),
                                              content: const Text(
                                                'Möchtest du die ausgewählten Workouts wirklich löschen?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.of(
                                                        ctx,
                                                      ).pop(false),
                                                  child: const Text(
                                                    'Abbrechen',
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.of(
                                                        ctx,
                                                      ).pop(true),
                                                  child: const Text('Löschen'),
                                                ),
                                              ],
                                            ),
                                      );
                                      if (confirmed == true) {
                                        await _deleteSelected(context);
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed:
                                        () => setState(
                                          () => _selectedWorkoutIds.clear(),
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                        /// Dynamischer freundlicher Header
                        if (!_selectionMode)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppTitle("Training", emoji: '🎯'),
                          ),

                        WeeklyActivityChart(
                          trainedDays: trainedDays,
                          monday: monday,
                          weeklyGoal: progressProvider.weeklyGoal,
                          trainingsDieseWoche: trainingsDieseWoche,
                          onGoalChanged: (newGoal) {
                            progressProvider.setWeeklyGoal(newGoal);
                          },
                        ),

                        const SizedBox(height: 16),

                        ...workouts.map((workout) {
                          final isSelected = _selectedWorkoutIds.contains(
                            workout.id,
                          );
                          return GestureDetector(
                            onLongPress: () => _toggleSelection(workout),
                            child: Opacity(
                              opacity: isSelected ? 0.6 : 1.0,
                              child: Stack(
                                children: [
                                  WorkoutCard(
                                    workout: workout,
                                    onTap: () async {
                                      if (_selectionMode) {
                                        _toggleSelection(workout);
                                      } else {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => WorkoutScreen(
                                                  workout: workout,
                                                ),
                                          ),
                                        );
                                        await workoutProvider.loadWorkouts();
                                      }
                                    },
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Icon(
                                        Icons.check_circle,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.secondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
          floatingActionButton:
              _selectionMode
                  ? null
                  : FloatingActionButton(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    onPressed: () => _createWorkout(context),
                    child: const Icon(Icons.add),
                  ),
        );
      },
    );
  }
}
