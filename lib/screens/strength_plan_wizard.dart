import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/strength_l10n.dart';
import '../models/strength_plan.dart';
import '../models/training_program.dart';
import '../models/training_profile.dart';
import '../providers/training_profile_provider.dart';
import '../providers/training_program_provider.dart';
import '../services/catalog_repository.dart';
import '../services/profile_readiness.dart';
import '../services/strength_planning.dart';
import '../widgets/plan_controls.dart';
import '../widgets/profile_question.dart';
import '../widgets/strength_focus_editor.dart';
import 'strength_profile_screen.dart';
import 'strength_proposal_screen.dart';

class StrengthSetupResult {
  const StrengthSetupResult(
    this.slots,
    this.proposal,
    this.goal,
    this.settings,
  );
  final List<ProgramSlot> slots;
  final StrengthPlanProposal proposal;
  final String goal;
  final Map<String, dynamic> settings;
}

class StrengthPlanWizard extends StatefulWidget {
  const StrengthPlanWizard({
    super.key,
    required this.program,
    required this.onComplete,
    required this.onSkip,
  });
  final TrainingProgram program;
  final ValueChanged<StrengthSetupResult> onComplete;
  final VoidCallback onSkip;
  @override
  State<StrengthPlanWizard> createState() => _StrengthPlanWizardState();
}

class _StrengthPlanWizardState extends State<StrengthPlanWizard> {
  final _form = GlobalKey<FormState>();
  final _minutes = TextEditingController(text: '45');
  List<TrainingProfileRecord> _places = [];
  UserTrainingProfile _user = const UserTrainingProfile();
  List<ProgramSlot> _slots = [];
  StrengthPlanProposal? _proposal;
  Set<int> _available = {1, 2, 3, 4, 5, 6, 7};
  String _pair = 'mixedSplit', _secondPair = 'mixedSplit';
  int _count = 3, _step = 0;
  bool _ready = false, _busy = false, _own = false, _customTime = false;
  String? _error;
  Future<void> _writes = Future.value();
  String get _key => 'strength-plan:${widget.program.id}';
  int get _time => int.tryParse(_minutes.text) ?? 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final repo = context.read<TrainingProgramProvider>().repository;
      _user = await repo.userProfile();
      if (!mounted) return;
      _places = await context.read<TrainingProfileProvider>().profiles();
      if (!mounted) return;
      if (ProfileReadiness.strengthForGeneration(_user, _places).isNotEmpty) {
        final done = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const StrengthProfileScreen()),
        );
        if (!mounted) return;
        if (done != true) {
          widget.onSkip();
          return;
        }
        _user = await repo.userProfile();
        if (!mounted) return;
        _places = await context.read<TrainingProfileProvider>().profiles();
      }
      if (!await CatalogRepository.instance.load()) {
        throw StateError('Catalog unavailable');
      }
      final draft = await repo.draft(_key);
      if (!mounted) return;
      final settings = draft ?? widget.program.strengthSettings;
      _count = (settings['count'] as int? ?? 3).clamp(1, 7);
      _minutes.text = '${settings['minutes'] as int? ?? 45}';
      _customTime = ![30, 45, 60, 75].contains(_time);
      _pair = settings['pair'] as String? ?? 'mixedSplit';
      _secondPair = settings['secondPair'] as String? ?? _pair;
      _available = Set<int>.from(
        settings['available'] ?? widget.program.availableDays,
      );
      _own = settings['own'] == true;
      _step = (draft?['step'] as int? ?? 0).clamp(0, 3);
      _slots =
          draft?['slots'] == null
              ? widget.program.currentSlots
                  .where((s) => s.kind == 'strength')
                  .toList()
              : [
                for (final s in draft!['slots'])
                  ProgramSlot.fromJson(Map<String, dynamic>.from(s)),
              ];
      if (draft?['proposal'] != null) {
        _proposal = StrengthPlanProposal.fromJson(
          Map<String, dynamic>.from(draft!['proposal']),
        );
      }
      _minutes.addListener(_persist);
      setState(() => _ready = true);
    } catch (error, stack) {
      debugPrint('Strength setup loading failed: $error\n$stack');
      if (mounted) setState(() => _error = 'error');
    }
  }

  Map<String, dynamic> get _settings => {
    'version': 1,
    'count': _count,
    'minutes': _time,
    'pair': _pair,
    'secondPair': _secondPair,
    'available': _available.toList()..sort(),
    'own': _own,
  };
  void _persist() {
    if (!_ready) return;
    final repo = context.read<TrainingProgramProvider>().repository;
    final data = {
      ..._settings,
      'step': _step,
      'slots': _slots.map((s) => s.toJson()).toList(),
      if (_proposal != null) 'proposal': _proposal!.toJson(),
    };
    _writes = _writes.then((_) => repo.saveDraft(_key, data)).catchError((
      Object _,
    ) {
      if (mounted) setState(() => _error = 'savingError');
    });
  }

  void _change(VoidCallback f) {
    setState(() {
      _error = null;
      f();
    });
    _persist();
  }

  Future<void> _skip() async {
    _persist();
    await _writes;
    if (mounted) widget.onSkip();
  }

  Future<bool> _confirmRegeneration() async {
    if (_proposal == null) return true;
    return await showDialog<bool>(
          context: context,
          builder:
              (c) => AlertDialog(
                title: Text(c.strength('regenerate')),
                content: Text(c.strength('regenerateHint')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(c.strength('cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(c.strength('regenerate')),
                  ),
                ],
              ),
        ) ==
        true;
  }

  List<String> get _labels =>
      _count == 7
          ? List.filled(7, 'custom')
          : _count == 4
          ? [
            ...StrengthPlanning.labels(4, pair: _pair).take(2),
            ...StrengthPlanning.labels(4, pair: _secondPair).take(2),
          ]
          : StrengthPlanning.labels(_count, pair: _pair);
  List<int> get _suggested => StrengthPlanning.suggestDays(
    _available.toList(),
    _labels.map(StrengthPlanning.focus).toList(),
  );
  bool get _spacingFits =>
      _suggested.length == _count &&
      StrengthPlanning.recoveryConflicts(
            _suggested,
            _labels.map(StrengthPlanning.focus).toList(),
          ) ==
          0;
  Future<void> _next() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_step == 0 && _count == 7 && !_own) {
      _change(() => _error = 'answerRequired');
      return;
    }
    if (_step == 2 &&
        (_available.length < _count || (!_spacingFits && !_own))) {
      _change(() => _error = 'dayRequired');
      return;
    }
    if (_step < 2) {
      _change(() => _step++);
      return;
    }
    if (_step == 2) {
      if (!await _confirmRegeneration() || !mounted) return;
      final labels = _labels, days = _suggested;
      // Explicit regeneration gets new slot identities; existing history stays intact.
      _slots = [
        for (var i = 0; i < days.length; i++)
          ProgramSlot(
            weekday: days[i],
            label: labels[i],
            focus: StrengthPlanning.focus(labels[i]).toList(),
          ),
      ];
      await _generate();
      if (mounted && _proposal != null) _change(() => _step = 3);
      return;
    }
    if (_proposal == null ||
        !_proposal!.ready ||
        !_proposal!.reviewed ||
        _slots.any((s) => s.effectiveFocus.isEmpty)) {
      _change(() => _error = 'reviewRequired');
      return;
    }
    await _writes;
    if (mounted) {
      widget.onComplete(
        StrengthSetupResult(_slots, _proposal!, _user.strengthGoal, _settings),
      );
    }
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final proposal = StrengthPlanning.generate(
        planId: widget.program.id,
        user: _user,
        places: _places,
        slots: _slots,
        goal: _user.strengthGoal,
        minutes: _time,
        label: (key) {
          final known = [
            ...StrengthPlanning.labels(6),
            'upper',
            'lowerCore',
            'fullBody',
            'custom',
            'pullLegs',
          ];
          return known.contains(key) ? context.strength(key) : key;
        },
      );
      if (mounted) _change(() => _proposal = proposal);
    } catch (_) {
      if (mounted) _change(() => _error = 'error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editDay(ProgramSlot slot) async {
    final result = await editStrengthFocus(context, slot);
    if (result == null || !mounted) return;
    _change(() {
      _slots = [for (final s in _slots) s.id == slot.id ? result : s];
    });
    final proposal = StrengthPlanning.generate(
      planId: widget.program.id,
      user: _user,
      places: _places,
      slots: [result],
      goal: _user.strengthGoal,
      minutes: _time,
      label:
          (s) =>
              [
                    'pushCore',
                    'pullLegs',
                    'push',
                    'pull',
                    'legs',
                    'upper',
                    'lowerCore',
                    'fullBody',
                    'custom',
                  ].contains(s)
                  ? context.strength(s)
                  : s,
    );
    _change(
      () =>
          _proposal = StrengthPlanProposal(
            workouts: [
              for (final w in _proposal?.workouts ?? <StrengthWorkoutDraft>[])
                if (w.slotId != slot.id) w,
              ...proposal.workouts,
            ],
          ),
    );
  }

  Future<void> _review(StrengthWorkoutDraft workout) async {
    final result = await Navigator.push<StrengthWorkoutDraft>(
      context,
      MaterialPageRoute(
        builder:
            (_) => StrengthProposalScreen(workout: workout, places: _places),
      ),
    );
    if (result != null && mounted) {
      _change(
        () =>
            _proposal = StrengthPlanProposal(
              workouts: [
                for (final w in _proposal!.workouts)
                  w.id == result.id ? result : w,
              ],
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: _load,
            child: Text(context.strength(_error ?? 'retry')),
          ),
        ),
      );
    }
    return ProfileQuestion(
      title: context.strength('strength'),
      question: context.strength(
        [
          'countQuestion',
          'timeQuestion',
          'availableDays',
          'strengthWeek',
        ][_step],
      ),
      step: _step,
      count: 4,
      formKey: _form,
      busy: _busy,
      error: null,
      onNext: _next,
      onLater: _skip,
      nextLabel: context.strength('next'),
      laterLabel: context.strength('skipSport'),
      onBack: () {
        if (_step == 0) {
          _skip();
        } else {
          _change(() => _step--);
        }
      },
      children: [
        if (_step == 0) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var n = 1; n <= 6; n++)
                ChoiceChip(
                  label: Text('$n×'),
                  selected: _count == n,
                  onSelected: (_) => _change(() => _count = n),
                ),
            ],
          ),
          TextButton(
            onPressed:
                () => _change(() {
                  _count = 7;
                  _own = true;
                }),
            child: Text(context.strength('customSplit')),
          ),
          if (_count == 7)
            Text('7× · ${context.strength('manualArrangement')}'),
        ],
        if (_step == 1) ...[
          Text(context.strength('timeHint')),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final n in [30, 45, 60, 75])
                ChoiceChip(
                  label: Text('$n min'),
                  selected: !_customTime && _time == n,
                  onSelected:
                      (_) => _change(() {
                        _customTime = false;
                        _minutes.text = '$n';
                      }),
                ),
              ChoiceChip(
                label: Text(context.strength('ownTime')),
                selected: _customTime,
                onSelected: (_) => _change(() => _customTime = true),
              ),
            ],
          ),
          if (_customTime)
            TextFormField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.strength('minutes'),
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n < 10 || n > 240
                    ? context.strength('timeError')
                    : null;
              },
            ),
        ],
        if (_step == 2) ...[
          PlanDayPicker(
            selected: _available,
            onChanged: (v) => _change(() => _available = v),
          ),
          const SizedBox(height: 16),
          if (!_spacingFits) ...[
            Text(context.strength('arrangementHint')),
            CheckboxListTile(
              value: _own,
              title: Text(context.strength('manualArrangement')),
              onChanged: (v) => _change(() => _own = v == true),
            ),
          ],
          TextButton.icon(
            onPressed:
                () => showDialog<void>(
                  context: context,
                  builder:
                      (c) => AlertDialog(
                        content: Text(c.strength('recoveryInfo')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: Text(c.strength('done')),
                          ),
                        ],
                      ),
                ),
            icon: const Icon(Icons.info_outline),
            label: Text(context.strength('splitHint')),
          ),
        ],
        if (_step == 3) ...[
          if (_count >= 3 && _count <= 5) ...[
            Text(
              context.strength('pairBlock'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pair in ['mixedSplit', 'upperLower'])
                  ChoiceChip(
                    label: Text(context.strength(pair)),
                    selected: _pair == pair,
                    onSelected: (_) async {
                      if (!await _confirmRegeneration() || !mounted) return;
                      _change(() {
                        _pair = pair;
                        _step = 2;
                        _proposal = null;
                      });
                    },
                  ),
              ],
            ),
          ],
          if (_count == 4) ...[
            const SizedBox(height: 12),
            Text(
              '${context.strength('pairBlock')} · 2',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pair in ['mixedSplit', 'upperLower'])
                  ChoiceChip(
                    label: Text(context.strength(pair)),
                    selected: _secondPair == pair,
                    onSelected: (_) async {
                      if (!await _confirmRegeneration() || !mounted) return;
                      _change(() {
                        _secondPair = pair;
                        _step = 2;
                        _proposal = null;
                      });
                    },
                  ),
              ],
            ),
          ],
          if (_count >= 5) Text(context.strength('pushPullLegs')),
          const SizedBox(height: 16),
          for (final s in _slots) _dayCard(s),
          TextButton.icon(
            onPressed: () async {
              if (await _confirmRegeneration() && mounted) await _generate();
            },
            icon: const Icon(Icons.refresh),
            label: Text(context.strength('regenerate')),
          ),
        ],
        if (_error != null)
          Text(
            context.strength(_error!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }

  Widget _dayCard(ProgramSlot s) {
    final w = _proposal?.workouts.where((w) => w.slotId == s.id).firstOrNull;
    final v = w?.variants.firstOrNull;
    final day = DateFormat.E(
      Localizations.localeOf(context).toString(),
    ).format(DateTime(2024, 1, s.weekday));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$day · ${w?.name ?? s.label}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              StrengthPlanning.expand(
                s.effectiveFocus,
              ).map(context.strength).join(' · '),
            ),
            if (v != null)
              Text(
                '${v.exercises.length} · ${context.strength('exercises')} · ~${(v.estimatedSeconds / 60).ceil()} min',
              ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => _editDay(s),
                  child: Text(context.strength('customSplit')),
                ),
                if (w != null)
                  TextButton(
                    onPressed: () => _review(w),
                    child: Text(
                      context.strength(
                        w.reviewed ||
                                (_proposal?.workouts.any(
                                      (other) =>
                                          other.reviewed &&
                                          other.fingerprint == w.fingerprint,
                                    ) ??
                                    false)
                            ? 'reviewedWorkout'
                            : 'reviewWorkout',
                      ),
                    ),
                  ),
              ],
            ),
            PlanDayPicker(
              selected: {s.weekday},
              onChanged: (days) {
                final newDay = days.difference({s.weekday}).firstOrNull;
                if (newDay != null) {
                  _change(() {
                    _own = true;
                    _slots = [
                      for (final slot in _slots)
                        slot.id == s.id ? slot.copyWith(weekday: newDay) : slot,
                    ];
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }
}
