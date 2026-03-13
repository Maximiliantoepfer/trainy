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
            decoration: const InputDecoration(hintText: 'Name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name eingeben' : null,
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
              child: const Text('Abbrechen')),
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
        title: const Text('Löschen?'),
        content: Text('„${workout.name}" wird entfernt.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Abbrechen')),
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
            ),
          ],
        ),
        body: Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: active.isActive
                  ? const ActiveWorkoutBanner()
                  : const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: _WeekStrip(
                trainedWeekdays: isProgressLoading ? const {} : trainedWeekdays,
                weeklyGoal: weeklyGoal,
              ),
            ),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : workouts.isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                          itemCount: workouts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
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
                                if (selected) _confirmAndDelete(w);
                                else _openWorkout(w);
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
      if (!d.isBefore(start) && d.isBefore(endExclusive)) set.add(d.weekday);
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
          const SizedBox(height: 16),
          Icon(Icons.add_rounded,
              size: 28, color: scheme.onSurfaceVariant.withOpacity(0.4)),
        ],
      ),
    );
  }
}

/// Compact weekly strip: 7 dots with progress bar. No text header.
class _WeekStrip extends StatelessWidget {
  final Set<int> trainedWeekdays;
  final int weeklyGoal;
  const _WeekStrip({required this.trainedWeekdays, required this.weeklyGoal});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final doneCount = trainedWeekdays.length;
    final progress =
        weeklyGoal > 0 ? (doneCount / weeklyGoal).clamp(0.0, 1.0) : 0.0;
    final goalMet = doneCount >= weeklyGoal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final weekday = i + 1;
                final done = trainedWeekdays.contains(weekday);
                return _DayDot(done: done);
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor:
                          scheme.surfaceContainerHighest.withOpacity(0.5),
                      valueColor: AlwaysStoppedAnimation(
                        goalMet ? const Color(0xFF4CAF50) : scheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: goalMet
                        ? const Color(0xFF4CAF50).withOpacity(0.12)
                        : scheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$doneCount/$weeklyGoal',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: goalMet
                              ? const Color(0xFF4CAF50)
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final bool done;
  const _DayDot({required this.done});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: done
            ? const Color(0xFF4CAF50)
            : scheme.surfaceContainerHighest.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : null,
    );
  }
}
