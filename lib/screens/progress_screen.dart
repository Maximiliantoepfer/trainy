import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/progress_provider.dart';
import '../providers/workout_provider.dart';
import '../models/workout_entry.dart';
import '../models/workout.dart';
import '../widgets/weekly_activity_chart.dart';
import 'workout_entry_detail_screen.dart';
import 'progress_insights_screen.dart';
import '../widgets/active_workout_banner.dart';
import '../utils/duration_utils.dart';
import '../providers/active_workout_provider.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with AutomaticKeepAliveClientMixin {
  bool _loadedOnce = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ProgressProvider>().loadData();
        context.read<WorkoutProvider>().loadWorkouts();
      });
      _loadedOnce = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<ProgressProvider>();
    final entries = provider.entries;
    final isActive = context.watch<ActiveWorkoutProvider>().isActive;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fortschritt'),
        actions: [
          IconButton(
            icon: Icon(Icons.insights_rounded,
                color: Theme.of(context).colorScheme.primary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ProgressInsightsScreen(),
                ),
              );
            },
          ),
        ],
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
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: WeeklyActivityChart(
                            entries: entries,
                            title: 'Aktivität',
                            subtitle: 'Workouts pro Tag',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (entries.isEmpty)
                        const _EmptyState()
                      else
                        ...List.generate(
                          entries.length,
                          (i) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _EntryCard(entry: entries[i]),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.show_chart_rounded,
                  size: 32, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Icon(Icons.fitness_center_rounded,
                size: 24, color: scheme.onSurfaceVariant.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final WorkoutEntry entry;
  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = entry.date;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';

    final workouts = context.watch<WorkoutProvider>().workouts;
    Workout? w;
    try {
      w = workouts.firstWhere((e) => e.id == entry.workoutId);
    } catch (_) {
      w = null;
    }
    final workoutName = w?.name ?? 'Workout';

    int totalSets = 0;
    int totalDuration = 0;
    entry.results.forEach((_, v) {
      final sets = v['sets'];
      if (sets is int) totalSets += sets;
      if (sets is String) {
        final s = int.tryParse(sets);
        if (s != null) totalSets += s;
      }
      final dur = v['duration'];
      if (dur is int) totalDuration += dur;
      if (dur is String) {
        final d = int.tryParse(dur);
        if (d != null) totalDuration += d;
      }
    });

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WorkoutEntryDetailScreen(entry: entry),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.fitness_center_rounded,
                    size: 20, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workoutName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 13,
                            color: scheme.onSurfaceVariant.withOpacity(0.5)),
                        const SizedBox(width: 4),
                        Text(dateStr,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant
                                      .withOpacity(0.6),
                                )),
                        const SizedBox(width: 10),
                        Icon(Icons.access_time_rounded,
                            size: 13,
                            color: scheme.onSurfaceVariant.withOpacity(0.5)),
                        const SizedBox(width: 3),
                        Text(timeStr,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant
                                      .withOpacity(0.6),
                                )),
                        if (totalSets > 0) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.layers_rounded,
                              size: 13,
                              color:
                                  scheme.onSurfaceVariant.withOpacity(0.5)),
                          const SizedBox(width: 3),
                          Text('$totalSets',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant
                                        .withOpacity(0.6),
                                    fontWeight: FontWeight.w600,
                                  )),
                        ],
                        if (totalDuration > 0) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.timer_outlined,
                              size: 13,
                              color:
                                  scheme.onSurfaceVariant.withOpacity(0.5)),
                          const SizedBox(width: 3),
                          Text(DurationFormatter.verbose(totalDuration),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant
                                        .withOpacity(0.6),
                                    fontWeight: FontWeight.w600,
                                  )),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant.withOpacity(0.3)),
            ],
          ),
        ),
      ),
    );
  }
}
