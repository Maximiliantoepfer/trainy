import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/plan_l10n.dart';
import '../l10n/cardio_l10n.dart';
import '../models/cardio.dart';
import '../models/training_program.dart';
import '../providers/cardio_provider.dart';
import '../providers/training_program_provider.dart';
import '../providers/workout_provider.dart';
import '../services/cardio_training.dart';
import '../widgets/plan_controls.dart';
import 'cardio_profile_screen.dart';
import 'cardio_editor_screen.dart';
import 'training_library_screen.dart';
import 'user_training_profile_screen.dart';

class TrainingPlanSetupScreen extends StatefulWidget {
  const TrainingPlanSetupScreen({
    super.key,
    this.existing,
    this.initialSection,
  });
  final TrainingProgram? existing;
  final String? initialSection;
  @override
  State<TrainingPlanSetupScreen> createState() =>
      _TrainingPlanSetupScreenState();
}

class _TrainingPlanSetupScreenState extends State<TrainingPlanSetupScreen> {
  final _name = TextEditingController(), _target = TextEditingController();
  final _form = GlobalKey<FormState>();
  TrainingProgram? _program;
  Set<String> _sports = {};
  Set<String> _configured = {};
  Set<int> _available = {1, 3, 5};
  int _step = 0, _week = 0;
  bool _busy = false, _ready = false, _runningChanged = false;
  String? _error;
  RunningPlanProposal? _running;
  Future<void> _writes = Future.value();
  String get _draftKey => 'plan:${widget.existing?.id ?? 'new'}';
  List<String> get _steps =>
      widget.initialSection != null
          ? [widget.initialSection!, 'preview']
          : [
            'interests',
            if (_sports.contains('strength')) 'strength',
            if (_sports.contains('running')) 'running',
            if (_sports.contains('mobility')) 'mobility',
            'preview',
          ];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<TrainingProgramProvider>().repository;
      final profile = await repo.userProfile(),
          draft = await repo.draft(_draftKey);
      if (!mounted) return;
      _program =
          widget.existing ??
          TrainingProgram(
            name: context.plan('myPlan'),
            start: DateUtils.dateOnly(DateTime.now()),
            strengthGoal: 'generalFitness',
            runningGoal: 'runFaster',
          );
      _sports =
          widget.existing == null
              ? profile.interests
                  .map((s) => s == 'cardio' ? 'running' : s)
                  .toSet()
              : {
                if (_program!.hasRunning) 'running',
                ..._program!.slots.map((s) => s.kind),
              };
      _available = widget.existing == null ? {1, 3, 5} : _program!.days;
      if (widget.initialSection != null) {
        _sports.add(widget.initialSection!);
        _available = {1, 2, 3, 4, 5, 6, 7};
      }
      _runningChanged = widget.existing == null;
      if (draft != null) {
        _program = TrainingProgram.fromJson(
          Map<String, dynamic>.from(draft['program'] as Map),
        );
        _sports = Set<String>.from(draft['sports'] as List);
        _available = Set<int>.from(draft['available'] as List);
        _step = draft['step'] as int? ?? 0;
        _runningChanged = draft['runningChanged'] == true;
        _configured = Set<String>.from(draft['configured'] as List? ?? []);
        final savedRunning = draft['running'] as Map?;
        if (savedRunning != null) {
          final r = Map<String, dynamic>.from(savedRunning);
          _running = RunningPlanProposal(
            id: r['id'] as String,
            request: RunningPlanRequest.fromJson(
              Map<String, dynamic>.from(r['request'] as Map),
            ),
            baseWeeks: r['baseWeeks'] as int,
            warnings: List<String>.from(r['warnings'] as List),
            occurrences: [
              for (final e in r['occurrences'] as List)
                ScheduledCardioWorkout(
                  id: e['id'] as String,
                  planId: r['id'] as String,
                  date: DateTime.parse(e['date'] as String),
                  workout: CardioWorkout.fromJson(
                    Map<String, dynamic>.from(e['workout'] as Map),
                  ),
                  locked: e['locked'] == true,
                ),
            ],
          );
        }
      }
      _step = _step.clamp(0, _steps.length - 1);
      _name.text = _program!.name;
      _target.text =
          draft?['targetText'] as String? ??
          (_program!.targetSeconds == null
              ? ''
              : CardioUnits.clock(_program!.targetSeconds!));
      _name.addListener(_persist);
      _target.addListener(_targetChanged);
      setState(() => _ready = true);
      if (_steps[_step] == 'preview' && _running == null) await _preview();
      if (draft != null &&
          widget.existing == null &&
          _steps[_step] == 'running' &&
          await repo.draft('running-profile') != null &&
          mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => CardioProfileScreen(
                  provider: context.read<CardioProvider>(),
                ),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'error');
    }
  }

  void _targetChanged() {
    _runningChanged = true;
    _running = null;
    _persist();
  }

  void _persist() {
    if (!_ready) return;
    _program = _program!.copyWith(name: _name.text);
    final repo = context.read<TrainingProgramProvider>().repository;
    final data = {
      'program': _program!.toJson(),
      'sports': _sports.toList(),
      'available': _available.toList(),
      'step': _step,
      'runningChanged': _runningChanged,
      'targetText': _target.text,
      'configured': _configured.toList(),
      if (_running != null)
        'running': {
          'id': _running!.id,
          'request': _running!.request.toJson(),
          'baseWeeks': _running!.baseWeeks,
          'warnings': _running!.warnings,
          'occurrences': [
            for (final o in _running!.occurrences)
              {
                'id': o.id,
                'date': dateKey(o.date),
                'workout': o.workout.toJson(),
                'locked': o.locked,
              },
          ],
        },
    };
    _writes = _writes.then((_) => repo.saveDraft(_draftKey, data)).catchError((
      Object e,
    ) {
      if (mounted) setState(() => _error = 'savingError');
    });
  }

  void _change(VoidCallback f, {bool running = false}) {
    setState(() {
      f();
      _error = null;
      if (running) {
        _runningChanged = true;
        _running = null;
      }
    });
    _persist();
  }

  void _setStrengthDays(Set<int> days, {String? split}) {
    final p = _program!,
        actual = split ?? ProgramSplits.recommended(days.length);
    final next = ProgramSplits.slots(days.toList(), actual);
    final slots = <ProgramSlot>[];
    for (final s in next) {
      final old =
          p.slots
              .where(
                (o) =>
                    o.kind == 'strength' &&
                    o.weekday == s.weekday &&
                    o.cycleWeek == s.cycleWeek &&
                    o.until == null,
              )
              .firstOrNull;
      slots.add(
        old == null
            ? s
            : old.copyWith(label: s.label, clearWorkout: old.label != s.label),
      );
    }
    final today = DateUtils.dateOnly(DateTime.now());
    for (final old in p.slots.where(
      (s) => s.kind == 'strength' && !slots.any((n) => n.id == s.id),
    )) {
      if (widget.existing != null) {
        slots.add(
          old.until != null
              ? old
              : old.copyWith(
                until: DateTime(today.year, today.month, today.day - 1),
              ),
        );
      }
    }
    _program = p.copyWith(
      split: actual,
      slots: [...p.slots.where((s) => s.kind != 'strength'), ...slots],
    );
  }

  List<ProgramSlot> get _currentSlots =>
      _program!.slots
          .where(
            (s) =>
                s.until == null ||
                !s.until!.isBefore(DateUtils.dateOnly(DateTime.now())),
          )
          .toList();
  void _distribute() {
    final days = _available.toList()..sort();
    if (widget.existing == null &&
        _program!.slots.isEmpty &&
        !_program!.hasRunning) {
      final running =
          _sports.contains('running')
              ? (_sports.contains('strength')
                  ? ProgramSplits.suggestedRunningDays(days)
                  : days)
              : <int>[];
      _program = _program!.copyWith(runningDays: running);
      if (_sports.contains('strength')) {
        final strength = days.where((d) => !running.contains(d)).toSet();
        _setStrengthDays(strength.isEmpty ? {days.first} : strength);
      }
    }
    if (!_sports.contains('running')) {
      _program = _program!.copyWith(runningDays: []);
    }
    _program = _program!.copyWith(
      slots: _program!.slots.where((s) => _sports.contains(s.kind)).toList(),
    );
    if (_sports.contains('mobility') &&
        !_program!.slots.any((s) => s.kind == 'mobility')) {
      _program = _program!.copyWith(
        slots: [
          ..._program!.slots,
          ProgramSlot(weekday: days.last, label: 'mobility', kind: 'mobility'),
        ],
      );
    }
  }

  Future<void> _preview() async {
    if (!_program!.hasRunning || !_runningChanged) return;
    final cardio = context.read<CardioProvider>();
    final p = await context
        .read<TrainingProgramProvider>()
        .repository
        .withRecentLoad(cardio.profile, DateTime.now());
    if (!mounted) return;
    final profile = AthleteRunningProfile.fromJson({
      ...p.toJson(),
      'weekdays': _program!.runningDays,
    });
    final seconds = CardioUnits.parseDuration(_target.text);
    _program = _program!.copyWith(
      targetSeconds: seconds,
      clearTargetTime: seconds == null,
    );
    _running = RunningPlanGenerator().generate(
      profile,
      RunningPlanRequest(
        targetMeters: _program!.targetMeters,
        startDate: _program!.start,
        targetSeconds: seconds,
        targetDate: _program!.targetDate,
      ),
      context.cardio,
    );
    if (mounted) setState(() {});
  }

  Future<void> _editRun(ScheduledCardioWorkout o) async {
    final workout = await Navigator.push<CardioWorkout>(
      context,
      MaterialPageRoute(
        builder:
            (_) => CardioEditorScreen(
              workout: o.workout,
              units: context.read<CardioProvider>().profile.units,
            ),
      ),
    );
    if (workout == null || !mounted || _running == null) return;
    final proposal = _running!;
    _change(
      () =>
          _running = RunningPlanProposal(
            id: proposal.id,
            request: proposal.request,
            baseWeeks: proposal.baseWeeks,
            warnings: proposal.warnings,
            occurrences: [
              for (final e in proposal.occurrences)
                e.id == o.id
                    ? ScheduledCardioWorkout(
                      id: e.id,
                      planId: e.planId,
                      date: e.date,
                      workout: workout,
                      locked: true,
                    )
                    : e,
            ],
          ),
    );
  }

  Future<void> _next() async {
    if (_busy) return;
    final step = _steps[_step];
    if (_form.currentState?.validate() != true) return;
    if (step == 'interests') {
      if (_sports.isEmpty || _available.isEmpty) {
        setState(
          () => _error = _sports.isEmpty ? 'chooseSport' : 'dayRequired',
        );
        return;
      }
      _distribute();
    }
    if (step == 'strength' && !_currentSlots.any((s) => s.kind == 'strength') ||
        step == 'running' && !_program!.hasRunning) {
      setState(() => _error = 'dayRequired');
      return;
    }
    final selectedDays =
        step == 'running'
            ? _program!.runningDays
            : _currentSlots.where((s) => s.kind == step).map((s) => s.weekday);
    if (selectedDays.any((d) => !_available.contains(d))) {
      setState(() => _error = 'changeDays');
      return;
    }
    setState(() => _busy = true);
    try {
      if (step == 'preview') {
        if (_program!.hasRunning &&
            _runningChanged &&
            widget.existing != null) {
          final yes = await showDialog<bool>(
            context: context,
            builder:
                (c) => AlertDialog(
                  title: Text(c.plan('regenerate')),
                  content: Text(c.plan('regenerateHint')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(c.plan('cancel')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(c.plan('next')),
                    ),
                  ],
                ),
          );
          if (yes != true) return;
        }
        if (!mounted) return;
        final store = context.read<TrainingProgramProvider>();
        await _writes;
        await store.repository.save(
          _program!.copyWith(name: _name.text),
          running: _runningChanged ? _running : null,
        );
        await store.repository.clearDraft(_draftKey);
        await store.load();
        if (!mounted) return;
        await context.read<CardioProvider>().load();
        if (mounted) Navigator.pop(context, true);
      } else {
        if (_steps[_step + 1] == 'preview') await _preview();
        if (mounted) _change(() => _step++);
        if (mounted &&
            widget.existing == null &&
            ['strength', 'running'].contains(_steps[_step]) &&
            !_configured.contains(_steps[_step])) {
          final sport = _steps[_step];
          _configured.add(sport);
          _persist();
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) =>
                      sport == 'strength'
                          ? const UserTrainingProfileScreen(
                            strengthOnly: true,
                            setup: true,
                          )
                          : CardioProfileScreen(
                            provider: context.read<CardioProvider>(),
                          ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'savingError');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.plan('savingError'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign(ProgramSlot s) async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                TrainingLibraryScreen(initialSport: s.kind, pickWorkout: true),
      ),
    );
    if (id != null && mounted) {
      _change(
        () =>
            _program = _program!.copyWith(
              slots:
                  _program!.slots
                      .map((o) => o.id == s.id ? o.copyWith(workoutId: id) : o)
                      .toList(),
            ),
      );
    }
  }

  Widget _choice(
    String title,
    String value,
    List<String> values,
    ValueChanged<String> apply,
  ) => Card(
    child: ListTile(
      title: Text(context.plan(title)),
      subtitle: Text(planLabel(context, value)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final v = await choosePlanValue(context, title, values, value);
        if (v != null && mounted) _change(() => apply(v));
      },
    ),
  );
  Widget _slot(ProgramSlot s) {
    final workout =
        context
            .watch<WorkoutProvider>()
            .workouts
            .where((w) => w.canonicalId == s.workoutId)
            .firstOrNull;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        s.kind == 'mobility' ? Icons.self_improvement : Icons.fitness_center,
      ),
      title: Text(workout?.name ?? planLabel(context, s.label)),
      subtitle: Text(
        '${DateFormat.E(Localizations.localeOf(context).toString()).format(DateTime(2024, 1, s.weekday))}${s.cycleWeek == 0 ? '' : ' · ${context.plan('weekNumber')} ${s.cycleWeek}'}${workout == null ? ' · ${context.plan('assignWorkout')}' : ''}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _assign(s),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _program, title = _ready ? _steps[_step] : 'createPlan';
    return PopScope(
      canPop: !_busy && _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_busy && _step > 0) _change(() => _step--);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            context.plan(widget.existing == null ? 'createPlan' : 'myPlan'),
          ),
          actions: [
            TextButton(
              onPressed:
                  _busy
                      ? null
                      : () async {
                        await _writes;
                        if (context.mounted) Navigator.pop(context);
                      },
              child: Text(context.plan('later')),
            ),
          ],
        ),
        bottomNavigationBar:
            !_ready
                ? null
                : SafeArea(
                  minimum: const EdgeInsets.all(20),
                  child: FilledButton(
                    onPressed: _busy ? null : _next,
                    child: Text(
                      context.plan(title == 'preview' ? 'activate' : 'next'),
                    ),
                  ),
                ),
        body:
            !_ready
                ? Center(
                  child: TextButton(
                    onPressed: _load,
                    child: Text(context.plan('retry')),
                  ),
                )
                : Form(
                  key: _form,
                  child: ListView(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.all(20),
                    children: [
                      LinearProgressIndicator(
                        value: (_step + 1) / _steps.length,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        context.plan(title),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 24),
                      if (title == 'interests') ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in ['strength', 'running', 'mobility'])
                              FilterChip(
                                label: Text(context.plan(s)),
                                selected: _sports.contains(s),
                                onSelected:
                                    (v) => _change(() {
                                      v ? _sports.add(s) : _sports.remove(s);
                                    }, running: s == 'running'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          context.plan('availableDays'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        PlanDayPicker(
                          selected: _available,
                          onChanged: (v) => _change(() => _available = v),
                        ),
                      ],
                      if (title == 'strength') ...[
                        Text(
                          context.plan('strengthDays'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        PlanDayPicker(
                          selected:
                              _currentSlots
                                  .where((s) => s.kind == 'strength')
                                  .map((s) => s.weekday)
                                  .toSet(),
                          available: _available,
                          onChanged: (v) => _change(() => _setStrengthDays(v)),
                        ),
                        const SizedBox(height: 24),
                        _choice(
                          'split',
                          p!.split,
                          ['fullBody', 'upperLower', 'pushPullLegs'],
                          (v) => _setStrengthDays(
                            _currentSlots
                                .where((s) => s.kind == 'strength')
                                .map((s) => s.weekday)
                                .toSet(),
                            split: v,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _choice(
                          'strengthGoal',
                          p.strengthGoal.isEmpty
                              ? 'generalFitness'
                              : p.strengthGoal,
                          ['generalFitness', 'buildMuscle', 'getStronger'],
                          (v) => _program = p.copyWith(strengthGoal: v),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.plan('strengthProfile')),
                          trailing: const Icon(Icons.chevron_right),
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => const UserTrainingProfileScreen(
                                        strengthOnly: true,
                                      ),
                                ),
                              ),
                        ),
                        for (final s in _currentSlots.where(
                          (s) => s.kind == 'strength',
                        ))
                          _slot(s),
                      ],
                      if (title == 'running') ...[
                        PlanDayPicker(
                          selected: p!.runningDays.toSet(),
                          available: _available,
                          onChanged:
                              (v) => _change(
                                () =>
                                    _program = p.copyWith(
                                      runningDays: v.toList()..sort(),
                                    ),
                                running: true,
                              ),
                        ),
                        const SizedBox(height: 24),
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(context.plan('runningProfile')),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              final changed = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => CardioProfileScreen(
                                        provider:
                                            context.read<CardioProvider>(),
                                      ),
                                ),
                              );
                              if (changed == true && mounted) {
                                _change(() {}, running: true);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        _choice(
                          'runningGoal',
                          p.runningGoal.isEmpty ? 'runFaster' : p.runningGoal,
                          ['runFaster', 'runFurther', 'firstDistance'],
                          (v) => _program = p.copyWith(runningGoal: v),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<double>(
                          value: p.targetMeters,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: context.plan('targetDistance'),
                          ),
                          items: [
                            for (final d in [5000.0, 10000.0, 21097.5, 42195.0])
                              DropdownMenuItem(
                                value: d,
                                child: Text(
                                  CardioUnits.distance(
                                    d,
                                    context
                                        .read<CardioProvider>()
                                        .profile
                                        .units,
                                    locale:
                                        Localizations.localeOf(
                                          context,
                                        ).toString(),
                                  ),
                                ),
                              ),
                          ],
                          onChanged:
                              (v) => _change(
                                () => _program = p.copyWith(targetMeters: v),
                                running: true,
                              ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _target,
                          keyboardType: TextInputType.datetime,
                          decoration: InputDecoration(
                            labelText: context.plan('targetTime'),
                            hintText: context.plan('durationHint'),
                            errorMaxLines: 3,
                          ),
                          validator:
                              (v) =>
                                  v == null ||
                                          v.trim().isEmpty ||
                                          CardioUnits.parseDuration(v) != null
                                      ? null
                                      : context.plan('durationError'),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.plan('targetDate')),
                          subtitle: Text(
                            p.targetDate == null
                                ? '—'
                                : DateFormat.yMMMd(
                                  Localizations.localeOf(context).toString(),
                                ).format(p.targetDate!),
                          ),
                          trailing:
                              p.targetDate == null
                                  ? const Icon(Icons.chevron_right)
                                  : IconButton(
                                    tooltip: context.plan('delete'),
                                    onPressed:
                                        () => _change(
                                          () =>
                                              _program = p.copyWith(
                                                clearTargetDate: true,
                                              ),
                                          running: true,
                                        ),
                                    icon: const Icon(Icons.clear),
                                  ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate:
                                  p.targetDate ??
                                  p.start.add(const Duration(days: 90)),
                              firstDate: p.start,
                              lastDate: DateTime(
                                p.start.year + 2,
                                p.start.month,
                                p.start.day,
                              ),
                            );
                            if (date != null && mounted) {
                              _change(
                                () => _program = p.copyWith(targetDate: date),
                                running: true,
                              );
                            }
                          },
                        ),
                      ],
                      if (title == 'mobility') ...[
                        PlanDayPicker(
                          selected:
                              _currentSlots
                                  .where((s) => s.kind == 'mobility')
                                  .map((s) => s.weekday)
                                  .toSet(),
                          available: _available,
                          onChanged:
                              (v) => _change(
                                () =>
                                    _program = p!.copyWith(
                                      slots: [
                                        ...p.slots.where(
                                          (s) => s.kind != 'mobility',
                                        ),
                                        for (final d in v)
                                          _currentSlots
                                                  .where(
                                                    (s) =>
                                                        s.kind == 'mobility' &&
                                                        s.weekday == d,
                                                  )
                                                  .firstOrNull ??
                                              ProgramSlot(
                                                weekday: d,
                                                label: 'mobility',
                                                kind: 'mobility',
                                              ),
                                      ],
                                    ),
                              ),
                        ),
                        for (final s in _currentSlots.where(
                          (s) => s.kind == 'mobility',
                        ))
                          _slot(s),
                      ],
                      if (title == 'preview') ...[
                        TextFormField(
                          controller: _name,
                          decoration: InputDecoration(
                            labelText: context.plan('name'),
                          ),
                          validator:
                              (v) =>
                                  v == null || v.trim().isEmpty
                                      ? context.plan('nameRequired')
                                      : null,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.plan('startDate')),
                          subtitle: Text(
                            DateFormat.yMMMd(
                              Localizations.localeOf(context).toString(),
                            ).format(p!.start),
                          ),
                          trailing:
                              widget.existing == null
                                  ? const Icon(Icons.chevron_right)
                                  : null,
                          onTap:
                              widget.existing != null
                                  ? null
                                  : () async {
                                    final now = DateUtils.dateOnly(
                                      DateTime.now(),
                                    );
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          p.start.isBefore(now) ? now : p.start,
                                      firstDate: now,
                                      lastDate: DateTime(now.year + 2),
                                    );
                                    if (date != null && mounted) {
                                      _change(
                                        () =>
                                            _program = p.copyWith(start: date),
                                        running: true,
                                      );
                                      try {
                                        await _preview();
                                      } catch (_) {
                                        if (mounted) {
                                          setState(() => _error = 'error');
                                        }
                                      }
                                    }
                                  },
                        ),
                        if (_currentSlots.any((s) => s.workoutId == null))
                          Text(
                            context.plan('missingWorkouts'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (p.runningDays.any(
                          (d) => _currentSlots.any((s) => s.weekday == d),
                        ))
                          PlanError('doubleDay'),
                        if (_currentSlots.any(
                          (s) =>
                              ProgramSplits.legHeavy(s.label) &&
                              p.runningDays.any(
                                (d) =>
                                    (s.weekday - d).abs() <= 1 ||
                                    (s.weekday - d).abs() == 6,
                              ),
                        )) ...[
                          Text(
                            context.plan('conflictHint'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          TextButton(
                            onPressed: () => _change(() => _step = 0),
                            child: Text(context.plan('changeDays')),
                          ),
                        ],
                        Row(
                          children: [
                            IconButton(
                              tooltip: context.plan('back'),
                              onPressed:
                                  _week == 0
                                      ? null
                                      : () => setState(() => _week--),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Text(
                                '${context.plan('weekNumber')} ${_week + 1}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            IconButton(
                              tooltip: context.plan('next'),
                              onPressed: () => setState(() => _week++),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        for (var d = 1; d <= 7; d++) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              DateFormat.E(
                                Localizations.localeOf(context).toString(),
                              ).format(DateTime(2024, 1, d)),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          for (final s in _currentSlots.where(
                            (s) =>
                                s.weekday == d &&
                                (s.cycleWeek == 0 ||
                                    s.cycleWeek == _week % 2 + 1),
                          ))
                            _slot(s),
                          for (final o
                              in _running?.occurrences.where(
                                    (o) =>
                                        o.date.weekday == d &&
                                        calendarDays(
                                                  o.date,
                                                  DateTime(
                                                    p.start.year,
                                                    p.start.month,
                                                    p.start.day -
                                                        p.start.weekday +
                                                        1,
                                                  ),
                                                ) ~/
                                                7 ==
                                            _week,
                                  ) ??
                                  <ScheduledCardioWorkout>[])
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.directions_run),
                              title: Text(o.workout.name),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _editRun(o),
                              subtitle: Text(
                                CardioUnits.clock(
                                  o.workout
                                      .expandedSteps()
                                      .where((s) => s.goal == StepGoal.time)
                                      .fold<double>(0, (a, s) => a + s.amount),
                                ),
                              ),
                            ),
                          if (!_runningChanged && p.runningDays.contains(d))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.directions_run),
                              title: Text(context.plan('running')),
                              subtitle: Text(context.plan('myPlan')),
                            ),
                        ],
                        if (_running != null) ...[
                          const SizedBox(height: 16),
                          for (final warning in _running!.warnings)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                context.cardio(warning),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          context.plan('planEstimate'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (_error != null) PlanError(_error!),
                    ],
                  ),
                ),
      ),
    );
  }
}
