import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/progress_provider.dart';
import '../providers/workout_provider.dart';
import '../models/workout_entry.dart';
import '../models/workout.dart';
import '../widgets/weekly_activity_chart.dart';
import 'workout_entry_detail_screen.dart';
import '../widgets/active_workout_banner.dart';
import '../widgets/trainings_calendar.dart';
import '../widgets/filtered_exercise_progress_chart.dart';
import '../widgets/tap_scale.dart';
import '../utils/duration_utils.dart';
import '../providers/active_workout_provider.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/screen_info_dialog.dart';

class ProgressScreen extends StatefulWidget {
  final VoidCallback? onSwipePastStart;
  final VoidCallback? onSwipePastEnd;
  const ProgressScreen({super.key, this.onSwipePastStart, this.onSwipePastEnd});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _loadedOnce = false;
  late final TabController _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
    final active = context.watch<ActiveWorkoutProvider>();

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitle('Fortschritt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, size: 20),
            onPressed: () => showScreenInfoDialog(
              context,
              title: 'Fortschritt',
              description: 'Verfolge deinen Trainingsfortschritt. Im Verlauf siehst du alle absolvierten Workouts, in Insights findest du Kalender und Übungsdiagramme.',
            ),
            tooltip: 'Info',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            56 + (active.isActive ? 56 : 0),
          ),
          child: Column(
            children: [
              if (active.isActive) const ActiveWorkoutBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.all(3),
                    dividerColor: Colors.transparent,
                    labelColor: scheme.onPrimary,
                    unselectedLabelColor: scheme.onSurfaceVariant,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    tabs: const [Tab(text: 'Verlauf'), Tab(text: 'Insights')],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : NotificationListener<OverscrollNotification>(
              onNotification: (notification) {
                if (notification.depth != 0) return false;
                if (_tabController.index == 0 && notification.overscroll < 0) {
                  widget.onSwipePastStart?.call();
                  return true;
                }
                if (_tabController.index == _tabController.length - 1 && notification.overscroll > 0) {
                  widget.onSwipePastEnd?.call();
                  return true;
                }
                return false;
              },
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHistoryTab(entries, provider),
                  _buildInsightsTab(entries),
                ],
              ),
            ),
    );
  }

  Widget _buildHistoryTab(List<WorkoutEntry> entries, ProgressProvider provider) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: WeeklyActivityChart(
              entries: entries,
              title: 'Aktivität',
              subtitle: 'Minuten pro Tag',
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
    );
  }

  Widget _buildInsightsTab(List<WorkoutEntry> entries) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: TrainingsCalendar(entries: entries),
          ),
        ),
        const SizedBox(height: 12),
        const FilteredExerciseProgressChart(),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.show_chart, size: 32, color: scheme.onPrimaryContainer),
            ),
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
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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

    return TapScale(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WorkoutEntryDetailScreen(entry: entry),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ImageIcon(const AssetImage('assets/icons/hantel.png'),
                  color: scheme.onPrimaryContainer, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(workoutName, style: textTheme.titleMedium,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(dateStr, style: textTheme.bodySmall),
                  if (totalSets > 0 || totalDuration > 0) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      if (totalSets > 0) _SmallChip(icon: Icons.layers, label: '$totalSets Sätze'),
                      if (totalDuration > 0) _SmallChip(icon: Icons.timer_outlined, label: DurationFormatter.verbose(totalDuration)),
                    ]),
                  ],
                ],
              )),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SmallChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          )),
        ],
      ),
    );
  }
}
