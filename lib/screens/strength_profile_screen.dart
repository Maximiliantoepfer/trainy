import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/l10n.dart';
import '../l10n/planning_l10n.dart';
import '../l10n/strength_l10n.dart';
import '../models/strength_equipment.dart';
import '../models/training_program.dart';
import '../models/training_profile.dart';
import '../providers/training_profile_provider.dart';
import '../providers/training_program_provider.dart';
import '../repositories/training_profile_repository.dart';
import '../utils/uuid_v4.dart';
import '../widgets/profile_question.dart';
import '../widgets/training_profile_settings_card.dart' show equipmentLabel;

class StrengthProfileScreen extends StatefulWidget {
  const StrengthProfileScreen({super.key});
  @override
  State<StrengthProfileScreen> createState() => _StrengthProfileScreenState();
}

class _StrengthProfileScreenState extends State<StrengthProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  List<TrainingProfileRecord> _places = [];
  final _selected = <Map<String, dynamic>>[];
  final _answers = <String>{};
  String? _level, _goal, _preference, _error;
  String _preset = 'home';
  int _step = 0;
  bool _ready = false, _busy = false;
  Future<void> _writes = Future.value();
  bool get _novice => ['starting', 'beginner'].contains(_level);
  bool get _gym => _selected.any((p) => p['kind'] == 'gym');
  List<String> get _steps => [
    'level',
    'goal',
    'places',
    for (var i = 0; i < _selected.length; i++) 'equipment:$i',
    if (_gym && !_novice) 'preference',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Map<String, dynamic> _record(TrainingProfileRecord p, String kind) => {
    'id': p.id,
    'name': p.name,
    'equipment': p.equipmentCodes.toList(),
    'kind': kind,
    'created': p.createdAtUtc.toIso8601String(),
  };
  Map<String, dynamic> _place(String kind) {
    final name = kind == 'home' ? context.l10n.homeGym : context.l10n.gym;
    final existing = _places.where((p) => p.name == name).firstOrNull;
    return existing == null
        ? {
          'id': UuidV4.generate(),
          'name': name,
          'kind': kind,
          'equipment':
              (kind == 'home'
                      ? TrainingProfileRepository.homeEquipment
                      : TrainingProfileRepository.gymEquipment)
                  .toList(),
          'created': DateTime.now().toUtc().toIso8601String(),
        }
        : _record(existing, kind);
  }

  Future<void> _load() async {
    try {
      final repo = context.read<TrainingProgramProvider>().repository;
      final user = await repo.userProfile();
      if (!mounted) return;
      _places = await context.read<TrainingProfileProvider>().profiles();
      final draft = await repo.draft('strength-profile');
      if (!mounted) return;
      _level =
          draft?['level'] as String? ??
          (user.strengthSetupVersion > 0 ? user.strengthLevel : null);
      _goal =
          draft?['goal'] as String? ??
          (user.strengthGoal.isEmpty ? null : user.strengthGoal);
      _preference =
          draft?['preference'] as String? ??
          (user.strengthPreference.isEmpty ? null : user.strengthPreference);
      _preset = draft?['preset'] as String? ?? 'home';
      _answers.addAll(
        List<String>.from(draft?['answers'] ?? user.strengthAnswers.toList()),
      );
      if (draft?['places'] is List) {
        _selected.addAll([
          for (final p in draft!['places']) Map<String, dynamic>.from(p),
        ]);
      } else if (draft?['equipment'] is List) {
        _selected.add({
          'id': draft?['selected'] ?? UuidV4.generate(),
          'name': draft?['name'] ?? context.l10n.homeGym,
          'kind': _preset,
          'equipment': draft!['equipment'],
          'created': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        for (final id in user.strengthPlaces) {
          final p = _places.where((p) => p.id == id).firstOrNull;
          if (p != null) {
            _selected.add(
              _record(p, p.name == context.l10n.gym ? 'gym' : 'home'),
            );
          }
        }
      }
      if (_selected.isEmpty) _selected.add(_place('home'));
      if (_selected.length > 1) _preset = 'both';
      _name.text = _selected.first['name'] as String;
      _step = (draft?['version'] == 2 ? (draft?['step'] as int? ?? 0) : 0)
          .clamp(0, _steps.length - 1);
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'error');
    }
  }

  void _persist() {
    if (!_ready) return;
    final repo = context.read<TrainingProgramProvider>().repository;
    final data = {
      'version': 2,
      'level': _level,
      'goal': _goal,
      'preference': _preference,
      'places': [
        for (final p in _selected)
          {...p, 'equipment': List<String>.from(p['equipment'])},
      ],
      'preset': _preset,
      'answers': _answers.toList(),
      'step': _step,
    };
    _writes = _writes
        .then((_) => repo.saveDraft('strength-profile', data))
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

  Future<void> _later() async {
    _persist();
    await _writes;
    if (mounted) Navigator.pop(context, false);
  }

  Future<void> _next() async {
    if (_busy || !_form.currentState!.validate()) return;
    final step = _steps[_step];
    if ((step == 'level' && _level == null) ||
        (step == 'goal' && _goal == null) ||
        (step == 'preference' && _preference == null)) {
      _change(() => _error = 'answerRequired');
      return;
    }
    _answers.add(step.startsWith('equipment') ? 'equipment' : step);
    if (_novice || !_gym) {
      _preference ??= 'guided';
      _answers.add('preference');
    }
    if (_step < _steps.length - 1) {
      _change(() => _step++);
      return;
    }
    if (_level == null ||
        _goal == null ||
        !_answers.containsAll({
          'level',
          'goal',
          'places',
          'equipment',
          'preference',
        })) {
      _change(() {
        _step = 0;
        _error = 'answerRequired';
      });
      return;
    }
    setState(() => _busy = true);
    try {
      _persist();
      await _writes;
      if (!mounted) return;
      final places = context.read<TrainingProfileProvider>();
      final repo = context.read<TrainingProgramProvider>().repository;
      final records = [
        for (final p in _selected)
          TrainingProfileRecord(
            id: p['id'] as String,
            name: (p['name'] as String).trim(),
            equipmentCodes: Set<String>.from(p['equipment']),
            createdAtUtc: DateTime.parse(p['created'] as String),
            updatedAtUtc: DateTime.now().toUtc(),
          ),
      ];
      for (final p in records) {
        await places.save(p);
      }
      await places.completeSetup(
        profiles: records,
        preferredProfileId: records.first.id,
      );
      final user = await repo.userProfile();
      await repo.saveUserProfile(
        UserTrainingProfile.fromJson({
          ...user.toJson(),
          'strengthLevel': _level,
          'strengthGoal': _goal,
          'strengthPreference': _novice ? 'guided' : _preference,
          'strengthProfileId': records.first.id,
          'strengthProfileIds': records.map((p) => p.id).toList(),
          'strengthSetupVersion': 2,
          'strengthAnswers': _answers.toList(),
          'interests': {...user.interests, 'strength'}.toList(),
          'interestsVersion': 1,
        }),
      );
      await repo.clearDraft('strength-profile');
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = 'savingError');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _choosePreset(String value) => _change(() {
    final previous = {for (final p in _selected) p['kind']: p};
    _preset = value;
    _selected.clear();
    for (final kind in value == 'both' ? ['home', 'gym'] : [value]) {
      _selected.add(
        previous[kind] ??
            (kind == 'custom'
                ? {
                  'id': UuidV4.generate(),
                  'name': '',
                  'kind': 'custom',
                  'equipment': ['bodyweight'],
                  'created': DateTime.now().toUtc().toIso8601String(),
                }
                : _place(kind)),
      );
    }
    _name.text = _selected.first['name'] as String;
  });
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
    final step = _steps[_step];
    final equipment =
        step.startsWith('equipment:')
            ? _selected[int.parse(step.split(':').last)]
            : null;
    final codes =
        equipment == null
            ? <String>{}
            : Set<String>.from(equipment['equipment']);
    return ProfileQuestion(
      title: context.planning('strengthProfile'),
      question:
          step == 'level'
              ? context.planning('level')
              : step == 'goal'
              ? context.strength('goalQuestion')
              : step == 'places'
              ? context.strength('placesQuestion')
              : step == 'preference'
              ? context.strength('preferenceQuestion')
              : context.planning('equipmentQuestion'),
      step: _step,
      count: _steps.length,
      formKey: _form,
      busy: _busy,
      error: _error,
      onNext: _next,
      onLater: _later,
      laterLabel: context.strength('skipSport'),
      onBack: () {
        if (_step == 0) {
          _later();
        } else {
          _change(() => _step--);
        }
      },
      children: [
        if (step == 'level')
          for (final value in [
            'starting',
            'beginner',
            'intermediate',
            'experienced',
          ])
            RadioListTile<String>(
              value: value,
              groupValue: _level,
              title: Text(context.planning(value)),
              onChanged: (v) => _change(() => _level = v),
            ),
        if (step == 'goal')
          for (final value in ['generalFitness', 'buildMuscle', 'getStronger'])
            RadioListTile<String>(
              value: value,
              groupValue: _goal,
              title: Text(context.strength(value)),
              onChanged: (v) => _change(() => _goal = v),
            ),
        if (step == 'places') ...[
          for (final e
              in {
                'home': context.l10n.homeGym,
                'gym': context.l10n.gym,
                'both': context.strength('both'),
                'custom': context.l10n.individualProfile,
              }.entries)
            RadioListTile<String>(
              value: e.key,
              groupValue: _preset,
              title: Text(e.value),
              onChanged: (v) => _choosePreset(v!),
            ),
          for (final place in _places)
            RadioListTile<String>(
              value: place.id,
              groupValue: _preset,
              title: Text(place.name),
              onChanged:
                  (_) => _change(() {
                    _preset = place.id;
                    _selected
                      ..clear()
                      ..add(
                        _record(
                          place,
                          place.name == context.l10n.gym ? 'gym' : 'custom',
                        ),
                      );
                  }),
            ),
          if (_preset == 'custom')
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: context.l10n.profileName),
              validator:
                  (v) =>
                      v == null || v.trim().isEmpty
                          ? context.l10n.nameRequired
                          : null,
              onChanged: (v) => _change(() => _selected.first['name'] = v),
            ),
        ],
        if (equipment != null) ...[
          Text(
            equipment['name'] as String,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(context.strength('equipmentHint')),
          for (final section in [
            StrengthEquipment.basic,
            StrengthEquipment.machines,
            codes.difference(StrengthEquipment.all),
          ])
            if (section.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                context.strength(
                  section == StrengthEquipment.basic
                      ? 'equipmentBasic'
                      : section == StrengthEquipment.machines
                      ? 'equipmentMachines'
                      : 'equipmentLegacy',
                ),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final code in section)
                    FilterChip(
                      label: Text(equipmentLabel(context, code)),
                      selected: codes.contains(code),
                      onSelected:
                          (v) => _change(() {
                            v ? codes.add(code) : codes.remove(code);
                            equipment['equipment'] = codes.toList();
                          }),
                    ),
                ],
              ),
            ],
        ],
        if (step == 'preference')
          for (final value in ['guided', 'freeWeights'])
            RadioListTile<String>(
              value: value,
              groupValue: _preference,
              title: Text(context.strength(value)),
              onChanged: (v) => _change(() => _preference = v),
            ),
      ],
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }
}
