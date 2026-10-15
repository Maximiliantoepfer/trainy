import 'dart:io';

import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:provider/provider.dart';

import '../models/exercise.dart';
import '../models/catalog_exercise.dart';
import '../providers/exercise_provider.dart';
import '../providers/active_workout_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/cloud_sync_provider.dart';
import '../widgets/active_workout_banner.dart';
import '../widgets/exercise_editor_sheet.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/screen_info_dialog.dart';
import '../widgets/tap_scale.dart';
import '../utils/goal_utils.dart';
import '../utils/utils.dart';
import '../utils/exercise_localization.dart';
import '../services/catalog_repository.dart';
import '../services/exercise_image_service.dart';
import '../l10n/l10n.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  bool _showCatalog = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ExerciseProvider>().loadExercises());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<ExerciseProvider>();
    final list = [...provider.exercises]..sort(
      (a, b) => displayExerciseName(
        context,
        a,
      ).toLowerCase().compareTo(displayExerciseName(context, b).toLowerCase()),
    );
    final scheme = Theme.of(context).colorScheme;
    final catalog = CatalogRepository.instance;
    final q = _query.toLowerCase();
    final filtered =
        _query.isEmpty
            ? list
            : list.where((e) {
              return displayExerciseName(
                    context,
                    e,
                  ).toLowerCase().contains(q) ||
                  e.name.toLowerCase().contains(q) ||
                  e.description.toLowerCase().contains(q) ||
                  e.mergedAliases.any((a) => a.toLowerCase().contains(q));
            }).toList();

    final isActive = context.watch<ActiveWorkoutProvider>().isActive;

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(context.l10n.exercises),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined, size: 20),
            onPressed: () => _reviewDuplicates(context),
            tooltip: context.l10n.reviewDuplicates,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, size: 20),
            onPressed:
                () => showScreenInfoDialog(
                  context,
                  title: context.l10n.exercises,
                  description: context.l10n.exerciseDescription,
                ),
            tooltip: context.l10n.info,
          ),
        ],
      ),
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child:
                isActive
                    ? const ActiveWorkoutBanner()
                    : const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: context.l10n.searchExercises,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: scheme.onSurfaceVariant.withOpacity(0.5),
                ),
                suffixIcon:
                    _query.isNotEmpty
                        ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                          onPressed: () {
                            setState(() {
                              _query = '';
                              _searchCtrl.clear();
                            });
                          },
                        )
                        : null,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (catalog.isLoaded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: false, label: Text(context.l10n.own)),
                  ButtonSegment(value: true, label: Text(context.l10n.catalog)),
                ],
                selected: {_showCatalog},
                onSelectionChanged:
                    (value) => setState(() => _showCatalog = value.first),
              ),
            ),
          Expanded(
            child:
                provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _showCatalog
                    ? _CatalogList(
                      query: _query,
                      onAdd: (item) async {
                        await provider.addCatalogExercise(item);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.catalogExerciseAdded),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    )
                    : list.isEmpty
                    ? _EmptyState(onAdd: () => _openEditor(context))
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final e = filtered[i];
                        final tags = [
                          if (e.trackSets) context.l10n.sets,
                          if (e.trackReps) context.l10n.repetitions,
                          if (e.trackWeight) context.l10n.weight,
                          if (e.trackDistance) context.l10n.distance,
                          if (e.trackDuration) context.l10n.duration,
                        ];
                        return _ExerciseTile(
                          exercise: e,
                          tags: tags,
                          aliasHint: matchingAlias(e, _query),
                          onTap: () => _openEditor(context, existing: e),
                          onLongPress: () => _confirmAndDeleteExercise(e),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.l10n.newExercise),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, {Exercise? existing}) async {
    await showExerciseEditorSheet(context, existing: existing);
  }

  Future<void> _confirmAndDeleteExercise(Exercise exercise) async {
    final provider = context.read<ExerciseProvider>();
    final entryCount = await provider.countEntriesForExercise(exercise.id);
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(context.l10n.deleteExercise),
            content: Text(
              entryCount > 0
                  ? context.l10n.deleteExerciseWithEntries(
                    displayExerciseName(context, exercise),
                    entryCount,
                  )
                  : context.l10n.deleteExerciseConfirmation(
                    displayExerciseName(context, exercise),
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(context.l10n.archive),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    await provider.deleteExercise(exercise.id);
    if (!mounted) return;

    context.read<ProgressProvider>().refreshEntries();
    try {
      context.read<CloudSyncProvider>().scheduleBackupSoon();
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.exerciseArchived),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _reviewDuplicates(BuildContext context) async {
    final provider = context.read<ExerciseProvider>();
    final suggestions = await provider.duplicateSuggestions();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text(
                  sheetContext.l10n.reviewDuplicates,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (suggestions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(sheetContext.l10n.noDuplicateSuggestions),
                  ),
                for (final suggestion in suggestions)
                  ListTile(
                    leading: const Icon(Icons.compare_arrows_rounded),
                    title: Text(
                      provider.exercises
                              .where(
                                (exercise) =>
                                    exercise.id == suggestion.sourceExerciseId,
                              )
                              .map(
                                (exercise) =>
                                    displayExerciseName(sheetContext, exercise),
                              )
                              .firstOrNull ??
                          sheetContext.l10n.exercise,
                    ),
                    subtitle: Text(suggestion.confidence),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: () async {
                            await provider.dismissDuplicateSuggestion(
                              suggestion.id,
                            );
                            if (sheetContext.mounted)
                              Navigator.pop(sheetContext);
                          },
                          child: Text(sheetContext.l10n.keepOwnExercise),
                        ),
                        FilledButton(
                          onPressed: () async {
                            await provider.acceptCatalogDuplicateSuggestion(
                              suggestion,
                            );
                            if (sheetContext.mounted)
                              Navigator.pop(sheetContext);
                          },
                          child: Text(sheetContext.l10n.adoptStandardExercise),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  final List<String> tags;
  final String? aliasHint;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _ExerciseTile({
    required this.exercise,
    required this.tags,
    this.aliasHint,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TapScale(
      child: Card(
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                if (exercise.catalogId != null ||
                    exercise.imagePaths.isNotEmpty) ...[
                  _ExerciseCover(exercise: exercise),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayExerciseName(context, exercise),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _OriginLabel(isCatalog: exercise.catalogId != null),
                          if (exercise.goal != null) ...[
                            const SizedBox(width: 8),
                            goalBadge(context, exercise.goal!, scheme),
                          ],
                        ],
                      ),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          tags.join(' · '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (aliasHint != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.formerName(aliasHint!),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Resolves only locally bundled covers or a personal image held in the app
/// directory.  It deliberately never accepts a network URL.
class _ExerciseCover extends StatelessWidget {
  const _ExerciseCover({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final definition = CatalogRepository.instance.byId(exercise.catalogId);
    final borderRadius = BorderRadius.circular(10);
    Widget child;
    if (definition != null) {
      child = Image.asset(
        definition.imageAssetPath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.fitness_center_rounded),
      );
    } else if (exercise.imagePaths.isNotEmpty) {
      child = FutureBuilder<File>(
        future: ExerciseImageService.instance.resolve(
          exercise.imagePaths.first,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.file(snapshot.data!, fit: BoxFit.cover);
          }
          return const Center(child: Icon(Icons.image_outlined));
        },
      );
    } else {
      child = const Icon(Icons.fitness_center_rounded);
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(width: 56, height: 56, child: child),
    );
  }
}

class _OriginLabel extends StatelessWidget {
  const _OriginLabel({required this.isCatalog});
  final bool isCatalog;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isCatalog ? scheme.primary : scheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: .12),
      ),
      child: Text(
        isCatalog ? context.l10n.standard : context.l10n.own,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList({required this.query, required this.onAdd});
  final String query;
  final Future<void> Function(LocalizedCatalogExercise item) onAdd;

  @override
  Widget build(BuildContext context) {
    final catalog = CatalogRepository.instance;
    if (!catalog.isLoaded) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(context.l10n.catalogUnavailable),
        ),
      );
    }
    final values = catalog.search(
      Localizations.localeOf(context).languageCode,
      query,
    );
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: values.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = values[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onAdd(item),
            child: SizedBox(
              height: 88,
              child: Row(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Image.asset(
                      item.definition.imageAssetPath,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => const Center(
                            child: Icon(Icons.fitness_center_rounded),
                          ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.content.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.content.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ImageIcon(
                const AssetImage('assets/icons/hantel.png'),
                size: 32,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.noExercises,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.noExercisesDescription,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
