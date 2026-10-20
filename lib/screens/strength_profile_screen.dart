import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/l10n.dart';
import '../l10n/planning_l10n.dart';
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
  final _equipment = <String>{};
  List<TrainingProfileRecord> _places = [];
  String? _level, _selected, _error;
  String _preset = 'home';
  int _step = 0;
  bool _ready = false, _busy = false;
  Future<void> _writes = Future.value();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
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
      _selected = draft?['selected'] as String? ?? user.strengthProfileId;
      if (draft == null && _selected == null) {
        _selected =
            _places
                .where((p) => p.name == context.l10n.homeGym && !p.isArchived)
                .firstOrNull
                ?.id;
      }
      final place = _places.where((p) => p.id == _selected).firstOrNull;
      if (place == null) _selected = null;
      _preset = draft?['preset'] as String? ?? 'home';
      _name.text =
          draft?['name'] as String? ?? place?.name ?? context.l10n.homeGym;
      _equipment.addAll(
        draft?['equipment'] == null
            ? place?.equipmentCodes ?? TrainingProfileRepository.homeEquipment
            : List<String>.from(draft!['equipment'] as List),
      );
      _step = (draft?['step'] as int? ?? 0).clamp(0, 2);
      _name.addListener(_persist);
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'error');
    }
  }

  void _persist() {
    if (!_ready) return;
    final repo = context.read<TrainingProgramProvider>().repository;
    final data = {
      'level': _level,
      'selected': _selected,
      'preset': _preset,
      'name': _name.text,
      'equipment': _equipment.toList(),
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
    await _writes;
    if (mounted) Navigator.pop(context, false);
  }

  Future<void> _next() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_level == null) {
      _change(() {
        _step = 0;
        _error = 'answerRequired';
      });
      return;
    }
    if (_step == 2 && _name.text.trim().isEmpty) {
      _change(() {
        _step = 1;
        _error = 'answerRequired';
      });
      return;
    }
    if (_step < 2) {
      _change(() => _step++);
      return;
    }
    setState(() => _busy = true);
    try {
      await _writes;
      if (!mounted) return;
      final places = context.read<TrainingProfileProvider>();
      final repo = context.read<TrainingProgramProvider>().repository;
      final now = DateTime.now().toUtc();
      final old = _places.where((p) => p.id == _selected).firstOrNull;
      final place =
          old?.copyWith(
            name: _name.text.trim(),
            equipmentCodes: {..._equipment},
            updatedAtUtc: now,
          ) ??
          TrainingProfileRecord(
            id: UuidV4.generate(),
            name: _name.text.trim(),
            equipmentCodes: {..._equipment},
            createdAtUtc: now,
            updatedAtUtc: now,
          );
      if (old != null) await places.save(place);
      await places.completeSetup(
        profiles: [place],
        preferredProfileId: place.id,
      );
      // A retry after a failed profile write must update this place, not duplicate it.
      _selected = place.id;
      _places = [..._places.where((p) => p.id != place.id), place];
      if (!mounted) return;
      _persist();
      await _writes;
      final user = await repo.userProfile();
      await repo.saveUserProfile(
        UserTrainingProfile.fromJson({
          ...user.toJson(),
          'strengthLevel': _level,
          'strengthProfileId': place.id,
          'strengthSetupVersion': 1,
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
    return ProfileQuestion(
      title: context.planning('strengthProfile'),
      question: context.planning(
        ['level', 'trainingPlace', 'equipmentQuestion'][_step],
      ),
      step: _step,
      count: 3,
      formKey: _form,
      busy: _busy,
      error: _error,
      onNext: _next,
      onLater: _later,
      onBack: () {
        if (_step == 0) {
          _later();
        } else {
          _change(() => _step--);
        }
      },
      children: [
        if (_step == 0)
          for (final l in [
            'starting',
            'beginner',
            'intermediate',
            'experienced',
          ])
            RadioListTile<String>(
              value: l,
              groupValue: _level,
              title: Text(context.planning(l)),
              onChanged: (v) => _change(() => _level = v),
            ),
        if (_step == 1) ...[
          for (final p in _places)
            RadioListTile<String>(
              value: p.id,
              groupValue: _selected,
              title: Text(p.name),
              onChanged:
                  (_) => _change(() {
                    _selected = p.id;
                    _name.text = p.name;
                    _equipment
                      ..clear()
                      ..addAll(p.equipmentCodes);
                  }),
            ),
          for (final e in {
            'home': context.l10n.homeGym,
            'gym': context.l10n.gym,
            'custom': context.l10n.individualProfile,
          }.entries.where(
            (e) => e.key == 'custom' || !_places.any((p) => p.name == e.value),
          ))
            RadioListTile<String>(
              value: e.key,
              groupValue: _selected == null ? _preset : null,
              title: Text(e.value),
              subtitle:
                  e.key == 'home' && _places.isEmpty
                      ? Text(context.planning('homeSuggestion'))
                      : null,
              onChanged:
                  (_) => _change(() {
                    _selected = null;
                    _preset = e.key;
                    _name.text = e.key == 'custom' ? '' : e.value;
                    _equipment
                      ..clear()
                      ..addAll(
                        e.key == 'home'
                            ? TrainingProfileRepository.homeEquipment
                            : e.key == 'gym'
                            ? TrainingProfileRepository.gymEquipment
                            : <String>{},
                      );
                  }),
            ),
          if (_selected == null && _preset == 'custom')
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: context.l10n.profileName),
              validator:
                  (v) =>
                      v == null || v.trim().isEmpty
                          ? context.l10n.nameRequired
                          : null,
            ),
        ],
        if (_step == 2) ...[
          Text(_name.text, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final code in TrainingProfileRepository.equipmentCodes)
                FilterChip(
                  label: Text(equipmentLabel(context, code)),
                  selected: _equipment.contains(code),
                  onSelected:
                      (v) => _change(() {
                        v ? _equipment.add(code) : _equipment.remove(code);
                      }),
                ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }
}
