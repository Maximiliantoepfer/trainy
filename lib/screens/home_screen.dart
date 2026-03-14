import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../providers/workout_provider.dart';
import '../providers/cloud_sync_provider.dart';
import '../providers/progress_provider.dart';
import '../widgets/workout_card.dart';
import 'workout_screen.dart';
import '../widgets/active_workout_banner.dart';
import '../providers/active_workout_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  int? _selectedWorkoutId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<WorkoutProvider>().loadWorkouts();
      context.read<ProgressProvider>().loadData();
    });
  }

  Future<void> _createWorkout(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final provider = context.read<WorkoutProvider>();

    String? name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neues Workout'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Workout-Name',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Bitte Namen eingeben';
              return null;
            },
            onFieldSubmitted: (_) {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );

    if (name == null) return;

    final w = await provider.createWorkout(name: name);
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WorkoutScreen(workout: w)),
    );
    await provider.loadWorkouts();
    try { context.read<CloudSyncProvider>().scheduleBackupSoon(); } catch (_) {}
  }

  Future<void> _confirmAndDelete(Workout workout) async {
    final provider = context.read<WorkoutProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Workout löschen?'),
        content: Text('„${workout.name}" wird endgültig gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await provider.deleteWorkout(workout.id);
    if (!mounted) return;

    setState(() => _selectedWorkoutId = null);
    try { context.read<CloudSyncProvider>().scheduleBackupSoon(); } catch (_) {}
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('„${workout.name}" gelöscht')),
    );
  }

  void _openWorkout(Workout workout) async {
    if (_selectedWorkoutId != null) {
      setState(() => _selectedWorkoutId = null);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WorkoutScreen(workout: workout)),
    );
    if (!mounted) return;
    await context.read<WorkoutProvider>().loadWorkouts();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<WorkoutProvider>();
    final workouts = provider.workouts;
    final active = context.watch<ActiveWorkoutProvider>();

    final progress = context.watch<ProgressProvider>();
    final trainedWeekdays = _trainedWeekdaysThisWeek(progress.entries);
    final weeklyGoal = progress.weeklyGoal.clamp(1, 7);
    final isProgressLoading = progress.isLoading;

    return PopScope(
      canPop: _selectedWorkoutId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedWorkoutId != null) {
          setState(() => _selectedWorkoutId = null);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workouts'),
          actions: [
            IconButton(
              onPressed: () => _createWorkout(context),
              icon: Icon(Icons.add_rounded,
                color: Theme.of(context).colorScheme.primary),
              tooltip: 'Neues Workout',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _createWorkout(context),
          child: const Icon(Icons.add_rounded),
        ),
        body: Column(
          children: [
            // Active workout banner
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: active.isActive
                  ? const ActiveWorkoutBanner()
                  : const SizedBox.shrink(),
            ),

            // Weekly overview
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: _WeeklyOverviewCard(
                trainedWeekdays: isProgressLoading ? const {} : trainedWeekdays,
                weeklyGoal: weeklyGoal,
              ),
            ),

            // Workout list
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : workouts.isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                          itemCount: workouts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final w = workouts[i];
                            final selected = w.id == _selectedWorkoutId;
                            return WorkoutCard(
                              workout: w,
                              selected: selected,
                              onTap: () => _openWorkout(w),
                              onLongPress: () {
                                setState(() => _selectedWorkoutId =
                                    selected ? null : w.id);
                              },
                              onPrimaryActionTap: () {
                                if (selected) {
                                  _confirmAndDelete(w);
                                } else {
                                  _openWorkout(w);
                                }
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Set<int> _trainedWeekdaysThisWeek(List entries) {
    if (entries.isEmpty) return {};
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final start = DateTime(monday.year, monday.month, monday.day);
    final endExclusive = start.add(const Duration(days: 7));

    final set = <int>{};
    for (final e in entries) {
      final DateTime d = e.date;
      if (!d.isBefore(start) && d.isBefore(endExclusive)) {
        set.add(d.weekday);
      }
    }
    return set;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.fitness_center_rounded,
                size: 32, color: scheme.primary),
            ),
            const SizedBox(height: 20),
            Text('Noch keine Workouts',
              style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Erstelle dein erstes Workout\nmit dem Plus-Button.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Weekly overview ---

class _WeeklyOverviewCard extends StatelessWidget {
  final Set<int> trainedWeekdays;
  final int weeklyGoal;
  const _WeeklyOverviewCard({
    required this.trainedWeekdays,
    required this.weeklyGoal,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final doneCount = trainedWeekdays.length;
    final progress = weeklyGoal > 0 ? (doneCount / weeklyGoal).clamp(0.0, 1.0) : 0.0;

    const labels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Diese Woche',
                  style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: doneCount >= weeklyGoal
                        ? const Color(0xFF4CAF50).withOpacity(0.12)
                        : scheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$doneCount / $weeklyGoal',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: doneCount >= weeklyGoal
                          ? const Color(0xFF4CAF50)
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: scheme.surfaceContainerHighest.withOpacity(0.5),
                valueColor: AlwaysStoppedAnimation(
                  doneCount >= weeklyGoal
                      ? const Color(0xFF4CAF50)
                      : scheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final weekday = i + 1;
                final done = trainedWeekdays.contains(weekday);
                return _DayDot(label: labels[i], done: done);
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final String label;
  final bool done;
  const _DayDot({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const doneColor = Color(0xFF4CAF50);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: done ? doneColor : scheme.surfaceContainerHighest.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
