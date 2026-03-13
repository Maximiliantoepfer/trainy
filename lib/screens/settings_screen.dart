import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/cloud_sync_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/workout_provider.dart';
import '../widgets/active_workout_banner.dart';
import '../providers/active_workout_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = context.watch<ThemeProvider>();
    final scheme = Theme.of(context).colorScheme;
    final progress = context.watch<ProgressProvider>();
    final weeklyGoal = progress.weeklyGoal.clamp(1, 7);
    final isActive = context.watch<ActiveWorkoutProvider>().isActive;

    Future<void> pickAccent() async {
      Color temp = theme.accent;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.palette_rounded, size: 28, color: scheme.primary),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: temp,
              onColorChanged: (c) => temp = c,
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                theme.setAccent(temp);
              },
              child: const Icon(Icons.check_rounded),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: isActive
                ? const ActiveWorkoutBanner()
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                // Theme mode
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.brightness_6_rounded,
                                size: 20, color: scheme.primary),
                            const SizedBox(width: 10),
                            Text('Darstellung',
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.auto_mode_rounded),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_rounded),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_rounded),
                            ),
                          ],
                          selected: {theme.themeMode},
                          onSelectionChanged: (v) =>
                              theme.setThemeMode(v.first),
                        ),
                        const SizedBox(height: 16),
                        // Color swatches + pick button
                        Row(
                          children: [
                            for (final c in _quickSwatches) ...[
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => theme.setAccent(c),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: c,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: c == theme.accent
                                          ? Border.all(
                                              color: scheme.onSurface,
                                              width: 2.5)
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: IconButton.filled(
                                onPressed: pickAccent,
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                    Icons.colorize_rounded,
                                    size: 18),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Weekly goal
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.flag_rounded,
                                size: 20, color: scheme.primary),
                            const SizedBox(width: 10),
                            Text('Wochenziel',
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: List.generate(
                            7,
                            (i) => ButtonSegment(
                              value: i + 1,
                              label: Text('${i + 1}'),
                            ),
                          ),
                          selected: {weeklyGoal},
                          onSelectionChanged: (v) {
                            final goal = v.first.clamp(1, 7);
                            context
                                .read<ProgressProvider>()
                                .setWeeklyGoal(goal);
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Cloud backup
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Consumer<CloudSyncProvider>(
                      builder: (context, sync, _) {
                        if (!sync.isSignedIn) {
                          return _CloudSignedOut(sync: sync);
                        }
                        return _CloudSignedIn(sync: sync);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudSignedOut extends StatelessWidget {
  final CloudSyncProvider sync;
  const _CloudSignedOut({required this.sync});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cloud_outlined, size: 20, color: scheme.primary),
            const SizedBox(width: 10),
            Text('Cloud-Backup',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: sync.isBusy
                ? null
                : () async {
                    try {
                      final cloud = context.read<CloudSyncProvider>();
                      await cloud.signInWithGoogle();
                      if (!context.mounted) return;

                      final exists = await cloud.remoteBackupExists();
                      if (exists) {
                        final choice = await showDialog<String>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            icon: Icon(Icons.cloud_done_rounded,
                                size: 32, color: scheme.primary),
                            content: const Text(
                              'Ein vorhandenes Cloud-Backup wurde gefunden.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, 'cancel'),
                                child: const Text('Abbrechen'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, 'merge'),
                                child: const Text('Zusammenführen'),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, 'load'),
                                child: const Text('Backup laden'),
                              ),
                            ],
                          ),
                        );

                        if (choice == 'load') {
                          try {
                            await cloud.restoreNow();
                            if (!context.mounted) return;
                            await context
                                .read<ExerciseProvider>()
                                .loadExercises();
                            await context
                                .read<WorkoutProvider>()
                                .loadWorkouts();
                            await context
                                .read<ProgressProvider>()
                                .loadData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Backup geladen')),
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Fehler: $e')),
                              );
                            }
                          }
                        } else if (choice == 'merge') {
                          try {
                            await cloud.mergeFromCloud();
                            if (!context.mounted) return;
                            await context
                                .read<ExerciseProvider>()
                                .loadExercises();
                            await context
                                .read<WorkoutProvider>()
                                .loadWorkouts();
                            await context
                                .read<ProgressProvider>()
                                .loadData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Mit Cloud zusammengeführt')),
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Fehler: $e')),
                              );
                            }
                          }
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Anmeldung erfolgreich')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Anmeldung fehlgeschlagen: $e')),
                        );
                      }
                    }
                  },
            icon: const Icon(Icons.login_rounded),
            label: const Text('Google'),
          ),
        ),
      ],
    );
  }
}

class _CloudSignedIn extends StatelessWidget {
  final CloudSyncProvider sync;
  const _CloudSignedIn({required this.sync});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final email = sync.user?.email ?? '';
    final lastSync = sync.lastSyncMillis > 0
        ? DateTime.fromMillisecondsSinceEpoch(sync.lastSyncMillis)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cloud_done_rounded, size: 20, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Cloud-Backup',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            // Auto-backup toggle
            Switch(
              value: sync.syncEnabled,
              onChanged: (v) async {
                await context.read<CloudSyncProvider>().setSyncEnabled(v);
              },
            ),
          ],
        ),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(email,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withOpacity(0.6))),
          ),
        ],
        if (lastSync != null) ...[
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 12,
                    color: scheme.onSurfaceVariant.withOpacity(0.4)),
                const SizedBox(width: 4),
                Text(
                  '${lastSync.toLocal().day.toString().padLeft(2, '0')}.'
                  '${lastSync.toLocal().month.toString().padLeft(2, '0')}. '
                  '${lastSync.toLocal().hour.toString().padLeft(2, '0')}:'
                  '${lastSync.toLocal().minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withOpacity(0.4)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: sync.isBusy
                    ? null
                    : () async {
                        try {
                          await context
                              .read<CloudSyncProvider>()
                              .backupNow();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Backup hochgeladen')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Fehler: $e')),
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                label: const Icon(Icons.arrow_upward_rounded, size: 16),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: sync.isBusy
                    ? null
                    : () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            icon: Icon(Icons.cloud_download_rounded,
                                size: 32, color: scheme.primary),
                            content: const Text(
                              'Dies ersetzt deine lokalen Daten mit dem Cloud-Backup.',
                            ),
                            actions: [
                              OutlinedButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, false),
                                child: const Text('Abbrechen'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, true),
                                child: const Icon(Icons.check_rounded),
                              ),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        try {
                          await context
                              .read<CloudSyncProvider>()
                              .restoreNow();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Backup wiederhergestellt')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Fehler: $e')),
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.cloud_download_rounded, size: 18),
                label: const Icon(Icons.arrow_downward_rounded, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: sync.isBusy
                ? null
                : () => context.read<CloudSyncProvider>().signOut(),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Abmelden'),
          ),
        ),
      ],
    );
  }
}

const _quickSwatches = <Color>[
  Color.fromARGB(255, 80, 127, 255),
  Color.fromARGB(255, 14, 199, 255),
  Color(0xFF00C853),
  Color(0xFFD81B60),
  Color(0xFF9C27B0),
  Color(0xFFF44336),
];
