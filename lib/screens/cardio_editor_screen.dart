import 'package:flutter/material.dart';
import '../l10n/cardio_l10n.dart';
import '../models/cardio.dart';
import '../services/cardio_training.dart';
import '../utils/uuid_v4.dart';

/// Edits a detached value. Saving an occurrence never mutates its template.
class CardioEditorScreen extends StatefulWidget {
  const CardioEditorScreen({
    super.key,
    required this.workout,
    required this.units,
  });
  final CardioWorkout workout;
  final DistanceSystem units;
  @override
  State<CardioEditorScreen> createState() => _CardioEditorState();
}

class _CardioEditorState extends State<CardioEditorScreen> {
  late final _name = TextEditingController(text: widget.workout.name);
  late CardioSport _sport = widget.workout.sport;
  late bool _indoor = widget.workout.indoor,
      _autoPause = widget.workout.autoPause;
  late final _steps = [...widget.workout.steps];
  late List<RoutineStep> _warmup = [...widget.workout.warmup],
      _cooldown = [...widget.workout.cooldown];
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _step([int? index]) async {
    final step = await Navigator.of(context).push<CardioStep>(
      MaterialPageRoute(
        builder:
            (_) => CardioStepScreen(
              step:
                  index == null
                      ? CardioStep(
                        movement:
                            _sport == CardioSport.running ? 'run' : _sport.name,
                      )
                      : _steps[index],
              units: widget.units,
              sport: _sport,
            ),
      ),
    );
    if (step != null && mounted) {
      setState(() {
        if (index == null) {
          _steps.add(step);
        } else {
          _steps[index] = step;
        }
      });
    }
  }

  Future<void> _routine(bool cooling) async {
    final value = await Navigator.of(context).push<List<RoutineStep>>(
      MaterialPageRoute(
        builder:
            (_) => CardioRoutineEditor(
              steps: cooling ? _cooldown : _warmup,
              cooling: cooling,
            ),
      ),
    );
    if (value != null && mounted) {
      setState(() {
        if (cooling) {
          _cooldown = value;
        } else {
          _warmup = value;
        }
      });
    }
  }

  void _save() {
    final w = CardioWorkout(
      id: widget.workout.id,
      name: _name.text.trim(),
      sport: _sport,
      indoor: _indoor,
      autoPause: _autoPause,
      templateCode: widget.workout.templateCode,
      steps: [..._steps],
      warmup: _warmup,
      cooldown: _cooldown,
    );
    try {
      w.validate();
      Navigator.pop(context, w);
    } catch (_) {
      setState(() => _error = context.cardio('invalid'));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.cardio('edit')),
      actions: [
        TextButton(onPressed: _save, child: Text(context.cardio('save'))),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _name,
          maxLength: 120,
          decoration: InputDecoration(labelText: context.cardio('name')),
        ),
        DropdownButtonFormField<CardioSport>(
          value: _sport,
          isExpanded: true,
          decoration: InputDecoration(labelText: context.cardio('sport')),
          items: [
            for (final s in CardioSport.values)
              DropdownMenuItem(value: s, child: Text(context.cardio(s.name))),
          ],
          onChanged: (s) {
            if (s != null) setState(() => _sport = s);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.cardio('indoor')),
          value: _indoor,
          onChanged: (v) => setState(() => _indoor = v),
        ),
        if (_indoor) Text(context.cardio('indoorInfo')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.cardio('autoPause')),
          value: _autoPause && !_indoor,
          onChanged: _indoor ? null : (v) => setState(() => _autoPause = v),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.wb_sunny_outlined),
            title: Text(context.cardio('warmup')),
            subtitle: Text(
              CardioUnits.clock(
                _warmup.fold<int>(0, (int a, b) => a + b.seconds),
              ),
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _routine(false),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            context.cardio('core'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _steps.length,
          onReorder:
              (from, to) => setState(() {
                if (to > from) to--;
                _steps.insert(to, _steps.removeAt(from));
              }),
          itemBuilder: (context, i) {
            final s = _steps[i];
            return Card(
              key: ValueKey(s.id),
              child: ListTile(
                onTap: () => _step(i),
                title: Text(
                  '${s.repeat > 1 ? '${s.repeat} × ' : ''}${s.name.isEmpty ? context.cardio(s.intensity.name) : s.name}',
                ),
                subtitle: Text(cardioStepDescription(s, widget.units, context)),
                trailing: PopupMenuButton<String>(
                  onSelected:
                      (v) => setState(() {
                        if (v == 'delete') {
                          _steps.removeAt(i);
                        } else {
                          _steps.insert(
                            i + 1,
                            s.copyWith(id: UuidV4.generate()),
                          );
                        }
                      }),
                  itemBuilder:
                      (_) => [
                        for (final k in ['copy', 'delete'])
                          PopupMenuItem(
                            value: k,
                            child: Text(context.cardio(k)),
                          ),
                      ],
                ),
              ),
            );
          },
        ),
        OutlinedButton.icon(
          onPressed: () => _step(),
          icon: const Icon(Icons.add),
          label: Text(context.cardio('add')),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.nights_stay_outlined),
            title: Text(context.cardio('cooldown')),
            subtitle: Text(
              CardioUnits.clock(
                _cooldown.fold<int>(0, (int a, b) => a + b.seconds),
              ),
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _routine(true),
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _save, child: Text(context.cardio('save'))),
      ],
    ),
  );
}

String cardioStepDescription(
  CardioStep s,
  DistanceSystem units,
  BuildContext context,
) {
  final goal =
      s.goal == StepGoal.time
          ? CardioUnits.clock(s.amount)
          : CardioUnits.distance(s.amount, units);
  final target =
      s.primaryTarget == 'heart_rate' && s.minHeartRate != null
          ? '${s.minHeartRate}–${s.maxHeartRate} bpm'
          : s.minSpeed == null
          ? context.cardio('effort')
          : '${CardioUnits.pace(s.maxSpeed, units)} – ${CardioUnits.pace(s.minSpeed, units)}';
  return '$goal · $target${s.recoverySeconds > 0 ? ' · ${context.cardio('recovery')} ${CardioUnits.clock(s.recoverySeconds)}' : ''}';
}

class CardioStepScreen extends StatefulWidget {
  const CardioStepScreen({
    super.key,
    required this.step,
    required this.units,
    required this.sport,
  });
  final CardioStep step;
  final DistanceSystem units;
  final CardioSport sport;
  @override
  State<CardioStepScreen> createState() => _CardioStepState();
}

class _CardioStepState extends State<CardioStepScreen> {
  late final _name = TextEditingController(text: widget.step.name);
  late StepGoal _goal = widget.step.goal;
  late CardioIntensity _intensity = widget.step.intensity;
  late String _movement = widget.step.movement,
      _target = widget.step.primaryTarget;
  late bool _standing = widget.step.standingRecovery;
  late final _amount = TextEditingController(
    text: (widget.step.amount /
            (_goal == StepGoal.time
                ? 60
                : CardioUnits.distanceUnit(widget.units)))
        .toStringAsFixed(2),
  );
  late final _repeat = TextEditingController(text: '${widget.step.repeat}');
  late final _rest = TextEditingController(
    text: '${widget.step.recoverySeconds}',
  );
  late final _low = TextEditingController(
    text: _speedText(widget.step.minSpeed),
  );
  late final _high = TextEditingController(
    text: _speedText(widget.step.maxSpeed),
  );
  late final _minHr = TextEditingController(
    text: widget.step.minHeartRate?.toString() ?? '',
  );
  late final _maxHr = TextEditingController(
    text: widget.step.maxHeartRate?.toString() ?? '',
  );
  String? _error;
  bool get _cycling => widget.sport == CardioSport.cycling;
  double get _unit => CardioUnits.distanceUnit(widget.units);
  String _speedText(double? speed) =>
      speed == null
          ? ''
          : _cycling
          ? (speed * 3600 / _unit).toStringAsFixed(1)
          : CardioUnits.clock(_unit / speed);
  double? _parseSpeed(String text) {
    if (text.trim().isEmpty) return null;
    if (_cycling) return double.parse(text.replaceAll(',', '.')) * _unit / 3600;
    final parts = text.split(':');
    final seconds =
        parts.length == 2
            ? double.parse(parts[0]) * 60 + double.parse(parts[1])
            : double.parse(text.replaceAll(',', '.')) * 60;
    return _unit / seconds;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _amount,
      _repeat,
      _rest,
      _low,
      _high,
      _minHr,
      _maxHr,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    try {
      final step = CardioStep(
        id: widget.step.id,
        name: _name.text.trim(),
        goal: _goal,
        amount:
            double.parse(_amount.text.replaceAll(',', '.')) *
            (_goal == StepGoal.time ? 60 : _unit),
        intensity: _intensity,
        movement: _movement,
        repeat: int.parse(_repeat.text),
        recoverySeconds: double.parse(_rest.text.replaceAll(',', '.')),
        standingRecovery: _standing,
        minSpeed: _parseSpeed(_low.text),
        maxSpeed: _parseSpeed(_high.text),
        minHeartRate: _minHr.text.isEmpty ? null : int.parse(_minHr.text),
        maxHeartRate: _maxHr.text.isEmpty ? null : int.parse(_maxHr.text),
        primaryTarget: _target,
      );
      step.validate();
      Navigator.pop(context, step);
    } catch (_) {
      setState(() => _error = context.cardio('invalid'));
    }
  }

  Widget _field(TextEditingController c, String label, {bool numeric = true}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextField(
          controller: c,
          keyboardType:
              numeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.cardio('edit'))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _field(_name, context.cardio('name'), numeric: false),
        SegmentedButton<StepGoal>(
          segments: [
            for (final g in StepGoal.values)
              ButtonSegment(value: g, label: Text(context.cardio(g.name))),
          ],
          selected: {_goal},
          onSelectionChanged:
              (v) => setState(() {
                _goal = v.single;
                _amount.text = _goal == StepGoal.time ? '5' : '1';
              }),
        ),
        _field(
          _amount,
          _goal == StepGoal.time
              ? context.cardio('minutes')
              : widget.units == DistanceSystem.metric
              ? 'km'
              : 'mi',
        ),
        DropdownButtonFormField<CardioIntensity>(
          isExpanded: true,
          itemHeight: null,
          value: _intensity,
          decoration: InputDecoration(labelText: context.cardio('intensity')),
          items: [
            for (final i in CardioIntensity.values)
              DropdownMenuItem(value: i, child: Text(context.cardio(i.name))),
          ],
          onChanged: (v) => setState(() => _intensity = v!),
        ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          itemHeight: null,
          value: _movement,
          decoration: InputDecoration(labelText: context.cardio('movement')),
          items: [
            for (final i in {
              'run',
              'walk',
              'rest',
              widget.sport.name,
              _movement,
            })
              DropdownMenuItem(value: i, child: Text(context.cardio(i))),
          ],
          onChanged: (v) => setState(() => _movement = v!),
        ),
        DropdownButtonFormField<String>(
          value: _target,
          isExpanded: true,
          itemHeight: null,
          decoration: InputDecoration(labelText: context.cardio('primary')),
          items: [
            for (final i in ['pace', 'heart_rate', 'effort'])
              DropdownMenuItem(
                value: i,
                child: Text(
                  context.cardio(i == 'heart_rate' ? 'heartRate' : i),
                ),
              ),
          ],
          onChanged: (v) => setState(() => _target = v!),
        ),
        if (_target == 'heart_rate')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(context.cardio('pulseLater')),
          ),
        _field(
          _low,
          '${context.cardio('minSpeed')} (${_cycling ? (widget.units == DistanceSystem.metric ? 'km/h' : 'mph') : 'min:${widget.units == DistanceSystem.metric ? 'sec/km' : 'sec/mi'}'})',
          numeric: _cycling,
        ),
        _field(
          _high,
          '${context.cardio('maxSpeed')} (${_cycling ? (widget.units == DistanceSystem.metric ? 'km/h' : 'mph') : 'min:${widget.units == DistanceSystem.metric ? 'sec/km' : 'sec/mi'}'})',
          numeric: _cycling,
        ),
        _field(_minHr, '${context.cardio('minPulse')} (bpm)'),
        _field(_maxHr, '${context.cardio('maxPulse')} (bpm)'),
        _field(_repeat, context.cardio('repeat')),
        _field(
          _rest,
          '${context.cardio('recovery')} (${context.cardio('seconds')})',
        ),
        SwitchListTile(
          title: Text(context.cardio('standing')),
          value: _standing,
          onChanged: (v) => setState(() => _standing = v),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton(onPressed: _save, child: Text(context.cardio('save'))),
      ],
    ),
  );
}

class CardioRoutineEditor extends StatefulWidget {
  const CardioRoutineEditor({
    super.key,
    required this.steps,
    required this.cooling,
  });
  final List<RoutineStep> steps;
  final bool cooling;
  @override
  State<CardioRoutineEditor> createState() => _RoutineEditorState();
}

class _RoutineEditorState extends State<CardioRoutineEditor> {
  final _routineForm = GlobalKey<FormState>();
  late List<RoutineStep> _steps = [...widget.steps];
  Future<void> _edit([int? index]) async {
    final choices =
        {
          ...CardioTraining.warmups.values.expand((v) => v),
          ...CardioTraining.cooldowns.values.expand((v) => v),
          'custom',
        }.toList();
    var exercise = index == null ? choices.first : _steps[index].exercise;
    var duration = '${index == null ? 30 : _steps[index].seconds}';
    var customName = index == null ? '' : _steps[index].customName;
    var instructions = index == null ? '' : _steps[index].instructions;
    final step = await showDialog<RoutineStep>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, set) => AlertDialog(
                  title: Text(ctx.cardio('edit')),
                  content: Form(
                    key: _routineForm,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: exercise,
                            items: [
                              for (final e in {...choices, exercise})
                                DropdownMenuItem(
                                  value: e,
                                  child: Text(ctx.cardio(e)),
                                ),
                            ],
                            onChanged: (v) => set(() => exercise = v!),
                          ),
                          if (exercise == 'custom') ...[
                            TextFormField(
                              key: const ValueKey('routineName'),
                              initialValue: customName,
                              onChanged: (v) => customName = v,
                              validator:
                                  (v) =>
                                      v == null || v.trim().isEmpty
                                          ? ctx.cardio('invalid')
                                          : null,
                              decoration: InputDecoration(
                                labelText: ctx.cardio('name'),
                              ),
                            ),
                            TextFormField(
                              key: const ValueKey('routineInstructions'),
                              initialValue: instructions,
                              onChanged: (v) => instructions = v,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: ctx.cardio('instructions'),
                              ),
                            ),
                          ],
                          TextFormField(
                            key: const ValueKey('routineDuration'),
                            initialValue: duration,
                            onChanged: (value) => duration = value,
                            validator: (v) {
                              final seconds = int.tryParse(v ?? '');
                              return seconds == null ||
                                      seconds <= 0 ||
                                      seconds > 3600
                                  ? ctx.cardio('invalid')
                                  : null;
                            },
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: ctx.cardio('seconds'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(ctx.cardio('cancel')),
                    ),
                    FilledButton(
                      onPressed: () {
                        if (_routineForm.currentState?.validate() != true) {
                          return;
                        }
                        final seconds = int.tryParse(duration);
                        if (seconds != null &&
                            seconds > 0 &&
                            seconds <= 3600 &&
                            (exercise != 'custom' ||
                                customName.trim().isNotEmpty)) {
                          Navigator.pop(
                            ctx,
                            RoutineStep(
                              exercise,
                              seconds: seconds,
                              customName:
                                  exercise == 'custom' ? customName.trim() : '',
                              instructions:
                                  exercise == 'custom'
                                      ? instructions.trim()
                                      : '',
                            ),
                          );
                        }
                      },
                      child: Text(ctx.cardio('save')),
                    ),
                  ],
                ),
          ),
    );
    if (step != null && mounted) {
      setState(() {
        if (index == null) {
          _steps.add(step);
        } else {
          _steps[index] = step;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.cardio(widget.cooling ? 'cooldown' : 'warmup')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _steps),
          child: Text(context.cardio('save')),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(context.cardio('routineInfo')),
        Wrap(
          spacing: 8,
          children: [
            for (final key
                in (widget.cooling
                        ? CardioTraining.cooldowns
                        : CardioTraining.warmups)
                    .keys)
              ActionChip(
                label: Text(context.cardio(key)),
                onPressed:
                    () => setState(
                      () =>
                          _steps = CardioTraining.routine(
                            key,
                            cooling: widget.cooling,
                          ),
                    ),
              ),
          ],
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _steps.length,
          onReorder:
              (a, b) => setState(() {
                if (b > a) b--;
                _steps.insert(b, _steps.removeAt(a));
              }),
          itemBuilder:
              (ctx, i) => ListTile(
                key: ValueKey(i),
                title: Text(
                  _steps[i].customName.isNotEmpty
                      ? _steps[i].customName
                      : ctx.cardio(_steps[i].exercise),
                ),
                subtitle: Text(CardioUnits.clock(_steps[i].seconds)),
                onTap: () => _edit(i),
                trailing: IconButton(
                  tooltip: ctx.cardio('delete'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _steps.removeAt(i)),
                ),
              ),
        ),
        OutlinedButton.icon(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: Text(context.cardio('add')),
        ),
      ],
    ),
  );
}
