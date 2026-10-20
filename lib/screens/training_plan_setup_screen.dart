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
import '../l10n/planning_l10n.dart';
import '../services/profile_readiness.dart';
import '../providers/training_profile_provider.dart';
import '../widgets/plan_week_block.dart';
import '../utils/goal_utils.dart';
import '../utils/uuid_v4.dart';
import '../l10n/strength_l10n.dart';
import '../models/strength_plan.dart';
import '../providers/exercise_provider.dart';
import 'strength_plan_wizard.dart';
import 'strength_proposal_screen.dart';
import 'workout_detail_screen.dart';
import 'training_plan_screen.dart' show PlannedCardioScreen;
import '../widgets/strength_focus_editor.dart';

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
  Set<int> _available = {1, 2, 3, 4, 5, 6, 7};
  int _strengthCount = 3, _runningCount = 3;
  int _step = 0, _previewWeeks = 4;
  bool _busy = false, _ready = false, _runningChanged = false;
  String? _error;
  RunningPlanProposal? _running;
  StrengthPlanProposal? _strength;
  final _protectedEntries = <String, ProgramEntry>{};
  var _strengthMoves = <String, String>{};
  final _strengthReplacements = <String, String>{};
  Set<String> _runningEdits = {};
  Future<void> _writes = Future.value();
  String get _draftKey => 'plan:${widget.existing?.id ?? 'new'}';
  DateTime _previewMonday(int week) {
    final start = _program!.start;
    return DateTime(
      start.year,
      start.month,
      start.day - start.weekday + 1 + week * 7,
    );
  }

  DateTime? get _previewEnd {
    final p = _program!;
    if (p.endDate != null || p.currentSlots.isNotEmpty) return p.endDate;
    final dates =
        (_running?.occurrences ??
                context.read<CardioProvider>().occurrences.where(
                  (o) => o.planId == p.id,
                ))
            .map((o) => o.date)
            .toList()
          ..sort();
    return dates.lastOrNull;
  }

  List<String> get _steps =>
      widget.existing != null && widget.initialSection != null
          ? [widget.initialSection!, 'preview']
          : [
            'interests',
            if (_sports.contains('strength')) 'strength',
            if (_sports.contains('strength')) 'runningTransition',
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
      final draft = await repo.draft(_draftKey);
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
              ? <String>{}
              : {
                if (_program!.hasRunning) 'running',
                ..._program!.slots.map((s) => s.kind),
              };
      _available = _program!.availableDays.toSet();
      if (widget.existing != null) {
        _strengthCount =
            _program!.currentSlots
                .where((s) => s.kind == 'strength')
                .map((s) => s.weekday)
                .toSet()
                .length;
        _runningCount = _program!.runningDays.length;
      }
      if (widget.initialSection != null) {
        _sports.add(widget.initialSection!);
      }
      _runningChanged = widget.existing == null;
      if (draft != null) {
        _program = TrainingProgram.fromJson(
          Map<String, dynamic>.from(draft['program'] as Map),
        );
        _sports = Set<String>.from(draft['sports'] as List);
        _available = Set<int>.from(draft['available'] as List);
        _strengthCount = draft['strengthCount'] as int? ?? 3;
        _runningCount = draft['runningCount'] as int? ?? 3;
        _step = draft['wizardVersion'] == 2 ? draft['step'] as int? ?? 0 : 0;
        if (draft['strength'] is Map) {
          _strength = StrengthPlanProposal.fromJson(
            Map<String, dynamic>.from(draft['strength']),
          );
        }
        _strengthMoves.addAll(
          Map<String, String>.from(draft['strengthMoves'] ?? const {}),
        );
        _strengthReplacements.addAll(
          Map<String, String>.from(draft['strengthReplacements'] ?? const {}),
        );
        _runningChanged = draft['runningChanged'] == true;
        _runningEdits = Set<String>.from(draft['runningEdits'] ?? const []);
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
                  planId: e['planId'] as String? ?? _program!.id,
                  date: DateTime.parse(e['date'] as String),
                  workout: CardioWorkout.fromJson(
                    Map<String, dynamic>.from(e['workout'] as Map),
                  ),
                  locked: e['locked'] == true,
                  status: e['status'] as String? ?? 'planned',
                  sessionId: e['sessionId'] as String?,
                ),
            ],
          );
        }
      }
      if (widget.existing != null) {
        for (final e in await repo.entries(
          widget.existing!,
          widget.existing!.start,
          DateTime(DateTime.now().year + 2),
        )) {
          if (e.completed || e.sessionId != null) _protectedEntries[e.id] = e;
        }
      }
      if (!mounted) return;
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
      if (_steps[_step] == 'running' && !await _ensureProfiles({'running'})) {
        _skipSport('running');
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
    _program = _program!.copyWith(
      name: _name.text,
      availableDays: _available.toList()..sort(),
    );
    final repo = context.read<TrainingProgramProvider>().repository;
    final data = {
      'wizardVersion': 2,
      'strength': _strength?.toJson(),
      'strengthMoves': {..._strengthMoves},
      'strengthReplacements': {..._strengthReplacements},
      'program': _program!.toJson(),
      'sports': _sports.toList(),
      'available': _available.toList(),
      'strengthCount': _strengthCount,
      'runningCount': _runningCount,
      'step': _step,
      'runningChanged': _runningChanged,
      'runningEdits': _runningEdits.toList(),
      'targetText': _target.text,
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
                'planId': o.planId,
                'date': dateKey(o.date),
                'workout': o.workout.toJson(),
                'locked': o.locked,
                'status': o.status,
                'sessionId': o.sessionId,
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
      _error = null;
      f();
      if (running) {
        _runningChanged = true;
        _running = null;
      }
    });
    _persist();
  }

  void _setStrengthDays(Set<int> days, {String? split}) {
    final p = _program!, actual = split ?? p.split;
    final next = ProgramSplits.slots(days.toList(), actual);
    final slots = <ProgramSlot>[];
    final moved =
        p.currentSlots
            .where((s) => s.kind == 'strength' && !days.contains(s.weekday))
            .toList();
    for (final s in next) {
      var old =
          p.slots
              .where(
                (o) =>
                    o.kind == 'strength' &&
                    o.weekday == s.weekday &&
                    o.cycleWeek == s.cycleWeek &&
                    o.until == null,
              )
              .firstOrNull;
      if (old == null && split == null && moved.isNotEmpty) {
        old = moved
            .removeAt(0)
            .copyWith(weekday: s.weekday, cycleWeek: s.cycleWeek);
      }
      slots.add(
        old == null
            ? s
            : split == null
            ? old
            : old.copyWith(
              label: s.label,
              focus: s.focus,
              clearWorkout: old.label != s.label,
            ),
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
      final strength =
          _sports.contains('strength')
              ? ProgramSplits.suggestedDays(days, _strengthCount)
              : <int>[];
      final running =
          _sports.contains('running')
              ? ProgramSplits.suggestedDays(
                days,
                _runningCount,
                avoid: strength.toSet(),
              )
              : <int>[];
      _program = _program!.copyWith(runningDays: running);
      if (_sports.contains('strength')) {
        _setStrengthDays(
          strength.toSet(),
          split: ProgramSplits.recommended(strength.length),
        );
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
    if (!await _ensureProfiles({'running'})) return;
    if (!mounted) return;
    final cardio = context.read<CardioProvider>();
    final p = cardio.profile;
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => PlannedCardioScreen(
              entry: ProgramEntry(
                id: o.id,
                planId: o.planId,
                date: o.date,
                name: o.workout.name,
                kind: 'running',
                cardio: o,
                completed: o.status == 'completed',
                sessionId: o.sessionId,
              ),
              preview: true,
              onSave: (workout) async {
                final proposal = _running;
                final items =
                    proposal?.occurrences ??
                    context
                        .read<CardioProvider>()
                        .occurrences
                        .where((e) => e.planId == _program!.id)
                        .toList();
                _change(() {
                  _runningEdits.add(o.id);
                  _runningChanged = true;
                  _running = RunningPlanProposal(
                    id: proposal?.id ?? _program!.id,
                    request:
                        proposal?.request ??
                        RunningPlanRequest(
                          targetMeters: _program!.targetMeters,
                          startDate: _program!.start,
                        ),
                    baseWeeks: proposal?.baseWeeks ?? 0,
                    warnings: proposal?.warnings ?? [],
                    occurrences: [
                      for (final e in items)
                        e.id == o.id
                            ? ScheduledCardioWorkout(
                              id: e.id,
                              planId: e.planId,
                              date: e.date,
                              workout: workout,
                              locked: true,
                              status: e.status,
                              sessionId: e.sessionId,
                            )
                            : e,
                    ],
                  );
                });
              },
            ),
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
      if (_sports.contains('running')) await _restoreRunningSettings();
      if (!mounted) return;
      final repo = context.read<TrainingProgramProvider>().repository;
      final user = await repo.userProfile();
      await repo.saveUserProfile(
        UserTrainingProfile.fromJson({
          ...user.toJson(),
          'interests': _sports.toList(),
          'interestsVersion': 1,
        }),
      );
      if (!mounted) return;
    }
    if (step == 'runningTransition') {
      await _restoreRunningSettings();
      if (!mounted) return;
      _sports.add('running');
      if (!_program!.hasRunning) {
        _program = _program!.copyWith(
          runningDays: ProgramSplits.suggestedDays(_available, _runningCount),
        );
      }
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
        if (_program!.days.isEmpty) {
          setState(() => _error = 'emptyPlanHint');
          return;
        }
        if (_generatedStrength != null &&
            (!_generatedStrength!.ready || !_generatedStrength!.reviewed)) {
          setState(() => _error = 'reviewRequired');
          return;
        }
        if (!await _ensureProfiles(_requiredSports)) return;
        if (!mounted) return;
        if (_program!.hasRunning && _runningChanged && _running == null) {
          await _preview();
          if (_running == null) return;
          if (!mounted) return;
        }
        if (_program!.endDate != null &&
            _running != null &&
            _running!.occurrences.any(
              (o) => o.date.isAfter(_program!.endDate!),
            )) {
          final proceed = await showDialog<bool>(
            context: context,
            builder:
                (c) => AlertDialog(
                  title: Text(c.plan('endDate')),
                  content: Text(c.plan('shortPlan')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(c.plan('cancel')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(c.plan('save')),
                    ),
                  ],
                ),
          );
          if (proceed != true || !mounted) return;
        }
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
        final locale = Localizations.localeOf(context).languageCode;
        await _writes;
        await store.repository.save(
          _program!.copyWith(name: _name.text),
          running: _runningChanged ? _running : null,
          strength: _generatedStrength,
          locale: locale,
          strengthMoves: _strengthMoves,
          strengthReplacements: _strengthReplacements,
          runningEdits: _runningEdits,
        );
        await store.repository.clearDraft(_draftKey);
        await store.load();
        if (!mounted) return;
        await context.read<WorkoutProvider>().loadWorkouts();
        if (!mounted) return;
        await context.read<ExerciseProvider?>()?.loadExercises();
        if (!mounted) return;
        await context.read<CardioProvider>().load();
        if (mounted) Navigator.pop(context, true);
      } else {
        final nextSport = _steps[_step + 1];
        if (nextSport == 'running' && !await _ensureProfiles({nextSport})) {
          if (mounted) _skipSport('running');
          return;
        }
        if (_steps[_step + 1] == 'preview') await _preview();
        if (mounted) _change(() => _step++);
      }
    } catch (error, stack) {
      debugPrint('Saving training plan failed: $error\n$stack');
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

  /// Manually assigned workouts replace their generated draft, including its
  /// readiness check; an unused reduced draft must not block activation.
  StrengthPlanProposal? get _generatedStrength =>
      _strength == null
          ? null
          : StrengthPlanProposal(
            workouts:
                _strength!.workouts
                    .where(
                      (w) => _program!.slots.any(
                        (s) => s.id == w.slotId && s.workoutId == null,
                      ),
                    )
                    .toList(),
          );

  Set<String> get _requiredSports =>
      widget.existing != null && widget.initialSection != null
          ? {widget.initialSection!}
          : _sports;

  Future<void> _restoreRunningSettings() async {
    final draft = await context
        .read<TrainingProgramProvider>()
        .repository
        .draft('running-plan:${_program!.id}');
    if (draft == null || !mounted) return;
    final deferred = TrainingProgram.fromJson(draft);
    _program = _program!.copyWith(
      runningDays: deferred.runningDays,
      runningGoal: deferred.runningGoal,
      targetMeters: deferred.targetMeters,
      targetSeconds: deferred.targetSeconds,
      targetDate: deferred.targetDate,
    );
    if (deferred.targetSeconds != null) {
      _target.text = CardioUnits.clock(deferred.targetSeconds!);
    }
  }

  Future<void> _skipSport(String sport) async {
    if (widget.existing != null && widget.initialSection == sport) {
      Navigator.pop(context, false);
      return;
    }
    if (sport == 'running') {
      await context.read<TrainingProgramProvider>().repository.saveDraft(
        'running-plan:${_program!.id}',
        _program!.toJson(),
      );
      if (!mounted) return;
    }
    _change(() {
      _sports.remove(sport);
      if (sport == 'running') {
        _program = _program!.copyWith(runningDays: []);
        _running = null;
      } else {
        _program = _program!.copyWith(
          slots: _program!.slots.where((s) => s.kind != sport).toList(),
        );
        if (sport == 'strength') _strength = null;
      }
      _step = _steps.length - 1;
      if (sport == 'strength' && _sports.contains('running')) {
        _step = _steps.indexOf('runningTransition');
      }
      if (_step < 0) _step = _steps.indexOf('running');
      if (_step < 0) _step = _steps.length - 1;
    });
    if (_steps[_step] == 'running' &&
        !await _ensureProfiles({'running'}) &&
        mounted) {
      await _skipSport('running');
    }
  }

  void _strengthComplete(StrengthSetupResult result) {
    _change(() {
      _strength = result.proposal;
      _program = _program!.copyWith(
        strengthGoal: result.goal,
        strengthSettings: {
          ...result.settings,
          'proposal': result.proposal.toJson(),
        },
        slots: [
          ..._program!.slots.where((s) => s.kind != 'strength'),
          ...result.slots,
        ],
      );
      _step = _steps.indexOf('runningTransition');
      if (_step < 0) _step = _steps.length - 1;
    });
  }

  Future<bool> _ensureProfiles(Set<String> sports) async {
    for (final sport in sports.where(
      (s) => s == 'strength' || s == 'running',
    )) {
      if (!mounted) return false;
      final cardio = context.read<CardioProvider>();
      final repo = context.read<TrainingProgramProvider>().repository;
      final places = context.read<TrainingProfileProvider>();
      Future<bool> ready() async =>
          sport == 'running'
              ? ProfileReadiness.running(cardio.profile).isEmpty
              : ProfileReadiness.strength(
                await repo.userProfile(),
                await places.profiles(),
              ).isEmpty;
      if (await ready()) continue;
      if (!mounted) return false;
      final completed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder:
              (_) =>
                  sport == 'running'
                      ? CardioProfileScreen(
                        provider: cardio,
                        setupRepository: repo,
                      )
                      : const UserTrainingProfileScreen(
                        strengthOnly: true,
                        setup: true,
                      ),
        ),
      );
      if (!mounted) return false;
      if (completed != true || !await ready()) {
        if (mounted) setState(() => _error = 'profileRequired');
        return false;
      }
      if (sport == 'running') {
        _running = null;
        _runningChanged = true;
      }
    }
    return true;
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

  Future<void> _editSlot(ProgramSlot slot) async {
    final result = await editStrengthFocus(context, slot);
    if (result != null && mounted) {
      _change(
        () =>
            _program = _program!.copyWith(
              slots: [
                for (final s in _program!.slots) s.id == slot.id ? result : s,
              ],
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
      leading: GoalIcon(s.kind),
      title: Text(planLabel(context, s.label)),
      subtitle: Text(
        '${DateFormat.E(Localizations.localeOf(context).toString()).format(DateTime(2024, 1, s.weekday))}${s.cycleWeek == 0 ? '' : ' · ${context.plan('weekNumber')} ${s.cycleWeek}'} · ${workout?.name ?? context.plan('assignWorkout')}',
      ),
      trailing: IconButton(
        tooltip: context.plan('assignWorkout'),
        icon: const Icon(Icons.fitness_center),
        onPressed: () => _assign(s),
      ),
      onTap: () => s.kind == 'strength' ? _editSlot(s) : _assign(s),
    );
  }

  Future<void> _reviewStrength(
    StrengthWorkoutDraft draft, {
    Widget? planActions,
  }) async {
    final places = await context.read<TrainingProfileProvider>().profiles();
    if (!mounted) return;
    final result = await Navigator.push<StrengthWorkoutDraft>(
      context,
      MaterialPageRoute(
        builder:
            (_) => StrengthProposalScreen(
              workout: draft,
              places: places,
              planActions: planActions,
            ),
      ),
    );
    if (result != null && mounted) {
      _change(
        () =>
            _strength = StrengthPlanProposal(
              workouts: [
                for (final w in _strength!.workouts)
                  w.id == result.id ? result : w,
              ],
            ),
      );
    }
  }

  List<ProgramEntry> _strengthPreviewEntries(DateTime monday) {
    final p = _program!, result = <ProgramEntry>[];
    var horizon = DateTime(monday.year, monday.month, monday.day + 7);
    for (final key in _strengthMoves.keys) {
      final original = DateTime.tryParse(
        key.substring(key.lastIndexOf(':') + 1),
      );
      if (original != null && !original.isBefore(horizon)) {
        horizon = DateTime(original.year, original.month, original.day + 1);
      }
    }
    final firstMonday = DateTime(
      p.start.year,
      p.start.month,
      p.start.day - p.start.weekday + 1,
    );
    for (
      var date = DateUtils.dateOnly(p.start);
      date.isBefore(horizon);
      date = DateTime(date.year, date.month, date.day + 1)
    ) {
      if (p.endDate != null && date.isAfter(p.endDate!)) break;
      final week = calendarDays(date, firstMonday) ~/ 7;
      for (final slot in p.slots.where(
        (s) =>
            s.weekday == date.weekday &&
            (s.cycleWeek == 0 || s.cycleWeek == week % 2 + 1) &&
            (s.from == null || !date.isBefore(s.from!)) &&
            (s.until == null || !date.isAfter(s.until!)),
      )) {
        final id = '${slot.id}:${dateKey(date)}';
        final target =
            _strengthMoves[id] == null
                ? date
                : DateTime.parse(_strengthMoves[id]!);
        if (calendarDays(target, monday) < 0 ||
            calendarDays(target, monday) >= 7) {
          continue;
        }
        final protected = _protectedEntries[id];
        if (protected != null) {
          result.add(protected);
          continue;
        }
        final draft =
            _generatedStrength?.workouts
                .where((w) => w.slotId == slot.id)
                .firstOrNull;
        final assigned =
            context
                .read<WorkoutProvider>()
                .workouts
                .where(
                  (w) =>
                      w.canonicalId ==
                      (_strengthReplacements[id] ?? slot.workoutId),
                )
                .firstOrNull;
        result.add(
          ProgramEntry(
            id: id,
            planId: p.id,
            date: target,
            originalDate: date,
            name: assigned?.name ?? draft?.name ?? slot.label,
            kind: slot.kind,
            slotId: slot.id,
            workoutId: _strengthReplacements[id] ?? slot.workoutId ?? draft?.id,
          ),
        );
      }
    }
    return result;
  }

  String? _proposalSummary(ProgramEntry e) {
    if (_strengthReplacements.containsKey(e.id)) return null;
    final w =
        _generatedStrength?.workouts
            .where((w) => w.slotId == e.slotId)
            .firstOrNull;
    final v = w?.variants.firstOrNull;
    return v == null
        ? null
        : '${v.exercises.length} ${context.strength('exercises')} · ~${(v.estimatedSeconds / 60).ceil()} min';
  }

  Future<void> _choosePreviewDate(ProgramEntry e) async {
    final date = await showDatePicker(
      context: context,
      initialDate: e.date,
      firstDate: _program!.start,
      lastDate: _program!.endDate ?? DateTime(2100),
    );
    if (date != null && mounted) _movePreview(e, date);
  }

  void _movePreview(ProgramEntry e, DateTime date) {
    if (e.completed || e.sessionId != null) return;
    final previousMoves = Map<String, String>.from(_strengthMoves),
        previousRunning = _running;
    final wasRunningChanged = _runningChanged;
    final previousRunningEdits = {..._runningEdits};
    _change(() {
      if (e.cardio == null) {
        _strengthMoves[e.id] = dateKey(date);
      } else {
        _runningEdits.add(e.id);
        final source = _running;
        final items =
            source?.occurrences ??
            context
                .read<CardioProvider>()
                .occurrences
                .where((o) => o.planId == _program!.id)
                .toList();
        _running = RunningPlanProposal(
          id: source?.id ?? _program!.id,
          request:
              source?.request ??
              RunningPlanRequest(
                targetMeters: _program!.targetMeters,
                startDate: _program!.start,
              ),
          baseWeeks: source?.baseWeeks ?? 0,
          warnings: source?.warnings ?? [],
          occurrences: [
            for (final o in items)
              o.id == e.id
                  ? ScheduledCardioWorkout(
                    id: o.id,
                    planId: o.planId,
                    date: date,
                    workout: o.workout,
                    locked: true,
                    status: o.status,
                    sessionId: o.sessionId,
                  )
                  : o,
          ],
        );
        _runningChanged = true;
      }
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.strength('moved')),
        action: SnackBarAction(
          label: context.strength('undoMove'),
          onPressed: () {
            _change(() {
              _strengthMoves = previousMoves;
              _running = previousRunning;
              _runningChanged = wasRunningChanged;
              _runningEdits = previousRunningEdits;
            });
          },
        ),
      ),
    );
  }

  Widget _weekPreview(int week) {
    final p = _program!;
    final monday = DateTime(
      p.start.year,
      p.start.month,
      p.start.day - p.start.weekday + 1 + week * 7,
    );
    final running =
        _running?.occurrences ??
        context
            .read<CardioProvider>()
            .occurrences
            .where((e) => e.planId == p.id)
            .toList();
    final entries = <ProgramEntry>[
      ..._strengthPreviewEntries(monday),
      for (final o in running)
        if (calendarDays(o.date, monday) >= 0 &&
            calendarDays(o.date, monday) < 7 &&
            (p.endDate == null || !o.date.isAfter(p.endDate!)))
          _protectedEntries[o.id] ??
              ProgramEntry(
                id: o.id,
                planId: p.id,
                date: o.date,
                name: o.workout.name,
                kind: 'running',
                cardio: o,
                completed: o.status == 'completed',
                sessionId: o.sessionId,
              ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entries.any(
          (e) => planPlacementWarning(p, e, e.date, entries) != null,
        ))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(context.planning('strengthOverlap')),
          ),
        PlanWeekBlock(
          monday: monday,
          planStart: p.start,
          planEnd: p.endDate,
          entries: entries,
          onAdd: _addPreview,
          onMove: _movePreview,
          onAccessibleMove: _choosePreviewDate,
          entryBuilder:
              (e) => PlanWorkoutTile(
                entry: e,
                units: context.read<CardioProvider>().profile.units,
                detail: _proposalSummary(e),
                onTap: () => _openPreviewEntry(e),
              ),
        ),
      ],
    );
  }

  Future<void> _replacePreviewStrength(ProgramEntry e) async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                TrainingLibraryScreen(initialSport: e.kind, pickWorkout: true),
      ),
    );
    if (id == null || !mounted) return;
    _change(() => _strengthReplacements[e.id] = id);
  }

  Future<void> _openPreviewEntry(ProgramEntry e) async {
    if (e.cardio != null) {
      await _editRun(e.cardio!);
      return;
    }
    final Widget? actions =
        _protectedEntries.containsKey(e.id)
            ? null
            : OutlinedButton.icon(
              icon: const Icon(Icons.swap_horiz),
              label: Text(context.strength('replaceWorkout')),
              onPressed: () async {
                Navigator.pop(context);
                await _replacePreviewStrength(e);
              },
            );
    final assigned =
        context
            .read<WorkoutProvider>()
            .workouts
            .where((w) => w.canonicalId == e.workoutId)
            .firstOrNull;
    if (assigned != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) =>
                  WorkoutDetailScreen(workout: assigned, planActions: actions),
        ),
      );
      return;
    }
    final draft =
        _generatedStrength?.workouts
            .where((w) => w.slotId == e.slotId)
            .firstOrNull;
    if (draft != null) {
      await _reviewStrength(draft, planActions: actions);
    } else if (!_protectedEntries.containsKey(e.id)) {
      await _replacePreviewStrength(e);
    }
  }

  Future<void> _addPreview(DateTime date) async {
    final p = _program!;
    if (date.isBefore(p.start) ||
        (p.endDate != null && date.isAfter(p.endDate!))) {
      return;
    }
    final choices = _sports.toList();
    final sport = await choosePlanValue(
      context,
      'typeQuestion',
      choices,
      choices.first,
    );
    if (sport == null || !mounted || !await _ensureProfiles({sport})) return;
    if (!mounted) return;
    if (sport != 'running') {
      final s = ProgramSlot(
        weekday: date.weekday,
        kind: sport,
        label: sport == 'strength' ? 'fullBody' : 'mobility',
        from: date,
        until: date,
      );
      _change(
        () => _program = _program!.copyWith(slots: [..._program!.slots, s]),
      );
      await _assign(s);
      return;
    }
    final cardio = context.read<CardioProvider>();
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
    if (workout == null || !mounted) return;
    final previous = _running;
    _change(() {
      _runningChanged = true;
      _program = _program!.copyWith(
        runningDays: {..._program!.runningDays, date.weekday}.toList()..sort(),
      );
      _running = RunningPlanProposal(
        id: previous?.id ?? p.id,
        request:
            previous?.request ??
            RunningPlanRequest(
              targetMeters: p.targetMeters,
              startDate: p.start,
            ),
        baseWeeks: previous?.baseWeeks ?? 0,
        warnings: previous?.warnings ?? [],
        occurrences: [
          ...previous?.occurrences ??
              cardio.occurrences.where((e) => e.planId == p.id),
          ScheduledCardioWorkout(
            id: UuidV4.generate(),
            planId: previous?.id ?? p.id,
            date: date,
            workout: workout,
            locked: true,
          ),
        ],
      );
    });
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
    if (_ready && title == 'strength') {
      return StrengthPlanWizard(
        key: ValueKey('strength-wizard-${p!.id}'),
        program: p,
        onComplete: _strengthComplete,
        onSkip: () => _skipSport('strength'),
      );
    }
    return PopScope(
      canPop: !_busy && _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_busy && _step > 0) _change(() => _step--);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed:
                _busy
                    ? null
                    : () {
                      if (_step > 0) {
                        _change(() => _step--);
                      } else {
                        Navigator.maybePop(context);
                      }
                    },
          ),
          title: Text(
            context.plan(widget.existing == null ? 'createPlan' : 'myPlan'),
          ),
          actions: [
            TextButton(
              onPressed:
                  _busy
                      ? null
                      : () async {
                        if (title == 'running') {
                          await _skipSport('running');
                          return;
                        }
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
                      title == 'runningTransition'
                          ? context.strength('configureRunning')
                          : context.plan(
                            title == 'preview' ? 'activate' : 'next',
                          ),
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
                        value: _busy ? null : (_step + 1) / _steps.length,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        title == 'interests'
                            ? context.planning('chooseTraining')
                            : context.strength(title),
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
                      ],
                      if (title == 'runningTransition') ...[
                        Text(context.strength('strengthPrepared')),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => _skipSport('running'),
                          child: Text(
                            context.strength('continueWithoutRunning'),
                          ),
                        ),
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
                            suffixText: 'min',
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
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.plan('endDate')),
                          subtitle: Text(
                            p!.endDate == null
                                ? context.plan('indefinite')
                                : DateFormat.yMMMd(
                                  Localizations.localeOf(context).toString(),
                                ).format(p.endDate!),
                          ),
                          trailing:
                              p.endDate == null
                                  ? const Icon(Icons.chevron_right)
                                  : IconButton(
                                    tooltip: context.plan('delete'),
                                    icon: const Icon(Icons.clear),
                                    onPressed:
                                        () => _change(
                                          () =>
                                              _program = p.copyWith(
                                                clearEndDate: true,
                                              ),
                                        ),
                                  ),
                          onTap: () async {
                            final end = await showDatePicker(
                              context: context,
                              initialDate:
                                  p.endDate ??
                                  p.start.add(const Duration(days: 90)),
                              firstDate: p.start,
                              lastDate: DateTime(2100),
                            );
                            if (end != null && mounted) {
                              _change(
                                () => _program = p.copyWith(endDate: end),
                              );
                            }
                          },
                        ),
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
                            ).format(p.start),
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
                        for (var week = 0; week < _previewWeeks; week++)
                          if (_previewEnd == null ||
                              !_previewMonday(week).isAfter(_previewEnd!))
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: _weekPreview(week),
                            ),
                        if (_previewEnd == null ||
                            !_previewMonday(
                              _previewWeeks,
                            ).isAfter(_previewEnd!))
                          TextButton(
                            onPressed: () => setState(() => _previewWeeks += 4),
                            child: Text(context.planning('moreWeeks')),
                          ),
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
                      if (_error != null)
                        Text(
                          context.planning(_error!),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
      ),
    );
  }
}
