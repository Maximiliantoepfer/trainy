import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/catalog_exercise.dart';
import '../models/training_profile.dart';

Future<CatalogQuery?> showExerciseLibraryFilterSheet(
  BuildContext context, {
  required CatalogQuery initialQuery,
  required List<TrainingProfileRecord> profiles,
}) => showModalBottomSheet<CatalogQuery>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder:
      (_) => _ExerciseLibraryFilterSheet(
        initialQuery: initialQuery,
        profiles: profiles,
      ),
);

class _ExerciseLibraryFilterSheet extends StatefulWidget {
  const _ExerciseLibraryFilterSheet({
    required this.initialQuery,
    required this.profiles,
  });

  final CatalogQuery initialQuery;
  final List<TrainingProfileRecord> profiles;

  @override
  State<_ExerciseLibraryFilterSheet> createState() =>
      _ExerciseLibraryFilterSheetState();
}

class _ExerciseLibraryFilterSheetState
    extends State<_ExerciseLibraryFilterSheet> {
  late String? _goalCode;
  late String? _profileId;
  late ExerciseSourceFilter _source;

  @override
  void initState() {
    super.initState();
    _goalCode =
        widget.initialQuery.goalCode == 'endurance'
            ? 'cardio'
            : widget.initialQuery.goalCode;
    _profileId = widget.initialQuery.profileId;
    _source = widget.initialQuery.source;
  }

  void _apply() {
    TrainingProfileRecord? profile;
    for (final candidate in widget.profiles) {
      if (candidate.id == _profileId) profile = candidate;
    }
    Navigator.pop(
      context,
      CatalogQuery(
        text: widget.initialQuery.text,
        goalCode: _goalCode,
        profileId: profile?.id,
        availableEquipment: profile?.equipmentCodes,
        source: _source,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.filters,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed:
                    () => setState(() {
                      _goalCode = null;
                      _profileId = null;
                      _source = ExerciseSourceFilter.all;
                    }),
                child: Text(context.l10n.resetFilters),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FilterSection(
            title: context.l10n.label,
            children: [
              ChoiceChip(
                label: Text(context.l10n.all),
                selected: _goalCode == null,
                onSelected: (_) => setState(() => _goalCode = null),
              ),
              for (final code in const ['strength', 'cardio', 'mobility'])
                ChoiceChip(
                  label: Text(context.l10n.goalLabel(code)),
                  selected: _goalCode == code,
                  onSelected: (_) => setState(() => _goalCode = code),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _FilterSection(
            title: context.l10n.trainingProfile,
            children: [
              ChoiceChip(
                label: Text(context.l10n.allProfiles),
                selected: _profileId == null,
                onSelected: (_) => setState(() => _profileId = null),
              ),
              for (final profile in widget.profiles)
                ChoiceChip(
                  label: Text(profile.name),
                  selected: _profileId == profile.id,
                  onSelected: (_) => setState(() => _profileId = profile.id),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _FilterSection(
            title: context.l10n.source,
            children: [
              for (final source in ExerciseSourceFilter.values)
                ChoiceChip(
                  label: Text(switch (source) {
                    ExerciseSourceFilter.all => context.l10n.all,
                    ExerciseSourceFilter.standard => context.l10n.standard,
                    ExerciseSourceFilter.custom => context.l10n.own,
                  }),
                  selected: _source == source,
                  onSelected: (_) => setState(() => _source = source),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _apply,
              child: Text(context.l10n.apply),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: children),
    ],
  );
}
