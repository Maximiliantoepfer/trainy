import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_database.dart';
import '../providers/cloud_sync_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/progress_provider.dart';

class OnboardingGate extends StatefulWidget {
  final Widget child;
  const OnboardingGate({super.key, required this.child});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowOnboarding());
  }

  Future<void> _maybeShowOnboarding() async {
    if (!mounted || _checked) return;
    _checked = true;
    final done = await SettingsDatabase.instance.getOnboardingDone();
    if (done) return;

    await _runOnboarding(context);
    await SettingsDatabase.instance.setOnboardingDone(true);
  }

  Future<void> _runOnboarding(BuildContext context) async {
    final cloud = context.read<CloudSyncProvider>();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Cloud-Backup einrichten?'),
            content: const Text(
              'Du kannst dich anmelden, um deine Trainingsdaten sicher in der Cloud zu sichern und zwischen Geräten zu synchronisieren. Das ist optional (Local-First).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'skip'),
                child: const Text('Ohne Cloud fortfahren'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, 'login'),
                icon: const Icon(Icons.login),
                label: const Text('Mit Google anmelden'),
              ),
            ],
          ),
    );

    if (result != 'login') return;

    try {
      await cloud.signInWithGoogle();
    } catch (_) {
      return; // Abbruch, Nutzer kann später in den Einstellungen anmelden
    }

    if (!context.mounted) return;
    final exists = await cloud.remoteBackupExists();
    if (!exists) return; // kein Backup vorhanden, fertig

    final choice = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Cloud-Backup gefunden'),
            content: const Text(
              'Es gibt bereits ein Cloud-Backup für diesen Account. Wie möchtest du fortfahren?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'skip'),
                child: const Text('Nicht laden'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'load'),
                child: const Text('Backup laden (ersetzen)'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, 'merge'),
                child: const Text('Zusammenführen (empfohlen)'),
              ),
            ],
          ),
    );

    if (choice == 'merge') {
      try {
        await cloud.mergeFromCloud();
        if (!context.mounted) return;
        await _reloadProviders(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mit Cloud zusammengefhrt')),
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
        }
      }
    } else if (choice == 'load') {
      try {
        await cloud.restoreNow();
        if (!context.mounted) return;
        await _reloadProviders(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Backup geladen')));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
        }
      }
    } else if (choice == 'skip') {
      // Sicherheitsabfrage: Cloud berschreiben?
      final overwrite = await showDialog<bool>(
        context: context,
        builder:
            (ctx2) => AlertDialog(
              title: const Text('Cloud berschreiben?'),
              content: const Text(
                'Alle alten Daten des Cloud-Backups gehen verloren. Fortfahren?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2, false),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx2, true),
                  child: const Text('Ja, berschreiben'),
                ),
              ],
            ),
      );
      if (overwrite == true) {
        try {
          await cloud.backupNow();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cloud-Backup aktualisiert')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
          }
        }
      }
    }
  }

  Future<void> _reloadProviders(BuildContext context) async {
    await context.read<ExerciseProvider>().loadExercises();
    await context.read<WorkoutProvider>().loadWorkouts();
    await context.read<ProgressProvider>().loadData();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
