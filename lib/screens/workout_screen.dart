import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';
import '../providers/cloud_sync_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/active_workout_provider.dart';
import '../providers/progress_provider.dart';
import '../widgets/active_workout_banner.dart';
import '../widgets/exercise_editor_form.dart';
import '../widgets/exercise_editor_sheet.dart';
import '../utils/goal_utils.dart';
import '../utils/utils.dart';
import 'workout_run_screen.dart';

const Duration _kWorkoutAnim = Duration(milliseconds: 200);

class WorkoutScreen extends StatefulWidget {
  final Workout workout;
  const WorkoutScreen({super.key, required this.workout});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late List<int> _exerciseIds;
  late Set<int> _assignedDays;

  @override
  void initState() {
    super.initState();
    _exerciseIds = List<int>.from(widget.workout.exerciseIds);
    _assignedDays = Set<int>.from(widget.workout.assignedDays);
  }

  void _toggleDay(int day) {
    final adding = !_assignedDays.contains(day);
    setState(() {
      if (adding) {
        _assignedDays = Set<int>.from(_assignedDays)..add(day);
      } else {
        _assignedDays = Set<int>.from(_assignedDays)..remove(day);
      }
    });
    context.read<WorkoutProvider>().setWorkoutDays(
      widget.workout.id,
      _assignedDays,
    );
    // Auto-Sync: Tag zu globalen Trainingstagen hinzufügen
    if (adding) {
      final progress = context.read<ProgressProvider>();
      final currentDays = progress.trainingDays.isEmpty
          ? progress.effectiveTrainingDays
          : progress.trainingDays;
      if (!currentDays.contains(day)) {
        progress.setTrainingDays(Set<int>.from(currentDays)..add(day));
      }
    }
    try {
      context.read<CloudSyncProvider>().scheduleBackupSoon();
    } catch (_) {}
  }

  Future<void> _persistOrder(BuildContext context) async {
    await context.read<WorkoutProvider>().setWorkoutExercises(
      widget.workout.id,
      _exerciseIds,
    );
    // trigger cloud backup soon (debounced)
    try {
      context.read<CloudSyncProvider>().scheduleBackupSoon();
    } catch (_) {}
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final id = _exerciseIds.removeAt(oldIndex);
      _exerciseIds.insert(newIndex, id);
    });
    _persistOrder(context);
  }

  Future<void> _openExerciseEditor(Exercise exercise) async {
    final saved = await showExerciseEditorSheet(
      context,
      existing: exercise,
      warnOnEdit: true,
    );
    if (saved && mounted) {
      setState(() {});
    }
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
    final trackDistance = ValueNotifier<bool>(false);
    final goal = ValueNotifier<String?>(null);

    final rootContext = context;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        Future<void> createAndAttach() async {
          final name = nameCtrl.text.trim();
          if (name.isEmpty) {
            await showDialog(
              context: ctx,
              builder:
                  (_) => AlertDialog(
                    title: const Text('Name fehlt'),
                    content: const Text('Bitte einen Namen eingeben'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
            );
            return;
          }

          final newId = await ctx.read<ExerciseProvider>().addExercise(
            name: name,
            description: descCtrl.text.trim(),
            trackSets: trackSets.value,
            trackReps: trackReps.value,
            trackWeight: trackWeight.value,
            trackDuration: trackDuration.value,
            trackDistance: trackDistance.value,
            goal: goal.value,
          );

          final merged = [
            ..._exerciseIds,
            if (!_exerciseIds.contains(newId)) newId,
          ];

          setState(() => _exerciseIds = merged);
          await _persistOrder(rootContext);

          if (rootContext.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(rootContext).showSnackBar(
              SnackBar(
                content: Text('„$name" wurde erstellt und hinzugefügt'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }

        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, modalSetState) {
            return DefaultTabController(
              length: 2,
              child: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final controller = DefaultTabController.of(ctx)!;
                    final scheme = Theme.of(ctx).colorScheme;
                    final filteredAll = searchQuery.isEmpty
                        ? all
                        : all.where((e) => e.name.toLowerCase().contains(searchQuery.toLowerCase())
                            || e.mergedAliases.any((a) => a.toLowerCase().contains(searchQuery.toLowerCase()))).toList();

                    return Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(
                                'Übungen hinzufügen',
                                style: Theme.of(ctx).textTheme.titleLarge,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TabBar(
                              indicator: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(10)),
                              indicatorSize: TabBarIndicatorSize.tab,
                              indicatorPadding: const EdgeInsets.all(3),
                              dividerColor: Colors.transparent,
                              labelColor: scheme.onPrimary,
                              unselectedLabelColor: scheme.onSurfaceVariant,
                              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              tabs: const [Tab(text: 'Vorhandene'), Tab(text: 'Neu erstellen')],
                              onTap: (_) => modalSetState(() {}),
                            ),
                          ),
                        ),

                        Expanded(
                          child: TabBarView(
                            children: [
                              // Tab 1: vorhandene Exercises auswählen
                              Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                    child: TextField(
                                      decoration: InputDecoration(
                                        hintText: 'Übung suchen...',
                                        prefixIcon: const Icon(Icons.search_rounded),
                                        suffixIcon: searchQuery.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.close),
                                                onPressed: () => modalSetState(() => searchQuery = ''),
                                              )
                                            : null,
                                      ),
                                      onChanged: (v) => modalSetState(() => searchQuery = v),
                                    ),
                                  ),
                                  Expanded(
                                    child: ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                      itemCount: filteredAll.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                                      itemBuilder: (_, i) {
                                        final e = filteredAll[i];
                                        final subtitle = <String>[];
                                        if (e.trackSets) subtitle.add('Sätze');
                                        if (e.trackReps) subtitle.add('Wdh.');
                                        if (e.trackWeight) subtitle.add('Gewicht');
                                        if (e.trackDistance) subtitle.add('Entfernung');
                                        if (e.trackDuration) subtitle.add('Dauer');
                                        final subtitleText = subtitle.join(' · ');
                                        final alias = matchingAlias(e, searchQuery);
                                        final cScheme = Theme.of(context).colorScheme;
                                        return Card(
                                          child: CheckboxListTile(
                                            value: selected.contains(e.id),
                                            onChanged: (v) {
                                              modalSetState(() {
                                                if (v == true) {
                                                  selected.add(e.id);
                                                } else {
                                                  selected.remove(e.id);
                                                }
                                              });
                                            },
                                            title: Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    e.name,
                                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                                if (e.goal != null) ...[
                                                  const SizedBox(width: 8),
                                                  goalBadge(e.goal!, cScheme),
                                                ],
                                              ],
                                            ),
                                            subtitle: (subtitleText.isEmpty && alias == null) ? null : Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (subtitleText.isNotEmpty) Text(subtitleText),
                                                if (alias != null)
                                                  Text('ehem. $alias',
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                      fontStyle: FontStyle.italic,
                                                      color: cScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            controlAffinity:
                                                ListTileControlAffinity.leading,
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

                              // Tab 2: neue Exercise erstellen
                              ListView(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                                children: [
                                  ExerciseEditorForm(
                                    nameCtrl: nameCtrl,
                                    descCtrl: descCtrl,
                                    trackSets: trackSets,
                                    trackReps: trackReps,
                                    trackWeight: trackWeight,
                                    trackDuration: trackDuration,
                                    trackDistance: trackDistance,
                                    goal: goal,
                                    autofocusName: true,
                                    onChanged: () => modalSetState(() {}),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Dynamische Bottom-CTA (achtet auf Keyboard)
                        AnimatedBuilder(
                          animation: controller.animation ?? controller,
                          builder: (_, __) {
                            final isCreateTab = controller.index == 1;
                            final canCreate = nameCtrl.text.trim().isNotEmpty;
                            final bottomInset =
                                MediaQuery.of(ctx).viewInsets.bottom;

                            return AnimatedPadding(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              padding: EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16 + bottomInset,
                              ),
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
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        switchInCurve: Curves.easeOut,
                                        switchOutCurve: Curves.easeIn,
                                        transitionBuilder:
                                            (child, anim) => FadeTransition(
                                              opacity: anim,
                                              child: child,
                                            ),
                                        child:
                                            isCreateTab
                                                ? FilledButton.icon(
                                                  key: const ValueKey(
                                                    'create_and_add',
                                                  ),
                                                  onPressed:
                                                      canCreate
                                                          ? () async =>
                                                              createAndAttach()
                                                          : null,
                                                  icon: const Icon(Icons.add),
                                                  label: const Text(
                                                    'Erstellen',
                                                  ),
                                                )
                                                : FilledButton(
                                                  key: const ValueKey(
                                                    'add_selected',
                                                  ),
                                                onPressed: () async {
                                                  final merged = [
                                                    ..._exerciseIds,
                                                    ...selected.where(
                                                      (id) =>
                                                          !_exerciseIds
                                                              .contains(id),
                                                    ),
                                                  ];
                                                  setState(
                                                    () => _exerciseIds = merged,
                                                  );
                                                  await _persistOrder(
                                                    rootContext,
                                                  );

                                                  if (rootContext.mounted) {
                                                    Navigator.pop(ctx);
                                                    ScaffoldMessenger.of(
                                                      rootContext,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Übungen hinzugefügt',
                                                        ),
                                                        behavior:
                                                            SnackBarBehavior
                                                                .floating,
                                                      ),
                                                    );
                                                  }
                                                },
                                                child: const Text(
                                                  'Hinzufügen',
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
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
      builder:
          (ctx) => AlertDialog(
            title: const Text('Workout umbenennen'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Workout-Name'),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () {
                  newName =
                      ctrl.text.trim().isNotEmpty
                          ? ctrl.text.trim()
                          : widget.workout.name;
                  Navigator.pop(ctx);
                },
                child: const Text('Speichern'),
              ),
            ],
          ),
    );
    await context.read<WorkoutProvider>().updateWorkoutName(
      widget.workout.id,
      newName,
    );
    setState(() => widget.workout.name = newName);
    try {
      context.read<CloudSyncProvider>().scheduleBackupSoon();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final exercises = context.watch<ExerciseProvider>().exercises;
    final active = context.watch<ActiveWorkoutProvider>();
    final items =
        _exerciseIds
            .map(
              (id) =>
                  exercises
                      .where((e) => e.id == id)
                      .cast<Exercise?>()
                      .firstOrNull,
            )
            .toList();

    final canStart = _exerciseIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _rename,
          child: Text(widget.workout.name, overflow: TextOverflow.ellipsis),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            48 + (active.isActive ? 56 : 0),
          ),
          child: Column(
            children: [
              _DayAssignmentRow(
                assignedDays: _assignedDays,
                onToggle: _toggleDay,
              ),
              if (active.isActive) const ActiveWorkoutBanner(),
            ],
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: _kWorkoutAnim,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          );
          return FadeTransition(
            opacity: curved,
            child: SizeTransition(sizeFactor: curved, child: child),
          );
        },
        child:
            _exerciseIds.isEmpty
                ? _EmptyState(
                  key: const ValueKey('workout-empty'),
                  onAdd: _addExercisesBottomSheet,
                )
                : ReorderableListView.builder(
                  key: const ValueKey('workout-list'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                  itemCount: _exerciseIds.length,
                  onReorder: _onReorder,
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, animation) {
                    HapticFeedback.mediumImpact();
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (_, __) => Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(16),
                        shadowColor: Colors.black26,
                        child: child,
                      ),
                    );
                  },
                  itemBuilder: (_, i) {
                    final id = _exerciseIds[i];
                    final e = items[i];
                    final scheme = Theme.of(context).colorScheme;
                    return Dismissible(
                      key: ValueKey('dismiss_$id'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Entfernen', style: TextStyle(
                              color: scheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            )),
                            const SizedBox(width: 8),
                            Icon(Icons.remove_circle_outline_rounded,
                              color: scheme.onSecondaryContainer),
                          ],
                        ),
                      ),
                      onDismissed: (_) async {
                        setState(() => _exerciseIds.removeAt(i));
                        await _persistOrder(context);
                      },
                      child: ReorderableDelayedDragStartListener(
                        index: i,
                        child: AnimatedSize(
                          key: ValueKey('exercise_$id'),
                          duration: _kWorkoutAnim,
                          curve: Curves.easeOut,
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: e != null ? () => _openExerciseEditor(e) : null,
                              borderRadius: BorderRadius.circular(16),
                              child: IntrinsicHeight(
                                child: Row(
                                  children: [
                                    if (e?.goal != null)
                                      Container(
                                        width: 4,
                                        color: goalColor(e!.goal!, scheme),
                                      ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          e?.name ?? 'Gelöschte Übung ($id)',
                                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                      if (e?.goal != null) ...[
                                                        const SizedBox(width: 8),
                                                        goalBadge(e!.goal!, scheme),
                                                      ],
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    e == null
                                                        ? 'Nicht mehr vorhanden'
                                                        : [
                                                            if (e.trackSets) 'Sätze',
                                                            if (e.trackReps) 'Wdh.',
                                                            if (e.trackWeight) 'Gewicht',
                                                            if (e.trackDistance) 'Entfernung',
                                                            if (e.trackDuration) 'Dauer',
                                                          ].join(' · '),
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(Icons.chevron_right_rounded,
                                              color: scheme.onSurfaceVariant.withOpacity(0.4)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      ),
      floatingActionButton: Builder(
        builder: (ctx) {
          final active = ctx.watch<ActiveWorkoutProvider>();
          final isThisActive =
              active.isActive && active.workout?.id == widget.workout.id;
          if (_exerciseIds.isEmpty && !isThisActive)
            return const SizedBox.shrink();
          final exercises = ctx.read<ExerciseProvider>().exercises;
          return FloatingActionButton.extended(
            onPressed: () {
              final list =
                  _exerciseIds
                      .map(
                        (id) =>
                            exercises
                                .where((e) => e.id == id)
                                .cast<Exercise?>()
                                .firstOrNull,
                      )
                      .whereType<Exercise>()
                      .toList();
              if (isThisActive) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => WorkoutRunScreen(
                          workout: widget.workout,
                          exercises: list,
                          autoStart: false,
                        ),
                  ),
                );
              } else {
                if (active.isActive) {
                  active.clear();
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => WorkoutRunScreen(
                          workout: widget.workout,
                          exercises: list,
                          autoStart: true,
                        ),
                  ),
                );
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton.tonalIcon(
            onPressed: _addExercisesBottomSheet,
            icon: const Icon(Icons.add),
            label: const Text('Weitere Übungen hinzufügen'),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Noch keine Übungen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Füge Übungen hinzu, um dein Workout zu starten.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Übungen hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }
}


class _DayAssignmentRow extends StatelessWidget {
  final Set<int> assignedDays;
  final void Function(int day) onToggle;
  const _DayAssignmentRow({required this.assignedDays, required this.onToggle});

  static const _labels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final day = i + 1;
          final selected = assignedDays.contains(day);
          return GestureDetector(
            onTap: () => onToggle(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: selected ? Border.all(color: scheme.primary, width: 1.5) : null,
              ),
              alignment: Alignment.center,
              child: Text(
                _labels[i],
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// kleine Extension um firstOrNull zu bekommen
extension _IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
