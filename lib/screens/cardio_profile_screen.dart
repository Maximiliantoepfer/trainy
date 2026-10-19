import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/plan_l10n.dart';
import '../models/cardio.dart';
import '../providers/cardio_provider.dart';
import '../repositories/training_program_repository.dart';

/// Four short, resumable questions. Global settings and scheduling live elsewhere.
class CardioProfileScreen extends StatefulWidget {
  const CardioProfileScreen({
    super.key,
    required this.provider,
    this.setupRepository,
  });
  final CardioProvider provider;
  final TrainingProgramRepository? setupRepository;
  @override
  State<CardioProfileScreen> createState() => _CardioProfileScreenState();
}

class _CardioProfileScreenState extends State<CardioProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  final _keys = <String, GlobalKey<FormFieldState<String>>>{};
  final _focus = <String, FocusNode>{};
  late final _repo =
      widget.setupRepository ??
      TrainingProgramRepository(database: widget.provider.repository.db);
  late AthleteRunningProfile _original;
  RunningLevel? _level;
  bool? _canFive;
  int? _frequency;
  DateTime? _date;
  DateTime? _bestDate;
  bool _bestOpen = false;
  bool _maximal = false, _paceMode = false, _busy = false, _ready = false;
  bool _pulseOpen = false;
  double? _exactSeconds, _exactDistance;
  String? _exactTimeText;
  int _step = 0;
  String? _error;
  Future<void> _writes = Future.value();
  final _initialText = <String, String>{};
  final _canonicalMeters = <String, double>{};
  final _canonicalText = <String, String>{};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    try {
      _original = widget.provider.profile;
      final p = _original, unit = CardioUnits.distanceUnit(p.units);
      final locale = Localizations.localeOf(context).toString();
      final values = {
        'distance': NumberFormat(
          '0.####',
          locale,
        ).format(p.referenceMeters / unit),
        'time':
            p.referenceSeconds == null
                ? ''
                : CardioUnits.clock(p.referenceSeconds!),
        'longest':
            p.longestMeters == 0
                ? ''
                : NumberFormat('0.####', locale).format(p.longestMeters / unit),
        'continuous': p.continuousMinutes == 0 ? '' : '${p.continuousMinutes}',
        'restPulse': p.restingHeartRate?.toString() ?? '',
        'maxPulse': p.maximumHeartRate?.toString() ?? '',
        'bestDistance': NumberFormat(
          '0.####',
          locale,
        ).format(p.bestMeters / unit),
        'bestTime':
            p.bestSeconds == null ? '' : CardioUnits.clock(p.bestSeconds!),
      };
      _initialText.addAll(values);
      _canonicalMeters.addAll({
        'distance': p.referenceMeters,
        'longest': p.longestMeters,
        'bestDistance': p.bestMeters,
      });
      _canonicalText.addAll({
        'distance': values['distance']!,
        'longest': values['longest']!,
        'bestDistance': values['bestDistance']!,
      });
      _level = p.level;
      _canFive = p.canRunFiveKm;
      _frequency = p.recentRunsPerWeek;
      _date = p.referenceDate;
      _maximal = p.isMaximal;
      _bestDate = p.bestDate;
      _bestOpen = p.bestSeconds != null;
      final draft = await _repo.draft('running-profile');
      if (!mounted) return;
      if (draft != null) {
        values.addAll(Map<String, String>.from(draft['fields'] as Map));
        _level =
            draft['level'] == null
                ? null
                : RunningLevel.values.byName(draft['level'] as String);
        _canFive = draft['canFive'] as bool?;
        _frequency = draft['frequency'] as int?;
        _date = DateTime.tryParse(draft['date'] as String? ?? '');
        _maximal = draft['maximal'] == true;
        _bestOpen = draft['bestOpen'] == true;
        _bestDate = DateTime.tryParse(draft['bestDate'] as String? ?? '');
        _step = (draft['step'] as int? ?? 0).clamp(0, 3);
        _paceMode = draft['paceMode'] == true;
        final oldUnits = DistanceSystem.values.byName(
          draft['units'] as String? ?? p.units.name,
        );
        if (oldUnits != p.units) {
          final factor = CardioUnits.distanceUnit(oldUnits) / unit;
          for (final key in ['distance', 'longest', 'bestDistance']) {
            final n = double.tryParse(values[key]!.replaceAll(',', '.'));
            if (n != null && n.isFinite) {
              values[key] = NumberFormat(
                '0.########',
                locale,
              ).format(n * factor);
            }
          }
          if (_paceMode) {
            final n = CardioUnits.parseDuration(values['time']!);
            if (n != null) values['time'] = CardioUnits.clock(n / factor);
          }
        }
        for (final key in ['distance', 'longest', 'bestDistance']) {
          final exact = (draft['canonicalMeters'] as Map?)?[key] as num?;
          if (exact != null && exact.isFinite) {
            _canonicalMeters[key] = exact.toDouble();
            _canonicalText[key] = values[key]!;
          }
        }
      }
      _pulseOpen =
          values['restPulse']!.isNotEmpty || values['maxPulse']!.isNotEmpty;
      for (final e in values.entries) {
        _fields[e.key] = TextEditingController(text: e.value)
          ..addListener(_persist);
        _keys[e.key] = GlobalKey<FormFieldState<String>>();
        _focus[e.key] = FocusNode();
      }
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'error');
    }
  }

  void _persist() {
    if (!_ready) return;
    final data = {
      'fields': {for (final e in _fields.entries) e.key: e.value.text},
      'step': _step,
      'level': _level?.name,
      'canFive': _canFive,
      'frequency': _frequency,
      'date': _date?.toIso8601String(),
      'maximal': _maximal,
      'bestOpen': _bestOpen,
      'bestDate': _bestDate?.toIso8601String(),
      'paceMode': _paceMode,
      'units': _original.units.name,
      'canonicalMeters': {
        'distance': _distance.isFinite ? _distance : null,
        'longest': _longest.isFinite ? _longest : null,
        'bestDistance': _bestDistance,
      },
    };
    _writes = _writes
        .then((_) => _repo.saveDraft('running-profile', data))
        .catchError((Object e) {
          if (mounted) setState(() => _error = 'savingError');
        });
  }

  void _change(VoidCallback action) {
    setState(action);
    _persist();
  }

  double? _number(String key) =>
      double.tryParse(_fields[key]!.text.trim().replaceAll(',', '.'));
  double get _bestDistance =>
      _fields['bestDistance']!.text == _canonicalText['bestDistance']
          ? _canonicalMeters['bestDistance']!
          : (_number('bestDistance') ?? 0) *
              CardioUnits.distanceUnit(_original.units);
  double? get _bestSeconds =>
      _fields['bestTime']!.text == _initialText['bestTime']
          ? _original.bestSeconds
          : CardioUnits.parseDuration(_fields['bestTime']!.text);
  double get _distance =>
      _fields['distance']!.text == _canonicalText['distance']
          ? _canonicalMeters['distance']!
          : (_number('distance') ?? 0) *
              CardioUnits.distanceUnit(_original.units);
  double get _longest =>
      _fields['longest']!.text == _canonicalText['longest']
          ? _canonicalMeters['longest']!
          : (_number('longest') ?? 0) *
              CardioUnits.distanceUnit(_original.units);
  double? get _seconds {
    if (_fields['time']!.text == _exactTimeText &&
        _distance == _exactDistance) {
      return _exactSeconds;
    }
    if (!_paceMode && _fields['time']!.text == _initialText['time']) {
      return _original.referenceSeconds;
    }
    final n = CardioUnits.parseDuration(_fields['time']!.text);
    return n == null
        ? null
        : _paceMode
        ? n * _distance / CardioUnits.distanceUnit(_original.units)
        : n;
  }

  String? _validate(String key, String? text) {
    final empty = (text ?? '').trim().isEmpty;
    if (key == 'bestTime') {
      return !_bestOpen || _maximal
          ? null
          : _bestSeconds == null
          ? context.plan('durationError')
          : null;
    }
    if (key == 'bestDistance' && (!_bestOpen || _maximal)) return null;
    if (key == 'time') {
      return empty && !_maximal
          ? null
          : (_seconds == null ? context.plan('durationError') : null);
    }
    if (empty && !['distance', 'bestDistance'].contains(key)) return null;
    final n = _number(key);
    if (n == null || !n.isFinite) return context.plan('numberError');
    if (key == 'restPulse' || key == 'maxPulse') {
      if (n < 25 || n > 250 || n != n.roundToDouble()) {
        return context.plan('pulseError');
      }
      if (key == 'maxPulse' &&
          _number('restPulse') != null &&
          n <= _number('restPulse')!) {
        return context.plan('pulseOrder');
      }
    } else if (n <= 0) {
      return context.plan('positiveError');
    }
    if (key == 'continuous' && n != n.roundToDouble()) {
      return context.plan('numberError');
    }
    return null;
  }

  Widget _field(String key, String title, {String? suffix, String? hint}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.plan(title),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Semantics(
              label: context.plan(title),
              child: TextFormField(
                key: _keys[key],
                controller: _fields[key],
                focusNode: _focus[key],
                keyboardType:
                    key == 'time' || key == 'bestTime'
                        ? TextInputType.datetime
                        : const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  suffixText: suffix,
                  hintText: hint,
                  errorMaxLines: 3,
                ),
                validator: (v) => _validate(key, v),
                onChanged: (_) {
                  if (key == 'restPulse' || key == 'maxPulse') setState(() {});
                },
              ),
            ),
          ],
        ),
      );
  Future<void> _next() async {
    if (_step == 3) {
      for (final group
          in <int, List<String>>{
            1: ['distance', 'time', 'bestDistance', 'bestTime'],
            2: [_canFive == true ? 'longest' : 'continuous'],
          }.entries) {
        if (group.value.any((k) => _validate(k, _fields[k]!.text) != null) ||
            (group.key == 1 && _maximal && _date == null)) {
          _change(() => _step = group.key);
          await WidgetsBinding.instance.endOfFrame;
          if (mounted) await _next();
          return;
        }
      }
    }
    final keys =
        _step == 1
            ? ['distance', 'time', 'bestDistance', 'bestTime']
            : _step == 2
            ? [_canFive == true ? 'longest' : 'continuous']
            : _step == 3
            ? ['restPulse', 'maxPulse']
            : <String>[];
    final bad =
        keys.where((k) => _validate(k, _fields[k]!.text) != null).firstOrNull;
    if (bad != null && _step == 3 && !_pulseOpen) {
      setState(() => _pulseOpen = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    if (_form.currentState?.validate() != true) {
      final first =
          _keys.entries
              .where((e) => e.value.currentState?.hasError == true)
              .firstOrNull;
      if (first != null) {
        _focus[first.key]!.requestFocus();
        Scrollable.ensureVisible(first.value.currentContext!, alignment: .2);
      }
      return;
    }
    if (_step == 1 && _maximal && _date == null) {
      setState(() => _error = 'dateRequired');
      return;
    }
    if (_step == 1 && !_maximal && _bestOpen && _bestDate == null) {
      setState(() => _error = 'dateRequired');
      return;
    }
    if (_step < 3) {
      _change(() {
        _step++;
        _error = null;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      final p = AthleteRunningProfile.fromJson({
        ...widget.provider.profile.toJson(),
        'referenceMeters': _distance,
        'referenceSeconds': _seconds,
        'referenceDate': _maximal ? _date?.toIso8601String() : null,
        'isMaximal': _maximal,
        'bestMeters': _bestDistance,
        'bestSeconds': _maximal || !_bestOpen ? null : _bestSeconds,
        'bestDate':
            _maximal || !_bestOpen ? null : _bestDate?.toIso8601String(),
        'level': _level?.name,
        'canRunFiveKm': _canFive,
        'recentRunsPerWeek': _frequency,
        'longestMeters': _canFive != true ? _original.longestMeters : _longest,
        'continuousMinutes':
            _canFive == true
                ? _original.continuousMinutes
                : (_number('continuous') ?? 0).toInt(),
        'restingHeartRate': _number('restPulse')?.toInt(),
        'maximumHeartRate': _number('maxPulse')?.toInt(),
      });
      await _writes;
      await widget.provider.repository.saveProfile(p);
      await _repo.clearDraft('running-profile');
      await widget.provider.load();
      final updates = await widget.provider.repository.targetAdjustment(p);
      if (updates.isNotEmpty && mounted) {
        final apply = await showDialog<bool>(
          context: context,
          builder:
              (c) => AlertDialog(
                title: Text(c.plan('updateTargets')),
                content: Text(c.plan('updateTargetsInfo')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(c.plan('later')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(c.plan('save')),
                  ),
                ],
              ),
        );
        if (apply == true) {
          await widget.provider.repository.applyAdjustment(updates);
          await widget.provider.load();
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = 'savingError');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    for (final n in _focus.values) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['level', 'performance', 'load', 'pulse'];
    return PopScope(
      canPop: _step == 0 && !_busy,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_busy && _step > 0) _change(() => _step--);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.plan('runningProfile')),
          actions: [
            IconButton(
              tooltip: context.plan('profileWhy'),
              icon: const Icon(Icons.info_outline),
              onPressed:
                  () => showDialog<void>(
                    context: context,
                    builder:
                        (c) => AlertDialog(
                          title: Text(c.plan('profileWhy')),
                          content: Text(c.plan('profileExplanation')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                  ),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
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
                    child: Text(context.plan(_step == 3 ? 'save' : 'next')),
                  ),
                ),
        body:
            !_ready
                ? Center(
                  child: TextButton(
                    onPressed: _load,
                    child: Text(context.plan(_error ?? 'retry')),
                  ),
                )
                : Form(
                  key: _form,
                  child: ListView(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.all(20),
                    children: [
                      LinearProgressIndicator(value: (_step + 1) / 4),
                      const SizedBox(height: 24),
                      Text(
                        context.plan(titles[_step]),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 24),
                      if (_step == 0) ...[
                        for (final level in RunningLevel.values)
                          RadioListTile<RunningLevel>(
                            contentPadding: EdgeInsets.zero,
                            value: level,
                            groupValue: _level,
                            title: Text(context.plan(level.name)),
                            subtitle: Text(context.plan('${level.name}Hint')),
                            onChanged: (v) => _change(() => _level = v),
                          ),
                        const SizedBox(height: 24),
                        Text(
                          context.plan('canFive'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final entry
                                in <String, bool?>{
                                  'yes': true,
                                  'notYet': false,
                                  'unknown': null,
                                }.entries)
                              ChoiceChip(
                                label: Text(context.plan(entry.key)),
                                selected: _canFive == entry.value,
                                onSelected:
                                    (_) =>
                                        _change(() => _canFive = entry.value),
                              ),
                          ],
                        ),
                      ],
                      if (_step == 1) ...[
                        _field(
                          'distance',
                          'distance',
                          suffix:
                              _original.units == DistanceSystem.metric
                                  ? 'km'
                                  : 'mi',
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final mode in [false, true])
                              ChoiceChip(
                                label: Text(
                                  context.plan(mode ? 'pace' : 'time'),
                                ),
                                selected: _paceMode == mode,
                                onSelected: (_) {
                                  final seconds = _seconds;
                                  _change(() {
                                    _paceMode = mode;
                                    if (seconds != null && _distance > 0) {
                                      _fields['time']!.text = CardioUnits.clock(
                                        mode
                                            ? seconds *
                                                CardioUnits.distanceUnit(
                                                  _original.units,
                                                ) /
                                                _distance
                                            : seconds,
                                      );
                                    }
                                    _exactSeconds = seconds;
                                    _exactDistance = _distance;
                                    _exactTimeText = _fields['time']!.text;
                                  });
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _field(
                          'time',
                          _paceMode ? 'pace' : 'timeQuestion',
                          suffix:
                              _paceMode
                                  ? (_original.units == DistanceSystem.metric
                                      ? 'min/km'
                                      : 'min/mi')
                                  : 'min',
                          hint: context.plan('durationHint'),
                        ),
                        Text(
                          context.plan('performanceKind'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final maximal in [false, true])
                          RadioListTile<bool>(
                            contentPadding: EdgeInsets.zero,
                            value: maximal,
                            groupValue: _maximal,
                            title: Text(
                              context.plan(maximal ? 'bestRun' : 'easyRun'),
                            ),
                            onChanged: (v) => _change(() => _maximal = v!),
                          ),
                        if (!_maximal) ...[
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(context.plan('bestTime')),
                            value: _bestOpen,
                            onChanged: (v) => _change(() => _bestOpen = v),
                          ),
                          if (_bestOpen) ...[
                            _field(
                              'bestDistance',
                              'distance',
                              suffix:
                                  _original.units == DistanceSystem.metric
                                      ? 'km'
                                      : 'mi',
                            ),
                            _field(
                              'bestTime',
                              'timeQuestion',
                              suffix: 'min',
                              hint: context.plan('durationHint'),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(context.plan('bestDate')),
                              subtitle: Text(
                                _bestDate == null
                                    ? '—'
                                    : DateFormat.yMMMd(
                                      Localizations.localeOf(
                                        context,
                                      ).toString(),
                                    ).format(_bestDate!),
                              ),
                              trailing: const Icon(
                                Icons.calendar_today_outlined,
                              ),
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _bestDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (d != null && mounted) {
                                  _change(() => _bestDate = d);
                                }
                              },
                            ),
                          ],
                        ],
                        if (_maximal) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(context.plan('testDate')),
                            subtitle: Text(
                              _date == null
                                  ? '—'
                                  : DateFormat.yMMMd(
                                    Localizations.localeOf(context).toString(),
                                  ).format(_date!),
                            ),
                            trailing: const Icon(Icons.calendar_today_outlined),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _date ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (date != null && mounted) {
                                _change(() => _date = date);
                              }
                            },
                          ),
                          Text(
                            context.plan('testInfo'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                      if (_step == 2) ...[
                        if (_canFive == true)
                          _field(
                            'longest',
                            'longest',
                            suffix:
                                _original.units == DistanceSystem.metric
                                    ? 'km'
                                    : 'mi',
                          )
                        else
                          _field(
                            'continuous',
                            'continuous',
                            suffix: context.plan('minutes'),
                          ),
                        Text(
                          context.plan('recentFrequency'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.plan('recentHint'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text(context.plan('unknown')),
                              selected: _frequency == null,
                              onSelected:
                                  (_) => _change(() => _frequency = null),
                            ),
                            for (var d = 0; d <= 7; d++)
                              ChoiceChip(
                                label: Text('$d'),
                                selected: _frequency == d,
                                onSelected:
                                    (_) => _change(() => _frequency = d),
                              ),
                          ],
                        ),
                      ],
                      if (_step == 3) ...[
                        ExpansionTile(
                          key: ValueKey('pulse-$_pulseOpen'),
                          title: Text(context.plan('pulse')),
                          initiallyExpanded: _pulseOpen,
                          onExpansionChanged: (v) => _pulseOpen = v,
                          children: [
                            _field('restPulse', 'restPulse', suffix: 'bpm'),
                            _field('maxPulse', 'maxPulse', suffix: 'bpm'),
                            if (_number('restPulse') != null &&
                                _number('maxPulse') != null &&
                                _validate(
                                      'restPulse',
                                      _fields['restPulse']!.text,
                                    ) ==
                                    null &&
                                _validate(
                                      'maxPulse',
                                      _fields['maxPulse']!.text,
                                    ) ==
                                    null &&
                                _number('maxPulse')! > _number('restPulse')!)
                              for (var i = 0; i < 5; i++)
                                ListTile(
                                  title: Text('Z${i + 1}'),
                                  trailing: Text(
                                    '${(_number('restPulse')! + (.5 + i * .1) * (_number('maxPulse')! - _number('restPulse')!)).round()}–${(_number('restPulse')! + (.6 + i * .1) * (_number('maxPulse')! - _number('restPulse')!)).round()} bpm',
                                  ),
                                )
                            else
                              Text(context.plan('pulseMissing')),
                            const SizedBox(height: 12),
                            Text(
                              context.plan('zoneInfo'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            context.plan(_error!),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
      ),
    );
  }
}
