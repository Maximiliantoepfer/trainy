import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/cloud_sync_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/workout_provider.dart';
import '../widgets/active_workout_banner.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/screen_info_dialog.dart';
import '../providers/active_workout_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/language_preference_picker.dart';
import '../models/workout_plan.dart';
import '../services/workout_plan_database.dart';
import '../l10n/l10n.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

const _profileEquipmentCodes = <String>[
  'bodyweight',
  'dumbbell',
  'barbell',
  'machine',
  'cable',
  'kettlebell',
  'bands',
];

class _NewTrainingProfile {
  const _NewTrainingProfile(this.name, this.equipmentCodes);

  final String name;
  final Set<String> equipmentCodes;
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _addTrainingProfile() async {
    final controller = TextEditingController();
    final selectedEquipment = <String>{};
    final result = await showDialog<_NewTrainingProfile>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  title: Text(ctx.l10n.trainingProfile),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: controller,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: ctx.l10n.profileName,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          ctx.l10n.equipment,
                          style: Theme.of(ctx).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final code in _profileEquipmentCodes)
                              FilterChip(
                                label: Text(_equipmentLabel(ctx, code)),
                                selected: selectedEquipment.contains(code),
                                onSelected:
                                    (selected) => setDialogState(() {
                                      if (selected) {
                                        selectedEquipment.add(code);
                                      } else {
                                        selectedEquipment.remove(code);
                                      }
                                    }),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(ctx.l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () {
                        final name = controller.text.trim();
                        if (name.isNotEmpty) {
                          Navigator.pop(
                            ctx,
                            _NewTrainingProfile(
                              name,
                              Set<String>.from(selectedEquipment),
                            ),
                          );
                        }
                      },
                      child: Text(ctx.l10n.add),
                    ),
                  ],
                ),
          ),
    );
    controller.dispose();
    if (result == null) return;
    final current = await WorkoutPlanDatabase.instance.profiles();
    await WorkoutPlanDatabase.instance.saveProfile(
      TrainingProfile(
        id: DateTime.now().microsecondsSinceEpoch,
        name: result.name,
        equipmentCodes: result.equipmentCodes.toList(),
        sort: current.length,
      ),
    );
    if (mounted) setState(() {});
  }

  String _equipmentLabel(BuildContext context, String code) => switch (code) {
    'bodyweight' => context.l10n.equipmentBodyweight,
    'dumbbell' => context.l10n.equipmentDumbbell,
    'barbell' => context.l10n.equipmentBarbell,
    'machine' => context.l10n.equipmentMachine,
    'cable' => context.l10n.equipmentCable,
    'kettlebell' => context.l10n.equipmentKettlebell,
    'bands' => context.l10n.equipmentBands,
    _ => code,
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = context.watch<ThemeProvider>();
    final scheme = Theme.of(context).colorScheme;
    final progress = context.watch<ProgressProvider>();
    final weeklyGoal = progress.weeklyGoal.clamp(1, 7);
    final active = context.watch<ActiveWorkoutProvider>();
    final locale = context.watch<LocaleProvider>();
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(l10n.settings),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, size: 20),
            onPressed:
                () => showScreenInfoDialog(
                  context,
                  title: l10n.settings,
                  description: l10n.settingsDescription,
                ),
            tooltip: l10n.info,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child:
                active.isActive
                    ? const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: ActiveWorkoutBanner(),
                    )
                    : const SizedBox.shrink(),
          ),

          // --- Appearance ---
          _SectionHeader(title: l10n.appearance),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.designMode,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(l10n.system),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(l10n.light),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(l10n.dark),
                      ),
                    ],
                    selected: {theme.themeMode},
                    onSelectionChanged: (v) {
                      final newMode = v.first;
                      theme.setThemeMode(newMode);
                      final brightness = _effectiveBrightness(context, newMode);
                      if (theme.hasContrastProblem(brightness)) {
                        _showContrastWarning(context, theme);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.accentColor,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.language,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LanguagePreferencePicker(
                    preference: locale.preference,
                    onChanged: context.read<LocaleProvider>().setPreference,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          _SectionHeader(title: l10n.trainingProfile),
          const SizedBox(height: 12),
          Card(
            child: FutureBuilder<List<TrainingProfile>>(
              future: WorkoutPlanDatabase.instance.profiles(),
              builder:
                  (context, snapshot) => ListTile(
                    leading: const Icon(Icons.fitness_center_rounded),
                    title: Text(l10n.trainingProfile),
                    subtitle: Text(
                      snapshot.hasData && snapshot.data!.isNotEmpty
                          ? snapshot.data!
                              .map((profile) => profile.name)
                              .join(' · ')
                          : l10n.noProfiles,
                    ),
                    trailing: IconButton(
                      tooltip: l10n.add,
                      onPressed: _addTrainingProfile,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ),
            ),
          ),

          const SizedBox(height: 24),

          // --- Goals ---
          _SectionHeader(title: l10n.weeklyGoal),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.trainingDaysPerWeek,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: List.generate(
                      7,
                      (i) =>
                          ButtonSegment(value: i + 1, label: Text('${i + 1}')),
                    ),
                    selected: {weeklyGoal},
                    onSelectionChanged:
                        (v) => context.read<ProgressProvider>().setWeeklyGoal(
                          v.first.clamp(1, 7),
                        ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.trainingDays,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TrainingDaysPicker(
                    selected:
                        progress.trainingDays.isEmpty
                            ? progress.effectiveTrainingDays
                            : progress.trainingDays,
                    onChanged:
                        (days) => context
                            .read<ProgressProvider>()
                            .setTrainingDays(days),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          _WorkoutScheduleCard(),

          const SizedBox(height: 24),

          // --- Cloud ---
          _SectionHeader(title: l10n.cloudBackup),
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
                          context.l10n.cloudBackupDescription,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                sync.isBusy ? null : () => _signIn(context),
                            icon: const Icon(Icons.login_rounded),
                            label: Text(l10n.signInWithGoogle),
                          ),
                        ),
                      ],
                    );
                  }

                  final email = sync.user?.email ?? context.l10n.signedIn;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.cloud_done_outlined,
                            size: 20,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              email,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      if (sync.lastSyncMillis > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.lastBackup(
                            _formatSync(context, sync.lastSyncMillis),
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.automaticBackup,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Switch(
                            value: sync.syncEnabled,
                            onChanged: (v) async {
                              await context
                                  .read<CloudSyncProvider>()
                                  .setSyncEnabled(v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                onPressed:
                                    sync.isBusy ? null : () => _backup(context),
                                icon: const Icon(Icons.cloud_upload_outlined),
                                label: Text(l10n.backUp),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed:
                                    sync.isBusy
                                        ? null
                                        : () => _restore(context),
                                icon: const Icon(Icons.cloud_download_outlined),
                                label: Text(l10n.load),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed:
                              sync.isBusy
                                  ? null
                                  : () =>
                                      context
                                          .read<CloudSyncProvider>()
                                          .signOut(),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: Text(l10n.signOut),
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
    final brightness = _effectiveBrightness(context, theme.themeMode);
    final colors = <Color>[
      ..._universalColors,
      if (brightness == Brightness.light) ..._lightOnlyColors,
      if (brightness == Brightness.dark) ..._darkOnlyColors,
    ];
    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(ctx.l10n.accentColor),
            content: SingleChildScrollView(
              child: BlockPicker(
                pickerColor: temp,
                onColorChanged: (c) => temp = c,
                availableColors: colors,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ctx.l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  theme.setAccent(temp);
                },
                child: Text(ctx.l10n.apply),
              ),
            ],
          ),
    );
  }

  void _showContrastWarning(BuildContext context, ThemeProvider theme) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.lowContrast),
        action: SnackBarAction(
          label: context.l10n.change,
          onPressed: () => _pickAccent(context, theme),
        ),
        duration: const Duration(seconds: 5),
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
          builder:
              (ctx) => AlertDialog(
                title: Text(ctx.l10n.cloudBackupFound),
                content: Text(ctx.l10n.cloudBackupFoundDescription),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'cancel'),
                    child: Text(ctx.l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, 'merge'),
                    child: Text(ctx.l10n.merge),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'load'),
                    child: Text(ctx.l10n.loadBackup),
                  ),
                ],
              ),
        );

        if (choice == 'load') {
          try {
            await cloud.restoreNow();
            if (!context.mounted) return;
            await _reloadAll(context);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(context.l10n.backupLoaded)));
          } catch (e) {
            if (context.mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.genericError)),
              );
          }
        } else if (choice == 'merge') {
          try {
            await cloud.mergeFromCloud();
            if (!context.mounted) return;
            await _reloadAll(context);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(context.l10n.merged)));
          } catch (e) {
            if (context.mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.genericError)),
              );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.signedInSuccessfully)),
        );
      }
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
    }
  }

  Future<void> _backup(BuildContext context) async {
    try {
      await context.read<CloudSyncProvider>().backupNow();
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.backupUploaded)));
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
    }
  }

  Future<void> _restore(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(ctx.l10n.restoreBackup),
            content: Text(ctx.l10n.restoreBackupDescription),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.l10n.restore),
              ),
            ],
          ),
    );
    if (ok != true) return;
    try {
      await context.read<CloudSyncProvider>().restoreNow();
      if (context.mounted) {
        await _reloadAll(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.backupRestoredSuccess)),
        );
      }
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
    }
  }

  Future<void> _reloadAll(BuildContext context) async {
    await context.read<ExerciseProvider>().loadExercises();
    await context.read<WorkoutProvider>().loadWorkouts();
    await context.read<ProgressProvider>().loadData();
  }

  String _formatSync(BuildContext context, int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    return DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).add_Hm().format(d);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
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
      child: SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isCustom ? null : color,
              gradient:
                  isCustom
                      ? LinearGradient(
                        colors: [
                          Colors.red,
                          Colors.orange,
                          Colors.yellow,
                          Colors.green,
                          Colors.blue,
                          Colors.purple,
                        ],
                      )
                      : null,
              shape: BoxShape.circle,
              border:
                  isSelected
                      ? Border.all(
                        color: Theme.of(context).colorScheme.onSurface,
                        width: 2.5,
                      )
                      : Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withOpacity(0.4),
                      ),
            ),
            child:
                isCustom
                    ? const Icon(
                      Icons.palette_rounded,
                      size: 18,
                      color: Colors.white,
                    )
                    : isSelected
                    ? const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Colors.white,
                    )
                    : null,
          ),
        ),
      ),
    );
  }
}

class _WorkoutScheduleCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final workouts = context.watch<WorkoutProvider>().workouts;
    final progress = context.watch<ProgressProvider>();
    final trainingDays =
        progress.trainingDays.isEmpty
            ? progress.effectiveTrainingDays
            : progress.trainingDays;

    if (workouts.isEmpty) return const SizedBox.shrink();

    // Tage mit mindestens einem zugewiesenen Workout
    final workoutAssignedDays = <int>{};
    for (final w in workouts) {
      workoutAssignedDays.addAll(w.assignedDays);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.trainingPlan,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ...List.generate(7, (i) {
              final day = i + 1;
              final isTrainingDay = trainingDays.contains(day);
              final hasWorkoutAssigned = workoutAssignedDays.contains(day);
              final showChips = isTrainingDay || hasWorkoutAssigned;
              final assignedWorkouts =
                  workouts.where((w) => w.assignedDays.contains(day)).toList();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        [
                          context.l10n.monday,
                          context.l10n.tuesday,
                          context.l10n.wednesday,
                          context.l10n.thursday,
                          context.l10n.friday,
                          context.l10n.saturday,
                          context.l10n.sunday,
                        ][i],
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color:
                              showChips
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant.withValues(
                                    alpha: 0.4,
                                  ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child:
                          showChips
                              ? Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final w in workouts)
                                    FilterChip(
                                      label: Text(w.name),
                                      selected: assignedWorkouts.contains(w),
                                      onSelected: (_) {
                                        final current = Set<int>.from(
                                          w.assignedDays,
                                        );
                                        if (current.contains(day)) {
                                          current.remove(day);
                                        } else {
                                          current.add(day);
                                          // Auto-Sync: Tag zu globalen Trainingstagen hinzufügen
                                          if (!trainingDays.contains(day)) {
                                            final updatedDays = Set<int>.from(
                                              trainingDays,
                                            )..add(day);
                                            context
                                                .read<ProgressProvider>()
                                                .setTrainingDays(updatedDays);
                                          }
                                        }
                                        context
                                            .read<WorkoutProvider>()
                                            .setWorkoutDays(w.id, current);
                                        try {
                                          context
                                              .read<CloudSyncProvider>()
                                              .scheduleBackupSoon();
                                        } catch (_) {}
                                      },
                                      visualDensity: VisualDensity.compact,
                                      labelStyle:
                                          Theme.of(
                                            context,
                                          ).textTheme.labelSmall,
                                    ),
                                ],
                              )
                              : Text(
                                context.l10n.restDay,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TrainingDaysPicker extends StatelessWidget {
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  const _TrainingDaysPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = i + 1;
        final isSelected = selected.contains(day);
        return GestureDetector(
          onTap: () {
            final next = Set<int>.from(selected);
            if (isSelected) {
              next.remove(day);
            } else {
              next.add(day);
            }
            onChanged(next);
          },
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest.withOpacity(0.5),
                  shape: BoxShape.circle,
                  border:
                      isSelected
                          ? Border.all(color: scheme.primary, width: 1.5)
                          : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  [
                    context.l10n.monday,
                    context.l10n.tuesday,
                    context.l10n.wednesday,
                    context.l10n.thursday,
                    context.l10n.friday,
                    context.l10n.saturday,
                    context.l10n.sunday,
                  ][i],
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color:
                        isSelected ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

const _quickSwatches = <Color>[
  Color(0xFF5285FA),
  Color(0xFF0EC7FF),
  Color(0xFF4CAF50),
  Color(0xFFFF5722),
  Color(0xFFD32F2F),
  Color(0xFFE91E63),
  Color(0xFF9C27B0),
];

const _universalColors = <Color>[
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.blue,
  Colors.teal,
  Colors.deepOrange,
  Colors.blueGrey,
];

const _lightOnlyColors = <Color>[
  Colors.deepPurple,
  Colors.indigo,
  Color(0xFF000000),
];

const _darkOnlyColors = <Color>[
  Colors.lightBlue,
  Colors.cyan,
  Colors.green,
  Colors.lightGreen,
  Colors.lime,
  Colors.yellow,
  Colors.amber,
  Colors.orange,
  Color(0xFFFFFFFF),
];

Brightness _effectiveBrightness(BuildContext context, ThemeMode mode) {
  return switch (mode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system => MediaQuery.platformBrightnessOf(context),
  };
}
