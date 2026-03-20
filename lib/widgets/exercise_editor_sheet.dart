import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/exercise.dart';
import '../providers/exercise_provider.dart';
import '../providers/cloud_sync_provider.dart';
import '../utils/goal_utils.dart';
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
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final descCtrl = TextEditingController(text: existing?.description ?? '');
  final trackSets = ValueNotifier(existing?.trackSets ?? true);
  final trackReps = ValueNotifier(existing?.trackReps ?? true);
  final trackWeight = ValueNotifier(existing?.trackWeight ?? true);
  final trackDuration = ValueNotifier(existing?.trackDuration ?? false);
  final trackDistance = ValueNotifier(existing?.trackDistance ?? false);
  final goal = ValueNotifier<String?>(existing?.goal);

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
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    existing == null ? 'Übung erstellen' : 'Übung bearbeiten',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                          child: const Text('Abbrechen'),
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
                                builder: (dCtx) => AlertDialog(
                                  title: const Text('Übung bearbeiten?'),
                                  content: const Text(
                                    'Änderungen wirken sich auf alle Workouts aus, die diese Übung verwenden.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dCtx, false),
                                      child: const Text('Abbrechen'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(dCtx, true),
                                      child: const Text('Speichern'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                            }

                            await ctx.read<ExerciseProvider>().addOrUpdateExercise(
                              id: existing?.id,
                              name: name,
                              description: descCtrl.text.trim(),
                              trackSets: trackSets.value,
                              trackReps: trackReps.value,
                              trackWeight: trackWeight.value,
                              trackDuration: trackDuration.value,
                              trackDistance: trackDistance.value,
                              goal: goal.value,
                            );
                            try {
                              ctx.read<CloudSyncProvider>().scheduleBackupSoon();
                            } catch (_) {}
                            saved = true;
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: Text(existing == null ? 'Erstellen' : 'Speichern'),
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
                    future: ctx.read<ExerciseProvider>().getMergeHistoryFull(existing.id),
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
                              builder: (_) => _MergeManagementSheet(
                                exercise: existing,
                              ),
                            );
                          },
                          icon: const Icon(Icons.merge_rounded, size: 18),
                          label: Text(
                            'Übungen zusammenführen${count > 0 ? ' ($count)' : ''}',
                          ),
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await context.read<ExerciseProvider>()
        .getMergeHistoryFull(widget.exercise.id);
    if (!mounted) return;
    setState(() { _entries = entries; _isLoading = false; });
  }

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    final sourceName = entry['sourceName'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Eintrag entfernen?'),
        content: Text(
          '„$sourceName" aus dem Zusammenführungsverlauf entfernen?\n\n'
          'Die übertragenen Trainingseinträge bleiben bei '
          '„${widget.exercise.name}" erhalten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await context.read<ExerciseProvider>()
        .deleteMergeHistoryEntry(entry['id'] as int);
    try { context.read<CloudSyncProvider>().scheduleBackupSoon(); } catch (_) {}
    _loadEntries();
  }

  Future<void> _addMerge() async {
    final provider = context.read<ExerciseProvider>();
    final allExercises = provider.exercises
        .where((e) => e.id != widget.exercise.id)
        .toList();

    if (allExercises.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine andere Übung vorhanden')),
        );
      }
      return;
    }

    // Picker – User wählt Übung die IN die aktuelle zusammengeführt wird
    final source = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => _MergePickerSheet(
        exercises: allExercises,
        title: 'In „${widget.exercise.name}" zusammenführen:',
      ),
    );

    if (source == null || !mounted) return;

    final entryCount = await provider.countEntriesForExercise(source.id);
    if (!mounted) return;

    // Bestätigungsdialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Zusammenführen?'),
        content: Text(
          '„${source.name}" wird in „${widget.exercise.name}" zusammengeführt.\n\n'
          '${entryCount > 0 ? '$entryCount Fortschrittseinträge werden übertragen.\n' : ''}'
          '„${source.name}" wird anschließend gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Zusammenführen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Merge: source wird gelöscht, aktuelle Übung ist target
    await provider.mergeExercise(source.id, widget.exercise.id);
    try { context.read<CloudSyncProvider>().scheduleBackupSoon(); } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('„${source.name}" → „${widget.exercise.name}" zusammengeführt'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd.MM.yyyy');

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
                    Text('Zusammenführungen',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text('„${widget.exercise.name}"',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

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
                'Noch keine Übungen zusammengeführt.',
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
                  final mergedAt = DateTime.tryParse(entry['mergedAt'] as String? ?? '');
                  return Card(
                    child: ListTile(
                      title: Text(name),
                      subtitle: Text(
                        mergedAt != null
                            ? 'Zusammengeführt am ${dateFmt.format(mergedAt.toLocal())}'
                            : 'Zusammengeführt',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline_rounded,
                            color: scheme.onSurfaceVariant),
                        onPressed: () => _deleteEntry(entry),
                        tooltip: 'Eintrag entfernen',
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
                label: const Text('Neue Übung zusammenführen'),
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
    final filtered = _query.isEmpty
        ? widget.exercises
        : widget.exercises
            .where((e) => e.name.toLowerCase().contains(_query.toLowerCase()))
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
                hintText: 'Übung suchen...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
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
                return Card(
                  child: ListTile(
                    title: Row(
                      children: [
                        Flexible(child: Text(e.name)),
                        if (e.goal != null) ...[
                          const SizedBox(width: 8),
                          goalBadge(e.goal!, scheme),
                        ],
                      ],
                    ),
                    subtitle: Text([
                      if (e.trackSets) 'Sätze',
                      if (e.trackReps) 'Wdh.',
                      if (e.trackWeight) 'Gewicht',
                      if (e.trackDistance) 'Entfernung',
                      if (e.trackDuration) 'Dauer',
                    ].join(' · ')),
                    trailing: Icon(Icons.arrow_forward_rounded,
                        color: scheme.onSurfaceVariant),
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
