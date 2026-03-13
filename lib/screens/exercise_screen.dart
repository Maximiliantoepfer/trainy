import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exercise.dart';
import '../providers/exercise_provider.dart';
import '../providers/active_workout_provider.dart';
import '../widgets/active_workout_banner.dart';
import '../providers/cloud_sync_provider.dart';

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
                hintText: 'Suchen...',
                prefixIcon: Icon(Icons.search_rounded,
                    color: scheme.onSurfaceVariant.withOpacity(0.5)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: scheme.onSurfaceVariant),
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
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? _EmptyState(onAdd: () => _openEditor(context))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _ExerciseTile(
                          exercise: filtered[i],
                          onTap: () =>
                              _openEditor(context, existing: filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, {Exercise? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    bool trackSets = existing?.trackSets ?? true;
    bool trackReps = existing?.trackReps ?? true;
    bool trackWeight = existing?.trackWeight ?? true;
    bool trackDuration = existing?.trackDuration ?? false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) => SafeArea(
            top: false,
            child: Padding(
              padding:
                  EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  _dragHandle(ctx),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        existing == null
                            ? Icons.add_circle_outline_rounded
                            : Icons.edit_outlined,
                        size: 28,
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: nameCtrl,
                            decoration:
                                const InputDecoration(hintText: 'Name'),
                            autofocus: true,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: descCtrl,
                            decoration: const InputDecoration(
                                hintText: 'Beschreibung'),
                            minLines: 1,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _TrackToggle(
                                icon: Icons.layers_rounded,
                                active: trackSets,
                                onTap: () =>
                                    setModal(() => trackSets = !trackSets),
                              ),
                              _TrackToggle(
                                icon: Icons.repeat_rounded,
                                active: trackReps,
                                onTap: () =>
                                    setModal(() => trackReps = !trackReps),
                              ),
                              _TrackToggle(
                                icon: Icons.fitness_center_rounded,
                                active: trackWeight,
                                onTap: () =>
                                    setModal(() => trackWeight = !trackWeight),
                              ),
                              _TrackToggle(
                                icon: Icons.timer_outlined,
                                active: trackDuration,
                                onTap: () => setModal(
                                    () => trackDuration = !trackDuration),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Abbrechen'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) return;
                              await ctx
                                  .read<ExerciseProvider>()
                                  .addOrUpdateExercise(
                                    id: existing?.id,
                                    name: name,
                                    description: descCtrl.text.trim(),
                                    trackSets: trackSets,
                                    trackReps: trackReps,
                                    trackWeight: trackWeight,
                                    trackDuration: trackDuration,
                                  );
                              try {
                                ctx
                                    .read<CloudSyncProvider>()
                                    .scheduleBackupSoon();
                              } catch (_) {}
                              if (mounted) Navigator.pop(ctx);
                            },
                            child: const Icon(Icons.check_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dragHandle(BuildContext ctx) => Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.outlineVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

class _TrackToggle extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _TrackToggle({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: active
              ? scheme.primary.withOpacity(0.12)
              : scheme.surfaceContainerHighest.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: active
                ? scheme.primary.withOpacity(0.4)
                : scheme.outlineVariant.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(icon,
            size: 22,
            color: active
                ? scheme.primary
                : scheme.onSurfaceVariant.withOpacity(0.4)),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onTap;
  const _ExerciseTile({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (exercise.trackSets)
                          _TrackIcon(Icons.layers_rounded, scheme),
                        if (exercise.trackReps)
                          _TrackIcon(Icons.repeat_rounded, scheme),
                        if (exercise.trackWeight)
                          _TrackIcon(Icons.fitness_center_rounded, scheme),
                        if (exercise.trackDuration)
                          _TrackIcon(Icons.timer_outlined, scheme),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant.withOpacity(0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackIcon extends StatelessWidget {
  final IconData icon;
  final ColorScheme scheme;
  const _TrackIcon(this.icon, this.scheme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Icon(icon,
          size: 15, color: scheme.onSurfaceVariant.withOpacity(0.45)),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.fitness_center_rounded,
                size: 32, color: scheme.primary),
          ),
          const SizedBox(height: 16),
          Icon(Icons.add_rounded,
              size: 28, color: scheme.onSurfaceVariant.withOpacity(0.4)),
        ],
      ),
    );
  }
}
