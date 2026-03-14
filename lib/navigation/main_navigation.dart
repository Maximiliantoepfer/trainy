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

  late final _pages = [
    const HomeScreen(),
    const ExerciseScreen(),
    ProgressScreen(
      onSwipePastStart: () => _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic),
      onSwipePastEnd: () => _pageController.animateToPage(3, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic),
    ),
    const SettingsScreen(),
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
        physics: const ClampingScrollPhysics(),
        onPageChanged: (i) => setState(() => _index = i),
        children: _pages,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Theme(
            data: Theme.of(context).copyWith(
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              hoverColor: Colors.transparent,
            ),
            child: NavigationBar(
              selectedIndex: _index,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
              onDestinationSelected: (i) {
                if (i == _index) return;
                _pageController.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              },
              destinations: [
                NavigationDestination(
                  icon: ImageIcon(AssetImage('assets/icons/web-house.png'), size: 26),
                  selectedIcon: ImageIcon(AssetImage('assets/icons/web-house.png'), size: 26),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: ImageIcon(AssetImage('assets/icons/hantel.png'), size: 26),
                  selectedIcon: ImageIcon(AssetImage('assets/icons/hantel.png'), size: 26),
                  label: 'Übungen',
                ),
                NavigationDestination(
                  icon: ImageIcon(AssetImage('assets/icons/diagramm.png'), size: 26),
                  selectedIcon: ImageIcon(AssetImage('assets/icons/diagramm.png'), size: 26),
                  label: 'Fortschritt',
                ),
                NavigationDestination(
                  icon: ImageIcon(AssetImage('assets/icons/die-einstellungen.png'), size: 26),
                  selectedIcon: ImageIcon(AssetImage('assets/icons/die-einstellungen.png'), size: 26),
                  label: 'Mehr',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
