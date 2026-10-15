import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/workout_plan.dart';

const _profileEquipmentCodes = <String>[
  'bodyweight',
  'dumbbell',
  'barbell',
  'machine',
  'cable',
  'kettlebell',
  'bands',
];

@immutable
class TrainingProfileDraft {
  const TrainingProfileDraft({
    required this.name,
    required this.equipmentCodes,
  });

  final String name;
  final Set<String> equipmentCodes;
}

typedef TrainingProfileLoader = Future<List<TrainingProfile>> Function();
typedef TrainingProfileSaver = Future<void> Function(TrainingProfile profile);

class TrainingProfileSettingsCard extends StatefulWidget {
  const TrainingProfileSettingsCard({
    super.key,
    required this.loadProfiles,
    required this.saveProfile,
    this.idFactory,
  });

  final TrainingProfileLoader loadProfiles;
  final TrainingProfileSaver saveProfile;
  final int Function()? idFactory;

  @override
  State<TrainingProfileSettingsCard> createState() =>
      _TrainingProfileSettingsCardState();
}

class _TrainingProfileSettingsCardState
    extends State<TrainingProfileSettingsCard> {
  late Future<List<TrainingProfile>> _profilesFuture;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _profilesFuture = widget.loadProfiles();
  }

  Future<void> _addProfile() async {
    if (_dialogOpen) return;
    setState(() => _dialogOpen = true);
    final result = await showDialog<TrainingProfileDraft>(
      context: context,
      builder: (_) => const _TrainingProfileDialog(),
    );
    if (!mounted) return;
    setState(() => _dialogOpen = false);
    if (result == null) return;

    try {
      final current = await _profilesFuture;
      if (!mounted) return;
      await widget.saveProfile(
        TrainingProfile(
          id: widget.idFactory?.call() ?? DateTime.now().microsecondsSinceEpoch,
          name: result.name,
          equipmentCodes: result.equipmentCodes.toList(growable: false),
          sort: current.length,
        ),
      );
      if (!mounted) return;
      setState(() => _profilesFuture = widget.loadProfiles());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: FutureBuilder<List<TrainingProfile>>(
        future: _profilesFuture,
        builder: (context, snapshot) {
          final subtitle = switch (snapshot.connectionState) {
            ConnectionState.waiting => const SizedBox(
              key: ValueKey('trainingProfilesLoading'),
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            _ when snapshot.hasError => Text(l10n.genericError),
            _ => Text(
              snapshot.data?.isNotEmpty == true
                  ? snapshot.data!.map((profile) => profile.name).join(' · ')
                  : l10n.noProfiles,
            ),
          };
          return ListTile(
            key: const ValueKey('trainingProfileCard'),
            leading: const Icon(Icons.fitness_center_rounded),
            title: Text(l10n.trainingProfile),
            subtitle: subtitle,
            trailing: IconButton(
              key: const ValueKey('addTrainingProfile'),
              tooltip: l10n.add,
              onPressed: _dialogOpen ? null : _addProfile,
              icon: const Icon(Icons.add_rounded),
            ),
          );
        },
      ),
    );
  }
}

class _TrainingProfileDialog extends StatefulWidget {
  const _TrainingProfileDialog();

  @override
  State<_TrainingProfileDialog> createState() => _TrainingProfileDialogState();
}

class _TrainingProfileDialogState extends State<_TrainingProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  final Set<String> _selectedEquipment = {};
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
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
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.trainingProfile),
      content: SingleChildScrollView(
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
                decoration: InputDecoration(labelText: l10n.profileName),
                onFieldSubmitted: (_) => _submit(),
                validator:
                    (value) =>
                        (value?.trim().isEmpty ?? true)
                            ? l10n.nameRequired
                            : null,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.equipment,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final code in _profileEquipmentCodes)
                    FilterChip(
                      key: ValueKey('trainingProfileEquipment_$code'),
                      label: Text(_equipmentLabel(context, code)),
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
      actions: [
        TextButton(
          key: const ValueKey('trainingProfileCancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('trainingProfileSubmit'),
          onPressed: _submit,
          child: Text(l10n.add),
        ),
      ],
    );
  }
}

String _equipmentLabel(BuildContext context, String code) => switch (code) {
  'bodyweight' => context.l10n.equipmentBodyweight,
  'dumbbell' => context.l10n.equipmentDumbbell,
  'barbell' => context.l10n.equipmentBarbell,
  'machine' => context.l10n.equipmentMachine,
  'cable' => context.l10n.equipmentCable,
  'kettlebell' => context.l10n.equipmentKettlebell,
  'bands' => context.l10n.equipmentBands,
  _ => code,
};
