import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_database.dart';
import '../providers/cloud_sync_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/progress_provider.dart';
import '../l10n/l10n.dart';

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
    if (done || !mounted) return;

    await _runOnboarding();
    await SettingsDatabase.instance.setOnboardingDone(true);
  }

  Future<void> _runOnboarding() async {
    final cloud = context.read<CloudSyncProvider>();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder:
          (ctx) => AlertDialog(
            title: Text(ctx.l10n.setUpCloudBackup),
            content: Text(ctx.l10n.setUpCloudBackupDescription),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'skip'),
                child: Text(ctx.l10n.continueWithoutCloud),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, 'login'),
                icon: const Icon(Icons.login),
                label: Text(ctx.l10n.signInWithGoogle),
              ),
            ],
          ),
    );
    if (!mounted) return;

    if (result != 'login') return;

    try {
      await cloud.signInWithGoogle();
    } catch (_) {
      return; // Abbruch, Nutzer kann später in den Einstellungen anmelden
    }

    if (!mounted) return;
    final exists = await cloud.remoteBackupExists();
    if (!exists) return; // kein Backup vorhanden, fertig
    if (!mounted) return;

    final choice = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(ctx.l10n.cloudBackupFound),
            content: Text(ctx.l10n.cloudBackupAccountFoundDescription),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'skip'),
                child: Text(ctx.l10n.doNotLoad),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'load'),
                child: Text(ctx.l10n.loadAndReplace),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, 'merge'),
                child: Text(ctx.l10n.mergeRecommended),
              ),
            ],
          ),
    );
    if (!mounted) return;

    if (choice == 'merge') {
      try {
        await cloud.mergeFromCloud();
        if (!mounted) return;
        await _reloadProviders();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.merged)));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
        }
      }
    } else if (choice == 'load') {
      try {
        await cloud.restoreNow();
        if (!mounted) return;
        await _reloadProviders();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.backupLoaded)));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
        }
      }
    } else if (choice == 'skip') {
      // Sicherheitsabfrage: Cloud berschreiben?
      final overwrite = await showDialog<bool>(
        context: context,
        builder:
            (ctx2) => AlertDialog(
              title: Text(ctx2.l10n.cloudOverwrite),
              content: Text(ctx2.l10n.cloudOverwriteDescription),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2, false),
                  child: Text(ctx2.l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx2, true),
                  child: Text(ctx2.l10n.overwrite),
                ),
              ],
            ),
      );
      if (!mounted) return;
      if (overwrite == true) {
        try {
          await cloud.backupNow();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.cloudBackupUpdated)),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
          }
        }
      }
    }
  }

  Future<void> _reloadProviders() async {
    final exercises = context.read<ExerciseProvider>();
    final workouts = context.read<WorkoutProvider>();
    final progress = context.read<ProgressProvider>();
    await exercises.loadExercises();
    await workouts.loadWorkouts();
    await progress.loadData();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
