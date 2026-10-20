import 'package:flutter/material.dart';
import '../l10n/strength_l10n.dart';
import '../models/catalog_exercise.dart';
import '../models/strength_plan.dart';
import '../models/training_profile.dart';
import '../models/workout_planning.dart';
import '../services/catalog_repository.dart';
import '../services/strength_planning.dart';
import '../widgets/strength_prescription_editor.dart';

/// Edits a proposal only; catalogue items are not inserted until activation.
class StrengthProposalScreen extends StatefulWidget {
  const StrengthProposalScreen({
    super.key,
    required this.workout,
    required this.places,
  });
  final StrengthWorkoutDraft workout;
  final List<TrainingProfileRecord> places;
  @override
  State<StrengthProposalScreen> createState() => _StrengthProposalState();
}

class _StrengthProposalState extends State<StrengthProposalScreen> {
  late StrengthWorkoutDraft _workout = widget.workout;
  int _index = 0;
  StrengthVariantDraft get _variant => _workout.variants[_index];
  void _update(StrengthVariantDraft variant) => setState(() {
    _workout = _workout.copyWith(
      variants: [
        for (var i = 0; i < _workout.variants.length; i++)
          i == _index ? variant : _workout.variants[i],
      ],
    );
  });
  Future<void> _choose({int? replacing}) async {
    var query = '';
    final place = widget.places.firstWhere((p) => p.id == _variant.profileId);
    final locale = Localizations.localeOf(context).languageCode;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (c) => StatefulBuilder(
            builder: (c, set) {
              final results = CatalogRepository.instance.search(
                locale,
                CatalogQuery(
                  text: query,
                  goalCode: 'strength',
                  availableEquipment: place.equipmentCodes,
                ),
              );
              return SafeArea(
                child: SizedBox(
                  height: MediaQuery.sizeOf(c).height * .75,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: c.strength('exercises'),
                            prefixIcon: const Icon(Icons.search),
                          ),
                          onChanged: (v) => set(() => query = v),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: results.length,
                          itemBuilder:
                              (c, i) => ListTile(
                                title: Text(results[i].content.name),
                                onTap:
                                    () => Navigator.pop(
                                      c,
                                      results[i].definition.id,
                                    ),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
    if (selected == null || !mounted) return;
    final previous = replacing == null ? null : _variant.exercises[replacing];
    final candidate =
        StrengthPlanning.candidates.where((e) => e.id == selected).firstOrNull;
    final exercise = StrengthExerciseDraft(
      catalogId: selected,
      prescription:
          previous == null
              ? const StrengthPrescription(sets: 2)
              : StrengthPrescription.fromJson({
                ...previous.prescription.toJson(),
                'source': 'manual',
              }),
      unilateral: candidate?.unilateral ?? false,
      optional: previous?.optional ?? false,
    );
    _update(
      _variant.copyWith(
        exercises: [
          for (var i = 0; i < _variant.exercises.length; i++)
            if (i == replacing) exercise else _variant.exercises[i],
          if (replacing == null) exercise,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final variant = _variant;
    final locale = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(_workout.name)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: () => Navigator.pop(context, _workout),
          child: Text(context.strength('save')),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_workout.variants.length > 1)
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < _workout.variants.length; i++)
                  ChoiceChip(
                    label: Text(_workout.variants[i].name),
                    selected: i == _index,
                    onSelected: (_) => setState(() => _index = i),
                  ),
              ],
            ),
          Text(
            '${context.strength('estimated')}: ~${(variant.estimatedSeconds / 60).ceil()} min',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(context.strength('warmupReserve')),
          const SizedBox(height: 16),
          for (final issue in variant.missing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${context.strength(issue.startsWith('equipment:') ? 'missingEquipmentFor' : 'missingTimeFor')} ${context.strength(issue.split(':').last)}',
              ),
            ),
          if (variant.missing.isNotEmpty)
            CheckboxListTile(
              value: variant.acceptedReduced,
              title: Text(context.strength('acceptReduced')),
              onChanged: (v) => _update(variant.copyWith(acceptedReduced: v)),
            ),
          for (var i = 0; i < variant.exercises.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      CatalogRepository.instance
                              .content(variant.exercises[i].catalogId, locale)
                              ?.name ??
                          variant.exercises[i].catalogId,
                    ),
                    subtitle: Text(
                      '${variant.exercises[i].prescription.label} · ${variant.exercises[i].prescription.restSeconds} s',
                    ),
                    trailing: const Icon(Icons.tune),
                    onTap: () async {
                      final p = await editStrengthPrescription(
                        context,
                        variant.exercises[i].prescription,
                      );
                      if (p == null || !mounted) return;
                      _update(
                        variant.copyWith(
                          exercises: [
                            for (var j = 0; j < variant.exercises.length; j++)
                              if (j == i)
                                StrengthExerciseDraft(
                                  catalogId: variant.exercises[j].catalogId,
                                  prescription: p,
                                  unilateral: variant.exercises[j].unilateral,
                                  optional: variant.exercises[j].optional,
                                )
                              else
                                variant.exercises[j],
                          ],
                        ),
                      );
                    },
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => _choose(replacing: i),
                        child: Text(context.strength('replace')),
                      ),
                      TextButton(
                        onPressed:
                            () => _update(
                              variant.copyWith(
                                exercises: [...variant.exercises]..removeAt(i),
                              ),
                            ),
                        child: Text(
                          Localizations.localeOf(context).languageCode == 'de'
                              ? 'Entfernen'
                              : 'Remove',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            onPressed: _choose,
            icon: const Icon(Icons.add),
            label: Text(context.strength('exercises')),
          ),
        ],
      ),
    );
  }
}
