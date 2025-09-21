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
  late final PageController _pageController;

  final _pages = const [
    HomeScreen(),
    ExerciseScreen(),
    ProgressScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (i) => setState(() => _index = i),
        children: _pages,
      ),

      // Wichtig: Labels ausblenden und Ripple/Highlight lokal abschalten
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          // verhindert die â€žHintergrunderleuchtungâ€œ beim Tippen
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: NavigationBar(
          // Nur Icons, keine Labels
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,

          // GrÃ¶ÃŸen/Farben kommen aus dem NavigationBarTheme (app_theme.dart)
          selectedIndex: _index,
          onDestinationSelected: (i) {
            if (i == _index) return;
            _pageController.animateToPage(
              i,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
            );
          },

          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Workouts', // wird dank alwaysHide nicht angezeigt
            ),
            NavigationDestination(
              icon: Icon(Icons.fitness_center_rounded, fill: 0),
              selectedIcon: Icon(Icons.fitness_center_rounded, fill: 0),
              label: 'Ãœbungen',
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
