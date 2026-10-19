import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/plan_l10n.dart';
import '../models/training_program.dart';
import '../models/workout_planning.dart';
import '../providers/exercise_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/training_program_provider.dart';
import '../repositories/workout_planning_repository.dart';
import '../utils/exercise_localization.dart';

class StrengthSplitScreen extends StatefulWidget {
  const StrengthSplitScreen({super.key, required this.entry});
  final ProgramEntry entry;
  @override
  State<StrengthSplitScreen> createState() => _StrengthSplitState();
}

class _StrengthSplitState extends State<StrengthSplitScreen> {
  WorkoutSetup? _setup;
  final _first = <String>{};
  late DateTime _second = DateTime(
    widget.entry.date.year,
    widget.entry.date.month,
    widget.entry.date.day + (widget.entry.date.weekday == 7 ? -1 : 1),
  );
  String? _error;
  bool _busy = false;
  List<DateTime> get _allowedDates {
    final p = context.read<TrainingProgramProvider>().plans.firstWhere(
      (p) => p.id == widget.entry.planId,
    );
    final day = widget.entry.date;
    return [
          for (var i = 1; i <= 7; i++)
            DateTime(day.year, day.month, day.day - day.weekday + i),
        ]
        .where(
          (d) =>
              dateKey(d) != dateKey(day) &&
              dateKey(d).compareTo(dateKey(p.start)) >= 0 &&
              (p.endDate == null ||
                  dateKey(d).compareTo(dateKey(p.endDate!)) <= 0),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final setups = await WorkoutPlanningRepository().setupsForWorkout(
        widget.entry.workoutId!,
      );
      final setup = setups.first;
      final slots =
          setup.groups.expand((g) => g.selectedVariant.slots).toList();
      if (mounted) {
        setState(() {
          _setup = setup;
          final available = _allowedDates;
          if (available.isNotEmpty &&
              !available.any((d) => dateKey(d) == dateKey(_second))) {
            _second = available.first;
          }
          if (available.isEmpty) _error = 'changeDays';
          _first.addAll(slots.take((slots.length / 2).ceil()).map((s) => s.id));
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'error');
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final state = context.read<TrainingProgramProvider>();
      final plan = state.plans.firstWhere((p) => p.id == widget.entry.planId);
      final neighbors = await state.repository.entries(
        plan,
        DateTime(_second.year, _second.month, _second.day - 1),
        DateTime(_second.year, _second.month, _second.day + 2),
      );
      final warning = planPlacementWarning(
        plan,
        widget.entry,
        _second,
        neighbors,
      );
      if (warning != null && mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder:
              (c) => AlertDialog(
                title: Text(c.plan(warning)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(c.plan('cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(c.plan('save')),
                  ),
                ],
              ),
        );
        if (confirm != true) return;
      }
      await state.repository.splitStrength(widget.entry, _first, _second);
      await state.load();
      if (!mounted) return;
      await context.read<WorkoutProvider>().loadWorkouts();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = 'savingError');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots =
        _setup?.groups.expand((g) => g.selectedVariant.slots).toList() ??
        <WorkoutSetupSlot>[];
    final locale = Localizations.localeOf(context).toString();
    final available = _allowedDates;
    final exercises = context.watch<ExerciseProvider>().exercises;
    return Scaffold(
      appBar: AppBar(title: Text(context.plan('splitSession'))),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(20),
        child: FilledButton(
          onPressed:
              _busy ||
                      available.isEmpty ||
                      _first.isEmpty ||
                      _first.length >= slots.length
                  ? null
                  : _save,
          child: Text(context.plan('save')),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(context.plan('splitHint')),
          const SizedBox(height: 16),
          Text(
            '1 · ${DateFormat.yMMMEd(locale).format(widget.entry.date)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('2 · ${DateFormat.yMMMEd(locale).format(_second)}'),
            trailing: const Icon(Icons.event_outlined),
            onTap: () async {
              if (available.isEmpty) return;
              final date = await showDatePicker(
                context: context,
                initialDate: _second,
                firstDate: available.first,
                lastDate: available.last,
                selectableDayPredicate:
                    (d) => dateKey(d) != dateKey(widget.entry.date),
              );
              if (date != null && mounted) setState(() => _second = date);
            },
          ),
          for (final slot in slots)
            Builder(
              builder: (c) {
                final exercise =
                    exercises
                        .where((e) => e.id == slot.localExerciseId)
                        .firstOrNull;
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _first.contains(slot.id),
                  title: Text(
                    exercise == null ? '—' : displayExerciseName(c, exercise),
                  ),
                  subtitle: Text(
                    '${_first.contains(slot.id) ? 1 : 2} · ${slot.prescription?.label ?? ''}',
                  ),
                  onChanged:
                      (v) => setState(() {
                        v == true
                            ? _first.add(slot.id)
                            : _first.remove(slot.id);
                      }),
                );
              },
            ),
          if (_error != null) Text(context.plan(_error!)),
        ],
      ),
    );
  }
}
