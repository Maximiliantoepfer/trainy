import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';
import '../providers/cloud_sync_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/active_workout_provider.dart';
import '../widgets/active_workout_banner.dart';
import 'workout_run_screen.dart';

class WorkoutScreen extends StatefulWidget {
  final Workout workout;
  const WorkoutScreen({super.key, required this.workout});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late List<int> _exerciseIds;

  @override
  void initState() {
    super.initState();
    _exerciseIds = List<int>.from(widget.workout.exerciseIds);
  }

  Future<void> _persistOrder(BuildContext context) async {
    await context.read<WorkoutProvider>().setWorkoutExercises(
          widget.workout.id, _exerciseIds);
    try { context.read<CloudSyncProvider>().scheduleBackupSoon(); } catch (_) {}
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final id = _exerciseIds.removeAt(oldIndex);
      _exerciseIds.insert(newIndex, id);
    });
    _persistOrder(context);
  }

  Future<void> _addExercisesBottomSheet() async {
    final all = context.read<ExerciseProvider>().exercises;
    final selected = Set<int>.from(_exerciseIds);
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final trackSets = ValueNotifier<bool>(true);
    final trackReps = ValueNotifier<bool>(true);
    final trackWeight = ValueNotifier<bool>(true);
    final trackDuration = ValueNotifier<bool>(false);
    final rootContext = context;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        Future<void> createAndAttach() async {
          final name = nameCtrl.text.trim();
          if (name.isEmpty) return;
          final newId = await ctx.read<ExerciseProvider>().addExercise(
                name: name,
                description: descCtrl.text.trim(),
                trackSets: trackSets.value,
                trackReps: trackReps.value,
                trackWeight: trackWeight.value,
                trackDuration: trackDuration.value,
              );
          final merged = [..._exerciseIds, if (!_exerciseIds.contains(newId)) newId];
          setState(() => _exerciseIds = merged);
          await _persistOrder(rootContext);
          if (rootContext.mounted) Navigator.pop(ctx);
        }

        return StatefulBuilder(
          builder: (ctx, modalSetState) {
            return DefaultTabController(
              length: 2,
              child: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final controller = DefaultTabController.of(ctx)!;
                    return Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 44, height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TabBar(
                          tabs: const [
                            Tab(icon: Icon(Icons.list_rounded)),
                            Tab(icon: Icon(Icons.add_rounded)),
                          ],
                          onTap: (_) => modalSetState(() {}),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              // Tab 1: existing exercises
                              ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                itemCount: all.length,
                                itemBuilder: (_, i) {
                                  final e = all[i];
                                  final isChecked = selected.contains(e.id);
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () {
                                        modalSetState(() {
                                          if (isChecked) selected.remove(e.id);
                                          else selected.add(e.id);
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 12),
                                        child: Row(
                                          children: [
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              width: 24, height: 24,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isChecked
                                                    ? Theme.of(ctx).colorScheme.primary
                                                    : Colors.transparent,
                                                border: Border.all(
                                                  color: isChecked
                                                      ? Theme.of(ctx).colorScheme.primary
                                                      : Theme.of(ctx).colorScheme.outlineVariant,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: isChecked
                                                  ? const Icon(Icons.check_rounded,
                                                      size: 16, color: Colors.white)
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(e.name,
                                                  style: Theme.of(ctx).textTheme.titleMedium),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (e.trackSets)
                                                  _MiniIcon(Icons.layers_rounded),
                                                if (e.trackReps)
                                                  _MiniIcon(Icons.repeat_rounded),
                                                if (e.trackWeight)
                                                  _MiniIcon(Icons.fitness_center_rounded),
                                                if (e.trackDuration)
                                                  _MiniIcon(Icons.timer_outlined),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Tab 2: create new
                              ListView(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                children: [
                                  TextField(
                                    controller: nameCtrl,
                                    decoration: const InputDecoration(hintText: 'Name'),
                                    autofocus: true,
                                    onChanged: (_) => modalSetState(() {}),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: descCtrl,
                                    decoration: const InputDecoration(hintText: 'Beschreibung'),
                                    minLines: 1, maxLines: 3,
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _TrackToggleSmall(icon: Icons.layers_rounded, notifier: trackSets, onChange: () => modalSetState(() {})),
                                      _TrackToggleSmall(icon: Icons.repeat_rounded, notifier: trackReps, onChange: () => modalSetState(() {})),
                                      _TrackToggleSmall(icon: Icons.fitness_center_rounded, notifier: trackWeight, onChange: () => modalSetState(() {})),
                                      _TrackToggleSmall(icon: Icons.timer_outlined, notifier: trackDuration, onChange: () => modalSetState(() {})),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        AnimatedBuilder(
                          animation: controller.animation ?? controller,
                          builder: (_, __) {
                            final isCreateTab = controller.index == 1;
                            final canCreate = nameCtrl.text.trim().isNotEmpty;
                            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
                            return AnimatedPadding(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
                              child: SizedBox(
                                width: double.infinity,
                                child: isCreateTab
                                    ? FilledButton.icon(
                                        onPressed: canCreate ? () async => createAndAttach() : null,
                                        icon: const Icon(Icons.add_rounded),
                                        label: const Text('Erstellen'),
                                      )
                                    : FilledButton.icon(
                                        onPressed: () async {
                                          final merged = [
                                            ..._exerciseIds,
                                            ...selected.where((id) => !_exerciseIds.contains(id)),
                                          ];
                                          setState(() => _exerciseIds = merged);
                                          await _persistOrder(rootContext);
                                          if (rootContext.mounted) Navigator.pop(ctx);
                                        },
                                        icon: const Icon(Icons.check_rounded),
                                        label: const Text('Fertig'),
                                      ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _rename() async {
    String newName = widget.workout.name;
    final ctrl = TextEditingController(text: widget.workout.name);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Icon(Icons.edit_outlined),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              newName = ctrl.text.trim().isNotEmpty
                  ? ctrl.text.trim()
                  : widget.workout.name;
              Navigator.pop(ctx);
            },
            child: const Icon(Icons.check_rounded),
          ),
        ],
      ),
    );
    await context.read<WorkoutProvider>().updateWorkoutName(
          widget.workout.id, newName);
    setState(() => widget.workout.name = newName);
    try { context.read<CloudSyncProvider>().scheduleBackupSoon(); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final exercises = context.watch<ExerciseProvider>().exercises;
    final active = context.watch<ActiveWorkoutProvider>();
    final scheme = Theme.of(context).colorScheme;
    final items = _exerciseIds
        .map((id) => exercises
            .where((e) => e.id == id)
            .cast<Exercise?>()
            .firstOrNull)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.name),
        bottom: active.isActive
            ? const PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: ActiveWorkoutBanner(),
              )
            : null,
        actions: [
          IconButton(
            onPressed: _rename,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: _exerciseIds.isEmpty
          ? _EmptyState(onAdd: _addExercisesBottomSheet)
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
              itemCount: _exerciseIds.length,
              onReorder: _onReorder,
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) =>
                  ScaleTransition(scale: animation, child: child),
              itemBuilder: (_, i) {
                final id = _exerciseIds[i];
                final e = items[i];
                return Card(
                  key: ValueKey('exercise_$id'),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: Icon(Icons.drag_handle_rounded,
                              color: scheme.onSurfaceVariant.withOpacity(0.4)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e?.name ?? '#$id',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (e != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (e.trackSets)
                                      _MiniIcon(Icons.layers_rounded),
                                    if (e.trackReps)
                                      _MiniIcon(Icons.repeat_rounded),
                                    if (e.trackWeight)
                                      _MiniIcon(Icons.fitness_center_rounded),
                                    if (e.trackDuration)
                                      _MiniIcon(Icons.timer_outlined),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 20,
                              color: scheme.onSurfaceVariant.withOpacity(0.4)),
                          onPressed: () async {
                            setState(() => _exerciseIds.removeAt(i));
                            await _persistOrder(context);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: Builder(
        builder: (ctx) {
          final active = ctx.watch<ActiveWorkoutProvider>();
          final isThisActive =
              active.isActive && active.workout?.id == widget.workout.id;
          if (_exerciseIds.isEmpty && !isThisActive) {
            return const SizedBox.shrink();
          }
          final exercises = ctx.read<ExerciseProvider>().exercises;
          return FloatingActionButton.extended(
            onPressed: () {
              final list = _exerciseIds
                  .map((id) => exercises
                      .where((e) => e.id == id)
                      .cast<Exercise?>()
                      .firstOrNull)
                  .whereType<Exercise>()
                  .toList();
              if (isThisActive) {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => WorkoutRunScreen(
                        workout: widget.workout,
                        exercises: list,
                        autoStart: false)));
              } else {
                if (active.isActive) active.clear();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => WorkoutRunScreen(
                        workout: widget.workout,
                        exercises: list,
                        autoStart: true)));
              }
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(isThisActive ? 'Fortsetzen' : 'Start'),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: FilledButton.tonalIcon(
            onPressed: _addExercisesBottomSheet,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Hinzufügen'),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd, super.key});

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
            child: Icon(Icons.list_alt_rounded,
                size: 32, color: scheme.primary),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  final IconData icon;
  const _MiniIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Icon(icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4)),
    );
  }
}

class _TrackToggleSmall extends StatelessWidget {
  final IconData icon;
  final ValueNotifier<bool> notifier;
  final VoidCallback onChange;

  const _TrackToggleSmall({
    required this.icon,
    required this.notifier,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (_, active, __) => GestureDetector(
        onTap: () {
          notifier.value = !notifier.value;
          onChange();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
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
              size: 20,
              color: active
                  ? scheme.primary
                  : scheme.onSurfaceVariant.withOpacity(0.4)),
        ),
      ),
    );
  }
}

extension _IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
