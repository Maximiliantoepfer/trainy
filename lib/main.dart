import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/theme_provider.dart';
import 'themes/app_theme.dart';

import 'providers/exercise_provider.dart';
import 'providers/workout_provider.dart';
import 'providers/progress_provider.dart';
import 'providers/cloud_sync_provider.dart';
import 'navigation/main_navigation.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TrainyApp());
}

class TrainyApp extends StatelessWidget {
  const TrainyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => ExerciseProvider()..loadExercises(),
        ),
        ChangeNotifierProvider(
          create: (_) => WorkoutProvider()..loadWorkouts(),
        ),
        ChangeNotifierProvider(create: (_) => ProgressProvider()),
        ChangeNotifierProvider(create: (_) => CloudSyncProvider()),
      ],
      child: const _ThemedApp(),
    );
  }
}

class _ThemedApp extends StatelessWidget {
  const _ThemedApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(theme.accent),
      darkTheme: AppTheme.dark(theme.accent),
      themeMode: theme.themeMode,
      // ⬇️ Reagiert auf App-Lebenszyklus (Resume etc.) und triggert Auto-Backup falls nötig
      home: const _AppLifecycleReactor(child: MainNavigation()),
    );
  }
}

class _AppLifecycleReactor extends StatefulWidget {
  final Widget child;
  const _AppLifecycleReactor({super.key, required this.child});

  @override
  State<_AppLifecycleReactor> createState() => _AppLifecycleReactorState();
}

class _AppLifecycleReactorState extends State<_AppLifecycleReactor>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Direkt nach dem ersten Build einmal prüfen (App-Start)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sync = context.read<CloudSyncProvider>();
      sync.maybeAutoBackup(reason: 'app_start');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Bei RESUME prüfen wir, ob ein Auto-Backup fällig ist
    if (state == AppLifecycleState.resumed) {
      final sync = context.read<CloudSyncProvider>();
      sync.onAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
