import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainy/screens/exercise_screen.dart';
import 'package:trainy/screens/home_screen.dart';
import '../providers/theme_provider.dart';
import 'settings_screen.dart';
import 'home_screen.dart';
import 'exercise_screen.dart';

class MainNavigation extends StatefulWidget {
  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 1; // Home ist die Mitte (Index 1)

  final List<Widget> _screens = [
    ExerciseScreen(), // Index 0 – links
    HomeScreen(), // Index 1 – Mitte
    SettingsScreen(), // Index 2 – rechts
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Provider.of<ThemeProvider>(context).getAccentColor();

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: accentColor,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Exercises'),
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
