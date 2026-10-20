import 'package:flutter/material.dart';
import '../l10n/strength_l10n.dart';
import '../models/catalog_exercise.dart';
import '../models/strength_plan.dart';
import '../models/training_profile.dart';
import '../models/workout_planning.dart';
import '../services/catalog_repository.dart';
import '../services/strength_planning.dart';
import '../services/strength_routines.dart';
import '../widgets/strength_routine_picker.dart';
import '../widgets/strength_prescription_editor.dart';

/// Edits a proposal only; catalogue items are not inserted until activation.
class StrengthProposalScreen extends StatefulWidget {
  const StrengthProposalScreen({
    super.key,
    required this.workout,
    required this.places,
    this.planActions,
  });
  final StrengthWorkoutDraft workout;
  final List<TrainingProfileRecord> places;
  final Widget? planActions;
  @override
  State<StrengthProposalScreen> createState() => _StrengthProposalState();
}

class _StrengthProposalState extends State<StrengthProposalScreen> {
  late StrengthWorkoutDraft _workout = widget.workout;
  int _index = 0;
  final _seenVariants = <int>{0};
  StrengthVariantDraft get _variant => _workout.variants[_index];
  void _update(StrengthVariantDraft variant) => setState(() {
    if (variant.estimatedSeconds > _variant.estimatedSeconds) {
      variant = variant.copyWith(acceptedExtraTime: false);
    }
    _workout = _workout.copyWith(
      variants: [
        for (var i = 0; i < _workout.variants.length; i++)
          i == _index ? variant : _workout.variants[i],
      ],
    );
  });
  Future<void> _choose({int? replacing, bool? cooling}) async {
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
                  goalCode: cooling == null ? 'strength' : 'mobility',
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
    final items =
        cooling == null
            ? _variant.exercises
            : cooling
            ? _variant.cooldown
            : _variant.warmup;
    final previous = replacing == null ? null : items[replacing];
    final candidate =
        StrengthPlanning.candidates.where((e) => e.id == selected).firstOrNull;
    final exercise = StrengthExerciseDraft(
      catalogId: selected,
      prescription:
          previous == null
              ? StrengthPrescription(
                sets: cooling == null ? 2 : 1,
                durationSeconds: cooling == null ? null : 30,
                restSeconds: cooling == null ? 90 : 0,
              )
              : StrengthPrescription.fromJson({
                ...previous.prescription.toJson(),
                'source': 'manual',
              }),
      unilateral: candidate?.unilateral ?? false,
      optional: previous?.optional ?? false,
    );
    final next = [
      for (var i = 0; i < items.length; i++)
        if (i == replacing) exercise else items[i],
      if (replacing == null) exercise,
    ];
    _update(
      cooling == null
          ? _variant.copyWith(exercises: next)
          : cooling
          ? _variant.copyWith(cooldown: next, acceptedExtraTime: false)
          : _variant.copyWith(warmup: next, acceptedExtraTime: false),
    );
  }

  Future<void> _routine(bool cooling) async {
    final choice = await pickStrengthRoutine(context, cooling: cooling);
    if (choice == null || !mounted) return;
    if (choice == 'individual') {
      await _choose(cooling: cooling);
      return;
    }
    final items =
        choice == 'none'
            ? <StrengthExerciseDraft>[]
            : StrengthRoutines.preset(choice, cooling: cooling);
    _update(
      cooling
          ? _variant.copyWith(cooldown: items, acceptedExtraTime: false)
          : _variant.copyWith(warmup: items, acceptedExtraTime: false),
    );
  }

  Widget _routineCard(bool cooling) {
    final items = cooling ? _variant.cooldown : _variant.warmup;
    final locale = Localizations.localeOf(context).languageCode;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              cooling ? Icons.nights_stay_outlined : Icons.wb_sunny_outlined,
            ),
            title: Text(context.strength(cooling ? 'cooldown' : 'warmup')),
            subtitle: Text(
              items.isEmpty
                  ? context.strength('noRoutine')
                  : '${items.length} · ${items.fold<int>(0, (s, e) => s + (e.prescription.durationSeconds == null ? e.estimatedSeconds : e.prescription.sets * e.prescription.durationSeconds! + (e.prescription.sets - 1) * e.prescription.restSeconds))} s',
            ),
            trailing: const Icon(Icons.tune),
            onTap: () => _routine(cooling),
          ),
          for (var i = 0; i < items.length; i++)
            ListTile(
              title: Text(
                CatalogRepository.instance
                        .content(items[i].catalogId, locale)
                        ?.name ??
                    items[i].catalogId,
              ),
              subtitle: Text(items[i].prescription.label),
              trailing: IconButton(
                tooltip: context.strength('noRoutine'),
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () {
                  final next = [...items]..removeAt(i);
                  _update(
                    cooling
                        ? _variant.copyWith(cooldown: next)
                        : _variant.copyWith(warmup: next),
                  );
                },
              ),
              onTap: () async {
                final p = await editStrengthPrescription(
                  context,
                  items[i].prescription,
                );
                if (p == null || !mounted) return;
                final next = [
                  for (var j = 0; j < items.length; j++)
                    if (j == i)
                      StrengthExerciseDraft(
                        catalogId: items[j].catalogId,
                        prescription: p,
                      )
                    else
                      items[j],
                ];
                _update(
                  cooling
                      ? _variant.copyWith(
                        cooldown: next,
                        acceptedExtraTime: false,
                      )
                      : _variant.copyWith(
                        warmup: next,
                        acceptedExtraTime: false,
                      ),
                );
              },
            ),
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
          onPressed:
              _seenVariants.length == _workout.variants.length && _workout.ready
                  ? () => Navigator.pop(context, _workout.confirmReview())
                  : null,
          child: Text(context.strength('confirmWorkout')),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.planActions != null) ...[
            widget.planActions!,
            const SizedBox(height: 16),
          ],
          if (_workout.variants.length > 1)
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < _workout.variants.length; i++)
                  ChoiceChip(
                    label: Text(_workout.variants[i].name),
                    selected: i == _index,
                    onSelected:
                        (_) => setState(() {
                          _index = i;
                          _seenVariants.add(i);
                        }),
                  ),
              ],
            ),
          Text(
            '${context.strength('estimated')}: ~${(variant.estimatedSeconds / 60).ceil()} min',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(context.strength('warmupReserve')),
          if (variant.overBudget)
            CheckboxListTile(
              value: variant.acceptedExtraTime,
              title: Text(context.strength('extraTime')),
              subtitle: Text(
                '~${(variant.estimatedSeconds / 60).ceil()} / ${variant.budgetSeconds! ~/ 60} min',
              ),
              onChanged: (v) => _update(variant.copyWith(acceptedExtraTime: v)),
            ),
          _routineCard(false),
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
          _routineCard(true),
        ],
      ),
    );
  }
}
