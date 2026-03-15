import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../providers/workout_provider.dart';
import '../providers/cloud_sync_provider.dart';
import '../providers/progress_provider.dart';
import '../widgets/workout_card.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/screen_info_dialog.dart';
import 'workout_screen.dart';
import 'backdate_workout_screen.dart';
import '../widgets/active_workout_banner.dart';
import '../widgets/animated_flame_icon.dart';
import '../widgets/motivational_quote_card.dart';
import '../providers/active_workout_provider.dart';
import '../providers/exercise_provider.dart';
import '../models/exercise.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  int? _selectedWorkoutId;
  DateTime _selectedDate = DateTime.now();

  @override
  bool get wantKeepAlive => true;

  DateTime _dateForWeekday(int weekday) {
    final base = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final monday = base.subtract(Duration(days: base.weekday - 1));
    return monday.add(Duration(days: weekday - 1));
  }

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

  bool get _isBackdating {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return sel.isBefore(today);
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

  Future<void> _openBackdateWorkout(Workout workout) async {
    final exercises = context.read<ExerciseProvider>().exercises;
    final list = workout.exerciseIds
        .map((id) => exercises.where((e) => e.id == id).cast<Exercise?>().firstOrNull)
        .whereType<Exercise>()
        .toList();

    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine Übungen im Workout'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BackdateWorkoutScreen(
          workout: workout,
          exercises: list,
          backdateDate: _selectedDate,
        ),
      ),
    );

    if (!mounted) return;
    if (result == true) {
      context.read<ProgressProvider>().loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<WorkoutProvider>();
    final workouts = provider.workouts;
    final active = context.watch<ActiveWorkoutProvider>();

    final progress = context.watch<ProgressProvider>();
    final trainedWeekdays = _trainedWeekdaysForSelectedWeek(progress.entries);
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
          title: const AppBarTitle('Trainy'),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, size: 20),
              onPressed: () => showScreenInfoDialog(
                context,
                title: 'Trainy',
                description: 'Dein Dashboard auf einen Blick. Hier siehst du deine Wochenübersicht, geplante Workouts und kannst direkt ein Training starten.',
              ),
              tooltip: 'Info',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Center(
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      locale: const Locale('de', 'DE'),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('d. MMMM', 'de_DE').format(_selectedDate),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.calendar_today_rounded,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
              child: Builder(builder: (_) {
                final now = DateTime.now();
                final currentMonday = DateTime(now.year, now.month, now.day)
                    .subtract(Duration(days: now.weekday - 1));
                final selectedBase = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
                final selectedMonday = selectedBase.subtract(Duration(days: selectedBase.weekday - 1));
                final isCurrentWeek = currentMonday == selectedMonday;
                return _WeeklyOverviewCard(
                  trainedWeekdays: isProgressLoading ? const {} : trainedWeekdays,
                  weeklyGoal: weeklyGoal,
                  trainingDays: effectiveTrainingDays,
                  streak: streak,
                  selectedWeekday: _selectedDate.weekday,
                  isCurrentWeek: isCurrentWeek,
                  onDayTap: (weekday) {
                    setState(() {
                      _selectedDate = _dateForWeekday(weekday);
                    });
                  },
                );
              }),
            ),

            // Motivational quote
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: MotivationalQuoteCard(),
            ),

            // Today's workout + backdate card
            Builder(builder: (context) {
              final selectedWorkouts = context.watch<WorkoutProvider>().workoutsForDay(_selectedDate.weekday);
              final now = DateTime.now();
              final isToday = _selectedDate.year == now.year &&
                  _selectedDate.month == now.month &&
                  _selectedDate.day == now.day;
              final dayLabel = isToday
                  ? 'Heutiges Training'
                  : '${DateFormat.EEEE('de_DE').format(_selectedDate)}-Training';

              return Column(
                children: [
                  if (selectedWorkouts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: _TodaysWorkoutCard(
                        workouts: selectedWorkouts,
                        onStart: (w) => _openWorkout(w),
                        dayLabel: dayLabel,
                      ),
                    ),
                  if (_isBackdating)
                    _BackdatePickerCard(
                      dayLabel: dayLabel,
                      onPickWorkout: (w) => _openBackdateWorkout(w),
                    ),
                ],
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

  Set<int> _trainedWeekdaysForSelectedWeek(List entries) {
    if (entries.isEmpty) return {};
    final base = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final monday = base.subtract(Duration(days: base.weekday - 1));
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
  final String dayLabel;
  const _TodaysWorkoutCard({
    required this.workouts,
    required this.onStart,
    this.dayLabel = 'Heutiges Training',
  });

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
                        Text(dayLabel,
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
              Text(dayLabel,
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
  final int selectedWeekday;
  final bool isCurrentWeek;
  final ValueChanged<int>? onDayTap;
  const _WeeklyOverviewCard({
    required this.trainedWeekdays,
    required this.weeklyGoal,
    required this.trainingDays,
    required this.streak,
    required this.selectedWeekday,
    this.isCurrentWeek = true,
    this.onDayTap,
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
                Text(isCurrentWeek ? 'Diese Woche' : 'Wochenübersicht',
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
                  isSelected: weekday == selectedWeekday,
                  onTap: () => onDayTap?.call(weekday),
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
  final bool isSelected;
  final VoidCallback? onTap;
  const _DayDot({
    required this.label,
    required this.done,
    required this.isTrainingDay,
    required this.isToday,
    this.isSelected = false,
    this.onTap,
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

    final highlighted = isSelected || isToday;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
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
                color: highlighted ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 16,
              height: 3,
              decoration: BoxDecoration(
                color: isSelected ? scheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackdatePickerCard extends StatelessWidget {
  final String dayLabel;
  final void Function(Workout) onPickWorkout;
  const _BackdatePickerCard({
    required this.dayLabel,
    required this.onPickWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Card(
        color: scheme.primaryContainer,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showWorkoutPicker(context),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.history_rounded,
                    color: scheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dayLabel,
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                        )),
                      const SizedBox(height: 4),
                      Text('Workout nachtragen',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        )),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWorkoutPicker(BuildContext context) {
    final workouts = context.read<WorkoutProvider>().workouts;
    if (workouts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine Workouts vorhanden'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('Workout auswählen',
                    style: Theme.of(ctx).textTheme.titleLarge),
              ),
              const SizedBox(height: 16),
              ...workouts.map((w) => ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20),
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ImageIcon(
                    const AssetImage('assets/icons/hantel.png'),
                    color: scheme.onPrimaryContainer,
                    size: 18,
                  ),
                ),
                title: Text(w.name),
                subtitle: Text('${w.exerciseIds.length} Übungen'),
                trailing: Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant),
                onTap: () {
                  Navigator.pop(ctx);
                  onPickWorkout(w);
                },
              )),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
