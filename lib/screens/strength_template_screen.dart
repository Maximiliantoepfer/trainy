import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/plan_l10n.dart';
import '../models/training_profile.dart';
import '../models/workout_planning.dart';
import '../providers/exercise_provider.dart';
import '../providers/workout_provider.dart';
import '../repositories/training_profile_repository.dart';
import '../repositories/workout_planning_repository.dart';
import '../services/catalog_repository.dart';
import '../services/strength_templates.dart';
import '../widgets/strength_prescription_editor.dart';
import 'user_training_profile_screen.dart';

class StrengthTemplateScreen extends StatefulWidget {
  const StrengthTemplateScreen({super.key, required this.code});
  final String code;
  @override
  State<StrengthTemplateScreen> createState() => _StrengthTemplateState();
}

class _StrengthTemplateState extends State<StrengthTemplateScreen> {
  final _catalog = CatalogRepository.instance;
  List<TrainingProfileRecord> _profiles = [];
  TrainingProfileRecord? _profile;
  final _selected = <String>{};
  final _choices = <String, StrengthAlternative>{};
  final _targets = <String, StrengthPrescription>{};
  bool _busy = false, _ready = false;
  String? _error;
  List<StrengthTemplateExercise> get _exercises =>
      StrengthTemplates.exercises(widget.code);
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (!await _catalog.load()) throw StateError('Catalog unavailable');
      final repo = TrainingProfileRepository();
      final profiles = await repo.profiles(),
          preferred = await repo.selectedProfileId();
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _ready = true;
        _selectProfile(
          profiles.where((p) => p.id == preferred).firstOrNull ??
              profiles.firstOrNull,
        );
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'error');
    }
  }

  void _selectProfile(TrainingProfileRecord? p) {
    _profile = p;
    _selected.clear();
    _choices.clear();
    for (final e in _exercises) {
      final choice = e.forEquipment(p?.equipmentCodes ?? {});
      if (choice != null) {
        _choices[e.key] = choice;
        if (!e.extra) _selected.add(e.key);
      }
      _targets.putIfAbsent(e.key, () => e.prescription);
    }
  }

  Future<void> _save() async {
    if (_busy || _profile == null || _selected.isEmpty) return;
    setState(() => _busy = true);
    try {
      final provider = context.read<ExerciseProvider>();
      final locale = Localizations.localeOf(context).languageCode;
      final ids = <int>[], targets = <int, StrengthPrescription>{};
      for (final e in _exercises.where((e) => _selected.contains(e.key))) {
        final item = _catalog.localized(_choices[e.key]!.catalogId, locale)!;
        final id = await provider.addCatalogExercise(item);
        if (!ids.contains(id)) {
          ids.add(id);
          targets[id] = _targets[e.key]!;
        }
      }
      if (!mounted) return;
      final workout = await WorkoutPlanningRepository().createWorkout(
        WorkoutEditorDraft(
          name: context.plan(widget.code),
          primaryGoal: WorkoutPrimaryGoal.strength,
          setupName: _profile!.name,
          profileId: _profile!.id,
          exerciseIds: ids,
          prescriptions: targets,
        ),
      );
      if (!mounted) return;
      await context.read<WorkoutProvider>().loadWorkouts();
      if (mounted) Navigator.pop(context, workout);
    } catch (_) {
      if (mounted) setState(() => _error = 'savingError');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(StrengthTemplateExercise e) {
    final choice = _choices[e.key] ?? e.alternatives.first;
    final name =
        _catalog
            .content(
              choice.catalogId,
              Localizations.localeOf(context).languageCode,
            )
            ?.name ??
        choice.catalogId;
    final available = _choices.containsKey(e.key);
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: _selected.contains(e.key),
          onChanged:
              !available || _busy
                  ? null
                  : (v) => setState(() {
                    v == true ? _selected.add(e.key) : _selected.remove(e.key);
                  }),
        ),
        title: Text(name),
        subtitle: Text(
          available ? _targets[e.key]!.label : context.plan('missingEquipment'),
        ),
        trailing:
            available
                ? IconButton(
                  tooltip: context.plan('edit'),
                  icon: const Icon(Icons.tune),
                  onPressed: () async {
                    final p = await editStrengthPrescription(
                      context,
                      _targets[e.key]!,
                    );
                    if (p != null && mounted) {
                      setState(() => _targets[e.key] = p);
                    }
                  },
                )
                : const Icon(Icons.warning_amber_rounded),
        onTap: () async {
          final choices =
              e.alternatives
                  .where((a) => a.available(_profile?.equipmentCodes ?? {}))
                  .toList();
          if (choices.length < 2) {
            if (available) {
              setState(() {
                _selected.contains(e.key)
                    ? _selected.remove(e.key)
                    : _selected.add(e.key);
              });
            }
            return;
          }
          final alt = await showModalBottomSheet<StrengthAlternative>(
            context: context,
            showDragHandle: true,
            builder:
                (c) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final a in choices)
                        ListTile(
                          title: Text(
                            _catalog
                                .content(
                                  a.catalogId,
                                  Localizations.localeOf(c).languageCode,
                                )!
                                .name,
                          ),
                          onTap: () => Navigator.pop(c, a),
                        ),
                    ],
                  ),
                ),
          );
          if (alt != null && mounted) setState(() => _choices[e.key] = alt);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.plan(widget.code))),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(20),
      child: FilledButton(
        onPressed: !_ready || _busy || _selected.isEmpty ? null : _save,
        child: Text(context.plan('save')),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_profiles.isNotEmpty)
          DropdownButtonFormField<String>(
            value: _profile?.id,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.plan('strengthProfile'),
            ),
            items: [
              for (final p in _profiles)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged:
                (id) => setState(
                  () => _selectProfile(_profiles.firstWhere((p) => p.id == id)),
                ),
          ),
        ListTile(
          title: Text(context.plan('strengthProfile')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => const UserTrainingProfileScreen(strengthOnly: true),
              ),
            );
            await _load();
          },
        ),
        if (_ready) ...[
          for (final e in _exercises.where((e) => !e.extra)) _row(e),
          ExpansionTile(
            title: Text(context.plan('extras')),
            children: [
              for (final e in _exercises.where((e) => e.extra)) _row(e),
            ],
          ),
        ],
        if (_error != null) Text(context.plan(_error!)),
      ],
    ),
  );
}
