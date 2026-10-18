import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/training_profile.dart';
import '../providers/training_profile_provider.dart';
import '../repositories/training_profile_repository.dart';
import '../utils/uuid_v4.dart';
import '../widgets/training_profile_settings_card.dart';

class ProfileOnboardingScreen extends StatefulWidget {
  const ProfileOnboardingScreen({
    super.key,
    required this.profiles,
    this.required = false,
  });
  final TrainingProfileProvider profiles;
  final bool required;
  @override
  State<ProfileOnboardingScreen> createState() =>
      _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState extends State<ProfileOnboardingScreen> {
  List<TrainingProfileRecord>? _drafts;
  String? _preferred;
  bool _saving = false;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_drafts != null) return;
    final now = DateTime.now().toUtc();
    _drafts = [
      TrainingProfileRecord(
        id: UuidV4.generate(),
        name: context.l10n.homeGym,
        equipmentCodes: TrainingProfileRepository.homeEquipment,
        createdAtUtc: now,
        updatedAtUtc: now,
      ),
      TrainingProfileRecord(
        id: UuidV4.generate(),
        name: context.l10n.gym,
        equipmentCodes: TrainingProfileRepository.gymEquipment,
        createdAtUtc: now,
        updatedAtUtc: now,
        sortOrder: 1,
      ),
    ];
    _preferred = _drafts!.first.id;
  }

  void _replace(int index, TrainingProfileRecord value) => setState(() {
    if (_preferred == _drafts![index].id) _preferred = value.id;
    _drafts![index] = value;
  });

  Future<void> _edit(int index) async {
    final record = _drafts![index];
    if (widget.profiles.activeProfiles.any((p) => p.id == record.id)) {
      final updated = await showTrainingProfileEditor(
        context,
        store: widget.profiles,
        existing: record,
      );
      if (mounted && updated != null) _replace(index, updated);
    } else {
      final draft = await showTrainingProfileDraft(context, existing: record);
      if (mounted && draft != null) {
        _replace(
          index,
          record.copyWith(
            name: draft.name,
            equipmentCodes: draft.equipmentCodes,
          ),
        );
      }
    }
  }

  Future<void> _reuse(int index) async {
    final value = await showModalBottomSheet<TrainingProfileRecord>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (c) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final p in widget.profiles.activeProfiles.where(
                  (p) =>
                      !_drafts!.asMap().entries.any(
                        (e) => e.key != index && e.value.id == p.id,
                      ),
                ))
                  ListTile(
                    title: Text(p.name),
                    onTap: () => Navigator.pop(c, p),
                  ),
              ],
            ),
          ),
    );
    if (mounted && value != null) _replace(index, value);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_drafts!.map((p) => p.name.trim().toLowerCase()).toSet().length !=
          _drafts!.length) {
        throw StateError(context.l10n.useExistingProfile);
      }
      // A same-name preset must be explicitly reused or renamed, never silently merged.
      for (final draft in _drafts!) {
        if (widget.profiles.activeProfiles.any(
          (p) =>
              p.id != draft.id &&
              p.name.trim().toLowerCase() == draft.name.trim().toLowerCase(),
        )) {
          throw StateError(context.l10n.useExistingProfile);
        }
      }
      await widget.profiles.completeSetup(
        profiles: _drafts!,
        preferredProfileId: _preferred!,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.required && !_saving,
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.required,
        title: Text(context.l10n.profileOnboardingTitle),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_error == null ? context.l10n.save : context.l10n.retry),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(context.l10n.profileOnboardingHint),
          const SizedBox(height: 20),
          for (var i = 0; i < _drafts!.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RadioListTile<String>(
                      value: _drafts![i].id,
                      groupValue: _preferred,
                      onChanged:
                          _saving
                              ? null
                              : (id) => setState(() => _preferred = id),
                      title: Text(_drafts![i].name),
                      subtitle: Text(
                        context.l10n.equipmentSelectionCount(
                          _drafts![i].equipmentCodes.length,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: _saving ? null : () => _edit(i),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(context.l10n.edit),
                        ),
                        if (widget.profiles.activeProfiles.isNotEmpty)
                          TextButton(
                            onPressed: _saving ? null : () => _reuse(i),
                            child: Text(context.l10n.useExistingProfile),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (_saving) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              '${context.l10n.localSaveFailed}\n$_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
  );
}
