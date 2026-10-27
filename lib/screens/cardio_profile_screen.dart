import '../models/training_program.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/planning_l10n.dart';
import '../l10n/cardio_l10n.dart';
import '../models/cardio.dart';
import '../providers/cardio_provider.dart';
import '../repositories/training_program_repository.dart';
import '../services/profile_readiness.dart';
import '../services/running_assessment.dart';
import '../widgets/profile_question.dart';
import '../models/running_preferences.dart';
import '../widgets/favorite_routes_editor.dart';
import 'running_replan_screen.dart';

class CardioProfileScreen extends StatefulWidget {
  const CardioProfileScreen({
    super.key,
    required this.provider,
    this.setupRepository,
    this.initialQuestion,
    this.offerReplan = true,
  });
  final CardioProvider provider;
  final TrainingProgramRepository? setupRepository;
  final String? initialQuestion;
  final bool offerReplan;
  @override
  State<CardioProfileScreen> createState() => _CardioProfileScreenState();
}

class _CardioProfileScreenState extends State<CardioProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  final _originalText = <String, String>{};
  final _canonical = <String, double>{};
  final _confirmed = <String>{};
  final _planning = <String, dynamic>{};
  List<int> _availableDays = [1, 2, 3, 4, 5, 6, 7];
  static const _adaptive = {
    'goal',
    'complaints',
    'walkMinutes',
    'walkPreparation',
    'weeklyMinutes',
    'longestMinutes',
    'longestDate',
    'longestEffort',
    'desiredDays',
    'availableDays',
    'minutesPerSession',
    'hardTrainingDays',
    'highLoadTolerated',
    'pulseSource',
    'zoneMethod',
    'routePreference',
    'walkBreaks',
    'audio',
    'customDayBudgets',
    'routeMeters',
    'breakWeeks',
  };
  late final _repo =
      widget.setupRepository ??
      TrainingProgramRepository(database: widget.provider.repository.db);
  late AthleteRunningProfile _original;
  AthleteRunningProfile? _history;
  String _loadSource = 'unknown';
  RunningLevel? _level;
  int? _months, _frequency;
  double? _volume;
  String? _kind, _error;
  DateTime? _date;
  bool _returning = false,
      _otherDistance = false,
      _ready = false,
      _busy = false;
  int _step = 0;
  Future<void> _writes = Future.value();
  List<String> get _steps => [
    'goal',
    'complaints',
    'level',
    if (_level != RunningLevel.starting || _returning) 'experience',
    if (_returning) 'breakWeeks',
    'continuous',
    if (_level == RunningLevel.starting ||
        (_fields['continuous'] != null &&
            (_number('continuous') ?? 0) < 30)) ...[
      'walkMinutes',
      'walkPreparation',
    ],
    'frequency',
    'volume',
    'longest',
    if (_planning['longestMinutes'] != null ||
        (_fields['longest'] != null && _meters('longest') > 0)) ...[
      'longestDate',
      'longestEffort',
    ],
    'desiredDays',
    'availableDays',
    'minutesPerSession',
    'customDayBudgets',
    'hardTrainingDays',
    if (_level == RunningLevel.experienced) 'highLoadTolerated',
    'reference',
    if (_kind != 'none') 'referenceKind',
    if (_kind == 'maximal') 'testDate',
    'restPulse',
    'maxPulse',
    'pulseSource',
    'zoneMethod',
    if (_planning['zoneMethod'] == 'manual')
      ...List.generate(6, (i) => 'zone$i'),
    'routes',
    'review',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    try {
      final p = widget.provider.profile;
      _original = p;
      _planning.addAll(p.planning.toJson());
      _planning['goal'] ??= 'runFaster';
      _planning['complaints'] ??= 'none';
      _planning['customDayBudgets'] = p.planning.dayMinutes.isNotEmpty;
      _planning['audio'] ??= true;
      _planning['walkBreaks'] ??= true;
      _availableDays =
          p.setupVersion == 0 ? [1, 2, 3, 4, 5, 6, 7] : [...p.weekdays];
      _loadSource = p.loadSource;
      final unit = CardioUnits.distanceUnit(p.units);
      final locale = Localizations.localeOf(context).toString();
      String distance(double m) =>
          NumberFormat('0.########', locale).format(m / unit);
      final values = <String, String>{
        'distance': distance(p.referenceMeters),
        'time':
            p.referenceSeconds == null
                ? ''
                : CardioUnits.clock(p.referenceSeconds!),
        'continuous':
            p.confirmedAnswers.contains('continuous') || p.continuousMinutes > 0
                ? '${p.continuousMinutes}'
                : '',
        'longest': p.longestMeters == 0 ? '' : distance(p.longestMeters),
        'restPulse': p.restingHeartRate?.toString() ?? '',
        'maxPulse': p.maximumHeartRate?.toString() ?? '',
      };
      _canonical.addAll({
        'distance': p.referenceMeters,
        'longest': p.longestMeters,
      });
      _originalText.addAll(values);
      _level = p.level;
      _months =
          p.confirmedAnswers.contains('experience') ? p.experienceMonths : null;
      _frequency = p.recentRunsPerWeek;
      _volume =
          p.weeklyMeters == 0 && p.loadSource == 'unknown'
              ? null
              : p.weeklyMeters;
      _kind = p.referenceKind;
      _date = p.referenceDate;
      _returning = p.returningAfterBreak;
      _confirmed.addAll(p.confirmedAnswers);
      final draft = await _repo.draft('running-profile');
      if (!mounted) return;
      String? restoredStep;
      if (draft != null) {
        _planning.addAll(
          Map<String, dynamic>.from(draft['planning'] as Map? ?? {}),
        );
        if (draft['availableDays'] is List) {
          _availableDays = List<int>.from(draft['availableDays'] as List);
        }
        // Older values survive, but visited flags never count as confirmation.
        final saved = Map<String, dynamic>.from(draft['fields'] as Map? ?? {});
        for (final key in values.keys) {
          if (saved[key] is String) values[key] = saved[key] as String;
        }
        final oldUnit = CardioUnits.distanceUnit(
          DistanceSystem.values.byName(
            draft['units'] as String? ?? p.units.name,
          ),
        );
        for (final key in ['distance', 'longest']) {
          final exact = (draft['canonicalMeters'] as Map?)?[key] as num?;
          final meters =
              exact?.toDouble() ??
              (double.tryParse(values[key]!.replaceAll(',', '.')) ?? 0) *
                  oldUnit;
          _canonical[key] = meters;
          values[key] = key == 'longest' && meters == 0 ? '' : distance(meters);
          _originalText[key] = values[key]!;
        }
        if (draft['paceMode'] == true) {
          final pace = CardioUnits.parseDuration(values['time']!);
          if (pace != null) {
            values['time'] = CardioUnits.clock(
              pace * _canonical['distance']! / oldUnit,
            );
          }
        }
        _level =
            RunningLevel.values
                .where((l) => l.name == draft['level'])
                .firstOrNull ??
            _level;
        if ([1, 2].contains(draft['version'])) {
          _months = draft['months'] as int?;
          _frequency = draft['frequency'] as int?;
          _volume = (draft['volume'] as num?)?.toDouble();
          _loadSource = draft['loadSource'] as String? ?? 'unknown';
          _kind = draft['kind'] as String?;
          _date = DateTime.tryParse(draft['date'] as String? ?? '');
          _returning = draft['returning'] == true;
          _confirmed
            ..clear()
            ..addAll(List<String>.from(draft['confirmed'] as List? ?? []));
          if (draft['version'] == 2) restoredStep = draft['stepKey'] as String?;
        }
      }
      if (!_confirmed.contains('hardTrainingDays')) {
        final programs = await _repo.plans();
        final activeId = await _repo.activeId();
        final program = programs.where((p) => p.id == activeId).firstOrNull;
        final draft = await _repo.draft('plan:new');
        final draftProgram =
            draft?['program'] is Map
                ? TrainingProgram.fromJson(
                  Map<String, dynamic>.from(draft!['program'] as Map),
                )
                : null;
        _planning['hardTrainingDays'] =
            (draftProgram ?? program)?.currentSlots
                .where((s) => s.kind == 'strength' && s.legHeavy)
                .map((s) => s.weekday)
                .toSet()
                .toList() ??
            _planning['hardTrainingDays'] ??
            [];
      }
      _planning['goal'] ??= 'runFaster';
      _planning['complaints'] ??= 'none';
      _otherDistance = _canonical['distance'] != 5000;
      for (final entry in values.entries) {
        _fields[entry.key] = TextEditingController(text: entry.value)
          ..addListener(_persist);
      }
      // Conditional questions depend on restored controller values. Resolve
      // the named step only after all those values have been installed.
      _step =
          (widget.initialQuestion ?? restoredStep) == null
              ? 0
              : _steps
                  .indexOf(widget.initialQuestion ?? restoredStep!)
                  .clamp(0, _steps.length - 1);
      setState(() => _ready = true);
      // History is a suggestion, never an implicit answer to a required question.
      try {
        final suggested = await _repo.withRecentLoad(
          const AthleteRunningProfile(),
          DateTime.now(),
        );
        if (mounted &&
            (suggested.recentRunsPerWeek != null ||
                suggested.weeklyMeters > 0)) {
          setState(() => _history = suggested);
        }
      } catch (_) {
        /* History availability must not block local setup. */
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'error');
    }
  }

  double? _number(String key) =>
      double.tryParse(_fields[key]!.text.trim().replaceAll(',', '.'));
  double _meters(String key) =>
      _fields[key]!.text == _originalText[key]
          ? _canonical[key]!
          : (_number(key) ?? 0) * CardioUnits.distanceUnit(_original.units);
  double? get _seconds =>
      _kind == 'none'
          ? null
          : _fields['time']!.text == _originalText['time']
          ? _original.referenceSeconds
          : CardioUnits.parseDuration(_fields['time']!.text);

  void _persist() {
    if (!_ready) return;
    final data = <String, dynamic>{
      'version': 2,
      'stepKey': _steps[_step],
      'planning': _planning,
      'availableDays': _availableDays,
      'step': _step,
      'level': _level?.name,
      'months': _months,
      'frequency': _frequency,
      'volume': _volume,
      'kind': _kind,
      'loadSource': _loadSource,
      'date': _date?.toIso8601String(),
      'returning': _returning,
      'confirmed': _confirmed.toList(),
      'units': _original.units.name,
      'fields': {for (final e in _fields.entries) e.key: e.value.text},
      'canonicalMeters': {
        for (final key in ['distance', 'longest'])
          key: _meters(key).isFinite ? _meters(key) : null,
      },
    };
    _writes = _writes
        .then((_) => _repo.saveDraft('running-profile', data))
        .catchError((Object _) {
          if (mounted) setState(() => _error = 'savingError');
        });
  }

  void _change(VoidCallback action) {
    setState(() {
      _error = null;
      action();
    });
    _persist();
  }

  AthleteRunningProfile _profile() => AthleteRunningProfile.fromJson({
    ..._original.toJson(),
    'setupVersion': 3,
    'planning': _planning,
    'weekdays': _availableDays,
    'confirmedAnswers': _confirmed.toList(),
    'level': _level?.name,
    'experienceMonths': _months ?? 0,
    'returningAfterBreak': _returning,
    'referenceKind': _kind,
    'referenceMeters': _meters('distance'),
    'referenceSeconds': _seconds,
    'referenceDate': _kind == 'maximal' ? _date?.toIso8601String() : null,
    'isMaximal': _kind == 'maximal',
    if (_kind == 'maximal') ...{'bestSeconds': null, 'bestDate': null},
    'continuousMinutes': _number('continuous')?.toInt() ?? 0,
    'canRunFiveKm':
        _kind == 'runWalk'
            ? false
            : (_seconds != null &&
                    _meters('distance') >= 5000 &&
                    (_number('continuous') ?? 0) * 60 >= _seconds!
                ? true
                : null),
    'recentRunsPerWeek': _frequency,
    'weeklyMeters': _volume,
    'loadSource':
        _volume == null && _planning['weeklyMinutes'] == null
            ? 'unknown'
            : _loadSource,
    'longestMeters': _meters('longest'),
    'restingHeartRate': _number('restPulse')?.toInt(),
    'maximumHeartRate': _number('maxPulse')?.toInt(),
  });

  String? _validate(String key, String? raw) {
    final empty = (raw ?? '').trim().isEmpty;
    if (key == 'time') {
      if (_kind == 'none') return null;
      return _seconds == null || _seconds! <= 0
          ? context.planning('normalDurationError')
          : null;
    }
    if (empty && ['longest', 'restPulse', 'maxPulse'].contains(key)) {
      return null;
    }
    final n = _number(key);
    if (n == null || !n.isFinite) return context.planning('numberError');
    if (key == 'continuous') {
      return n < 0 || n != n.roundToDouble()
          ? context.planning('nonNegativeError')
          : null;
    }
    if (key == 'restPulse' || key == 'maxPulse') {
      if (n < 25 || n > 250 || n != n.roundToDouble()) {
        return context.planning('pulseError');
      }
      if (key == 'maxPulse' &&
          _number('restPulse') != null &&
          n <= _number('restPulse')!) {
        return context.planning('pulseOrder');
      }
    }
    return n <= 0 ? context.planning('positiveError') : null;
  }

  Future<void> _later() async {
    await _writes;
    if (mounted) Navigator.pop(context, false);
  }

  Future<void> _next() async {
    if (_busy || !_form.currentState!.validate()) return;
    final key = _steps[_step];
    if (_adaptive.contains(key) &&
        ![
          'weeklyMinutes',
          'longestMinutes',
          'hardTrainingDays',
          'availableDays',
          'pulseSource',
        ].contains(key) &&
        _planning[key] == null) {
      setState(() => _error = 'answerRequired');
      return;
    }
    if (key == 'availableDays' &&
        (_availableDays.isEmpty ||
            _availableDays.length < (_planning['desiredDays'] as int? ?? 1))) {
      setState(() => _error = 'answerRequired');
      return;
    }
    if ((key == 'level' && _level == null) ||
        (key == 'experience' && _months == null) ||
        (key == 'frequency' && !_confirmed.contains(key)) ||
        (key == 'referenceKind' && _kind == null)) {
      setState(() => _error = 'answerRequired');
      return;
    }
    if (key == 'testDate' && _date == null) {
      setState(() => _error = 'dateRequired');
      return;
    }
    _confirmed.add(key);
    if (key == 'level' && _level == RunningLevel.starting && !_returning) {
      _months = 0;
      _confirmed.add('experience');
    }
    if (key == 'volume') _confirmed.add('weeklyMinutes');
    if (key == 'customDayBudgets' && _planning[key] != true) {
      _planning['dayMinutes'] = <String, int>{};
    }
    if (key == 'routes') {
      _planning['routePreference'] = 'distance';
      _confirmed.add('routes');
    }
    if (key != 'review') {
      final followUp = switch (key) {
        'level' => _steps.contains('experience') ? 'experience' : null,
        'experience' => _returning ? 'breakWeeks' : null,
        'longest' => _steps.contains('longestDate') ? 'longestDate' : null,
        'longestDate' => 'longestEffort',
        'reference' => _kind != 'none' ? 'referenceKind' : null,
        'referenceKind' => _kind == 'maximal' ? 'testDate' : null,
        'zoneMethod' => _planning['zoneMethod'] == 'manual' ? 'zone0' : null,
        'zone0' => 'zone1',
        'zone1' => 'zone2',
        'zone2' => 'zone3',
        'zone3' => 'zone4',
        'zone4' => 'zone5',
        _ => null,
      };
      _change(
        () =>
            _step =
                widget.initialQuestion == null
                    ? _step + 1
                    : _steps.indexOf(followUp ?? 'review'),
      );
      return;
    }
    // Validate all screens again, including imported or restored drafts.
    for (final e
        in {
          'continuous': 'continuous',
          'distance': 'reference',
          'time': 'reference',
          'longest': 'longest',
          'restPulse': 'restPulse',
          'maxPulse': 'maxPulse',
        }.entries) {
      if (_validate(e.key, _fields[e.key]!.text) != null) {
        _change(() => _step = _steps.indexOf(e.value));
        return;
      }
    }
    final p = _profile();
    final missing =
        ProfileReadiness.running(
          p,
        ).where((k) => k != 'confirmProfile').toList();
    if (missing.isNotEmpty) {
      final index = _steps.indexOf(missing.first);
      _change(() {
        _step = index < 0 ? 0 : index;
        _error = 'answerRequired';
      });
      return;
    }
    try {
      p.validate();
    } catch (_) {
      setState(() => _error = 'numberError');
      return;
    }
    if (_level!.index > RunningAssessment.level(p).index && !_returning) {
      setState(() => _error = 'levelMismatch');
      return;
    }
    setState(() => _busy = true);
    try {
      await _writes;
      ProfileReadiness.requireRunning(p);
      await widget.provider.repository.saveProfile(p);
      final user = await _repo.userProfile();
      await _repo.saveUserProfile(
        UserTrainingProfile.fromJson({
          ...user.toJson(),
          'interests': {...user.interests, 'running'}.toList(),
          'interestsVersion': 1,
        }),
      );
      await _repo.clearDraft('running-profile');
      await widget.provider.load();
      if (widget.offerReplan && widget.setupRepository == null) {
        final activeId = await _repo.activeId();
        final active =
            (await _repo.plans())
                .where((p) => p.id == activeId && p.hasRunning)
                .firstOrNull;
        if (active != null && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RunningReplanScreen(plan: active),
            ),
          );
          return;
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = 'savingError');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String key, {String? suffix, String? label}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: _fields[key],
      key: ValueKey('running-$key'),
      keyboardType:
          key == 'time'
              ? TextInputType.datetime
              : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        errorMaxLines: 3,
      ),
      validator: (v) => _validate(key, v),
    ),
  );
  Widget _choice<T>(
    T value,
    T? selected,
    String title,
    ValueChanged<T> change,
  ) => RadioListTile<T>(
    value: value,
    groupValue: selected,
    title: Text(title),
    contentPadding: EdgeInsets.zero,
    onChanged: (v) {
      if (v != null) _change(() => change(v));
    },
  );
  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null && mounted) _change(() => _date = d);
  }

  List<Widget> _volumeQuestion() {
    final mode =
        _planning['volumeUnit'] as String? ??
        (_planning['weeklyMinutes'] != null
            ? 'minutes'
            : _volume != null
            ? 'distance'
            : 'unknown');
    return [
      Wrap(
        spacing: 8,
        children: [
          for (final value in ['minutes', 'distance', 'unknown'])
            ChoiceChip(
              label: Text(context.recording(value)),
              selected: mode == value,
              onSelected:
                  (_) => _change(() {
                    _planning['volumeUnit'] = value;
                    _volume = null;
                    _planning['weeklyMinutes'] = null;
                    _loadSource =
                        value == 'unknown' ? 'unknown' : 'selfReported';
                  }),
            ),
        ],
      ),
      const SizedBox(height: 16),
      if (mode != 'unknown')
        TextFormField(
          key: ValueKey('volume-$mode'),
          initialValue:
              mode == 'minutes'
                  ? _planning['weeklyMinutes']?.toString() ?? ''
                  : _volume == null
                  ? ''
                  : (_volume! / CardioUnits.distanceUnit(_original.units))
                      .toString(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText:
                mode == 'minutes'
                    ? 'min'
                    : _original.units == DistanceSystem.metric
                    ? 'km'
                    : 'mi',
          ),
          validator: (raw) {
            final v = double.tryParse((raw ?? '').replaceAll(',', '.'));
            return v != null &&
                    v.isFinite &&
                    v >= 0 &&
                    v <= (mode == 'minutes' ? 1800 : 300)
                ? null
                : context.planning('numberError');
          },
          onChanged: (raw) {
            final v = double.tryParse(raw.replaceAll(',', '.'));
            if (mode == 'minutes') {
              _planning['weeklyMinutes'] = v;
            } else {
              _volume =
                  v == null
                      ? null
                      : v * CardioUnits.distanceUnit(_original.units);
            }
            _loadSource = 'selfReported';
            _persist();
          },
        ),
    ];
  }

  List<Widget> _planningQuestion(String key) {
    String label(String value) => context.running(value);
    final choices = <String, List<Object>>{
      'goal': ['runFaster', 'runFurther', 'firstDistance'],
      'complaints': ['none', 'pain', 'medical'],
      'walkPreparation': [true, false],
      'highLoadTolerated': [true, false],
      'walkBreaks': [true, false],
      'audio': [true, false],
      'customDayBudgets': [false, true],
      'desiredDays': [1, 2, 3, 4, 5, 6],
      'pulseSource': ['unknown', 'watch', 'chest', 'diagnostic'],
      'zoneMethod': ['karvonen', 'manual'],
      'routePreference': ['time', 'distance'],
    };
    if (choices.containsKey(key)) {
      return [
        for (final v in choices[key]!)
          _choice<Object>(
            v,
            _planning[key],
            v is bool
                ? label(v ? 'yes' : 'no')
                : v is int
                ? '$v'
                : label('$v'),
            (value) {
              _planning[key] = value;
              _confirmed.add(key);
            },
          ),
        if (key == 'desiredDays' && _planning[key] == 1)
          Text(label('singleDayHint')),
        if (key == 'complaints' && _planning[key] != 'none')
          Text(label('restrictedTraining')),
        if (key == 'customDayBudgets' && _planning[key] == true)
          for (final day in _availableDays)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      DateFormat.EEEE(
                        Localizations.localeOf(context).toString(),
                      ).format(DateTime(2026, 10, 18 + day)),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('day-budget-$day'),
                      initialValue:
                          '${(_planning['dayMinutes'] as Map?)?['$day'] ?? _planning['minutesPerSession'] ?? 45}',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(suffixText: 'min'),
                      validator: (raw) {
                        final n = int.tryParse(raw ?? '');
                        return n != null && n >= 10 && n <= 300
                            ? null
                            : context.planning('numberError');
                      },
                      onChanged: (raw) {
                        final values = Map<String, dynamic>.from(
                          _planning['dayMinutes'] as Map? ?? {},
                        );
                        values['$day'] = int.tryParse(raw);
                        _planning['dayMinutes'] = values;
                        _persist();
                      },
                    ),
                  ),
                ],
              ),
            ),
        if (key == 'zoneMethod') Text(label('manualZoneHint')),
      ];
    }
    if (key == 'availableDays' || key == 'hardTrainingDays') {
      final selected =
          key == 'availableDays'
              ? _availableDays
              : List<int>.from(_planning['hardTrainingDays'] as List? ?? []);
      return [
        for (var day = 1; day <= 7; day++)
          CheckboxListTile(
            title: Text(
              DateFormat.EEEE(
                Localizations.localeOf(context).toString(),
              ).format(DateTime(2026, 10, 19 + day - 1)),
            ),
            value: selected.contains(day),
            onChanged:
                (v) => _change(() {
                  v == true ? selected.add(day) : selected.remove(day);
                  selected.sort();
                  if (key == 'availableDays') {
                    _availableDays = selected;
                  } else {
                    _planning[key] = selected;
                  }
                }),
          ),
      ];
    }
    if (key == 'longestDate') {
      return [
        ListTile(
          title: Text(
            _planning[key] == null
                ? label(key)
                : DateFormat.yMMMd().format(
                  DateTime.parse(_planning[key] as String),
                ),
          ),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: () async {
            final now = DateTime.now();
            final result = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: now.subtract(const Duration(days: 30)),
              lastDate: now,
            );
            if (result != null) {
              _change(() => _planning[key] = result.toIso8601String());
            }
          },
        ),
      ];
    }
    final zone = key.startsWith('zone') && key != 'zoneMethod';
    final dayBudget = key.startsWith('budget');
    final day = dayBudget ? key.substring(6) : null;
    final dayMinutes = Map<String, dynamic>.from(
      _planning['dayMinutes'] as Map? ?? {},
    );
    final route = key == 'routeMeters';
    final distanceUnit = CardioUnits.distanceUnit(_original.units);
    final zoneIndex = zone ? int.parse(key.substring(4)) : -1;
    final bounds = List<int>.from(_planning['zoneBounds'] as List? ?? []);
    final optional = ['weeklyMinutes', 'longestMinutes'].contains(key);
    return [
      if (key == 'minutesPerSession') Text(label('timeBudgetHint')),
      TextFormField(
        key: ValueKey(key),
        initialValue:
            zone
                ? (bounds.length > zoneIndex ? '${bounds[zoneIndex]}' : '')
                : dayBudget
                ? '${dayMinutes[day] ?? _planning['minutesPerSession'] ?? 45}'
                : route
                ? (_planning[key] == null
                    ? ''
                    : ((_planning[key] as num) / distanceUnit).toStringAsFixed(
                      2,
                    ))
                : _planning[key]?.toString() ?? '',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          suffixText:
              zone
                  ? 'bpm'
                  : route
                  ? (_original.units == DistanceSystem.metric ? 'km' : 'mi')
                  : key == 'longestEffort'
                  ? '/ 10'
                  : key == 'breakWeeks'
                  ? context.recording('weeks')
                  : 'min',
        ),
        validator: (raw) {
          if (optional && (raw ?? '').trim().isEmpty) return null;
          if (route) {
            final meters =
                (double.tryParse((raw ?? '').replaceAll(',', '.')) ?? 0) *
                distanceUnit;
            return meters >= 100 && meters <= 100000
                ? null
                : context.planning('numberError');
          }
          final v = int.tryParse(raw ?? '');
          if (v == null ||
              v <
                  (zone
                      ? 25
                      : key == 'walkMinutes' || key == 'weeklyMinutes'
                      ? 0
                      : 1) ||
              v >
                  (zone
                      ? 250
                      : key == 'longestEffort'
                      ? 10
                      : key == 'weeklyMinutes'
                      ? 1800
                      : key == 'breakWeeks'
                      ? 520
                      : 300) ||
              ((key == 'minutesPerSession' || dayBudget) && v < 10)) {
            return context.planning('numberError');
          }
          if (zone &&
              zoneIndex > 0 &&
              bounds.length >= zoneIndex &&
              v <= bounds[zoneIndex - 1]) {
            return context.planning('pulseOrder');
          }
          return null;
        },
        onChanged: (text) {
          final value = int.tryParse(text);
          if (route) {
            _planning[key] =
                (double.tryParse(text.replaceAll(',', '.')) ?? 0) *
                distanceUnit;
          } else if (dayBudget) {
            dayMinutes[day!] = value;
            _planning['dayMinutes'] = dayMinutes;
          } else if (zone) {
            while (bounds.length <= zoneIndex) {
              bounds.add(0);
            }
            bounds[zoneIndex] = value ?? 0;
            _planning['zoneBounds'] = bounds;
            _planning['zoneSource'] = 'manual';
          } else {
            _planning[key] = value;
          }
          _persist();
        },
      ),
      if (optional) Text(label('unknown')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: _load,
            child: Text(context.planning(_error ?? 'retry')),
          ),
        ),
      );
    }
    final key = _steps[_step],
        unit = _original.units == DistanceSystem.metric ? 'km' : 'mi';
    final title = switch (key) {
      'experience' => 'experienceQuestion',
      'continuous' => 'continuousQuestion',
      'frequency' => 'frequencyQuestion',
      'volume' => 'volumeQuestion',
      'reference' =>
        _otherDistance ? 'referenceOtherQuestion' : 'referenceQuestion',
      'referenceKind' => 'referenceKindQuestion',
      'longest' => 'longestQuestion',
      'restPulse' => 'restPulseQuestion',
      'maxPulse' => 'maxPulseQuestion',
      'review' => 'profileReview',
      _ => key,
    };
    final content = <Widget>[
      if (_adaptive.contains(key) ||
          key.startsWith('budget') ||
          RegExp(r'^zone[0-5]$').hasMatch(key))
        ..._planningQuestion(key),
      if (key == 'level') ...[
        _choice(
          'new',
          _returning
              ? 'returning'
              : _level == RunningLevel.starting
              ? 'new'
              : _level?.name,
          context.recording('newRunner'),
          (_) {
            _level = RunningLevel.starting;
            _returning = false;
          },
        ),
        _choice(
          'returning',
          _returning ? 'returning' : null,
          context.recording('returning'),
          (_) {
            _returning = true;
            _level ??= RunningLevel.beginner;
          },
        ),
        for (final l in RunningLevel.values.skip(1))
          _choice(l, _returning ? null : _level, context.planning(l.name), (v) {
            _level = v;
            _returning = false;
          }),
      ],
      if (key == 'experience') ...[
        for (final e
            in {
              0: 'newRunner',
              2: 'twoMonths',
              6: 'sixMonths',
              24: 'twoYears',
            }.entries)
          _choice(e.key, _months, context.planning(e.value), (v) {
            _months = v;
          }),
      ],
      if (key == 'continuous') ...[
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: context.planning('continuousHelp'),
            onPressed:
                () => showDialog<void>(
                  context: context,
                  builder:
                      (c) => AlertDialog(
                        content: Text(c.planning('continuousHelp')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                ),
          ),
        ),
        const SizedBox(height: 16),
        _field('continuous', suffix: 'min'),
      ],
      if (key == 'frequency') ...[
        Text(context.recording('frequencyHint')),
        _choice(
          -1,
          _frequency == null && _confirmed.contains(key) ? -1 : null,
          context.planning('unknown'),
          (_) {
            _frequency = null;
            _confirmed.add(key);
          },
        ),
        if (_history?.recentRunsPerWeek != null)
          Text(
            '${context.planning('historySuggestion')}: ${_history!.recentRunsPerWeek}',
          ),
        for (var i = 0; i <= 7; i++)
          _choice(i, _frequency, '$i', (v) {
            _frequency = v;
            _confirmed.add(key);
          }),
      ],
      if (key == 'volume') ...[
        if ((_history?.weeklyMeters ?? 0) > 0)
          OutlinedButton(
            onPressed:
                () => _change(() {
                  _volume = _history!.weeklyMeters;
                  _planning['weeklyMinutes'] = null;
                  _planning['volumeUnit'] = 'distance';
                  _loadSource = 'historyConfirmed';
                  _confirmed.add(key);
                }),
            child: Text(
              '${context.planning('historySuggestion')}: ${CardioUnits.distance(_history!.weeklyMeters, _original.units)}',
            ),
          ),
        ..._volumeQuestion(),
      ],
      if (key == 'reference') ...[
        TextButton(
          onPressed:
              () => _change(() {
                _kind = 'none';
                _fields['time']!.clear();
                _confirmed.add('reference');
                _step++;
              }),
          child: Text(context.running('skipReference')),
        ),
        if (_otherDistance)
          _field('distance', suffix: unit, label: context.planning('distance')),
        Text(context.planning('referenceHelp')),
        const SizedBox(height: 16),
        _field('time', suffix: 'min'),
        if (_kind == 'none')
          TextButton(
            onPressed: () => _change(() => _kind = null),
            child: Text(context.planning('referenceQuestion')),
          ),
        if (!_otherDistance)
          TextButton(
            onPressed: () => _change(() => _otherDistance = true),
            child: Text(context.planning('otherDistance')),
          ),
      ],
      if (key == 'referenceKind') ...[
        for (final e
            in {
              'normal': 'normalReference',
              'runWalk': 'walkReference',
              'maximal': 'maximalReference',
            }.entries)
          _choice(e.key, _kind, context.planning(e.value), (v) => _kind = v),
        Text(
          context.planning('estimatedHelp'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      if (key == 'testDate')
        ListTile(
          title: Text(
            _date == null
                ? context.planning('testDate')
                : DateFormat.yMMMd(
                  Localizations.localeOf(context).toString(),
                ).format(_date!),
          ),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: _pickDate,
        ),
      if (key == 'longest') ...[
        ..._planningQuestion('longestMinutes'),
        ExpansionTile(
          title: Text(context.recording('optionalDistance')),
          children: [_field('longest', suffix: unit)],
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed:
              () => _change(() {
                _fields['longest']!.clear();
                _planning['longestMinutes'] = null;
                _planning['longestDate'] = null;
                _planning['longestEffort'] = null;
                _confirmed.add('longest');
                _step++;
              }),
          child: Text(context.recording('unknown')),
        ),
      ],
      if (key == 'restPulse' || key == 'maxPulse') ...[
        Text(context.planning('pulseOptional')),
        const SizedBox(height: 16),
        _field(key, suffix: 'bpm'),
      ],
      if (key == 'review') ...[
        Text(
          context.planning(RunningAssessment.level(_profile()).name),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Text(
          context.planning(switch (RunningAssessment.level(_profile())) {
            RunningLevel.starting => 'baseReason',
            RunningLevel.beginner => 'beginnerReason',
            _ => 'advancedReason',
          }),
        ),
        const SizedBox(height: 16),
        if (_kind != 'none')
          Text(
            '${CardioUnits.distance(_meters('distance'), _original.units, locale: Localizations.localeOf(context).toString())} · ${CardioUnits.clock(_seconds ?? 0)}',
          ),
        if (_kind == 'none') Text(context.running('noReference')),
        if (_profile().zones.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                _planning['zoneMethod'] == 'manual'
                    ? '${context.cardio('heartRate')} · ${context.running('manual')}'
                    : context.cardio('zones'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _planning['zoneMethod'] == 'manual'
                      ? context.running('manualZoneHint')
                      : context.planning('zoneInfo'),
                ),
              ),
              for (final zone in _profile().zones.indexed)
                ListTile(
                  title: Text('Zone ${zone.$1 + 1}'),
                  trailing: Text(
                    '${zone.$2.$1}–${zone.$2.$2} bpm',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
            ],
          ),
        if (_level != null &&
            _level!.index > RunningAssessment.level(_profile()).index &&
            !_returning)
          TextButton(
            onPressed:
                () =>
                    _change(() => _level = RunningAssessment.level(_profile())),
            child: Text(context.planning('useSuggestedLevel')),
          ),
      ],
      if (key == 'routes')
        FavoriteRoutesEditor(
          routes:
              (_planning['favoriteRoutes'] as List? ?? [])
                  .map(
                    (r) => FavoriteRunningRoute.fromJson(
                      Map<String, dynamic>.from(r as Map),
                    ),
                  )
                  .toList(),
          units: _original.units,
          onChanged:
              (routes) => _change(
                () =>
                    _planning['favoriteRoutes'] =
                        routes.map((r) => r.toJson()).toList(),
              ),
        ),
    ];
    return ProfileQuestion(
      title: context.planning('runningProfile'),
      question:
          [
                'level',
                'volume',
                'longest',
                'routes',
                'breakWeeks',
                'customDayBudgets',
              ].contains(key)
              ? context.recording(
                key == 'level'
                    ? 'context'
                    : key == 'customDayBudgets'
                    ? 'dayBudgets'
                    : key,
              )
              : key.startsWith('budget')
              ? '${context.running('minutesPerSession')} · ${DateFormat.EEEE(Localizations.localeOf(context).toString()).format(DateTime(2026, 10, 18 + int.parse(key.substring(6))))}'
              : _adaptive.contains(key)
              ? context.running(key)
              : RegExp(r'^zone[0-5]$').hasMatch(key)
              ? '${context.running('zoneBoundary')} ${int.parse(key.substring(4)) + 1} / 6'
              : context.planning(title),
      step: _step,
      count: _steps.length,
      formKey: _form,
      onNext: _next,
      onBack: () {
        if (_step == 0) {
          _later();
        } else {
          _change(() => _step--);
        }
      },
      onLater: _later,
      busy: _busy,
      error: _error,
      children: content,
    );
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }
}
