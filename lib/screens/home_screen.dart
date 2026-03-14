import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../providers/workout_provider.dart';
import '../providers/cloud_sync_provider.dart';
import '../providers/progress_provider.dart';
import '../widgets/workout_card.dart';
import 'workout_screen.dart';
import '../widgets/active_workout_banner.dart';
import '../widgets/animated_flame_icon.dart';
import '../widgets/motivational_quote_card.dart';
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
    final effectiveTrainingDays = progress.effectiveTrainingDays;
    final isProgressLoading = progress.isLoading;
    final streak = _calculateStreak(progress.entries);

    return PopScope(
      canPop: _selectedWorkoutId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedWorkoutId != null) {
          setState(() => _selectedWorkoutId = null);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trainy'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _createWorkout(context),
          child: const Icon(Icons.add_rounded),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 100),
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: _WeeklyOverviewCard(
                trainedWeekdays: isProgressLoading ? const {} : trainedWeekdays,
                weeklyGoal: weeklyGoal,
                trainingDays: effectiveTrainingDays,
                streak: streak,
              ),
            ),

            // Motivational quote
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: MotivationalQuoteCard(),
            ),

            // Today's workout
            Builder(builder: (context) {
              final todayWorkouts = context.watch<WorkoutProvider>().workoutsForDay(DateTime.now().weekday);
              if (todayWorkouts.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: _TodaysWorkoutCard(
                  workouts: todayWorkouts,
                  onStart: (w) => _openWorkout(w),
                ),
              );
            }),

            // Workout list
            if (provider.isLoading)
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (workouts.isEmpty)
              _EmptyState(onCreateWorkout: () => _createWorkout(context))
            else
              ...List.generate(workouts.length, (i) {
                final w = workouts[i];
                final selected = w.id == _selectedWorkoutId;
                return Padding(
                  padding: EdgeInsets.fromLTRB(20, i == 0 ? 12 : 6, 20, 6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 300 + (i * 50)),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - v)),
                        child: child,
                      ),
                    ),
                    child: WorkoutCard(
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
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  int _calculateStreak(List entries) {
    if (entries.isEmpty) return 0;
    final days = <DateTime>{};
    for (final e in entries) {
      final DateTime d = e.date;
      days.add(DateTime(d.year, d.month, d.day));
    }
    final sorted = days.toList()..sort((a, b) => b.compareTo(a));
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    int streak = 0;
    var check = todayDate;
    // Allow starting from today or yesterday
    if (sorted.isEmpty) return 0;
    if (sorted.first != todayDate) {
      final yesterday = todayDate.subtract(const Duration(days: 1));
      if (sorted.first != yesterday) return 0;
      check = yesterday;
    }
    for (final d in sorted) {
      if (d == check) {
        streak++;
        check = check.subtract(const Duration(days: 1));
      } else if (d.isBefore(check)) {
        break;
      }
    }
    return streak;
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

class _TodaysWorkoutCard extends StatelessWidget {
  final List<Workout> workouts;
  final void Function(Workout) onStart;
  const _TodaysWorkoutCard({required this.workouts, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (workouts.length == 1) {
      final w = workouts.first;
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - v)),
            child: child,
          ),
        ),
        child: Card(
          color: scheme.primaryContainer,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onStart(w),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Heutiges Training',
                          style: textTheme.labelLarge?.copyWith(
                            color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                          )),
                        const SizedBox(height: 4),
                        Text(w.name,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onPrimaryContainer,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text('${w.exerciseIds.length} Übungen',
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                          )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => onStart(w),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text("Los geht's"),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Multiple workouts
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - v)),
          child: child,
        ),
      ),
      child: Card(
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Heutiges Training',
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                )),
              const SizedBox(height: 12),
              ...workouts.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onStart(w),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ImageIcon(
                            const AssetImage('assets/icons/hantel.png'),
                            color: scheme.onPrimaryContainer,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(w.name,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onPrimaryContainer,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text('${w.exerciseIds.length} Übungen',
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                                )),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => onStart(w),
                          icon: Icon(Icons.play_arrow_rounded,
                            color: scheme.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateWorkout;
  const _EmptyState({required this.onCreateWorkout});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
              child: Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ImageIcon(const AssetImage('assets/icons/hantel.png'),
                  size: 32, color: scheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(height: 20),
            Text('Noch keine Workouts',
              style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Erstelle Workouts, füge Übungen hinzu und tracke deinen Fortschritt.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreateWorkout,
              icon: const Icon(Icons.add),
              label: const Text('Erstes Workout erstellen'),
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
  final Set<int> trainingDays;
  final int streak;
  const _WeeklyOverviewCard({
    required this.trainedWeekdays,
    required this.weeklyGoal,
    required this.trainingDays,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final doneCount = trainedWeekdays.length;
    final progress = weeklyGoal > 0 ? (doneCount / weeklyGoal).clamp(0.0, 1.0) : 0.0;
    final goalReached = doneCount >= weeklyGoal;
    final today = DateTime.now().weekday;

    const labels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Diese Woche',
                  style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: goalReached
                        ? scheme.tertiary.withValues(alpha: 0.12)
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (goalReached) ...[
                        Icon(Icons.celebration_rounded, size: 16, color: scheme.tertiary),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        '$doneCount / $weeklyGoal',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: goalReached
                              ? scheme.tertiary
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar with optional glow
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, animatedProgress, __) => Container(
                decoration: goalReached
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.tertiary.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      )
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: animatedProgress,
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation(
                      goalReached ? scheme.tertiary : scheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final weekday = i + 1;
                final done = trainedWeekdays.contains(weekday);
                final isTrainingDay = trainingDays.contains(weekday);
                return _DayDot(
                  label: labels[i],
                  done: done,
                  isTrainingDay: isTrainingDay,
                  isToday: weekday == today,
                );
              }),
            ),
            if (streak > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const AnimatedFlameIcon(size: 28),
                  const SizedBox(width: 8),
                  Text(
                    '$streak-Tage-Streak',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFFF6D00),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final String label;
  final bool done;
  final bool isTrainingDay;
  final bool isToday;
  const _DayDot({
    required this.label,
    required this.done,
    required this.isTrainingDay,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // 3 states: trainingDone, trainingPending, restDay
    final Color bgColor;
    final Widget? child;
    if (done) {
      bgColor = scheme.tertiary;
      child = Icon(Icons.check_rounded, color: scheme.onTertiary, size: 22);
    } else if (isTrainingDay) {
      bgColor = scheme.surfaceContainerHighest.withValues(alpha: 0.65);
      child = ImageIcon(
        const AssetImage('assets/icons/muskel.png'),
        color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
        size: 21,
      );
    } else {
      bgColor = scheme.surfaceContainerHighest.withValues(alpha: 0.65);
      child = ImageIcon(
        const AssetImage('assets/icons/sofa.png'),
        color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
        size: 21,
      );
    }

    return Semantics(
      label: '$label: ${done ? "trainiert" : isTrainingDay ? "geplant" : "Ruhetag"}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: isToday
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.primary, width: 2),
                  )
                : null,
            padding: isToday ? const EdgeInsets.all(1) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: child,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isToday ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
