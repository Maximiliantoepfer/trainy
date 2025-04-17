import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainy/screens/exercise_screen.dart';
import 'package:trainy/screens/home_screen.dart';
import 'package:trainy/screens/settings_screen.dart';
import 'package:trainy/screens/workout_screen.dart'; // Import WorkoutScreen if needed for routing
import 'package:trainy/screens/edit_exercise_in_workout_screen.dart'; // Import Edit screen if needed for routing

import '../providers/theme_provider.dart';

// Define keys for nested Navigators
final GlobalKey<NavigatorState> _exerciseNavigatorKey =
    GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _settingsNavigatorKey =
    GlobalKey<NavigatorState>();

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 1; // Home is the middle (Index 1)

  // Define route names for clarity (optional but good practice)
  static const String homeRoute = '/home';
  static const String exercisesRoute = '/exercises';
  static const String settingsRoute = '/settings';
  // Add routes for other screens if they should be navigable within a specific tab's Navigator
  // static const String workoutRoute = '/workout';
  // static const String editExerciseInWorkoutRoute = '/editExerciseInWorkout';

  // Function to generate routes for nested Navigators
  Route<dynamic> _onGenerateRoute(
    RouteSettings settings,
    Widget initialScreen,
  ) {
    // print("Nested route: ${settings.name}"); // For debugging
    Widget page;
    switch (settings.name) {
      // Add cases for other routes pushed within this tab's navigator
      // case workoutRoute:
      //   page = WorkoutScreen(workoutId: settings.arguments as String); // Example argument passing
      //   break;
      // case editExerciseInWorkoutRoute:
      //   page = EditExerciseInWorkoutScreen(exerciseInWorkout: settings.arguments as ExerciseInWorkout); // Example
      //   break;
      default: // Default route is the initial screen for the tab
        page = initialScreen;
    }
    return MaterialPageRoute(builder: (context) => page, settings: settings);
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Provider.of<ThemeProvider>(context).getAccentColor();

    // Define the nested Navigators for each tab
    final List<Widget> screens = [
      // Exercises Tab Navigator
      Navigator(
        key: _exerciseNavigatorKey,
        initialRoute: exercisesRoute, // Use initialRoute or onGenerateRoute
        onGenerateRoute:
            (settings) => _onGenerateRoute(settings, ExerciseScreen()),
      ),
      // Home Tab Navigator
      Navigator(
        key: _homeNavigatorKey,
        initialRoute: homeRoute, // Use initialRoute or onGenerateRoute
        onGenerateRoute: (settings) => _onGenerateRoute(settings, HomeScreen()),
      ),
      // Settings Tab Navigator
      Navigator(
        key: _settingsNavigatorKey,
        initialRoute: settingsRoute, // Use initialRoute or onGenerateRoute
        onGenerateRoute:
            (settings) => _onGenerateRoute(settings, SettingsScreen()),
      ),
    ];

    return Scaffold(
      // Use IndexedStack to keep the state of each tab's Navigator alive
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: accentColor,
        onTap: (index) {
          // If the user taps the *same* tab again, pop to the root of that tab's navigator
          if (index == _selectedIndex) {
            switch (index) {
              case 0:
                _exerciseNavigatorKey.currentState?.popUntil(
                  (route) => route.isFirst,
                );
                break;
              case 1:
                _homeNavigatorKey.currentState?.popUntil(
                  (route) => route.isFirst,
                );
                break;
              case 2:
                _settingsNavigatorKey.currentState?.popUntil(
                  (route) => route.isFirst,
                );
                break;
            }
          } else {
            // Otherwise, just switch the tab index
            setState(() {
              _selectedIndex = index;
            });
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Exercises',
          ), // Changed icon
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// Helper function (optional) to easily access the correct navigator based on context
// This might be useful if navigation calls become complex
// NavigatorState nestedNavigator(BuildContext context) {
//   return Navigator.of(context);
// }
