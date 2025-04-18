import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainy/screens/exercise_screen.dart';
import 'package:trainy/screens/home_screen.dart';
import 'package:trainy/screens/settings_screen.dart';
import '../providers/theme_provider.dart';

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
  int _selectedIndex = 1;

  Route<dynamic> _onGenerateRoute(
    RouteSettings settings,
    Widget initialScreen,
  ) {
    return MaterialPageRoute(
      builder: (context) => initialScreen,
      settings: settings,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Provider.of<ThemeProvider>(context).getAccentColor();

    final List<Widget> screens = [
      Navigator(
        key: _exerciseNavigatorKey,
        onGenerateRoute:
            (settings) => _onGenerateRoute(settings, const ExerciseScreen()),
      ),
      Navigator(
        key: _homeNavigatorKey,
        onGenerateRoute:
            (settings) => _onGenerateRoute(settings, const HomeScreen()),
      ),
      Navigator(
        key: _settingsNavigatorKey,
        onGenerateRoute:
            (settings) => _onGenerateRoute(settings, SettingsScreen()),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: accentColor,
        onTap: (index) {
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
            setState(() {
              _selectedIndex = index;
            });
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Exercises',
          ),
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
