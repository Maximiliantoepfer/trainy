import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/catalog_exercise.dart';
import '../models/library_exercise_item.dart';
import '../models/exercise.dart';
import '../providers/exercise_provider.dart';
import '../services/catalog_repository.dart';
import '../services/database_schema_v2.dart';
import '../utils/exercise_localization.dart';
import '../utils/goal_utils.dart';

class ExercisePickerResult {
  ExercisePickerResult(Iterable<int> exerciseIds, Iterable<String> catalogIds)
    : exerciseIds = Set.unmodifiable(exerciseIds),
      catalogIds = Set.unmodifiable(catalogIds);
  final Set<int> exerciseIds;
  final Set<String> catalogIds;

  Future<List<Exercise>> materialize(
    ExerciseProvider provider,
    String locale,
  ) async {
    final ids = <int>{...exerciseIds};
    for (final id in catalogIds) {
      final item = CatalogRepository.instance.localized(id, locale);
      if (item == null) throw StateError('Catalog exercise unavailable: $id');
      ids.add(await provider.addCatalogExercise(item));
    }
    return [
      for (final id in ids) provider.exercises.firstWhere((e) => e.id == id),
    ];
  }
}

/// Uses the complete offline library; equipment and family affect ranking only.
class WorkoutExercisePicker extends StatefulWidget {
  const WorkoutExercisePicker({
    super.key,
    this.selectedExerciseIds = const {},
    this.selectedCatalogIds = const {},
    this.availableEquipment,
    this.preferredFamily,
    this.single = false,
    this.excludedIds = const {},
  });
  final Set<int> selectedExerciseIds;
  final Set<String> selectedCatalogIds;
  final Set<String>? availableEquipment;
  final String? preferredFamily;
  final bool single;
  final Set<int> excludedIds;

  @override
  State<WorkoutExercisePicker> createState() => _WorkoutExercisePickerState();
}

class _WorkoutExercisePickerState extends State<WorkoutExercisePicker> {
  final _search = TextEditingController();
  late final Set<int> _selected = {...widget.selectedExerciseIds};
  late final Set<String> _catalog = {...widget.selectedCatalogIds};
  String? _goal;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = CatalogRepository.instance;
    final local = context.watch<ExerciseProvider>().exercises;
    final locale = Localizations.localeOf(context).languageCode;
    final materialized = {
      for (final e in local)
        if (e.catalogId != null) e.catalogId!: e,
    };
    final query = CatalogQuery(text: _search.text, goalCode: _goal);
    final normalized = CatalogRepository.normalizeSearchText(_search.text);
    final catalogItems =
        repository.isLoaded
            ? repository.search(locale, query)
            : <LocalizedCatalogExercise>[];
    final items = <LibraryExerciseItem>[
      for (final item in catalogItems)
        LibraryExerciseItem.catalog(
          item,
          exercise: materialized[item.definition.id],
        ),
      for (final exercise in local)
        if ((exercise.catalogId == null ||
                repository.byId(exercise.catalogId) == null) &&
            (_goal == null ||
                exercise.goalCodes.contains(_goal) ||
                exercise.goal == _goal) &&
            (normalized.isEmpty ||
                CatalogRepository.normalizeSearchText(
                  '${displayExerciseName(context, exercise)} ${exercise.name} ${exercise.description} ${exercise.mergedAliases.join(' ')}',
                ).replaceAll(' ', '').contains(normalized.replaceAll(' ', ''))))
          LibraryExerciseItem.custom(exercise),
    ];
    int rank(LibraryExerciseItem item) {
      final definition = item.catalog?.definition;
      if (widget.preferredFamily != null &&
          definition?.movementFamilyId == widget.preferredFamily) {
        return 0;
      }
      final required =
          definition?.equipmentIds
              .map(DatabaseSchemaV2.normalizeEquipmentCode)
              .where((e) => !{'bodyweight', 'unknown', 'other'}.contains(e))
              .toSet() ??
          <String>{};
      if (widget.availableEquipment != null &&
          widget.availableEquipment!.containsAll(required)) {
        return 1;
      }
      return 2;
    }

    // Stable ranking preserves the search engine's exact-name/alias ordering.
    if (normalized.isEmpty) {
      final order = {for (var i = 0; i < items.length; i++) items[i]: i};
      items.sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        return byRank == 0 ? order[a]!.compareTo(order[b]!) : byRank;
      });
    }
    return FractionallySizedBox(
      heightFactor: .94,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(context.l10n.selectExercise),
          leading: IconButton(
            tooltip: context.l10n.cancel,
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
          actions: [
            if (!widget.single)
              TextButton(
                onPressed:
                    () => Navigator.pop(
                      context,
                      ExercisePickerResult(_selected, _catalog),
                    ),
                child: Text(context.l10n.apply),
              ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: context.l10n.searchExercise,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonFormField<String>(
                value: _goal ?? '',
                isExpanded: true,
                decoration: InputDecoration(labelText: context.l10n.label),
                items: [
                  DropdownMenuItem(value: '', child: Text(context.l10n.all)),
                  for (final code in [
                    'strength',
                    'endurance',
                    'cardio',
                    'mobility',
                  ])
                    DropdownMenuItem(
                      value: code,
                      child: Text(goalLabel(context, code)),
                    ),
                ],
                onChanged:
                    (value) =>
                        setState(() => _goal = value == '' ? null : value),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  items.isEmpty
                      ? Center(child: Text(context.l10n.noExercisesFound))
                      : ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: items.length,
                        itemBuilder: (_, index) {
                          final item = items[index];
                          final exercise = item.exercise;
                          final catalogId = item.catalog?.definition.id;
                          final id = exercise?.id;
                          final disabled =
                              id != null && widget.excludedIds.contains(id);
                          final selected =
                              (id != null && _selected.contains(id)) ||
                              (catalogId != null &&
                                  _catalog.contains(catalogId));
                          final name =
                              exercise == null
                                  ? item.catalog!.content.name
                                  : displayExerciseName(context, exercise);
                          void toggle() {
                            if (widget.single) {
                              Navigator.pop(
                                context,
                                ExercisePickerResult(
                                  id == null ? [] : [id],
                                  id == null && catalogId != null
                                      ? [catalogId]
                                      : [],
                                ),
                              );
                            } else {
                              setState(() {
                                if (selected) {
                                  _selected.remove(id);
                                  _catalog.remove(catalogId);
                                } else if (id != null) {
                                  _selected.add(id);
                                } else if (catalogId != null) {
                                  _catalog.add(catalogId);
                                }
                              });
                            }
                          }

                          return ListTile(
                            key: ValueKey(catalogId ?? 'local:$id'),
                            title: Text(name),
                            subtitle: Text(
                              disabled
                                  ? context.l10n.alreadyInWorkout
                                  : item.isStandard
                                  ? context.l10n.standard
                                  : context.l10n.own,
                            ),
                            enabled: !disabled,
                            onTap: disabled ? null : toggle,
                            leading:
                                item.catalog == null
                                    ? const Icon(Icons.fitness_center)
                                    : ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        item.catalog!.definition.imageAssetPath,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, e, s) => const Icon(
                                              Icons.fitness_center,
                                            ),
                                      ),
                                    ),
                            trailing:
                                widget.single
                                    ? const Icon(Icons.chevron_right)
                                    : Checkbox(
                                      value: selected,
                                      onChanged:
                                          disabled ? null : (_) => toggle(),
                                    ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
