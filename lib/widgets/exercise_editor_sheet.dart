import 'package:flutter/material.dart';
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
              // Merge-Verlauf anzeigen (nur bei bestehender Übung)
              if (existing != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: FutureBuilder<List<String>>(
                    future: ctx.read<ExerciseProvider>().getMergeHistory(existing.id),
                    builder: (context, snapshot) {
                      final names = snapshot.data;
                      if (names == null || names.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        'Zusammengeführt: ${names.join(", ")}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
              // Zusammenführen-Button (nur bei bestehender Übung)
              if (existing != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: TextButton.icon(
                      onPressed: () async {
                        final merged = await _startMerge(ctx, existing);
                        if (merged) {
                          saved = true;
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                      icon: const Icon(Icons.merge_rounded, size: 18),
                      label: const Text('Mit anderer Übung zusammenführen'),
                    ),
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

/// Startet den Merge-Flow: Picker → Bestätigung → Ausführung.
/// Gibt `true` zurück wenn der Merge durchgeführt wurde.
Future<bool> _startMerge(BuildContext context, Exercise source) async {
  final provider = context.read<ExerciseProvider>();
  final allExercises = provider.exercises
      .where((e) => e.id != source.id)
      .toList();

  if (allExercises.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Keine andere Übung vorhanden')),
    );
    return false;
  }

  // Picker
  final target = await showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _MergePickerSheet(
      exercises: allExercises,
      sourceName: source.name,
    ),
  );

  if (target == null || !context.mounted) return false;

  // Anzahl betroffener Einträge ermitteln
  final entryCount = await provider.countEntriesForExercise(source.id);

  if (!context.mounted) return false;

  // Bestätigungsdialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: const Text('Zusammenführen?'),
      content: Text(
        '„${source.name}" wird in „${target.name}" zusammengeführt.\n\n'
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

  if (confirmed != true || !context.mounted) return false;

  // Merge ausführen
  await provider.mergeExercise(source.id, target.id);
  try {
    context.read<CloudSyncProvider>().scheduleBackupSoon();
  } catch (_) {}

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('„${source.name}" → „${target.name}" zusammengeführt'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  return true;
}

/// Picker-Sheet zum Auswählen der Ziel-Übung.
class _MergePickerSheet extends StatefulWidget {
  final List<Exercise> exercises;
  final String sourceName;
  const _MergePickerSheet({required this.exercises, required this.sourceName});

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
                '„${widget.sourceName}" zusammenführen mit:',
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
