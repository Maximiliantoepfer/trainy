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
    'continuous',
    if (_level == RunningLevel.starting ||
        (_fields['continuous'] != null &&
            (_number('continuous') ?? 0) < 30)) ...[
      'walkMinutes',
      'walkPreparation',
    ],
    'frequency',
    'volume',
    'weeklyMinutes',
    'longest',
    'longestMinutes',
    if (_planning['longestMinutes'] != null) ...[
      'longestDate',
      'longestEffort',
    ],
    'experience',
    'desiredDays',
    'availableDays',
    'minutesPerSession',
    'customDayBudgets',
    if (_planning['customDayBudgets'] == true)
      ..._availableDays.map((d) => 'budget$d'),
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
    'routePreference',
    if (_planning['routePreference'] == 'distance') 'routeMeters',
    'walkBreaks',
    'audio',
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
      _otherDistance = _canonical['distance'] != 5000;
      for (final entry in values.entries) {
        _fields[entry.key] = TextEditingController(text: entry.value)
          ..addListener(_persist);
      }
      // Conditional questions depend on restored controller values. Resolve
      // the named step only after all those values have been installed.
      _step =
          restoredStep == null
              ? 0
              : _steps.indexOf(restoredStep).clamp(0, _steps.length - 1);
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
    'setupVersion': 2,
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
    'loadSource': _volume == null ? 'unknown' : _loadSource,
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
        (['frequency', 'volume'].contains(key) && !_confirmed.contains(key)) ||
        (key == 'referenceKind' && _kind == null)) {
      setState(() => _error = 'answerRequired');
      return;
    }
    if (key == 'testDate' && _date == null) {
      setState(() => _error = 'dateRequired');
      return;
    }
    _confirmed.add(key);
    if (key != 'review') {
      _change(() => _step++);
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
      final changes = await widget.provider.repository.targetAdjustment(p);
      if (changes.isNotEmpty && mounted) {
        final yes = await showDialog<bool>(
          context: context,
          builder:
              (c) => AlertDialog(
                title: Text(c.planning('regenerate')),
                content: Text(c.planning('regenerateHint')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(c.planning('later')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(c.planning('save')),
                  ),
                ],
              ),
        );
        if (yes == true) {
          await widget.provider.repository.applyAdjustment(changes);
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
        if (key == 'complaints') Text(label('restrictedTraining')),
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
        for (final l in RunningLevel.values)
          _choice(l, _level, context.planning(l.name), (v) => _level = v),
      ],
      if (key == 'experience') ...[
        for (final e
            in {
              0: 'newRunner',
              2: 'twoMonths',
              6: 'sixMonths',
              24: 'twoYears',
            }.entries)
          _choice(
            e.key,
            _returning ? null : _months,
            context.planning(e.value),
            (v) {
              _months = v;
              _returning = false;
            },
          ),
        _choice(-1, _returning ? -1 : null, context.planning('returning'), (_) {
          _months = 0;
          _returning = true;
        }),
      ],
      if (key == 'continuous') ...[
        Text(context.planning('continuousHelp')),
        const SizedBox(height: 16),
        _field('continuous', suffix: 'min'),
      ],
      if (key == 'frequency') ...[
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
        Text(context.planning('volumeHelp')),
        const SizedBox(height: 8),
        if ((_history?.weeklyMeters ?? 0) > 0)
          OutlinedButton(
            onPressed:
                () => _change(() {
                  _volume = _history!.weeklyMeters;
                  _loadSource = 'historyConfirmed';
                  _confirmed.add(key);
                }),
            child: Text(
              '${context.planning('historySuggestion')}: ${CardioUnits.distance(_history!.weeklyMeters, _original.units)}',
            ),
          ),
        if (_loadSource == 'historyConfirmed' && _volume != null)
          Text('✓ ${CardioUnits.distance(_volume!, _original.units)}'),
        for (final m in [0, 5000, 15000, 30000, 50000, 70000])
          _choice(
            m.toDouble(),
            _volume,
            m == 0
                ? context.planning('volume0')
                : _original.units == DistanceSystem.metric
                ? context.planning('volume${m ~/ 1000}')
                : '${CardioUnits.distance(m.toDouble(), _original.units, locale: Localizations.localeOf(context).toString())} ≈',
            (v) {
              _volume = v;
              _loadSource = 'selfReported';
              _confirmed.add(key);
            },
          ),
        _choice(
          -1.0,
          _confirmed.contains(key) && _volume == null ? -1.0 : null,
          context.planning('unknown'),
          (_) {
            _volume = null;
            _confirmed.add(key);
          },
        ),
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
        Text(context.planning('longestHelp')),
        const SizedBox(height: 16),
        _field('longest', suffix: unit),
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
                context.cardio('zones'),
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
    ];
    return ProfileQuestion(
      title: context.planning('runningProfile'),
      question:
          key.startsWith('budget')
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
