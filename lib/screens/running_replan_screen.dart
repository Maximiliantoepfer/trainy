import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/training_program.dart';
import '../providers/cardio_provider.dart';
import '../providers/training_program_provider.dart';
import '../l10n/cardio_l10n.dart';
import '../l10n/planning_l10n.dart';
import '../l10n/plan_l10n.dart';
import '../models/cardio.dart';
import 'package:intl/intl.dart';
import '../services/profile_readiness.dart';
import '../services/running_replan.dart';
import '../widgets/plan_week_block.dart';
import 'cardio_profile_screen.dart';
import 'training_plan_screen.dart';

class RunningReplanScreen extends StatefulWidget {
  const RunningReplanScreen({super.key, required this.plan});
  final TrainingProgram plan;
  @override
  State<RunningReplanScreen> createState() => _ReplanState();
}

class _ReplanState extends State<RunningReplanScreen> {
  late TrainingProgram _plan = widget.plan;
  RunningReplanPreview? _preview;
  bool _busy = false, _after = true;
  String? _error;
  Future<void> _calculate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final p = context.read<CardioProvider>();
    try {
      final missing = ProfileReadiness.running(p.profile);
      if (missing.isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => CardioProfileScreen(provider: p, offerReplan: false),
          ),
        );
        if (!mounted || ProfileReadiness.running(p.profile).isNotEmpty) return;
      }
      final preview = await RunningReplan(
        p.repository,
      ).preview(_plan, context.cardio);
      if (mounted) setState(() => _preview = preview);
    } catch (_) {
      if (mounted) setState(() => _error = 'planChanged');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final p = context.read<CardioProvider>();
    try {
      await RunningReplan(p.repository).apply(_preview!);
      await p.load();
      if (!mounted) return;
      await context.read<TrainingProgramProvider>().load();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _preview = null;
          _error = 'planChanged';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CardioProvider>();
    final rows =
        _preview == null
            ? <ProgramEntry>[]
            : (_after ? _preview!.after : _preview!.before)
                .map(
                  (o) => ProgramEntry(
                    id: o.id,
                    planId: o.planId,
                    date: o.date,
                    name: o.workout.name,
                    kind: 'running',
                    cardio: o,
                    completed: o.status == 'completed',
                    sessionId: o.sessionId,
                  ),
                )
                .toList();
    final weeks =
        rows
            .map(
              (o) => DateTime(
                o.date.year,
                o.date.month,
                o.date.day - o.date.weekday + 1,
              ),
            )
            .toSet()
            .toList()
          ..sort();
    final values = <String, String>{
      'goal': context.running(p.profile.planning.goal ?? 'runFaster'),
      'complaints': context.running(p.profile.planning.complaints ?? 'none'),
      'experience':
          '${p.profile.experienceMonths} ${context.planning('months')}',
      'frequency':
          p.profile.recentRunsPerWeek?.toString() ??
          context.recording('unknown'),
      'availableDays': p.profile.weekdays
          .map(
            (d) => DateFormat.E(
              Localizations.localeOf(context).toString(),
            ).format(DateTime(2026, 10, 18 + d)),
          )
          .join(', '),
      'customDayBudgets':
          p.profile.planning.dayMinutes.isEmpty
              ? context.recording('sameBudgets')
              : p.profile.planning.dayMinutes.entries
                  .map(
                    (e) =>
                        '${DateFormat.E(Localizations.localeOf(context).toString()).format(DateTime(2026, 10, 18 + e.key))}: ${e.value} min',
                  )
                  .join(' · '),
      'hardTrainingDays':
          p.profile.planning.hardTrainingDays.isEmpty
              ? context.running('none')
              : p.profile.planning.hardTrainingDays
                  .map(
                    (d) => DateFormat.E(
                      Localizations.localeOf(context).toString(),
                    ).format(DateTime(2026, 10, 18 + d)),
                  )
                  .join(', '),
      'reference':
          p.profile.referenceSeconds == null
              ? context.recording('unknown')
              : '${CardioUnits.distance(p.profile.referenceMeters, p.profile.units)} · ${CardioUnits.clock(p.profile.referenceSeconds!)}',
      'restPulse':
          p.profile.restingHeartRate == null
              ? '—'
              : '${p.profile.restingHeartRate} bpm',
      'maxPulse':
          p.profile.maximumHeartRate == null
              ? '—'
              : '${p.profile.maximumHeartRate} bpm',
      'zoneMethod': context.running(p.profile.planning.zoneMethod),
      'level':
          p.profile.returningAfterBreak
              ? context.recording('returning')
              : context.planning(p.profile.level?.name ?? 'starting'),
      'continuous': '${p.profile.continuousMinutes} min',
      'volume':
          p.profile.planning.weeklyMinutes == null
              ? p.profile.weeklyMeters > 0
                  ? CardioUnits.distance(
                    p.profile.weeklyMeters,
                    p.profile.units,
                  )
                  : context.recording('unknown')
              : '${p.profile.planning.weeklyMinutes} min',
      'longest':
          p.profile.planning.longestMinutes == null
              ? p.profile.longestMeters > 0
                  ? CardioUnits.distance(
                    p.profile.longestMeters,
                    p.profile.units,
                  )
                  : context.recording('unknown')
              : '${p.profile.planning.longestMinutes} min',
      'desiredDays':
          '${p.profile.planning.desiredDays ?? p.profile.weekdays.length}',
      'minutesPerSession': '${p.profile.planning.minutesPerSession ?? 45} min',
      'routes': '${p.profile.planning.favoriteRoutes.length}',
    };
    return Scaffold(
      appBar: AppBar(title: Text(context.recording('replan'))),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed:
              _busy
                  ? null
                  : _preview == null
                  ? _calculate
                  : _apply,
          child: Text(
            context.recording(_preview == null ? 'recalculate' : 'applyPlan'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(context.recording('futureOnly')),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                context.recording(_error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_preview == null) ...[
            Text(
              context.recording('reviewInputs'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<double>(
              value: _plan.targetMeters,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.plan('targetDistance'),
              ),
              items: [
                for (final d in [5000.0, 10000.0, 21097.5, 42195.0])
                  DropdownMenuItem(
                    value: d,
                    child: Text(CardioUnits.distance(d, p.profile.units)),
                  ),
              ],
              onChanged:
                  _busy
                      ? null
                      : (d) {
                        if (d != null) {
                          setState(
                            () =>
                                _plan = _plan.copyWith(
                                  targetMeters: d,
                                  clearTargetTime: true,
                                ),
                          );
                        }
                      },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.plan('targetDate')),
              subtitle: Text(
                _plan.targetDate == null
                    ? '—'
                    : DateFormat.yMMMd(
                      Localizations.localeOf(context).toString(),
                    ).format(_plan.targetDate!),
              ),
              trailing:
                  _plan.targetDate == null
                      ? const Icon(Icons.calendar_today_outlined)
                      : IconButton(
                        tooltip: context.plan('delete'),
                        onPressed:
                            _busy
                                ? null
                                : () => setState(
                                  () =>
                                      _plan = _plan.copyWith(
                                        clearTargetDate: true,
                                      ),
                                ),
                        icon: const Icon(Icons.clear),
                      ),
              onTap:
                  _busy
                      ? null
                      : () async {
                        final now = DateTime.now();
                        final selected = await showDatePicker(
                          context: context,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 728)),
                          initialDate:
                              _plan.targetDate != null &&
                                      _plan.targetDate!.isAfter(now)
                                  ? _plan.targetDate
                                  : now,
                        );
                        if (selected != null && mounted) {
                          setState(
                            () => _plan = _plan.copyWith(targetDate: selected),
                          );
                        }
                      },
            ),
            for (final key in [
              'goal',
              'complaints',
              'level',
              if (p.profile.level != RunningLevel.starting ||
                  p.profile.returningAfterBreak)
                'experience',
              'continuous',
              'frequency',
              'volume',
              'longest',
              'desiredDays',
              'availableDays',
              'minutesPerSession',
              'customDayBudgets',
              'hardTrainingDays',
              'reference',
              'restPulse',
              'maxPulse',
              'zoneMethod',
              'routes',
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.planning('input$key')),
                subtitle: values[key] == null ? null : Text(values[key]!),
                trailing: const Icon(Icons.chevron_right),
                onTap:
                    _busy
                        ? null
                        : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => CardioProfileScreen(
                                    provider: p,
                                    initialQuestion: key,
                                    offerReplan: false,
                                  ),
                            ),
                          );
                          if (mounted) setState(() => _preview = null);
                        },
              ),
          ] else ...[
            for (final warning in _preview!.warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(context.cardio(warning)),
              ),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(context.recording('before')),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(context.recording('after')),
                ),
              ],
              selected: {_after},
              onSelectionChanged: (s) => setState(() => _after = s.single),
            ),
            const SizedBox(height: 16),
            for (final week in weeks)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PlanWeekBlock(
                  monday: week,
                  entries: rows,
                  entryBuilder:
                      (e) => PlanWorkoutTile(
                        entry: e,
                        units: p.profile.units,
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => PlannedCardioScreen(
                                      entry: e,
                                      preview: true,
                                    ),
                              ),
                            ),
                      ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
