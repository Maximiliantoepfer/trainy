import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/workout_provider.dart';
import 'providers/exercise_provider.dart';
import 'screens/main_navigation.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExerciseProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'trainy',
          theme: themeProvider.getTheme().copyWith(
            colorScheme: themeProvider.getTheme().colorScheme.copyWith(
              primary: themeProvider.getAccentColor(),
            ),
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
          ),
          home: MainNavigation(),
        );
      },
    );
  }
}
