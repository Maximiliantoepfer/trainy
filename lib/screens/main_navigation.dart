import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainy/screens/exercise_screen.dart';
import 'package:trainy/screens/home_screen.dart';
import 'package:trainy/screens/settings_screen.dart';
import 'package:trainy/screens/progress_screen.dart';
import '../providers/theme_provider.dart';

final GlobalKey<NavigatorState> _exerciseNavigatorKey =
    GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _progressNavigatorKey =
    GlobalKey<NavigatorState>();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        key: _progressNavigatorKey,
        onGenerateRoute:
            (settings) => _onGenerateRoute(settings, ProgressScreen()),
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
        iconSize: 28,
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: accentColor,
        unselectedItemColor: isDark ? Colors.white70 : Colors.black54,
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
                _progressNavigatorKey.currentState?.popUntil(
                  (route) => route.isFirst,
                );
                break;
              case 3:
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
            icon: Icon(Icons.fitness_center_outlined),
            label: 'Exercises',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart_outlined),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
