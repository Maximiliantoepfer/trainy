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

  @override
  Widget build(BuildContext context) {
    final pages = const [
      HomeScreen(),
      ExerciseScreen(),
      ProgressScreen(),
      SettingsScreen(),
    ];

    // Lokales Theme ohne Ripple/Highlights (kompatibel, ohne InkWellThemeData)
    final theme = Theme.of(context);
    final navTheme = theme.copyWith(
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      navigationBarTheme: theme.navigationBarTheme.copyWith(
        // Sicherheitshalber auch hier: KEIN Indicator/Highlight
        indicatorColor: Colors.transparent,
      ),
    );

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: Theme(
        data: navTheme,
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),

          // Labels aus (nur Icons)
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,

          // Hintergrund & Icon-Styles kommen aus dem Theme
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center),
              label: 'Exercises',
            ),
            NavigationDestination(
              icon: Icon(Icons.show_chart_outlined),
              selectedIcon: Icon(Icons.show_chart),
              label: 'Progress',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
