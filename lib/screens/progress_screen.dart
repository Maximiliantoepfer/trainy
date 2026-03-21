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
import '../widgets/pinned_chart_card.dart';
import '../widgets/chart_data_builder.dart';
import '../widgets/tap_scale.dart';
import '../providers/exercise_provider.dart';
import '../utils/duration_utils.dart';
import '../providers/active_workout_provider.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/screen_info_dialog.dart';
import '../providers/cloud_sync_provider.dart';

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
    final provider = context.watch<ProgressProvider>();
    final allExercises = context.watch<ExerciseProvider>().exercises;
    final order = provider.effectiveInsightsOrder;
    final rec = _findRecommendation(entries, allExercises);

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: order.length,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(animation.value);
            return Transform.scale(
              scale: 1.0 + 0.02 * t,
              child: Material(
                elevation: 4.0 * t,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      onReorder: (oldIndex, newIndex) {
        provider.reorderInsights(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final item = order[index];

        if (item == 'calendar') {
          return Padding(
            key: const ValueKey('calendar'),
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: TrainingsCalendar(entries: entries),
              ),
            ),
          );
        }

        if (item == 'recommendation') {
          if (rec == null) {
            return SizedBox.shrink(key: const ValueKey('recommendation'));
          }
          return Padding(
            key: const ValueKey('recommendation'),
            padding: const EdgeInsets.only(bottom: 10),
            child: PinnedChartCard(
              isRecommendation: true,
              recommendedExerciseId: rec.$1,
              recommendedMetric: rec.$2,
            ),
          );
        }

        if (item == 'main_chart') {
          return Padding(
            key: const ValueKey('main_chart'),
            padding: const EdgeInsets.only(bottom: 10),
            child: const FilteredExerciseProgressChart(),
          );
        }

        // pinned:{id}
        if (item.startsWith('pinned:')) {
          final id = int.tryParse(item.substring(7));
          final pc = id != null
              ? provider.pinnedCharts.cast<dynamic>().firstWhere(
                    (c) => c.id == id,
                    orElse: () => null,
                  )
              : null;
          if (pc == null) {
            return SizedBox.shrink(key: ValueKey(item));
          }
          return Padding(
            key: ValueKey(item),
            padding: const EdgeInsets.only(bottom: 10),
            child: PinnedChartCard(pinnedChart: pc),
          );
        }

        return SizedBox.shrink(key: ValueKey(item));
      },
    );
  }

  /// Findet die meisttrainierte Übung + passende Kombimetrik.
  (int, String)? _findRecommendation(
    List<WorkoutEntry> entries,
    List<dynamic> exercises,
  ) {
    if (entries.isEmpty || exercises.isEmpty) return null;

    // Zähle Einträge pro Übung
    final counts = <int, int>{};
    for (final entry in entries) {
      for (final exId in entry.results.keys) {
        counts[exId] = (counts[exId] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;

    // Sortiere nach Häufigkeit
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topExId = sorted.first.key;
    final exercise = exercises.cast<dynamic>().firstWhere(
      (ex) => ex.id == topExId,
      orElse: () => null,
    );
    if (exercise == null) return null;

    final metric = defaultMetricForExercise(
      trackSets: exercise.trackSets as bool,
      trackReps: exercise.trackReps as bool,
      trackWeight: exercise.trackWeight as bool,
      trackDuration: exercise.trackDuration as bool,
      trackDistance: exercise.trackDistance as bool,
    );

    return (topExId, metric);
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

    // Gesamtsätze (aggregiert über Exercises)
    int totalSets = 0;
    entry.results.forEach((_, v) {
      final sets = v['sets'];
      if (sets is int) totalSets += sets;
      if (sets is String) {
        final s = int.tryParse(sets);
        if (s != null) totalSets += s;
      }
    });
    final sessionDuration = entry.durationSeconds;

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
          onLongPress: () => _confirmDelete(context),
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
                  if (totalSets > 0 || (sessionDuration != null && sessionDuration > 0)) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      if (totalSets > 0) _SmallChip(icon: Icons.layers, label: '$totalSets Sätze'),
                      if (sessionDuration != null && sessionDuration > 0) _SmallChip(icon: Icons.timer_outlined, label: DurationFormatter.verbose(sessionDuration)),
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

  void _confirmDelete(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag löschen?'),
        content: const Text('Dieser Trainingseintrag wird unwiderruflich gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await context.read<ProgressProvider>().deleteEntry(entry);
    if (!context.mounted) return;
    try { context.read<CloudSyncProvider>().scheduleBackupSoon(); } catch (_) {}
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
