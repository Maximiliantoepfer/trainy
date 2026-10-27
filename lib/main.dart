import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/theme_provider.dart';
import 'themes/app_theme.dart';

import 'providers/exercise_provider.dart';
import 'providers/workout_provider.dart';
import 'providers/training_profile_provider.dart';
import 'providers/progress_provider.dart';
import 'providers/cloud_sync_provider.dart';
import 'providers/active_workout_provider.dart';
import 'providers/cardio_provider.dart';
import 'providers/training_program_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/data_lifecycle_provider.dart';
import 'l10n/l10n.dart';
import 'navigation/main_navigation.dart';
import 'widgets/onboarding_gate.dart';
import 'widgets/data_recovery_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'services/data_lifecycle_coordinator.dart';
import 'services/data_operation.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final startup = await DataLifecycleCoordinator.instance.ensureReady();
  // Firebase is optional storage, but its SDK must be initialized before a
  // recovery retry can rebuild the normal provider tree. Initializing it does
  // not read remote data and therefore does not weaken the local-first flow.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (startup.isReady &&
      await DataLifecycleCoordinator.instance.hasPendingAccountDeletion()) {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      try {
        await current.reload();
      } on FirebaseAuthException catch (error) {
        if (error.code == 'user-not-found' || error.code == 'user-disabled') {
          await FirebaseAuth.instance.signOut();
        }
      }
    }
  }
  if (startup.isReady) {
    await DataLifecycleCoordinator.instance
        .completePendingAccountDeletionIfNeeded(
          isSignedIn: FirebaseAuth.instance.currentUser != null,
        );
  }
  await initializeDateFormatting();
  runApp(TrainyApp(initialStartupResult: startup));
}

class TrainyApp extends StatelessWidget {
  const TrainyApp({super.key, required this.initialStartupResult});

  final DataStartupResult initialStartupResult;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()..init()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create:
              (_) => DataLifecycleProvider(initialResult: initialStartupResult),
        ),
      ],
      child: const _DataProviders(),
    );
  }
}

class _DataProviders extends StatelessWidget {
  const _DataProviders();

  @override
  Widget build(BuildContext context) {
    final lifecycle = context.watch<DataLifecycleProvider>();
    if (lifecycle.needsRecovery) {
      return const _ThemedApp(home: DataRecoveryScreen());
    }
    final generation = lifecycle.generation;
    return MultiProvider(
      key: ValueKey(generation),
      providers: [
        ChangeNotifierProvider(
          create: (_) => TrainingProfileProvider()..reload(),
        ),
        ChangeNotifierProvider(
          create: (_) => ExerciseProvider()..loadExercises(),
        ),
        ChangeNotifierProvider(
          create: (_) => WorkoutProvider()..loadWorkouts(),
        ),
        ChangeNotifierProvider(create: (_) => ProgressProvider()),
        ChangeNotifierProvider(
          create: (_) => TrainingProgramProvider()..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => CardioProvider()..initialize(),
          lazy: false,
        ),
        ChangeNotifierProvider(create: (_) => CloudSyncProvider()),
        ChangeNotifierProvider(
          create: (_) => ActiveWorkoutProvider()..restorePersistedWorkout(),
        ),
      ],
      child: const _ThemedApp(),
    );
  }
}

class _ThemedApp extends StatelessWidget {
  const _ThemedApp({this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final locale = context.watch<LocaleProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder:
          (context, child) => AnimatedBuilder(
            animation: DataOperation.instance,
            builder:
                (context, _) => Stack(
                  children: [
                    AbsorbPointer(
                      absorbing: DataOperation.instance.blocksInteraction,
                      child: child,
                    ),
                    if (DataOperation.instance.isBusy)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(child: LinearProgressIndicator()),
                      ),
                  ],
                ),
          ),
      onGenerateTitle: (context) => context.l10n.appName,
      theme: AppTheme.light(theme.accent),
      darkTheme: AppTheme.dark(theme.accent),
      themeMode: theme.themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale.localeOverride,
      localeResolutionCallback: resolveAppLocale,
      home:
          home ??
          const OnboardingGate(
            child: _AppLifecycleReactor(child: MainNavigation()),
          ),
    );
  }
}

/// Reagiert auf App-Start & -Resume und triggert ggf. Auto-Backup.
class _AppLifecycleReactor extends StatefulWidget {
  final Widget child;
  const _AppLifecycleReactor({required this.child});

  @override
  State<_AppLifecycleReactor> createState() => _AppLifecycleReactorState();
}

class _AppLifecycleReactorState extends State<_AppLifecycleReactor>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CloudSyncProvider>().maybeAutoBackup(reason: 'app_start');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<CloudSyncProvider>().onAppResumed();
      unawaited(context.read<CardioProvider>().load());
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
