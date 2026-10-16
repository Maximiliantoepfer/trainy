import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/training_profile.dart';
import '../repositories/training_profile_repository.dart';
import '../utils/uuid_v4.dart';
import 'local_save_dialog.dart';

/// Shared by settings, workout creation and the workout's profile chooser.
Future<TrainingProfileRecord?> showTrainingProfileEditor(
  BuildContext context, {
  required TrainingProfileStore store,
  TrainingProfileRecord? existing,
  int sortOrder = 0,
}) async {
  final draft = await showDialog<TrainingProfileDraft>(
    context: context,
    builder: (_) => _TrainingProfileDialog(initial: existing),
  );
  if (draft == null || !context.mounted) return null;
  final now = DateTime.now().toUtc();
  final value =
      existing?.copyWith(
        name: draft.name,
        equipmentCodes: draft.equipmentCodes,
        updatedAtUtc: now,
      ) ??
      TrainingProfileRecord(
        id: UuidV4.generate(),
        name: draft.name,
        equipmentCodes: draft.equipmentCodes,
        sortOrder: sortOrder,
        createdAtUtc: now,
        updatedAtUtc: now,
      );
  return showLocalSave(context, () async {
    await store.save(value);
    return value;
  });
}

@immutable
class TrainingProfileDraft {
  const TrainingProfileDraft({
    required this.name,
    required this.equipmentCodes,
  });

  final String name;
  final Set<String> equipmentCodes;
}

@immutable
class _ProfileViewData {
  const _ProfileViewData(this.profiles);

  final List<TrainingProfileRecord> profiles;
}

class TrainingProfileSettingsCard extends StatefulWidget {
  const TrainingProfileSettingsCard({super.key, required this.store});

  final TrainingProfileStore store;

  @override
  State<TrainingProfileSettingsCard> createState() =>
      _TrainingProfileSettingsCardState();
}

class _TrainingProfileSettingsCardState
    extends State<TrainingProfileSettingsCard> {
  late Future<_ProfileViewData> _profilesFuture;
  bool _modalOpen = false;
  bool _mutationRunning = false;

  @override
  void initState() {
    super.initState();
    _profilesFuture = _load();
  }

  Future<_ProfileViewData> _load() async {
    return _ProfileViewData(await widget.store.profiles());
  }

  void _refresh() {
    if (!mounted) return;
    // A setState callback must be synchronous. Using the assignment expression
    // directly would return the Future from _load() in debug builds.
    setState(() {
      _profilesFuture = _load();
    });
  }

  Future<void> _showEditor([TrainingProfileRecord? existing]) async {
    if (_modalOpen || _mutationRunning) return;
    setState(() => _modalOpen = true);
    try {
      final current = await _profilesFuture;
      if (!mounted) return;
      final result = await showTrainingProfileEditor(
        context,
        store: widget.store,
        existing: existing,
        sortOrder: current.profiles.length,
      );
      if (result != null && mounted) _refresh();
    } finally {
      if (mounted) setState(() => _modalOpen = false);
    }
  }

  Future<void> _archive(TrainingProfileRecord profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(dialogContext.l10n.archiveProfile),
            content: Text(
              dialogContext.l10n.archiveProfileDescription(profile.name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(dialogContext.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(dialogContext.l10n.archive),
              ),
            ],
          ),
    );
    if (confirmed == true && mounted) {
      await _mutate(() => widget.store.archive(profile.id));
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_mutationRunning) return;
    setState(() => _mutationRunning = true);
    try {
      await action();
      _refresh();
    } on TrainingProfileRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.profileOperationFailed(error.operation)),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.profileOperationFailed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _mutationRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<_ProfileViewData>(
        future: _profilesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(
                  key: ValueKey('trainingProfilesLoading'),
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return _ProfileError(error: snapshot.error!, onRetry: _refresh);
          }
          final data = snapshot.requireData;
          return Column(
            key: const ValueKey('trainingProfileCard'),
            children: [
              ListTile(
                leading: const Icon(Icons.fitness_center_rounded),
                title: Text(context.l10n.trainingProfile),
                subtitle: Text(context.l10n.trainingProfileDescription),
                trailing: IconButton(
                  key: const ValueKey('addTrainingProfile'),
                  tooltip: context.l10n.add,
                  onPressed:
                      _modalOpen || _mutationRunning ? null : _showEditor,
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
              if (data.profiles.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(context.l10n.noProfiles),
                  ),
                )
              else
                for (final profile in data.profiles)
                  _ProfileTile(
                    profile: profile,
                    enabled: !_mutationRunning,
                    onEdit: () => _showEditor(profile),
                    onArchive: () => _archive(profile),
                  ),
              if (_mutationRunning) const LinearProgressIndicator(minHeight: 2),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.profileLoadFailed,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 4),
        Text('$error', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(context.l10n.retry),
        ),
      ],
    ),
  );
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.enabled,
    required this.onEdit,
    required this.onArchive,
  });

  final TrainingProfileRecord profile;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey('trainingProfile_${profile.id}'),
    leading: const Icon(Icons.fitness_center_rounded),
    title: Text(profile.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      profile.equipmentCodes.isEmpty
          ? context.l10n.noEquipmentSelected
          : profile.equipmentCodes
              .map((code) => equipmentLabel(context, code))
              .join(' · '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: PopupMenuButton<String>(
      enabled: enabled,
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'archive') onArchive();
      },
      itemBuilder:
          (context) => [
            PopupMenuItem(value: 'edit', child: Text(context.l10n.edit)),
            PopupMenuItem(value: 'archive', child: Text(context.l10n.archive)),
          ],
    ),
  );
}

class _TrainingProfileDialog extends StatefulWidget {
  const _TrainingProfileDialog({this.initial});

  final TrainingProfileRecord? initial;

  @override
  State<_TrainingProfileDialog> createState() => _TrainingProfileDialogState();
}

class _TrainingProfileDialogState extends State<_TrainingProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Set<String> _selectedEquipment;
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;

  @override
  void initState() {
    super.initState();
    _selectedEquipment = {
      ...(widget.initial?.equipmentCodes ?? {'bodyweight'}),
    };
    _nameController = TextEditingController(text: widget.initial?.name);
    _nameFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      TrainingProfileDraft(
        name: _nameController.text.trim(),
        equipmentCodes: Set.unmodifiable(_selectedEquipment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      actionsPadding: const EdgeInsets.all(16),
      title: Text(
        editing
            ? context.l10n.editTrainingProfile
            : context.l10n.addTrainingProfile,
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 8),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  key: const ValueKey('trainingProfileName'),
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: context.l10n.profileName,
                  ),
                  onFieldSubmitted: (_) => _submit(),
                  validator:
                      (value) =>
                          (value?.trim().isEmpty ?? true)
                              ? context.l10n.nameRequired
                              : null,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.equipment,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 0,
                  children: [
                    for (final code in TrainingProfileRepository.equipmentCodes)
                      FilterChip(
                        key: ValueKey('trainingProfileEquipment_$code'),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.standard,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        label: Text(equipmentLabel(context, code)),
                        selected: _selectedEquipment.contains(code),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedEquipment.add(code);
                            } else {
                              _selectedEquipment.remove(code);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('trainingProfileCancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('trainingProfileSubmit'),
          onPressed: _submit,
          child: Text(editing ? context.l10n.save : context.l10n.add),
        ),
      ],
    );
  }
}

String equipmentLabel(BuildContext context, String code) => switch (code) {
  'bodyweight' => context.l10n.equipmentBodyweight,
  'dumbbell' => context.l10n.equipmentDumbbell,
  'barbell' => context.l10n.equipmentBarbell,
  'bench' => context.l10n.equipmentBench,
  'rack' => context.l10n.equipmentRack,
  'pull_up_bar' => context.l10n.equipmentPullUpBar,
  'cable' => context.l10n.equipmentCable,
  'machine' => context.l10n.equipmentMachine,
  'kettlebell' => context.l10n.equipmentKettlebell,
  'bands' => context.l10n.equipmentBands,
  'medicine_ball' => context.l10n.equipmentMedicineBall,
  'exercise_ball' => context.l10n.equipmentExerciseBall,
  'foam_roller' => context.l10n.equipmentFoamRoller,
  'ez_bar' => context.l10n.equipmentEzBar,
  'mat' => context.l10n.equipmentMat,
  'cardio_machine' => context.l10n.equipmentCardioMachine,
  'bicycle' => context.l10n.equipmentBicycle,
  'pool' => context.l10n.equipmentPool,
  _ => context.l10n.equipmentOther,
};
