// lib/screens/home_screen.dart
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

const Duration _kHomeAnim = Duration(milliseconds: 200);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _selectedWorkoutId;

  @override
  void initState() {
    super.initState();
    // Beim ersten Ã–ffnen Workouts + Progress laden
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
      builder:
          (ctx) => AlertDialog(
            title: const Text('Neues Workout'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Workout-Namen eingeben',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Bitte Namen eingeben';
                  }
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
                child: const Text('Speichern'),
              ),
            ],
          ),
    );

    if (name == null) return;

    final w = await provider.createWorkout(name: name);
    if (!mounted) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => WorkoutScreen(workout: w)));
    await provider.loadWorkouts();
    try {
      context.read<CloudSyncProvider>().scheduleBackupSoon();
    } catch (_) {}
  }

  Future<void> _confirmAndDelete(Workout workout) async {
    final provider = context.read<WorkoutProvider>();
    final scheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Workout lÃ¶schen?'),
            content: Text(
              'â€ž${workout.name}â€œ wird endgÃ¼ltig gelÃ¶scht. Fortfahren?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(Colors.red),
                  foregroundColor: MaterialStateProperty.all<Color>(
                    Colors.white,
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('LÃ¶schen'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    await provider.deleteWorkout(workout.id);
    if (!mounted) return;

    setState(() => _selectedWorkoutId = null);
    try {
      context.read<CloudSyncProvider>().scheduleBackupSoon();
    } catch (_) {}
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('â€ž${workout.name}â€œ gelÃ¶scht'),
        backgroundColor: scheme.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openWorkout(Workout workout) async {
    if (_selectedWorkoutId != null) {
      setState(() => _selectedWorkoutId = null);
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => WorkoutScreen(workout: workout)));
    if (!mounted) return;
    await context.read<WorkoutProvider>().loadWorkouts();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final workouts = provider.workouts;
    final active = context.watch<ActiveWorkoutProvider>();

    final progress = context.watch<ProgressProvider>();
    final trainedWeekdays = _trainedWeekdaysThisWeek(progress.entries);
    final weeklyGoal = progress.weeklyGoal.clamp(1, 7);
    final isProgressLoading = progress.isLoading;

    return WillPopScope(
      onWillPop: () async {
        if (_selectedWorkoutId != null) {
          setState(() => _selectedWorkoutId = null);
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workouts'),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(active.isActive ? 56 : 0),
            child: AnimatedSwitcher(
              duration: _kHomeAnim,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                  reverseCurve: Curves.easeIn,
                );
                return FadeTransition(
                  opacity: curved,
                  child: SizeTransition(
                    sizeFactor: curved,
                    axisAlignment: -1,
                    child: child,
                  ),
                );
              },
              child:
                  active.isActive
                      ? const ActiveWorkoutBanner(key: ValueKey('home-banner'))
                      : const SizedBox(
                        key: ValueKey('home-banner-empty'),
                        height: 0,
                      ),
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => _createWorkout(context),
              icon: const Icon(Icons.add),
              tooltip: 'Neues Workout',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _createWorkout(context),
          shape: const CircleBorder(), // â¬…ï¸ explizit rund
          child: const Icon(Icons.add),
        ),
        body: AnimatedSwitcher(
          duration: _kHomeAnim,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
              reverseCurve: Curves.easeIn,
            );
            return FadeTransition(opacity: curved, child: child);
          },
          child:
              provider.isLoading
                  ? const Center(
                    key: ValueKey('home-loading'),
                    child: CircularProgressIndicator(),
                  )
                  : Column(
                    key: const ValueKey('home-content'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: _WeeklyOverviewCard(
                          trainedWeekdays:
                              isProgressLoading ? const {} : trainedWeekdays,
                          weeklyGoal: weeklyGoal,
                        ),
                      ),
                      Expanded(
                        child:
                            workouts.isEmpty
                                ? const _EmptyState()
                                : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    100,
                                  ),
                                  itemCount: workouts.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (ctx, i) {
                                    final w = workouts[i];
                                    final selected = w.id == _selectedWorkoutId;

                                    return WorkoutCard(
                                      workout: w,
                                      selected: selected,
                                      onTap: () => _openWorkout(w),
                                      onLongPress: () {
                                        setState(
                                          () =>
                                              _selectedWorkoutId =
                                                  selected ? null : w.id,
                                        );
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
      ),
    );
  }

  Set<int> _trainedWeekdaysThisWeek(List entries) {
    if (entries.isEmpty) return {};
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
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
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center_rounded, size: 52),
            const SizedBox(height: 16),
            Text('Noch keine Workouts', style: text.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Erstelle dein erstes Workout mit dem Plus-Button.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// --- Wochen-Widget (Moâ€“So) mit Ziel -----------------------------------------

class _WeeklyOverviewCard extends StatelessWidget {
  final Set<int> trainedWeekdays; // 1=Mo .. 7=So
  final int weeklyGoal; // 1..7
  const _WeeklyOverviewCard({
    required this.trainedWeekdays,
    required this.weeklyGoal,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    const labels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

    final headerStyle = text.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
    );

    final counterStyle = text.bodyLarge?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Diese Woche', style: headerStyle),
                const Spacer(),
                Text(
                  '${trainedWeekdays.length}/$weeklyGoal',
                  style: counterStyle,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final weekday = i + 1;
                final done = trainedWeekdays.contains(weekday);
                final label = labels[i];
                return _DayPill(label: label, done: done);
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  final String label;
  final bool done;
  const _DayPill({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // HELLERES GrÃ¼n fÃ¼r Done (vorher 0xFF2E7D32)
    const Color doneFill = Color(0xFF4CAF50); // Green 500
    const Color doneShadow = Color(0x404CAF50); // 25% Alpha

    final dayLabelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontSize: 15.5,
      fontWeight: FontWeight.w800,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      letterSpacing: -0.1,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: done ? doneFill : scheme.surfaceVariant,
            shape: BoxShape.circle,
            border: Border.all(color: done ? doneFill : scheme.outlineVariant),
            boxShadow:
                done
                    ? const [
                      BoxShadow(
                        color: doneShadow,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child:
                done
                    ? const Icon(
                      Icons.check_rounded,
                      key: ValueKey('icon_done'),
                      color: Colors.white,
                      size: 20,
                    )
                    : Icon(
                      Icons.fiber_manual_record,
                      key: const ValueKey('icon_neutral'),
                      size: 10,
                      color: scheme.onSurfaceVariant,
                    ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: dayLabelStyle),
      ],
    );
  }
}
