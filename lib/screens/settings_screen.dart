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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final scheme = Theme.of(context).colorScheme;
    final progress = context.watch<ProgressProvider>();
    final weeklyGoal = progress.weeklyGoal.clamp(1, 7);
    final active = context.watch<ActiveWorkoutProvider>();

    Future<void> _pickAccent() async {
      Color temp = theme.accent;
      await showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Akzentfarbe wählen'),
              content: SingleChildScrollView(
                child: BlockPicker(
                  pickerColor: temp,
                  onColorChanged: (c) => temp = c,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    theme.setAccent(temp);
                  },
                  child: const Text('Übernehmen'),
                ),
              ],
            ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        bottom: active.isActive
            ? const PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: ActiveWorkoutBanner(),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Darstellung
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Darstellung',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.auto_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Hell'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dunkel'),
                        icon: Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {theme.themeMode},
                    onSelectionChanged: (v) => theme.setThemeMode(v.first),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Akzentfarbe'),
                    subtitle: Text(
                      '#${theme.accent.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: FilledButton.icon(
                      onPressed: _pickAccent,
                      icon: const Icon(Icons.palette_outlined),
                      label: const Text('Ändern'),
                    ),
                    onTap: _pickAccent,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in _quickSwatches)
                          InkWell(
                            onTap: () => theme.setAccent(c),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      c == theme.accent
                                          ? scheme.primary
                                          : scheme.outlineVariant,
                                  width: c == theme.accent ? 3 : 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Ziele
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ziele', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Text(
                    'Trainingstage pro Woche',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 1, label: Text('1x')),
                      ButtonSegment(value: 2, label: Text('2x')),
                      ButtonSegment(value: 3, label: Text('3x')),
                      ButtonSegment(value: 4, label: Text('4x')),
                      ButtonSegment(value: 5, label: Text('5x')),
                      ButtonSegment(value: 6, label: Text('6x')),
                      ButtonSegment(value: 7, label: Text('7x')),
                    ],
                    selected: {weeklyGoal},
                    onSelectionChanged: (v) {
                      final goal = v.first.clamp(1, 7);
                      context.read<ProgressProvider>().setWeeklyGoal(goal);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Cloud-Backup
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Consumer<CloudSyncProvider>(
                builder: (context, sync, _) {
                  final onSurfaceVar =
                      Theme.of(context).colorScheme.onSurfaceVariant;

                  if (!sync.isSignedIn) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cloud-Backup',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Melde dich mit Google an, um deine Trainingsdaten sicher in der Cloud zu sichern oder wiederherzustellen.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: onSurfaceVar),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: sync.isBusy
                              ? null
                              : () async {
                                  try {
                                    final cloud = context.read<CloudSyncProvider>();
                                    await cloud.signInWithGoogle();
                                    if (!context.mounted) return;

                                    // After login: if backup exists, offer safe choices
                                    final exists = await cloud.remoteBackupExists();
                                    if (exists) {
                                      final choice = await showDialog<String>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Cloud-Backup gefunden'),
                                          content: const Text(
                                            'Ein vorhandenes Cloud-Backup wurde gefunden. Wie moechtest du fortfahren?'
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, 'cancel'),
                                              child: const Text('Abbrechen'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.pop(ctx, 'merge'),
                                              child: const Text('Zusammenfuehren (empfohlen)'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, 'load'),
                                              child: const Text('Backup laden'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (choice == 'load') {
                                        try {
                                          await cloud.restoreNow();
                                          if (!context.mounted) return;
                                          // Reload views
                                          await context.read<ExerciseProvider>().loadExercises();
                                          await context.read<WorkoutProvider>().loadWorkouts();
                                          await context.read<ProgressProvider>().loadData();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Backup geladen')),
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
                                          await context.read<ExerciseProvider>().loadExercises();
                                          await context.read<WorkoutProvider>().loadWorkouts();
                                          await context.read<ProgressProvider>().loadData();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Mit Cloud zusammengefuehrt')),
                                          );
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Fehler: $e')),
                                            );
                                          }
                                        }
                                      } else if (choice == 'cancel') {
                                        // No-op
                                      } else {
                                        // Fallback path: offer to overwrite cloud (double confirm)
                                        final overwrite = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx2) => AlertDialog(
                                            title: const Text('Cloud ueberschreiben?'),
                                            content: const Text('Alle alten Daten des Cloud-Backups gehen verloren. Fortfahren?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx2, false),
                                                child: const Text('Abbrechen'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.pop(ctx2, true),
                                                child: const Text('Ja, ueberschreiben'),
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
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Fehler: $e')),
                                              );
                                            }
                                          }
                                        }
                                      }
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Anmeldung erfolgreich')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Anmeldung fehlgeschlagen: $e')),
                                      );
                                    }
                                  }
                                },
                          icon: const Icon(Icons.login),
                          label: const Text('Mit Google anmelden'),
                        ),
                      ],
                    );
                  }

                  final email = sync.user?.email ?? 'angemeldet';
                  final lastSync =
                      sync.lastSyncMillis > 0
                          ? DateTime.fromMillisecondsSinceEpoch(
                            sync.lastSyncMillis,
                          )
                          : null;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cloud-Backup',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Angemeldet: $email',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: onSurfaceVar),
                      ),
                      if (lastSync != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Letzte Sicherung: ${lastSync.toLocal()}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: onSurfaceVar),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Automatische Sicherung'),
                        subtitle: Text(
                          'Sichert spätestens alle 2 Stunden automatisch – beim App-Start, nach Pause/Fortsetzen und in Intervallen.',
                          style: TextStyle(color: onSurfaceVar),
                        ),
                        value: sync.syncEnabled,
                        onChanged: (v) async {
                          await context
                              .read<CloudSyncProvider>()
                              .setSyncEnabled(v);
                          if (v && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Automatische Sicherung aktiviert',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed:
                                  sync.isBusy
                                      ? null
                                      : () async {
                                        try {
                                          await context
                                              .read<CloudSyncProvider>()
                                              .backupNow();
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Backup hochgeladen',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text('Fehler: $e'),
                                              ),
                                            );
                                          }
                                        }
                                      },
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: const Text('Jetzt sichern'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  sync.isBusy
                                      ? null
                                      : () async {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder:
                                              (ctx) => AlertDialog(
                                                title: const Text(
                                                  'Aus Cloud wiederherstellen?',
                                                ),
                                                content: const Text(
                                                  'Dies ersetzt deine lokalen Daten mit dem Cloud-Backup. Fortfahren?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          ctx,
                                                          false,
                                                        ),
                                                    child: const Text(
                                                      'Abbrechen',
                                                    ),
                                                  ),
                                                  FilledButton(
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          ctx,
                                                          true,
                                                        ),
                                                    child: const Text(
                                                      'Ja, wiederherstellen',
                                                    ),
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
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Backup wiederhergestellt',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text('Fehler: $e'),
                                              ),
                                            );
                                          }
                                        }
                                      },
                              icon: const Icon(Icons.cloud_download_outlined),
                              label: const Text('Aus Cloud laden'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed:
                            sync.isBusy
                                ? null
                                : () =>
                                    context.read<CloudSyncProvider>().signOut(),
                        icon: const Icon(Icons.logout),
                        label: const Text('Abmelden'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _quickSwatches = <Color>[
  Color.fromARGB(255, 59, 111, 255),
  Color.fromARGB(255, 14, 199, 255),
  Color(0xFF00C853),
  Color(0xFFD81B60),
  Color(0xFF9C27B0),
  Color(0xFFF44336),
];
