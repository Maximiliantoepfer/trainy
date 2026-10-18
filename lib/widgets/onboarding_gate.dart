import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_database.dart';
import '../providers/cloud_sync_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/training_profile_provider.dart';
import '../models/training_profile.dart';
import '../screens/profile_onboarding_screen.dart';
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
    try {
      await _showOnboarding();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.genericError),
          duration: const Duration(seconds: 15),
          action: SnackBarAction(
            label: context.l10n.retry,
            onPressed: () {
              _checked = false;
              _maybeShowOnboarding();
            },
          ),
        ),
      );
    }
  }

  Future<void> _showOnboarding() async {
    final done = await SettingsDatabase.instance.getOnboardingDone();
    if (!mounted) return;
    if (!done) {
      try {
        await _runOnboarding();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
        }
      }
      await SettingsDatabase.instance.setOnboardingDone(true);
    }
    if (!mounted) return;
    final profiles = context.read<TrainingProfileProvider>();
    await profiles.reload();
    if (!mounted) return;
    if (profiles.error != null) throw profiles.error!;
    final required = profiles.onboardingState == ProfileSetupState.required;
    if (!required && profiles.onboardingState != ProfileSetupState.offer) {
      return;
    }
    if (!required) {
      final configure = await showDialog<bool>(
        context: context,
        builder:
            (c) => AlertDialog(
              title: Text(c.l10n.profileIntroTitle),
              content: Text(c.l10n.profileIntroBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(c.l10n.later),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(c.l10n.configure),
                ),
              ],
            ),
      );
      await profiles.dismissSetupOffer();
      if (configure != true || !mounted) return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) =>
                ProfileOnboardingScreen(profiles: profiles, required: required),
      ),
    );
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
            ],
          ),
    );
    if (!mounted) return;

    if (choice == 'load') {
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
    final profiles = context.read<TrainingProfileProvider>();
    final exercises = context.read<ExerciseProvider>();
    final workouts = context.read<WorkoutProvider>();
    final progress = context.read<ProgressProvider>();
    await profiles.reload();
    await exercises.loadExercises();
    await workouts.loadWorkouts();
    await progress.loadData();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
