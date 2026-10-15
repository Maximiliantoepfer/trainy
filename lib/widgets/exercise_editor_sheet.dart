import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/exercise.dart';
import '../providers/exercise_provider.dart';
import '../providers/cloud_sync_provider.dart';
import '../utils/goal_utils.dart';
import '../utils/utils.dart';
import '../utils/exercise_localization.dart';
import '../services/exercise_image_service.dart';
import '../l10n/l10n.dart';
import 'exercise_editor_form.dart';

/// Shared BottomSheet zum Erstellen / Bearbeiten einer Übung.
///
/// [warnOnEdit] zeigt vor dem Speichern einer bestehenden Übung eine
/// Bestätigung, dass sich Änderungen auf alle Workouts auswirken.
/// Gibt `true` zurück, wenn gespeichert oder zusammengeführt wurde.
Future<bool> showExerciseEditorSheet(
  BuildContext context, {
  Exercise? existing,
  bool warnOnEdit = false,
}) async {
  final nameCtrl = TextEditingController(
    text: existing == null ? '' : displayExerciseName(context, existing),
  );
  final descCtrl = TextEditingController(text: existing?.description ?? '');
  final trackSets = ValueNotifier(existing?.trackSets ?? true);
  final trackReps = ValueNotifier(existing?.trackReps ?? true);
  final trackWeight = ValueNotifier(existing?.trackWeight ?? true);
  final trackDuration = ValueNotifier(existing?.trackDuration ?? false);
  final trackDistance = ValueNotifier(existing?.trackDistance ?? false);
  final goal = ValueNotifier<String?>(existing?.goal);
  final goalCodes = ValueNotifier<List<String>>(
    existing?.goalCodes.isNotEmpty == true
        ? List<String>.from(existing!.goalCodes)
        : (existing?.goal == null ? [] : [existing!.goal!]),
  );
  final imagePaths = ValueNotifier<List<String>>(
    List<String>.from(existing?.imagePaths ?? const []),
  );

  bool saved = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    existing == null
                        ? ctx.l10n.newExercise
                        : ctx.l10n.editExercise,
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (existing != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ValueListenableBuilder<List<String>>(
                    valueListenable: imagePaths,
                    builder:
                        (ctx, paths, _) => OutlinedButton.icon(
                          onPressed: () async {
                            final path = await ExerciseImageService.instance
                                .pickAndStoreCover(exerciseId: existing.id);
                            if (path != null)
                              imagePaths.value = [path, ...paths];
                          },
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text('${ctx.l10n.add} (${paths.length})'),
                        ),
                  ),
                ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: ExerciseEditorForm(
                    nameCtrl: nameCtrl,
                    descCtrl: descCtrl,
                    trackSets: trackSets,
                    trackReps: trackReps,
                    trackWeight: trackWeight,
                    trackDuration: trackDuration,
                    trackDistance: trackDistance,
                    goal: goal,
                    goalCodes: goalCodes,
                    autofocusName: existing == null,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(ctx.l10n.cancel),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;

                            if (warnOnEdit && existing != null) {
                              final confirmed = await showDialog<bool>(
                                context: ctx,
                                builder:
                                    (dCtx) => AlertDialog(
                                      title: Text(
                                        dCtx.l10n.editExerciseConfirmationTitle,
                                      ),
                                      content: Text(
                                        dCtx.l10n.editExerciseConfirmation,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(dCtx, false),
                                          child: Text(dCtx.l10n.cancel),
                                        ),
                                        FilledButton(
                                          onPressed:
                                              () => Navigator.pop(dCtx, true),
                                          child: Text(dCtx.l10n.save),
                                        ),
                                      ],
                                    ),
                              );
                              if (confirmed != true) return;
                            }

                            await ctx
                                .read<ExerciseProvider>()
                                .addOrUpdateExercise(
                                  id: existing?.id,
                                  name: name,
                                  description: descCtrl.text.trim(),
                                  trackSets: trackSets.value,
                                  trackReps: trackReps.value,
                                  trackWeight: trackWeight.value,
                                  trackDuration: trackDuration.value,
                                  trackDistance: trackDistance.value,
                                  goal: goal.value,
                                  standardKey: existing?.standardKey,
                                  catalogId: existing?.catalogId,
                                  alias: existing?.alias,
                                  notes: existing?.notes ?? '',
                                  goalCodes: goalCodes.value,
                                  imagePaths: imagePaths.value,
                                  isNameCustom:
                                      existing?.catalogId != null &&
                                              name ==
                                                  displayExerciseName(
                                                    ctx,
                                                    existing!,
                                                  )
                                          ? false
                                          : existing?.isNameCustom,
                                );
                            try {
                              ctx
                                  .read<CloudSyncProvider>()
                                  .scheduleBackupSoon();
                            } catch (_) {}
                            saved = true;
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: Text(
                            existing == null ? ctx.l10n.create : ctx.l10n.save,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Zusammenführen-Button (nur bei bestehender Übung)
              if (existing != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: ctx.read<ExerciseProvider>().getMergeHistoryFull(
                      existing.id,
                    ),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: TextButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: ctx,
                              isScrollControlled: true,
                              useSafeArea: true,
                              showDragHandle: true,
                              builder:
                                  (_) =>
                                      _MergeManagementSheet(exercise: existing),
                            );
                          },
                          icon: const Icon(Icons.merge_rounded, size: 18),
                          label: Text(ctx.l10n.mergeExercises(count)),
                        ),
                      );
                    },
                  ),
                )
              else
                const SizedBox(height: 16),
            ],
          ),
        ),
      );
    },
  );

  return saved;
}

/// Management-Sheet: zeigt Merge-Verlauf und ermöglicht neue Zusammenführungen.
class _MergeManagementSheet extends StatefulWidget {
  final Exercise exercise;
  const _MergeManagementSheet({required this.exercise});

  @override
  State<_MergeManagementSheet> createState() => _MergeManagementSheetState();
}

class _MergeManagementSheetState extends State<_MergeManagementSheet> {
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _redirects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await context.read<ExerciseProvider>().getMergeHistoryFull(
      widget.exercise.id,
    );
    final redirects = await context
        .read<ExerciseProvider>()
        .activeRedirectsForTarget(widget.exercise.id);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _redirects = redirects;
      _isLoading = false;
    });
  }

  Future<void> _undoRedirect(int id) async {
    await context.read<ExerciseProvider>().undoMerge(id);
    try {
      context.read<CloudSyncProvider>().scheduleBackupSoon();
    } catch (_) {}
    if (mounted) _loadEntries();
  }

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    final sourceName = entry['sourceName'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dCtx) => AlertDialog(
            title: Text(dCtx.l10n.removeEntry),
            content: Text(
              dCtx.l10n.removeMergeEntryDescription(
                sourceName,
                displayExerciseName(dCtx, widget.exercise),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: Text(dCtx.l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(dCtx, true),
                child: Text(dCtx.l10n.remove),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    await context.read<ExerciseProvider>().deleteMergeHistoryEntry(
      entry['id'] as int,
    );
    try {
      context.read<CloudSyncProvider>().scheduleBackupSoon();
    } catch (_) {}
    _loadEntries();
  }

  Future<void> _addMerge() async {
    final provider = context.read<ExerciseProvider>();
    final allExercises =
        provider.exercises.where((e) => e.id != widget.exercise.id).toList();

    if (allExercises.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.noOtherExercise)));
      }
      return;
    }

    // Picker – User wählt Übung die IN die aktuelle zusammengeführt wird
    final source = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (ctx) => _MergePickerSheet(
            exercises: allExercises,
            title: context.l10n.mergeInto(
              displayExerciseName(context, widget.exercise),
            ),
          ),
    );

    if (source == null || !mounted) return;

    final entryCount = await provider.countEntriesForExercise(source.id);
    if (!mounted) return;

    // Bestätigungsdialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dCtx) => AlertDialog(
            title: Text(dCtx.l10n.confirmMerge),
            content: Text(
              dCtx.l10n.mergeDescription(
                displayExerciseName(dCtx, source),
                displayExerciseName(dCtx, widget.exercise),
                entryCount,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: Text(dCtx.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dCtx, true),
                child: Text(dCtx.l10n.merge),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    // Merge: source wird gelöscht, aktuelle Übung ist target
    await provider.mergeExercise(source.id, widget.exercise.id);
    try {
      context.read<CloudSyncProvider>().scheduleBackupSoon();
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.mergedResult(
              displayExerciseName(context, source),
              displayExerciseName(context, widget.exercise),
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    );

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.mergeHistory,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '„${displayExerciseName(context, widget.exercise)}"',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (!_isLoading && _redirects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                children: [
                  for (final redirect in _redirects)
                    Builder(
                      builder: (context) {
                        final snapshot = Map<String, dynamic>.from(
                          jsonDecode(redirect['sourceSnapshotJson'] as String)
                              as Map,
                        );
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.undo_rounded),
                            title: Text(
                              snapshot['name'] as String? ??
                                  context.l10n.exercise,
                            ),
                            subtitle: Text(context.l10n.merged),
                            trailing: TextButton(
                              onPressed:
                                  () => _undoRedirect(redirect['id'] as int),
                              child: Text(context.l10n.undo),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

          // Liste oder Leer-Zustand
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                context.l10n.noMergedExercises,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                itemCount: _entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  final entry = _entries[i];
                  final name = entry['sourceName'] as String;
                  final mergedAt = DateTime.tryParse(
                    entry['mergedAt'] as String? ?? '',
                  );
                  return Card(
                    child: ListTile(
                      title: Text(name),
                      subtitle: Text(
                        mergedAt != null
                            ? context.l10n.mergedOn(
                              dateFmt.format(mergedAt.toLocal()),
                            )
                            : context.l10n.merged,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                        onPressed: () => _deleteEntry(entry),
                        tooltip: context.l10n.remove,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Neue Zusammenführung
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 40,
              child: TextButton.icon(
                onPressed: _addMerge,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.l10n.newMerge),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Picker-Sheet zum Auswählen der Ziel-Übung.
class _MergePickerSheet extends StatefulWidget {
  final List<Exercise> exercises;
  final String title;
  const _MergePickerSheet({required this.exercises, required this.title});

  @override
  State<_MergePickerSheet> createState() => _MergePickerSheetState();
}

class _MergePickerSheetState extends State<_MergePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered =
        _query.isEmpty
            ? widget.exercises
            : widget.exercises
                .where(
                  (e) =>
                      e.name.toLowerCase().contains(_query.toLowerCase()) ||
                      e.mergedAliases.any(
                        (a) => a.toLowerCase().contains(_query.toLowerCase()),
                      ),
                )
                .toList();

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: context.l10n.searchExercises,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon:
                    _query.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _query = ''),
                        )
                        : null,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) {
                final e = filtered[i];
                final alias = matchingAlias(e, _query);
                return Card(
                  child: ListTile(
                    title: Row(
                      children: [
                        Flexible(child: Text(displayExerciseName(context, e))),
                        if (e.goal != null) ...[
                          const SizedBox(width: 8),
                          goalBadge(context, e.goal!, scheme),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            if (e.trackSets) context.l10n.sets,
                            if (e.trackReps) context.l10n.repetitions,
                            if (e.trackWeight) context.l10n.weight,
                            if (e.trackDistance) context.l10n.distance,
                            if (e.trackDuration) context.l10n.duration,
                          ].join(' · '),
                        ),
                        if (alias != null)
                          Text(
                            context.l10n.formerName(alias),
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
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                    onTap: () => Navigator.pop(context, e),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
