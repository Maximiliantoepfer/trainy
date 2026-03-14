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
    final active = context.watch<ActiveWorkoutProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: active.isActive
                ? const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: ActiveWorkoutBanner(),
                  )
                : const SizedBox.shrink(),
          ),

          // --- Appearance ---
          _SectionHeader(title: 'Darstellung'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Design-Modus',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('System')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Hell')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dunkel')),
                    ],
                    selected: {theme.themeMode},
                    onSelectionChanged: (v) => theme.setThemeMode(v.first),
                  ),
                  const SizedBox(height: 20),
                  Text('Akzentfarbe',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in _quickSwatches)
                        _ColorDot(
                          color: c,
                          isSelected: c.value == theme.accent.value,
                          onTap: () => theme.setAccent(c),
                        ),
                      _ColorDot(
                        color: theme.accent,
                        isSelected: false,
                        isCustom: true,
                        onTap: () => _pickAccent(context, theme),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // --- Goals ---
          _SectionHeader(title: 'Wochenziel'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trainingstage pro Woche',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: List.generate(7, (i) =>
                        ButtonSegment(value: i + 1, label: Text('${i + 1}'))),
                    selected: {weeklyGoal},
                    onSelectionChanged: (v) =>
                        context.read<ProgressProvider>().setWeeklyGoal(v.first.clamp(1, 7)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // --- Cloud ---
          _SectionHeader(title: 'Cloud-Backup'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Consumer<CloudSyncProvider>(
                builder: (context, sync, _) {
                  if (!sync.isSignedIn) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sichere deine Daten in der Cloud.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: sync.isBusy ? null : () => _signIn(context),
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('Mit Google anmelden'),
                          ),
                        ),
                      ],
                    );
                  }

                  final email = sync.user?.email ?? 'angemeldet';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cloud_done_outlined, size: 20,
                              color: scheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(email,
                                style: Theme.of(context).textTheme.bodyMedium),
                          ),
                        ],
                      ),
                      if (sync.lastSyncMillis > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Letzte Sicherung: ${_formatSync(sync.lastSyncMillis)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: Text('Auto-Backup',
                              style: Theme.of(context).textTheme.bodyMedium)),
                          Switch(
                            value: sync.syncEnabled,
                            onChanged: (v) async {
                              await context.read<CloudSyncProvider>().setSyncEnabled(v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: FilledButton.icon(
                            onPressed: sync.isBusy ? null : () => _backup(context),
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text('Sichern'),
                          )),
                          const SizedBox(width: 10),
                          Expanded(child: OutlinedButton.icon(
                            onPressed: sync.isBusy ? null : () => _restore(context),
                            icon: const Icon(Icons.cloud_download_outlined),
                            label: const Text('Laden'),
                          )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: sync.isBusy ? null : () =>
                              context.read<CloudSyncProvider>().signOut(),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Abmelden'),
                        ),
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

  Future<void> _pickAccent(BuildContext context, ThemeProvider theme) async {
    Color temp = theme.accent;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Akzentfarbe'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: temp,
            onColorChanged: (c) => temp = c,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(onPressed: () { Navigator.pop(ctx); theme.setAccent(temp); },
              child: const Text('Übernehmen')),
        ],
      ),
    );
  }

  Future<void> _signIn(BuildContext context) async {
    try {
      final cloud = context.read<CloudSyncProvider>();
      await cloud.signInWithGoogle();
      if (!context.mounted) return;

      final exists = await cloud.remoteBackupExists();
      if (exists) {
        final choice = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cloud-Backup gefunden'),
            content: const Text('Ein vorhandenes Backup wurde gefunden.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Abbrechen')),
              FilledButton(onPressed: () => Navigator.pop(ctx, 'merge'), child: const Text('Zusammenführen')),
              TextButton(onPressed: () => Navigator.pop(ctx, 'load'), child: const Text('Backup laden')),
            ],
          ),
        );

        if (choice == 'load') {
          try {
            await cloud.restoreNow();
            if (!context.mounted) return;
            await _reloadAll(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup geladen')));
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
          }
        } else if (choice == 'merge') {
          try {
            await cloud.mergeFromCloud();
            if (!context.mounted) return;
            await _reloadAll(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zusammengeführt')));
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anmeldung erfolgreich')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _backup(BuildContext context) async {
    try {
      await context.read<CloudSyncProvider>().backupNow();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup hochgeladen')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _restore(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wiederherstellen?'),
        content: const Text('Lokale Daten werden durch das Cloud-Backup ersetzt.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Wiederherstellen')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context.read<CloudSyncProvider>().restoreNow();
      if (context.mounted) {
        await _reloadAll(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wiederhergestellt')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _reloadAll(BuildContext context) async {
    await context.read<ExerciseProvider>().loadExercises();
    await context.read<WorkoutProvider>().loadWorkouts();
    await context.read<ProgressProvider>().loadData();
  }

  String _formatSync(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          )),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final bool isCustom;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.isCustom = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isCustom ? null : color,
          gradient: isCustom
              ? LinearGradient(colors: [
                  Colors.red, Colors.orange, Colors.yellow,
                  Colors.green, Colors.blue, Colors.purple,
                ])
              : null,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.5)
              : Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4)),
        ),
        child: isCustom
            ? const Icon(Icons.palette_rounded, size: 18, color: Colors.white)
            : isSelected
                ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                : null,
      ),
    );
  }
}

const _quickSwatches = <Color>[
  Color(0xFF4776F8),
  Color(0xFF0EC7FF),
  Color(0xFF4CAF50),
  Color(0xFFE91E63),
  Color(0xFF9C27B0),
  Color(0xFFFF5722),
];
