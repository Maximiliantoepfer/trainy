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
import '../providers/active_workout_provider.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ProgressProvider>().loadData();
        // Für die Titelauflösung (Workoutname)
        context.read<WorkoutProvider>().loadWorkouts();
      });
      _loadedOnce = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProgressProvider>();
    final entries = provider.entries;
    final active = context.watch<ActiveWorkoutProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fortschritt'),
        bottom: active.isActive
            ? const PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: ActiveWorkoutBanner(),
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Insights',
            icon: const Icon(Icons.insights_outlined),
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
      body:
          provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: [
                  // Weekly Activity Chart (oben)
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
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _EntryCard(entry: entries[i]),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.show_chart, size: 64),
            const SizedBox(height: 12),
            Text(
              'Noch keine Einträge',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Starte ein Workout und erfasse Sätze, dann erscheinen sie hier.',
              textAlign: TextAlign.center,
            ),
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
    final date = entry.date;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year} • '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';

    // Workout-Name via Provider
    final workouts = context.watch<WorkoutProvider>().workouts;
    Workout? w;
    try {
      w = workouts.firstWhere((e) => e.id == entry.workoutId);
    } catch (_) {
      w = null;
    }
    final workoutName = w?.name ?? 'Workout';

    // Gesamtsätze/-dauer (aggregiert über Exercises)
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
      child: ListTile(
        title: Text(
          'Workout – $workoutName',
          style: const TextStyle(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$dateStr'
          '${totalSets > 0 ? ' · $totalSets Sätze' : ''}'
          '${totalDuration > 0 ? ' · ${_formatDuration(totalDuration)}' : ''}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WorkoutEntryDetailScreen(entry: entry),
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}
