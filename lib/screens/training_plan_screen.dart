import 'package:flutter/material.dart';
import 'dart:convert';
import '../providers/progress_provider.dart';
import '../widgets/week_activity_card.dart';
import 'strength_session_summary_screen.dart';
import 'strength_split_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/plan_l10n.dart';
import '../l10n/cardio_l10n.dart';
import '../models/training_program.dart';
import '../models/cardio.dart';
import '../providers/training_program_provider.dart';
import '../providers/cardio_provider.dart';
import '../providers/workout_provider.dart';
import '../widgets/plan_controls.dart';
import 'training_plan_setup_screen.dart';
import 'training_library_screen.dart';
import 'workout_detail_screen.dart';
import 'cardio_session_screen.dart';
import 'cardio_editor_screen.dart';

Future<void> openPlanSetup(
  BuildContext context, {
  TrainingProgram? plan,
  String? section,
}) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder:
          (_) =>
              TrainingPlanSetupScreen(existing: plan, initialSection: section),
    ),
  );
  if (context.mounted) await context.read<TrainingProgramProvider>().load();
}

class TrainingPlanCard extends StatelessWidget {
  const TrainingPlanCard({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainingProgramProvider>();
    final p = state.active;
    if (state.error != null) return PlanError('error', onRetry: state.load);
    if (!state.loaded) return const SizedBox.shrink();
    if (p == null && state.plans.any((p) => p.status == 'active')) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.calendar_month_outlined),
          title: Text(context.plan('choosePlan')),
          subtitle: Text(context.plan('choosePlanHint')),
          trailing: const Icon(Icons.chevron_right),
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrainingPlanScreen()),
              ),
        ),
      );
    }
    if (p != null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.calendar_month_outlined),
          title: Text(p.name),
          subtitle: Text(
            [
              if (p.currentSlots.any((s) => s.kind == 'strength') &&
                  p.strengthGoal.isNotEmpty)
                planLabel(context, p.strengthGoal),
              if (p.hasRunning && p.runningGoal.isNotEmpty)
                planLabel(context, p.runningGoal),
              '${p.days.length} ${context.cardio('days')}',
            ].join(' · '),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrainingPlanScreen()),
              ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(height: 20),
            Text(
              context.plan('planIntro'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(context.plan('planHint')),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => openPlanSetup(context),
              child: Text(
                context.plan(
                  state.pendingDraft == null ? 'createPlan' : 'resumePlan',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrainingPlanScreen extends StatefulWidget {
  const TrainingPlanScreen({super.key, this.initialDate});
  final DateTime? initialDate;
  @override
  State<TrainingPlanScreen> createState() => _TrainingPlanScreenState();
}

class _TrainingPlanScreenState extends State<TrainingPlanScreen> {
  late DateTime _date = DateUtils.dateOnly(
    widget.initialDate ?? DateTime.now(),
  );
  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainingProgramProvider>();
    final p = state.active;
    return Scaffold(
      appBar: AppBar(
        title: Text(p?.name ?? context.plan('myPlan')),
        actions: [
          if (p != null)
            IconButton(
              tooltip: context.plan('edit'),
              onPressed: () => openPlanSetup(context, plan: p),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (p == null && state.plans.isEmpty) const TrainingPlanCard(),
          if (p != null) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.fitness_center),
                    title: Text(context.plan('editStrength')),
                    subtitle: Text(
                      planLabel(
                        context,
                        p.strengthGoal.isEmpty
                            ? 'generalFitness'
                            : p.strengthGoal,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        () => openPlanSetup(
                          context,
                          plan: p,
                          section: 'strength',
                        ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.directions_run),
                    title: Text(context.plan('editRunning')),
                    subtitle: Text(
                      p.hasRunning
                          ? CardioUnits.distance(
                            p.targetMeters,
                            context.read<CardioProvider>().profile.units,
                            locale: Localizations.localeOf(context).toString(),
                          )
                          : context.plan('add'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        () =>
                            openPlanSetup(context, plan: p, section: 'running'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            PlanWeekView(
              program: p,
              date: _date,
              onDateChanged: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: 24),
          ],
          if (state.plans.isNotEmpty &&
              (state.plans.length > 1 || p == null)) ...[
            Text(
              context.plan(p == null ? 'choosePlan' : 'savedPlans'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final saved in state.plans)
              ListTile(
                title: Text(saved.name),
                trailing:
                    saved.id == p?.id
                        ? const Icon(Icons.check)
                        : const Icon(Icons.chevron_right),
                onTap: () async {
                  try {
                    await state.activate(saved.id);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.plan('error'))),
                      );
                    }
                  }
                },
              ),
          ],
          if (p != null || state.plans.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => openPlanSetup(context),
              icon: const Icon(Icons.add),
              label: Text(context.plan('createPlan')),
            ),
        ],
      ),
    );
  }
}

class PlanWeekView extends StatefulWidget {
  const PlanWeekView({
    super.key,
    required this.program,
    required this.date,
    required this.onDateChanged,
    this.todayFirst = false,
    this.beforeEntries,
  });
  final TrainingProgram? program;
  final Widget? beforeEntries;
  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;
  final bool todayFirst;
  @override
  State<PlanWeekView> createState() => _PlanWeekViewState();
}

class _PlanWeekViewState extends State<PlanWeekView> {
  late Future<List<ProgramEntry>> _entries;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant PlanWeekView old) {
    super.didUpdateWidget(old);
    if (old.program != widget.program || old.date != widget.date) _reload();
  }

  DateTime get _monday => DateTime(
    widget.date.year,
    widget.date.month,
    widget.date.day - widget.date.weekday + 1,
  );
  void _reload() {
    _entries = context.read<TrainingProgramProvider>().repository.weekEntries(
      widget.program,
      _monday,
      DateTime(_monday.year, _monday.month, _monday.day + 7),
    );
  }

  Future<void> _open(ProgramEntry entry) async {
    if (entry.completed && entry.sessionId != null) {
      if (entry.kind == 'running') {
        final rows = await context.read<CardioProvider>().repository.history();
        final row = rows.where((r) => r['id'] == entry.sessionId).firstOrNull;
        if (row != null && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => CardioSummaryScreen(
                    runtime: cardioHistoryRuntime(row),
                    snapshot:
                        jsonDecode(row['snapshot_json'] as String)
                            as Map<String, dynamic>,
                  ),
            ),
          );
        }
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) =>
                    StrengthSessionSummaryScreen(sessionId: entry.sessionId!),
          ),
        );
      }
      return;
    }
    if (entry.cardio != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlannedCardioScreen(entry: entry)),
      );
    } else if (entry.needsWorkout) {
      final id = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder:
              (_) => TrainingLibraryScreen(
                initialSport: entry.kind,
                pickWorkout: true,
              ),
        ),
      );
      if (id != null && mounted) {
        try {
          final store = context.read<TrainingProgramProvider>();
          await store.repository.save(
            widget.program!.copyWith(
              slots:
                  widget.program!.slots
                      .map(
                        (s) =>
                            s.id == entry.slotId
                                ? s.copyWith(workoutId: id)
                                : s,
                      )
                      .toList(),
            ),
            activate: false,
          );
          await store.load();
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.plan('savingError'))),
            );
          }
        }
      }
    } else {
      final w =
          context
              .read<WorkoutProvider>()
              .workouts
              .where((w) => w.canonicalId == entry.workoutId)
              .firstOrNull;
      if (w != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => WorkoutDetailScreen(
                  workout: w,
                  plannedOccurrenceId: entry.id,
                  trainingProgramId: entry.planId,
                ),
          ),
        );
      }
    }
    if (mounted) setState(_reload);
  }

  Future<void> _move(ProgramEntry entry) async {
    final date = await showDatePicker(
      context: context,
      initialDate: entry.date,
      firstDate: widget.program!.start,
      lastDate: widget.program!.endDate ?? DateTime(2100),
    );
    if (date == null || !mounted) return;
    List<ProgramEntry> neighbors;
    try {
      neighbors = await context
          .read<TrainingProgramProvider>()
          .repository
          .entries(
            widget.program!,
            DateTime(date.year, date.month, date.day - 1),
            DateTime(date.year, date.month, date.day + 2),
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.plan('error'))));
      }
      return;
    }
    if (!mounted) return;
    final doubleDay = neighbors.any(
      (e) => e.id != entry.id && dateKey(e.date) == dateKey(date),
    );
    bool demanding(ProgramEntry e) =>
        e.cardio?.workout.templateCode == 'longRun' ||
        (e.cardio?.workout.steps.any(
              (s) =>
                  ![
                    CardioIntensity.easy,
                    CardioIntensity.recovery,
                  ].contains(s.intensity),
            ) ??
            false);
    bool legs(ProgramEntry e) =>
        widget.program!.slots.any((s) => s.id == e.slotId && s.legHeavy);
    final recoveryConflict = neighbors.any(
      (e) =>
          e.id != entry.id &&
          ((legs(entry) && demanding(e)) || (demanding(entry) && legs(e))),
    );
    final future = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: Text(c.plan('move')),
            content:
                doubleDay || recoveryConflict
                    ? Text(c.plan(doubleDay ? 'doubleDay' : 'conflictHint'))
                    : null,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(c.plan('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(c.plan('onlyThis')),
              ),
              if (entry.splitSourceId == null)
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(c.plan('future')),
                ),
            ],
          ),
    );
    if (future == null || !mounted) return;
    try {
      final state = context.read<TrainingProgramProvider>();
      if (entry.cardio != null) {
        await context.read<CardioProvider>().repository.move(
          entry.cardio!,
          date,
          future: future,
        );
        if (mounted) await context.read<CardioProvider>().load();
      } else {
        await state.repository.moveStrength(
          widget.program!,
          entry,
          date,
          future: future,
        );
      }
      await state.load();
      if (mounted) setState(_reload);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.plan('savingError'))));
      }
    }
  }

  Widget _entry(ProgramEntry e) => Card(
    child: ListTile(
      leading: Icon(
        e.completed
            ? Icons.check_circle_outline
            : e.kind == 'running'
            ? Icons.directions_run
            : e.kind == 'mobility'
            ? Icons.self_improvement
            : Icons.fitness_center,
      ),
      title: Text(planLabel(context, e.name)),
      subtitle: e.needsWorkout ? Text(context.plan('assignWorkout')) : null,
      onTap: () => _open(e),
      trailing:
          e.completed || e.sessionId != null
              ? null
              : IconButton(
                tooltip: context.plan('move'),
                icon: const Icon(Icons.event_outlined),
                onPressed: () => _actions(e),
              ),
    ),
  );

  Future<void> _actions(ProgramEntry e) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (c) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final key in [
                  'move',
                  'swap',
                  if (e.cardio == null && e.workoutId != null)
                    e.splitSourceId == null ? 'splitSession' : 'undoSplit',
                ])
                  ListTile(
                    title: Text(c.plan(key)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(c, key),
                  ),
              ],
            ),
          ),
    );
    if (action == null || !mounted) return;
    try {
      final store = context.read<TrainingProgramProvider>();
      if (action == 'move') {
        await _move(e);
        return;
      }
      if (action == 'splitSession') {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StrengthSplitScreen(entry: e)),
        );
      } else if (action == 'undoSplit') {
        await store.repository.undoSplit(e.splitSourceId!);
      } else if (action == 'swap') {
        final candidates =
            (await _entries)
                .where(
                  (p) => p.id != e.id && !p.completed && p.sessionId == null,
                )
                .toList();
        if (!mounted) return;
        final other = await showModalBottomSheet<ProgramEntry>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder:
              (c) => SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final p in candidates)
                        ListTile(
                          title: Text(planLabel(c, p.name)),
                          subtitle: Text(
                            DateFormat.yMMMEd(
                              Localizations.localeOf(c).toString(),
                            ).format(p.date),
                          ),
                          onTap: () => Navigator.pop(c, p),
                        ),
                    ],
                  ),
                ),
              ),
        );
        if (other == null) return;
        final neighbors = await store.repository.entries(
          widget.program!,
          DateTime(_monday.year, _monday.month, _monday.day - 1),
          DateTime(_monday.year, _monday.month, _monday.day + 8),
        );
        final warning =
            planPlacementWarning(
              widget.program!,
              e,
              other.date,
              neighbors,
              excluded: {other.id},
            ) ??
            planPlacementWarning(
              widget.program!,
              other,
              e.date,
              neighbors,
              excluded: {e.id},
            );
        if (!mounted) return;
        if (warning != null) {
          final proceed = await showDialog<bool>(
            context: context,
            builder:
                (c) => AlertDialog(
                  title: Text(c.plan(warning)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(c.plan('cancel')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(c.plan('swap')),
                    ),
                  ],
                ),
          );
          if (proceed != true) return;
        }
        await store.repository.swapEntries(e, other);
      }
      await store.load();
      if (mounted) {
        await context.read<WorkoutProvider>().loadWorkouts();
      }
      if (mounted) setState(_reload);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.plan('savingError'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ProgramEntry>>(
    future: _entries,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return PlanError('error', onRetry: () => setState(_reload));
      }
      if (!snapshot.hasData) return const SizedBox(height: 48);
      final entries = snapshot.data!,
          locale = Localizations.localeOf(context).toString();
      final selected =
          entries
              .where((e) => dateKey(e.date) == dateKey(widget.date))
              .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WeekActivityCard(
            date: widget.date,
            entries: entries,
            streak: context.watch<ProgressProvider?>()?.currentStreak ?? 0,
            onDateChanged: widget.onDateChanged,
          ),
          if (widget.todayFirst) ...[
            const SizedBox(height: 24),
            if (widget.beforeEntries != null) widget.beforeEntries!,
            Text(
              dateKey(widget.date) == dateKey(DateTime.now())
                  ? context.plan('today')
                  : DateFormat.yMMMEd(locale).format(widget.date),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (selected.isEmpty) Text(context.plan('restDay')),
            for (final e in selected)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _entry(e),
              ),
          ],
          if (!widget.todayFirst)
            for (var d = 1; d <= 7; d++) ...[
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 8),
                child: Text(
                  DateFormat.EEEE(locale).format(DateTime(2024, 1, d)),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final e in entries.where((e) => e.date.weekday == d))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _entry(e),
                ),
            ],
        ],
      );
    },
  );
}

class PlannedCardioScreen extends StatefulWidget {
  const PlannedCardioScreen({super.key, required this.entry});
  final ProgramEntry entry;
  @override
  State<PlannedCardioScreen> createState() => _PlannedCardioScreenState();
}

class _PlannedCardioScreenState extends State<PlannedCardioScreen> {
  late CardioWorkout _workout = widget.entry.cardio!.workout;
  String? _error;
  @override
  Widget build(BuildContext context) {
    final p = context.watch<CardioProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(_workout.name)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(20),
        child: FilledButton.icon(
          onPressed:
              () => startCardioWorkout(
                context,
                _workout,
                occurrenceId: widget.entry.id,
              ),
          icon: const Icon(Icons.play_arrow),
          label: Text(context.cardio('start')),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final step in _workout.steps)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${step.repeat > 1 ? '${step.repeat} × ' : ''}${step.name.isEmpty ? context.cardio(step.intensity.name) : step.name}',
              ),
              subtitle: Text(
                cardioStepDescription(step, p.profile.units, context),
              ),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: Text(context.plan('edit')),
            onPressed: () async {
              final value = await Navigator.push<CardioWorkout>(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => CardioEditorScreen(
                        workout: _workout,
                        units: p.profile.units,
                      ),
                ),
              );
              if (value == null) return;
              try {
                await p.repository.editOccurrence(widget.entry.cardio!, value);
                await p.load();
                if (mounted) setState(() => _workout = value);
              } catch (_) {
                if (mounted) setState(() => _error = 'savingError');
              }
            },
          ),
          if (_error != null) PlanError(_error!),
        ],
      ),
    );
  }
}
