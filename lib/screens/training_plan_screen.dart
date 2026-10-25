import '../l10n/strength_l10n.dart';
import 'package:flutter/material.dart';
import '../widgets/plan_week_block.dart';
import '../widgets/motivational_quote_card.dart';
import '../l10n/planning_l10n.dart';
import '../services/profile_readiness.dart';
import '../services/cardio_training.dart';
import '../providers/training_profile_provider.dart';
import 'user_training_profile_screen.dart';
import 'cardio_profile_screen.dart';
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
import 'running_workout_picker.dart';
import 'cardio_screen.dart';

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
        child: Column(
          children: [
            ListTile(
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
                ].where((s) => s.trim().isNotEmpty).join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TrainingPlanScreen(),
                    ),
                  ),
            ),
          ],
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
  final _scroll = ScrollController();
  final _weekKeys = <String, GlobalKey>{};
  GlobalKey? _anchor;
  double? _anchorY;
  final _loadingEarlier = <String>{};
  bool _awayFromTop = false;
  int _weeks = 4, _backWeeks = 0;
  late DateTime _date = DateUtils.dateOnly(
    widget.initialDate ?? DateTime.now(),
  );
  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final away = _scroll.offset > 200;
      if (away != _awayFromTop && mounted) setState(() => _awayFromTop = away);
    });
  }

  void _restoreAnchor(String date) {
    if (_anchor == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final box = _anchor?.currentContext?.findRenderObject();
      if (box is RenderBox && _anchorY != null) {
        final delta = box.localToGlobal(Offset.zero).dy - _anchorY!;
        _scroll.jumpTo(
          (_scroll.offset + delta).clamp(0, _scroll.position.maxScrollExtent),
        );
      }
      _loadingEarlier.remove(date);
      if (_loadingEarlier.isEmpty) {
        _anchor = null;
        _anchorY = null;
      }
    });
  }

  void _earlier() {
    final date = dateKey(_weekStart(-_backWeeks));
    _anchor = _weekKeys[date];
    final box = _anchor?.currentContext?.findRenderObject();
    _anchorY = box is RenderBox ? box.localToGlobal(Offset.zero).dy : null;
    _loadingEarlier.addAll(
      List.generate(4, (i) => dateKey(_weekStart(-_backWeeks - i - 1))),
    );
    setState(() => _backWeeks += 4);
  }

  Future<void> _jump({bool today = false}) async {
    final chosen =
        today
            ? DateTime.now()
            : await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
    if (chosen == null || !mounted) return;
    setState(() {
      _date = DateUtils.dateOnly(chosen);
      _backWeeks = 0;
      _weeks = 4;
      _anchor = null;
      _loadingEarlier.clear();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  DateTime _weekStart(int offset) => DateTime(
    _date.year,
    _date.month,
    _date.day - _date.weekday + 1 + offset * 7,
  );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainingProgramProvider>();
    final p = state.active;
    final runningDates =
        context
            .watch<CardioProvider>()
            .occurrences
            .where((o) => o.planId == p?.id)
            .map((o) => o.date)
            .toList()
          ..sort();
    final calendarEnd =
        p?.endDate ??
        (p != null && p.currentSlots.isEmpty && runningDates.isNotEmpty
            ? runningDates.last
            : null);
    return Scaffold(
      appBar: AppBar(
        title: Text(p?.name ?? context.plan('myPlan')),
        actions: [
          if (p != null)
            IconButton(
              tooltip: context.plan('edit'),
              onPressed: () => openPlanSetup(context, plan: p),
              icon: const Icon(Icons.tune_outlined),
            ),
        ],
      ),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        children: [
          if (p == null && state.plans.isEmpty) const TrainingPlanCard(),
          if (p != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                [
                  if (p.currentSlots.any((s) => s.kind == 'strength'))
                    planLabel(context, p.strengthGoal),
                  if (p.hasRunning) planLabel(context, p.runningGoal),
                  DateFormat.yMMMd(
                    Localizations.localeOf(context).toString(),
                  ).format(p.start),
                  calendarEnd == null
                      ? context.plan('indefinite')
                      : DateFormat.yMMMd(
                        Localizations.localeOf(context).toString(),
                      ).format(calendarEnd),
                ].where((value) => value.trim().isNotEmpty).join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.fitness_center_outlined),
                  label: Text(context.plan('strength')),
                  onPressed:
                      () =>
                          openPlanSetup(context, plan: p, section: 'strength'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.directions_run),
                  label: Text(context.plan('running')),
                  onPressed:
                      () => openPlanSetup(context, plan: p, section: 'running'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_outline),
                  label: Text(context.strength('profileShort')),
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UserTrainingProfileScreen(),
                        ),
                      ),
                ),
                if (p.hasRunning)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.auto_graph_outlined),
                    label: Text(context.cardio('adapt')),
                    onPressed: () async {
                      await CardioScreen.showAdaptation(
                        context,
                        context.read<CardioProvider>(),
                      );
                      if (mounted) setState(() {});
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _jump(),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      DateFormat.yMMM(
                        Localizations.localeOf(context).toString(),
                      ).format(_date),
                    ),
                  ),
                ),
                if (_awayFromTop ||
                    _backWeeks > 0 ||
                    calendarDays(DateTime.now(), _weekStart(0)) < 0 ||
                    calendarDays(DateTime.now(), _weekStart(0)) >= 7) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _jump(today: true),
                    icon: const Icon(Icons.today_outlined),
                    label: Text(context.plan('today')),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _earlier,
              icon: const Icon(Icons.expand_less),
              label: Text(context.planning('earlierWeeks')),
            ),
            const SizedBox(height: 8),
            for (var week = -_backWeeks; week < _weeks; week++)
              if (week <= 0 ||
                  calendarEnd == null ||
                  !_weekStart(week).isAfter(calendarEnd))
                Padding(
                  key: _weekKeys.putIfAbsent(
                    dateKey(_weekStart(week)),
                    () => GlobalKey(),
                  ),
                  padding: const EdgeInsets.only(bottom: 16),
                  child: PlanWeekView(
                    key: ValueKey(
                      '${p.id}:${dateKey(_date)}:$week:${context.watch<ProgressProvider?>()?.entries.length}',
                    ),
                    program: p,
                    date: _weekStart(week),
                    onDateChanged: (_) {},
                    onLoaded: () => _restoreAnchor(dateKey(_weekStart(week))),
                  ),
                ),
            if (calendarEnd == null || !_weekStart(_weeks).isAfter(calendarEnd))
              TextButton(
                onPressed: () => setState(() => _weeks += 4),
                child: Text(context.planning('moreWeeks')),
              ),
            const SizedBox(height: 16),
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
                    final cardio = context.read<CardioProvider>();
                    final equipment = context.read<TrainingProfileProvider>();
                    if (saved.currentSlots.any((s) => s.kind == 'strength') &&
                        ProfileReadiness.strength(
                          await state.repository.userProfile(),
                          await equipment.profiles(),
                        ).isNotEmpty) {
                      if (!context.mounted) return;
                      final done = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => const UserTrainingProfileScreen(
                                strengthOnly: true,
                              ),
                        ),
                      );
                      if (done != true || !context.mounted) return;
                    }
                    if (saved.hasRunning &&
                        ProfileReadiness.running(cardio.profile).isNotEmpty) {
                      if (!context.mounted) return;
                      final done = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => CardioProfileScreen(
                                provider: cardio,
                                setupRepository: state.repository,
                              ),
                        ),
                      );
                      if (done != true || !context.mounted) return;
                    }
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
    this.todayOverride,
    this.onLoaded,
  });
  final TrainingProgram? program;
  final Widget? beforeEntries;
  final DateTime date;
  final DateTime? todayOverride;
  final VoidCallback? onLoaded;
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
    _entries.then((_) {
      if (mounted) widget.onLoaded?.call();
    }, onError: (Object _) {});
  }

  Future<void> _add(DateTime day) async {
    final plan = widget.program;
    if (plan == null ||
        day.isBefore(DateUtils.dateOnly(plan.start)) ||
        (plan.endDate != null && day.isAfter(plan.endDate!))) {
      return;
    }
    final sport = await choosePlanValue(context, 'typeQuestion', [
      'strength',
      'running',
      'mobility',
    ], 'strength');
    if (sport == null || !mounted) return;
    final store = context.read<TrainingProgramProvider>();
    final cardio = context.read<CardioProvider>();
    try {
      if (sport == 'running') {
        if (ProfileReadiness.running(cardio.profile).isNotEmpty) {
          final yes = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder:
                  (_) => CardioProfileScreen(
                    provider: cardio,
                    setupRepository: store.repository,
                  ),
            ),
          );
          if (yes != true || !mounted) return;
        }
        if (!mounted) return;
        final workout = await Navigator.push<CardioWorkout>(
          context,
          MaterialPageRoute(
            builder:
                (_) => CardioEditorScreen(
                  workout: CardioTraining.template(
                    'easy5k',
                    cardio.profile,
                    context.cardio,
                  ),
                  units: cardio.profile.units,
                ),
          ),
        );
        if (workout == null) return;
        await store.repository.addCardioOccurrence(plan, day, workout);
        await cardio.load();
      } else {
        final places = context.read<TrainingProfileProvider>();
        if (sport == 'strength' &&
            ProfileReadiness.strength(
              await store.repository.userProfile(),
              await places.profiles(),
            ).isNotEmpty) {
          if (!mounted) return;
          final yes = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder:
                  (_) => const UserTrainingProfileScreen(
                    strengthOnly: true,
                    setup: true,
                  ),
            ),
          );
          if (yes != true || !mounted) return;
        }
        if (!mounted) return;
        final id = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder:
                (_) => TrainingLibraryScreen(
                  initialSport: sport,
                  pickWorkout: true,
                ),
          ),
        );
        if (id == null) return;
        await store.repository.save(
          plan.copyWith(
            slots: [
              ...plan.slots,
              ProgramSlot(
                weekday: day.weekday,
                label: sport == 'strength' ? 'fullBody' : 'mobility',
                kind: sport,
                workoutId: id,
                from: day,
                until: day,
              ),
            ],
          ),
        );
      }
      await store.load();
      if (mounted) setState(_reload);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.plan('savingError'))));
      }
    }
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
                  planActions: _planActions(entry),
                ),
          ),
        );
      }
    }
    if (mounted) setState(_reload);
  }

  Widget _planActions(ProgramEntry e) =>
      e.completed || e.sessionId != null
          ? const SizedBox.shrink()
          : Wrap(
            spacing: 8,
            children: [
              for (final action in [
                'replaceWorkout',
                if (e.cardio == null && e.workoutId != null)
                  e.splitSourceId == null ? 'splitSession' : 'undoSplit',
              ])
                OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _actions(e, chosen: action);
                  },
                  child: Text(context.strength(action)),
                ),
            ],
          );

  Future<void> _drop(ProgramEntry e, DateTime date) async {
    final store = context.read<TrainingProgramProvider>(),
        cardio = context.read<CardioProvider>();
    try {
      if (e.cardio != null) {
        await cardio.repository.move(e.cardio!, date, future: false);
        await cardio.load();
      } else {
        await store.repository.moveStrength(
          widget.program!,
          e,
          date,
          future: false,
        );
      }
      await store.load();
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.strength('moved')),
          action: SnackBarAction(
            label: context.strength('undoMove'),
            onPressed: () async {
              try {
                // Read back before undoing: a workout started in the meantime stays protected.
                final moved =
                    (await store.repository.entries(
                      widget.program!,
                      date,
                      DateTime(date.year, date.month, date.day + 1),
                    )).where((x) => x.id == e.id).firstOrNull;
                if (moved == null ||
                    moved.completed ||
                    moved.sessionId != null) {
                  return;
                }
                if (moved.cardio != null) {
                  await cardio.repository.move(
                    moved.cardio!,
                    e.date,
                    future: false,
                  );
                  await cardio.load();
                } else {
                  await store.repository.moveStrength(
                    widget.program!,
                    moved,
                    e.date,
                    future: false,
                  );
                }
                await store.load();
                if (mounted) setState(_reload);
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.plan('savingError'))),
                  );
                }
              }
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.plan('savingError'))));
      }
    }
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
    final warning = planPlacementWarning(
      widget.program!,
      entry,
      date,
      neighbors,
    );
    final future = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: Text(c.plan('move')),
            content: warning != null ? Text(c.planning(warning)) : null,
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

  Widget _entry(ProgramEntry e) => PlanWorkoutTile(
    entry: e,
    onTap: () => _open(e),
    units: context.read<CardioProvider>().profile.units,
  );

  Future<void> _actions(ProgramEntry e, {required String chosen}) async {
    if (e.completed || e.sessionId != null) return;
    try {
      final store = context.read<TrainingProgramProvider>();
      if (chosen == 'replaceWorkout') {
        final id = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder:
                (_) => TrainingLibraryScreen(
                  initialSport: e.kind,
                  pickWorkout: true,
                ),
          ),
        );
        if (id == null || !mounted) return;
        await store.repository.replaceStrengthOccurrence(
          widget.program!,
          e,
          id,
        );
      } else if (chosen == 'splitSession') {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StrengthSplitScreen(entry: e)),
        );
      } else if (chosen == 'undoSplit') {
        await store.repository.undoSplit(e.splitSourceId!);
      }
      await store.load();
      if (mounted) await context.read<WorkoutProvider>().loadWorkouts();
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
      final entries = snapshot.data!;
      final selected =
          entries
              .where((e) => dateKey(e.date) == dateKey(widget.date))
              .toList();
      if (!widget.todayFirst) {
        return PlanWeekBlock(
          monday: _monday,
          planStart: widget.program?.start,
          planEnd: widget.program?.endDate,
          entries: entries,
          entryBuilder: _entry,
          onMove: widget.program == null ? null : _drop,
          onAccessibleMove: widget.program == null ? null : _move,
          onAdd: widget.program == null ? null : _add,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WeekActivityCard(
            date: widget.date,
            todayOverride: widget.todayOverride,
            entries: entries,
            streak: context.watch<ProgressProvider?>()?.currentStreak ?? 0,
            onDateChanged: widget.onDateChanged,
          ),
          const SizedBox(height: 16),
          if (widget.beforeEntries != null) widget.beforeEntries!,
          MotivationalQuoteCard(date: widget.todayOverride),
          if (widget.program != null || selected.isNotEmpty)
            const SizedBox(height: 16),
          if (selected.isEmpty && widget.program != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.planning('restDay')),
            ),
          for (final e in selected)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _entry(e),
            ),
        ],
      );
    },
  );
}

class PlannedCardioScreen extends StatefulWidget {
  const PlannedCardioScreen({
    super.key,
    required this.entry,
    this.onSave,
    this.preview = false,
  });
  final ProgramEntry entry;
  final Future<void> Function(CardioWorkout)? onSave;
  final bool preview;
  @override
  State<PlannedCardioScreen> createState() => _PlannedCardioScreenState();
}

class _PlannedCardioScreenState extends State<PlannedCardioScreen> {
  late CardioWorkout _workout = widget.entry.cardio!.workout;
  String? _error;
  bool _saving = false;
  Future<void> _changeWorkout({bool replace = false}) async {
    final p = context.read<CardioProvider>();
    final value = await Navigator.push<CardioWorkout>(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                replace
                    ? RunningWorkoutPicker(sport: _workout.sport)
                    : CardioEditorScreen(
                      workout: _workout,
                      units: p.profile.units,
                      lockSport: true,
                    ),
      ),
    );
    if (value == null || !mounted) return;
    setState(() => _saving = true);
    try {
      if (widget.onSave != null) {
        await widget.onSave!(value);
      } else {
        await p.repository.editOccurrence(widget.entry.cardio!, value);
        await p.load();
      }
      if (mounted) {
        setState(() {
          _workout = value;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'savingError');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CardioProvider>();
    final timeOnly = _workout.steps.every((s) => s.goal == StepGoal.time);
    final seconds =
        _workout.expandedSteps().fold<double>(
          0,
          (n, s) => n + (s.goal == StepGoal.time ? s.amount : 0),
        ) +
        [
          ..._workout.warmup,
          ..._workout.cooldown,
        ].fold<int>(0, (n, s) => n + s.seconds);
    final editable = !widget.entry.completed && widget.entry.sessionId == null;
    Widget routine(
      String title,
      List<RoutineStep> steps,
      IconData icon,
    ) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.cardio(title),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  CardioUnits.clock(
                    steps.fold<int>(0, (n, s) => n + s.seconds),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final step in steps)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${step.customName.isEmpty ? context.cardio(step.exercise) : step.customName} · ${CardioUnits.clock(step.seconds)}',
                ),
              ),
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(_workout.name)),
      bottomNavigationBar:
          widget.preview || !editable
              ? null
              : SafeArea(
                minimum: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed:
                      _saving
                          ? null
                          : () => startCardioWorkout(
                            context,
                            _workout,
                            occurrenceId: widget.entry.id,
                          ),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(context.cardio('start')),
                ),
              ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (timeOnly) ...[
            Text(
              '${context.cardio('time')}: ${CardioUnits.clock(seconds)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
          ],
          if (editable) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _changeWorkout(),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.plan('edit')),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _saving ? null : () => _changeWorkout(replace: true),
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(context.strength('replaceWorkout')),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          if (_workout.warmup.isNotEmpty) ...[
            routine('warmup', _workout.warmup, Icons.wb_sunny_outlined),
            const SizedBox(height: 16),
          ],
          Text(
            context.cardio('core'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final step in _workout.steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  title: Text(
                    '${step.repeat > 1 ? '${step.repeat} × ' : ''}${step.name.isEmpty ? context.cardio(step.intensity.name) : step.name}',
                  ),
                  subtitle: Text(
                    cardioStepDescription(step, p.profile.units, context),
                  ),
                ),
              ),
            ),
          if (_workout.cooldown.isNotEmpty) ...[
            const SizedBox(height: 8),
            routine('cooldown', _workout.cooldown, Icons.nights_stay_outlined),
          ],
          if (_error != null) PlanError(_error!),
        ],
      ),
    );
  }
}
