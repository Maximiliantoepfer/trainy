import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/plan_l10n.dart';
import '../l10n/cardio_l10n.dart';
import '../models/cardio.dart';
import '../models/workout.dart';
import '../models/workout_planning.dart';
import '../providers/workout_provider.dart';
import '../providers/cardio_provider.dart';
import '../services/cardio_training.dart';
import '../widgets/plan_controls.dart';
import 'exercise_screen.dart';
import 'workout_detail_screen.dart';
import 'cardio_editor_screen.dart';
import 'cardio_session_screen.dart';

class TrainingLibraryScreen extends StatefulWidget {
  const TrainingLibraryScreen({
    super.key,
    this.initialSport = 'all',
    this.pickWorkout = false,
  });
  final String initialSport;
  final bool pickWorkout;
  @override
  State<TrainingLibraryScreen> createState() => _TrainingLibraryScreenState();
}

class _TrainingLibraryScreenState extends State<TrainingLibraryScreen> {
  late String _sport = widget.initialSport;
  String? _error;
  Future<void> _strength(Workout w) async {
    if (widget.pickWorkout) {
      Navigator.pop(context, w.canonicalId);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkoutDetailScreen(workout: w)),
    );
    if (mounted) await context.read<WorkoutProvider>().loadWorkouts();
  }

  Future<void> _create() async {
    final sport =
        widget.pickWorkout
            ? _sport
            : await choosePlanValue(context, 'typeQuestion', [
              'strength',
              'running',
              'cardio',
              'mobility',
            ], _sport);
    if (sport == null || !mounted) return;
    setState(() => _sport = sport);
    if (sport == 'strength' || sport == 'mobility') {
      final w = await Navigator.push<Workout>(
        context,
        MaterialPageRoute(
          builder:
              (_) => WorkoutEditorScreen(
                initialGoal:
                    sport == 'mobility'
                        ? WorkoutPrimaryGoal.mobility
                        : WorkoutPrimaryGoal.strength,
              ),
        ),
      );
      if (!mounted) return;
      await context.read<WorkoutProvider>().loadWorkouts();
      if (w != null && mounted) await _strength(w);
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CardioTemplatePicker(sport: sport)),
      );
      if (mounted) await context.read<CardioProvider>().load();
    }
  }

  Widget _workouts() {
    final strength = context.watch<WorkoutProvider>().workouts;
    final cardio = context.watch<CardioProvider>();
    final mine =
        strength
            .where(
              (w) =>
                  _sport == 'all' ||
                  w.primaryGoalCode == _sport ||
                  (_sport == 'cardio' && w.primaryGoalCode == 'endurance'),
            )
            .toList();
    final running =
        cardio.workouts
            .where(
              (w) =>
                  _sport == 'all' ||
                  (_sport == 'running' && w.sport == CardioSport.running) ||
                  (_sport == 'cardio' && w.sport != CardioSport.running),
            )
            .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.pickWorkout)
          Text(
            context.plan(_sport),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        if (!widget.pickWorkout)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in [
                'all',
                'strength',
                'running',
                'cardio',
                'mobility',
              ])
                ChoiceChip(
                  label: Text(context.plan(s)),
                  selected: _sport == s,
                  onSelected: (_) => setState(() => _sport = s),
                ),
            ],
          ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _create,
          icon: const Icon(Icons.add),
          label: Text(context.plan('newWorkout')),
        ),
        const SizedBox(height: 24),
        Text(
          context.plan('ownWorkouts'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (mine.isEmpty && running.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(context.plan('emptyWorkouts')),
          ),
        for (final w in mine)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: Icon(
                  w.primaryGoalCode == 'mobility'
                      ? Icons.self_improvement
                      : Icons.fitness_center,
                ),
                title: Text(w.name),
                subtitle: Text(
                  '${w.exerciseIds.length} ${context.plan('exercises')}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _strength(w),
                onLongPress:
                    widget.pickWorkout
                        ? null
                        : () async {
                          final remove = await showDialog<bool>(
                            context: context,
                            builder:
                                (c) => AlertDialog(
                                  title: Text(c.plan('deleteWorkout')),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: Text(c.plan('cancel')),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: Text(c.plan('delete')),
                                    ),
                                  ],
                                ),
                          );
                          if (remove == true && mounted) {
                            try {
                              await context
                                  .read<WorkoutProvider>()
                                  .deleteWorkout(w.id);
                            } catch (_) {
                              if (mounted) setState(() => _error = 'error');
                            }
                          }
                        },
              ),
            ),
          ),
        if (!widget.pickWorkout)
          for (final w in running)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Icon(
                    w.sport == CardioSport.running
                        ? Icons.directions_run
                        : Icons.directions_bike,
                  ),
                  title: Text(w.name),
                  subtitle: Text(context.cardio(w.sport.name)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CardioWorkoutDetail(workout: w),
                        ),
                      ),
                ),
              ),
            ),
        if (!widget.pickWorkout &&
            ['all', 'running', 'cardio'].contains(_sport)) ...[
          const SizedBox(height: 24),
          Text(
            context.plan('templates'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (_sport != 'cardio')
            for (final code in CardioTraining.templateCodes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.cardio(code)),
                trailing: const Icon(Icons.chevron_right),
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => CardioWorkoutDetail(
                              workout: CardioTraining.template(
                                code,
                                cardio.profile,
                                context.cardio,
                              ),
                              template: true,
                            ),
                      ),
                    ),
              ),
          if (_sport != 'running')
            for (final sport in CardioSport.values.where(
              (s) => s != CardioSport.running,
            ))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.cardio(sport.name)),
                leading: const Icon(Icons.directions_bike),
                trailing: const Icon(Icons.chevron_right),
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => CardioTemplatePicker(
                              sport: 'cardio',
                              activity: sport,
                            ),
                      ),
                    ),
              ),
        ],
        if (_error != null) PlanError(_error!),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: widget.pickWorkout ? 1 : 2,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          context.plan(widget.pickWorkout ? 'assignWorkout' : 'training'),
        ),
        bottom:
            widget.pickWorkout
                ? null
                : TabBar(
                  tabs: [
                    Tab(text: context.plan('workouts')),
                    Tab(text: context.plan('exercises')),
                  ],
                ),
      ),
      body:
          widget.pickWorkout
              ? _workouts()
              : TabBarView(
                children: [_workouts(), const ExerciseScreen(embedded: true)],
              ),
    ),
  );
}

class CardioTemplatePicker extends StatelessWidget {
  const CardioTemplatePicker({super.key, required this.sport, this.activity});
  final String sport;
  final CardioSport? activity;
  @override
  Widget build(BuildContext context) {
    final p = context.watch<CardioProvider>();
    final selected =
        activity ??
        (sport == 'running' ? CardioSport.running : CardioSport.cycling);
    return Scaffold(
      appBar: AppBar(title: Text(context.plan('templates'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            title: Text(context.plan('emptyWorkout')),
            trailing: const Icon(Icons.add),
            onTap: () async {
              final edited = await Navigator.push<CardioWorkout>(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => CardioEditorScreen(
                        workout: CardioWorkout(
                          name: context.cardio(selected.name),
                          sport: selected,
                          steps: [CardioStep(amount: 1800)],
                        ),
                        units: p.profile.units,
                      ),
                ),
              );
              if (edited != null) {
                try {
                  await p.repository.saveWorkout(edited);
                  await p.load();
                  if (context.mounted) Navigator.pop(context);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.plan('savingError'))),
                    );
                  }
                }
              }
            },
          ),
          if (sport == 'cardio' && activity == null)
            for (final s in CardioSport.values.where(
              (s) => s != CardioSport.running,
            ))
              ListTile(
                title: Text(context.cardio(s.name)),
                trailing: const Icon(Icons.chevron_right),
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => CardioTemplatePicker(
                              sport: 'cardio',
                              activity: s,
                            ),
                      ),
                    ),
              )
          else
            for (final code
                in selected == CardioSport.running
                    ? CardioTraining.templateCodes
                    : ['easySession', 'intervalSession'])
              ListTile(
                title: Text(context.cardio(code)),
                trailing: const Icon(Icons.chevron_right),
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => CardioWorkoutDetail(
                              workout: CardioTraining.template(
                                code,
                                p.profile,
                                context.cardio,
                                sport: selected,
                                indoor:
                                    ![
                                      CardioSport.running,
                                      CardioSport.cycling,
                                      CardioSport.walking,
                                    ].contains(selected),
                              ),
                              template: true,
                            ),
                      ),
                    ),
              ),
        ],
      ),
    );
  }
}

class CardioWorkoutDetail extends StatefulWidget {
  const CardioWorkoutDetail({
    super.key,
    required this.workout,
    this.template = false,
  });
  final CardioWorkout workout;
  final bool template;
  @override
  State<CardioWorkoutDetail> createState() => _CardioWorkoutDetailState();
}

class _CardioWorkoutDetailState extends State<CardioWorkoutDetail> {
  late CardioWorkout _workout = widget.workout;
  bool _saved = false, _busy = false;
  String? _error;
  Future<void> _edit() async {
    final p = context.read<CardioProvider>();
    final value = await Navigator.push<CardioWorkout>(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                CardioEditorScreen(workout: _workout, units: p.profile.units),
      ),
    );
    if (value == null || !mounted) return;
    try {
      await p.repository.saveWorkout(value);
      await p.load();
      if (mounted) {
        setState(() {
          _workout = value;
          _saved = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'savingError');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CardioProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_workout.name),
        actions: [
          IconButton(
            tooltip: context.plan('edit'),
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(20),
        child: FilledButton.icon(
          onPressed:
              _busy
                  ? null
                  : () async {
                    setState(() => _busy = true);
                    await startCardioWorkout(context, _workout);
                    if (mounted) setState(() => _busy = false);
                  },
          icon: const Icon(Icons.play_arrow),
          label: Text(context.cardio('start')),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${context.cardio(_workout.sport.name)} · ${context.cardio(_workout.indoor ? 'indoor' : 'outdoor')}',
          ),
          const SizedBox(height: 20),
          for (final step in _workout.steps)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                step.name.isEmpty
                    ? context.cardio(step.intensity.name)
                    : step.name,
              ),
              subtitle: Text(
                '${step.repeat > 1 ? '${step.repeat} × ' : ''}${cardioStepDescription(step, p.profile.units, context)}',
              ),
            ),
          if (widget.template && !_saved)
            OutlinedButton(onPressed: _edit, child: Text(context.plan('save'))),
          if (!widget.template || _saved)
            TextButton(
              onPressed: () async {
                final remove = await showDialog<bool>(
                  context: context,
                  builder:
                      (c) => AlertDialog(
                        title: Text(c.plan('deleteWorkout')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text(c.plan('cancel')),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: Text(c.plan('delete')),
                          ),
                        ],
                      ),
                );
                if (remove == true) {
                  try {
                    await p.repository.deleteWorkout(_workout.id);
                    await p.load();
                    if (context.mounted) Navigator.pop(context);
                  } catch (_) {
                    if (mounted) setState(() => _error = 'error');
                  }
                }
              },
              child: Text(context.plan('delete')),
            ),
          if (_error != null) PlanError(_error!),
        ],
      ),
    );
  }
}
