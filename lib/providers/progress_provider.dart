// lib/providers/progress_provider.dart
import 'package:flutter/material.dart';
import '../models/workout_entry.dart';
import '../services/workout_entry_database.dart';
import '../services/settings_database.dart';

class ProgressProvider extends ChangeNotifier {
  List<WorkoutEntry> _entries = [];
  int _weeklyGoal = 2;
  bool _isLoading = true;

  List<WorkoutEntry> get entries => _entries;
  int get weeklyGoal => _weeklyGoal;
  bool get isLoading => _isLoading;

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    // Settings (Weekly Goal) laden
    _weeklyGoal = await SettingsDatabase.instance.getWeeklyGoal();

    // Einträge laden
    _entries = await WorkoutEntryDatabase.instance.getAllEntries();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setWeeklyGoal(int goal) async {
    _weeklyGoal = goal;
    await SettingsDatabase.instance.setWeeklyGoal(goal);
    notifyListeners();
  }

  Future<void> refreshEntries() async {
    _entries = await WorkoutEntryDatabase.instance.getAllEntries();
    notifyListeners();
  }

  /// Kompatibler Hook nach einem gespeicherten Workout.
  Future<void> addWorkout({Duration? duration}) async {
    await refreshEntries();
  }
}
