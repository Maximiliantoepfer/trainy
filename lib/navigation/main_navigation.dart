import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/exercise_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/settings_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _index = 0;

  final _pages = const [
    HomeScreen(),
    ExerciseScreen(),
    ProgressScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],

      // Wichtig: Labels ausblenden und Ripple/Highlight lokal abschalten
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          // verhindert die „Hintergrunderleuchtung“ beim Tippen
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: NavigationBar(
          // Nur Icons, keine Labels
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,

          // Größen/Farben kommen aus dem NavigationBarTheme (app_theme.dart)
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),

          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Workouts', // wird dank alwaysHide nicht angezeigt
            ),
            NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center),
              label: 'Übungen',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Fortschritt',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Einstellungen',
            ),
          ],
        ),
      ),
    );
  }
}
