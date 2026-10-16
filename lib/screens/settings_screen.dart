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
import '../providers/data_lifecycle_provider.dart';
import '../widgets/language_preference_picker.dart';
import '../repositories/training_profile_repository.dart';
import '../l10n/l10n.dart';
import '../widgets/training_profile_settings_card.dart';
import '../utils/goal_utils.dart';
import 'weekly_planner_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  late final TrainingProfileRepository _trainingProfiles =
      TrainingProfileRepository();

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
                          isSelected: c.toARGB32() == theme.accent.toARGB32(),
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
          TrainingProfileSettingsCard(store: _trainingProfiles),

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
                            onPressed: sync.isBusy ? null : _signIn,
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
                                onPressed: sync.isBusy ? null : _backup,
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
                                onPressed: sync.isBusy ? null : _restore,
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

          const SizedBox(height: 24),
          _SectionHeader(title: l10n.dataAndPrivacy),
          const SizedBox(height: 12),
          Card(
            child: Consumer<CloudSyncProvider>(
              builder:
                  (context, sync, _) => Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.restart_alt_rounded),
                        title: Text(l10n.resetLocalTrainingData),
                        subtitle: Text(l10n.resetLocalTrainingDataDescription),
                        enabled:
                            !sync.isBusy &&
                            !context.watch<DataLifecycleProvider>().isBusy,
                        onTap: _resetLocalData,
                      ),
                      if (sync.isSignedIn) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.cloud_off_outlined),
                          title: Text(l10n.deleteCloudData),
                          subtitle: Text(l10n.deleteCloudDataDescription),
                          enabled: !sync.isBusy,
                          onTap: _deleteCloudData,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            Icons.person_remove_outlined,
                            color: scheme.error,
                          ),
                          title: Text(
                            l10n.deleteAccountAndData,
                            style: TextStyle(color: scheme.error),
                          ),
                          subtitle: Text(l10n.deleteAccountAndDataDescription),
                          enabled: !sync.isBusy,
                          onTap: _deleteAccountAndData,
                        ),
                      ],
                    ],
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

  Future<void> _signIn() async {
    try {
      final cloud = context.read<CloudSyncProvider>();
      await cloud.signInWithGoogle();
      if (!context.mounted) return;

      final exists = await cloud.remoteBackupExists();
      if (!mounted) return;
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
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'load'),
                    child: Text(ctx.l10n.loadBackup),
                  ),
                ],
              ),
        );
        if (!mounted) return;

        if (choice == 'load') {
          try {
            await cloud.restoreNow();
            if (!mounted) return;
            await _reloadAll();
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(context.l10n.backupLoaded)));
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.genericError)),
              );
            }
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.signedInSuccessfully)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
      }
    }
  }

  Future<void> _backup() async {
    final cloud = context.read<CloudSyncProvider>();
    try {
      await cloud.backupNow();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.backupUploaded)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
      }
    }
  }

  Future<void> _restore() async {
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
    if (!mounted) return;
    if (ok != true) return;
    final cloud = context.read<CloudSyncProvider>();
    try {
      await cloud.restoreNow();
      if (mounted) {
        await _reloadAll();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.backupRestoredSuccess)),
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

  Future<bool> _discardActiveWorkoutIfNeeded() async {
    final active = context.read<ActiveWorkoutProvider>();
    if (!active.isActive) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(dialogContext.l10n.activeWorkoutMustEnd),
            content: Text(dialogContext.l10n.activeWorkoutMustEndDescription),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(dialogContext.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(dialogContext.l10n.discardAndContinue),
              ),
            ],
          ),
    );
    if (discard == true) active.clear();
    return discard == true;
  }

  Future<bool> _confirmTwice({
    required String firstTitle,
    required String firstBody,
    required String secondTitle,
    required String secondBody,
    required String actionLabel,
    bool destructive = false,
  }) async {
    Future<bool?> ask(String title, String body, bool finalStep) =>
        showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: Text(title),
                content: Text(body),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(dialogContext.l10n.cancel),
                  ),
                  FilledButton(
                    style:
                        destructive
                            ? FilledButton.styleFrom(
                              backgroundColor:
                                  Theme.of(dialogContext).colorScheme.error,
                            )
                            : null,
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(
                      finalStep
                          ? actionLabel
                          : dialogContext.l10n.continueLabel,
                    ),
                  ),
                ],
              ),
        );
    if (await ask(firstTitle, firstBody, false) != true || !mounted) {
      return false;
    }
    return await ask(secondTitle, secondBody, true) == true;
  }

  Future<void> _resetLocalData() async {
    if (!await _discardActiveWorkoutIfNeeded() || !mounted) return;
    final confirmed = await _confirmTwice(
      firstTitle: context.l10n.resetLocalTrainingData,
      firstBody: context.l10n.resetLocalTrainingDataConfirm,
      secondTitle: context.l10n.confirmResetAgain,
      secondBody: context.l10n.confirmResetAgainDescription,
      actionLabel: context.l10n.resetNow,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await context.read<DataLifecycleProvider>().resetLocalTrainingData();
  }

  Future<void> _deleteCloudData() async {
    final confirmed = await _confirmTwice(
      firstTitle: context.l10n.deleteCloudData,
      firstBody: context.l10n.deleteCloudDataConfirm,
      secondTitle: context.l10n.confirmCloudDeleteAgain,
      secondBody: context.l10n.confirmCloudDeleteAgainDescription,
      actionLabel: context.l10n.deletePermanently,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await context.read<CloudSyncProvider>().deleteCloudData();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.cloudDataDeleted)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
      }
    }
  }

  Future<void> _deleteAccountAndData() async {
    if (!await _discardActiveWorkoutIfNeeded() || !mounted) return;
    final confirmed = await _confirmTwice(
      firstTitle: context.l10n.deleteAccountAndData,
      firstBody: context.l10n.deleteAccountAndDataConfirm,
      secondTitle: context.l10n.confirmAccountDeleteAgain,
      secondBody: context.l10n.confirmAccountDeleteAgainDescription,
      actionLabel: context.l10n.deletePermanently,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final cloud = context.read<CloudSyncProvider>();
    final lifecycle = context.read<DataLifecycleProvider>();
    try {
      await cloud.deleteAccountAndAllData();
      lifecycle.notifyDataWasReplaced();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
      }
    }
  }

  Future<void> _reloadAll() async {
    final exercises = context.read<ExerciseProvider>();
    final workouts = context.read<WorkoutProvider>();
    final progress = context.read<ProgressProvider>();
    await exercises.loadExercises();
    await workouts.loadWorkouts();
    await progress.loadData();
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
                        ).colorScheme.outlineVariant.withValues(alpha: 0.4),
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
    final workoutProvider = context.watch<WorkoutProvider>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  context.l10n.trainingPlan,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WeeklyPlannerScreen()),
                  ),
                  child: Text(context.l10n.editWeeklyPlanner),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(7, (i) {
              final day = i + 1;
              final assignedWorkouts =
                  workoutProvider.workoutsForDay(day);

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
                          color: assignedWorkouts.isNotEmpty
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child:
                          assignedWorkouts.isNotEmpty
                              ? Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final w in assignedWorkouts.take(2))
                                    Chip(
                                      avatar: GoalIcon(w.primaryGoalCode, size: 15),
                                      label: Text(w.name),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  if (assignedWorkouts.length > 2)
                                    Chip(label: Text('+${assignedWorkouts.length - 2}')),
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
