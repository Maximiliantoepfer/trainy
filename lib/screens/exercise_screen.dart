import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exercise.dart';
import '../providers/exercise_provider.dart';
import '../providers/active_workout_provider.dart';
import '../widgets/active_workout_banner.dart';
import '../providers/cloud_sync_provider.dart';
import '../widgets/exercise_editor_form.dart';
import '../utils/goal_utils.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

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
    final list = provider.exercises;
    final scheme = Theme.of(context).colorScheme;
    final filtered = _query.isEmpty
        ? list
        : list.where((e) {
            final q = _query.toLowerCase();
            return e.name.toLowerCase().contains(q) ||
                (e.description?.toLowerCase().contains(q) ?? false);
          }).toList();

    final isActive = context.watch<ActiveWorkoutProvider>().isActive;

    return Scaffold(
      appBar: AppBar(title: const Text('Übungen')),
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: isActive
                ? const ActiveWorkoutBanner()
                : const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Übung suchen...',
                prefixIcon: Icon(Icons.search_rounded,
                    color: scheme.onSurfaceVariant.withOpacity(0.5)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: scheme.onSurfaceVariant),
                        onPressed: () {
                          setState(() { _query = ''; _searchCtrl.clear(); });
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? _EmptyState(onAdd: () => _openEditor(context))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final e = filtered[i];
                          final tags = [
                            if (e.trackSets) 'Sätze',
                            if (e.trackReps) 'Wdh.',
                            if (e.trackWeight) 'Gewicht',
                            if (e.trackDuration) 'Dauer',
                          ];
                          return _ExerciseTile(
                            exercise: e, tags: tags,
                            onTap: () => _openEditor(context, existing: e),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Neue Übung'),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, {Exercise? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final trackSets = ValueNotifier(existing?.trackSets ?? true);
    final trackReps = ValueNotifier(existing?.trackReps ?? true);
    final trackWeight = ValueNotifier(existing?.trackWeight ?? true);
    final trackDuration = ValueNotifier(existing?.trackDuration ?? false);
    final goal = ValueNotifier<String?>(existing?.goal);

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
                      autofocusName: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      Expanded(child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Abbrechen'),
                        ),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: SizedBox(
                        height: 48,
                        child: FilledButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          await ctx.read<ExerciseProvider>().addOrUpdateExercise(
                            id: existing?.id, name: name, description: descCtrl.text.trim(),
                            trackSets: trackSets.value, trackReps: trackReps.value,
                            trackWeight: trackWeight.value, trackDuration: trackDuration.value,
                            goal: goal.value,
                          );
                          try { ctx.read<CloudSyncProvider>().scheduleBackupSoon(); } catch (_) {}
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(existing == null ? '„$name" angelegt' : '„$name" aktualisiert')),
                            );
                          }
                        },
                        child: Text(existing == null ? 'Erstellen' : 'Speichern'),
                      ))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  final List<String> tags;
  final VoidCallback onTap;
  const _ExerciseTile({required this.exercise, required this.tags, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(exercise.name, style: Theme.of(context).textTheme.titleMedium)),
                    if (exercise.goal != null) ...[
                      const SizedBox(width: 8),
                      goalBadge(exercise.goal!, scheme),
                    ],
                  ],
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(tags.join(' · '), style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            )),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant.withOpacity(0.4)),
          ]),
        ),
      ),
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.fitness_center_rounded, size: 32, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 20),
          Text('Noch keine Übungen', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Lege deine erste Übung an.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
