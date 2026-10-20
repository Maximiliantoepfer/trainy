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
import 'exercise_editor_sheet.dart';
import 'library_exercise_thumbnail.dart';

@immutable
class ExerciseSelectionRef {
  const ExerciseSelectionRef({this.exerciseId, this.catalogId})
    : assert(exerciseId != null || catalogId != null);
  final int? exerciseId;
  final String? catalogId;
  String get key => catalogId ?? 'local:$exerciseId';
}

class ExercisePickerResult {
  ExercisePickerResult(Iterable<int> exerciseIds, Iterable<String> catalogIds)
    : references = List.unmodifiable([
        for (final id in exerciseIds) ExerciseSelectionRef(exerciseId: id),
        for (final id in catalogIds) ExerciseSelectionRef(catalogId: id),
      ]);
  ExercisePickerResult.ordered(Iterable<ExerciseSelectionRef> values)
    : references = List.unmodifiable(values);
  final List<ExerciseSelectionRef> references;
  Set<int> get exerciseIds =>
      references.map((r) => r.exerciseId).whereType<int>().toSet();
  Set<String> get catalogIds =>
      references
          .where((r) => r.exerciseId == null)
          .map((r) => r.catalogId)
          .whereType<String>()
          .toSet();

  Future<List<Exercise>> materialize(
    ExerciseProvider provider,
    String locale,
  ) async {
    final ids = <int>{};
    for (final ref in references) {
      if (ref.exerciseId != null) {
        ids.add(ref.exerciseId!);
      } else {
        final item = CatalogRepository.instance.localized(
          ref.catalogId!,
          locale,
        );
        if (item == null) {
          throw StateError('Catalog exercise unavailable: ${ref.catalogId}');
        }
        ids.add(await provider.addCatalogExercise(item));
      }
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
    this.selectedReferences,
    this.initialGoal,
  });
  final Set<int> selectedExerciseIds;
  final Set<String> selectedCatalogIds;
  final Set<String>? availableEquipment;
  final String? preferredFamily;
  final bool single;
  final Set<int> excludedIds;
  final List<ExerciseSelectionRef>? selectedReferences;
  final String? initialGoal;

  @override
  State<WorkoutExercisePicker> createState() => _WorkoutExercisePickerState();
}

class _WorkoutExercisePickerState extends State<WorkoutExercisePicker> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  bool _creating = false;
  int? _newExerciseId;
  late final List<ExerciseSelectionRef> _selection = [
    ...?widget.selectedReferences,
    if (widget.selectedReferences == null) ...[
      for (final id in widget.selectedExerciseIds)
        ExerciseSelectionRef(exerciseId: id),
      for (final id in widget.selectedCatalogIds)
        ExerciseSelectionRef(catalogId: id),
    ],
  ];
  late String? _goal = widget.initialGoal;
  bool _normalizedSelection = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_normalizedSelection) return;
    _normalizedSelection = true;
    final local = context.read<ExerciseProvider>().exercises;
    final seen = <String>{};
    final normalized = <ExerciseSelectionRef>[];
    for (final ref in _selection) {
      final exercise =
          local
              .where(
                (e) =>
                    ref.exerciseId == e.id ||
                    (ref.catalogId != null && ref.catalogId == e.catalogId),
              )
              .firstOrNull;
      final next = ExerciseSelectionRef(
        exerciseId: exercise?.id ?? ref.exerciseId,
        catalogId: ref.catalogId ?? exercise?.catalogId,
      );
      if (seen.add(next.key)) normalized.add(next);
    }
    _selection
      ..clear()
      ..addAll(normalized);
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _createExercise() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final value = await showExerciseEditorSheet(
        context,
        initialName: _search.text.trim(),
      );
      if (!mounted || value == null) return;
      if (widget.single) {
        Navigator.pop(
          context,
          ExercisePickerResult([value.exerciseId], const []),
        );
        return;
      }
      setState(() {
        if (!_selection.any((r) => r.exerciseId == value.exerciseId)) {
          _selection.add(ExerciseSelectionRef(exerciseId: value.exerciseId));
        }
        _newExerciseId = value.exerciseId;
        _goal = null;
        _search.clear();
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
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
                (_goal == 'cardio' &&
                    (exercise.goalCodes.contains('endurance') ||
                        exercise.goal == 'endurance')) ||
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
    // Reveal the explicitly created exercise without losing other selections.
    // Normal ranking resumes as soon as the user enters a query or label.
    if (_newExerciseId != null && normalized.isEmpty && _goal == null) {
      final index = items.indexWhere(
        (item) => item.exercise?.id == _newExerciseId,
      );
      if (index > 0) items.insert(0, items.removeAt(index));
    }
    return FractionallySizedBox(
      heightFactor: .94,
      child: Scaffold(
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child:
              widget.single
                  ? _createButton()
                  : FilledButton(
                    key: const ValueKey('pickerApply'),
                    onPressed:
                        _creating
                            ? null
                            : () => Navigator.pop(
                              context,
                              ExercisePickerResult.ordered(_selection),
                            ),
                    child: Text(
                      context.l10n.applyExerciseSelection(_selection.length),
                    ),
                  ),
        ),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(context.l10n.exercises),
          leading: IconButton(
            tooltip: context.l10n.cancel,
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
          actions: [
            if (!widget.single &&
                MediaQuery.sizeOf(context).width >= 380 &&
                MediaQuery.textScalerOf(context).scale(14) <= 21)
              _createButton(),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.single &&
                (MediaQuery.sizeOf(context).width < 380 ||
                    MediaQuery.textScalerOf(context).scale(14) > 21))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _createButton(),
              ),
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
                  for (final code in ['strength', 'cardio', 'mobility'])
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
                        controller: _scroll,
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
                          final selected = _selection.any(
                            (r) =>
                                (id != null && r.exerciseId == id) ||
                                (catalogId != null && r.catalogId == catalogId),
                          );
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
                                  _selection.removeWhere(
                                    (r) =>
                                        (id != null && r.exerciseId == id) ||
                                        (catalogId != null &&
                                            r.catalogId == catalogId),
                                  );
                                } else {
                                  _selection.add(
                                    ExerciseSelectionRef(
                                      exerciseId: id,
                                      catalogId: catalogId,
                                    ),
                                  );
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
                            leading: LibraryExerciseThumbnail(
                              assetPath:
                                  item.catalog?.definition.imageAssetPath,
                              personalPath: exercise?.imagePaths.firstOrNull,
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

  Widget _createButton() => TextButton.icon(
    key: const ValueKey('pickerCreateExercise'),
    onPressed: _creating ? null : _createExercise,
    icon: const Icon(Icons.add),
    label: Text(context.l10n.newExercise),
  );
}
