import 'dart:convert';
import '../services/profile_readiness.dart';
import 'package:flutter/material.dart';
import 'training_plan_setup_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/cardio_l10n.dart';
import '../models/cardio.dart';
import '../providers/cardio_provider.dart';
import '../services/cardio_training.dart';
import 'cardio_editor_screen.dart';
import 'cardio_health_screen.dart';
import 'cardio_profile_screen.dart';
import 'cardio_session_screen.dart';

/// A local-only entry point; no sign-in, permissions or network are needed to browse.
class CardioScreen extends StatelessWidget {
  const CardioScreen({super.key});
  Future<void> _edit(
    BuildContext context,
    CardioWorkout workout, {
    ScheduledCardioWorkout? occurrence,
  }) async {
    final p = context.read<CardioProvider>();
    final edited = await Navigator.push<CardioWorkout>(
      context,
      MaterialPageRoute(
        builder:
            (_) => CardioEditorScreen(workout: workout, units: p.profile.units),
      ),
    );
    if (edited == null) return;
    try {
      if (occurrence == null) {
        await p.repository.saveWorkout(edited);
      } else {
        await p.repository.editOccurrence(occurrence, edited);
      }
      await p.load();
    } catch (_) {
      if (context.mounted) _error(context);
    }
  }

  void _error(BuildContext context) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.cardio('error'))));
  Future<void> _move(BuildContext context, ScheduledCardioWorkout o) async {
    final p = context.read<CardioProvider>();
    final date = await showDatePicker(
      context: context,
      initialDate: o.date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;
    final future = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(ctx.cardio('move')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.cardio('onlyThis')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.cardio('futureToo')),
              ),
            ],
          ),
    );
    if (future == null) return;
    try {
      await p.repository.move(o, date, future: future);
      await p.load();
    } catch (_) {
      if (context.mounted) _error(context);
    }
  }

  static Future<void> showAdaptation(
    BuildContext context,
    CardioProvider p,
  ) async {
    try {
      final proposal = await p.repository.adaptation(context.cardio);
      if (!context.mounted) return;
      var saving = false;
      final yes = await showDialog<Object>(
        context: context,
        barrierDismissible: false,
        builder:
            (ctx) => StatefulBuilder(
              builder:
                  (ctx, update) => PopScope(
                    canPop: !saving,
                    child: AlertDialog(
                      title: Text(ctx.forecast('review')),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ctx.running('reason'),
                              style: Theme.of(ctx).textTheme.titleMedium,
                            ),
                            Text(
                              proposal.reason == 'structure'
                                  ? ctx.forecast('structure')
                                  : ctx.running(proposal.reason),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              ctx.running('changes'),
                              style: Theme.of(ctx).textTheme.titleMedium,
                            ),
                            if (proposal.changes.isEmpty)
                              Text(ctx.forecast('noRecommendation')),
                            for (final o in p.occurrences.where(
                              (o) => proposal.changes.containsKey(o.id),
                            )) ...[
                              const SizedBox(height: 8),
                              ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text(
                                  DateFormat.yMMMd(
                                    Localizations.localeOf(ctx).toString(),
                                  ).format(o.date),
                                ),
                                subtitle: Text(proposal.changes[o.id]!.name),
                                children: [
                                  for (final pair in [
                                    ('before', o.workout),
                                    ('after', proposal.changes[o.id]!),
                                  ])
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${ctx.forecast(pair.$1)} · ${pair.$2.name}',
                                            style:
                                                Theme.of(
                                                  ctx,
                                                ).textTheme.titleSmall,
                                          ),
                                          for (final step in pair.$2.steps)
                                            Text(
                                              '${step.repeat > 1 ? '${step.repeat} × ' : ''}${step.goal == StepGoal.time ? CardioUnits.clock(step.amount) : CardioUnits.distance(step.amount, p.profile.units)} · ${CardioTraining.targetDescription(step, p.profile.units, ctx.cardio)}',
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              ctx.running('consideredRuns'),
                              style: Theme.of(ctx).textTheme.titleMedium,
                            ),
                            for (final row in p.history.where(
                              (r) => (proposal.reason == 'easyPaceEvidence'
                                      ? proposal.fitness.easySourceIds
                                      : proposal.reason == 'reduceLoad'
                                      ? proposal.fitness.concernSourceIds
                                      : proposal.fitness.sourceIds)
                                  .contains(r['id']),
                            ))
                              Text(
                                '${DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(row['started_at_utc'] as int))} · ${row['name_snapshot']}',
                              ),
                            Text(
                              '${ctx.running('ruleVersion')}: ${proposal.ruleVersion}',
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed:
                              saving ? null : () => Navigator.pop(ctx, false),
                          child: Text(ctx.cardio('cancel')),
                        ),
                        if (proposal.changes.isNotEmpty)
                          FilledButton(
                            onPressed:
                                saving
                                    ? null
                                    : () async {
                                      update(() => saving = true);
                                      try {
                                        await p.repository.acceptAdaptation(
                                          proposal,
                                        );
                                        await p.load();
                                        if (ctx.mounted) {
                                          Navigator.pop(ctx, true);
                                        }
                                      } catch (error) {
                                        if (ctx.mounted) {
                                          Navigator.pop(ctx, error);
                                        }
                                      }
                                    },
                            child:
                                saving
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Text(ctx.cardio('accept')),
                          ),
                      ],
                    ),
                  ),
            ),
      );
      if (yes != null && yes is! bool) throw yes;
      if (yes == true) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.forecast('applied'))));
        }
      }
    } on ProfileIncomplete {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.running('profileRequired'))),
      );
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CardioProfileScreen(provider: p)),
      );
    } catch (error) {
      await p.load();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().contains('stale_proposal')
                  ? context.forecast('stale')
                  : context.cardio('error'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CardioProvider>();
    final locale = Localizations.localeOf(context).toString();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.cardio('cardio')),
          actions: [
            IconButton(
              tooltip: context.cardio('health'),
              icon: const Icon(Icons.favorite_outline),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CardioHealthScreen(),
                    ),
                  ),
            ),
            IconButton(
              tooltip: context.cardio('profile'),
              icon: const Icon(Icons.tune),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CardioProfileScreen(provider: p),
                    ),
                  ),
            ),
          ],
          bottom: TabBar(
            tabs: [
              for (final key in ['library', 'plan', 'history'])
                Tab(text: context.cardio(key)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (p.active)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text(context.cardio('continueLabel')),
                      subtitle: Text(p.runtime?['name'] as String? ?? ''),
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CardioSessionScreen(),
                            ),
                          ),
                    ),
                  ),
                if (!p.loaded)
                  TextButton(
                    onPressed: p.load,
                    child: Text(context.cardio('retry')),
                  ),
                Text(
                  context.cardio('localOnly'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (ProfileReadiness.running(p.profile).isNotEmpty)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(context.cardio('profile')),
                      subtitle: Text(context.cardio('profileIntro')),
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CardioProfileScreen(provider: p),
                            ),
                          ),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(context.cardio('newWorkout')),
                  onPressed:
                      () => _edit(
                        context,
                        CardioTraining.template(
                          'easySession',
                          p.profile,
                          context.cardio,
                        ),
                      ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.directions_run_outlined),
                    title: Text(context.cardio('drills')),
                    trailing: const Icon(Icons.play_arrow),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => CardioRoutinePlayer(
                                  steps: CardioTraining.routine('drills'),
                                  cooling: false,
                                ),
                          ),
                        ),
                  ),
                ),
                for (final w in p.workouts)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.directions_run),
                      title: Text(w.name),
                      subtitle: Text(
                        '${context.cardio(w.sport.name)} · ${context.cardio(w.indoor ? 'indoor' : 'outdoor')}',
                      ),
                      onTap: () => _details(context, w),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') {
                            _edit(context, w);
                            return;
                          }
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder:
                                (ctx) => AlertDialog(
                                  title: Text(ctx.cardio('deleteConfirm')),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(ctx, false),
                                      child: Text(ctx.cardio('cancel')),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(ctx.cardio('delete')),
                                    ),
                                  ],
                                ),
                          );
                          if (confirmed == true) {
                            try {
                              await p.repository.deleteWorkout(w.id);
                              await p.load();
                            } catch (_) {
                              if (context.mounted) _error(context);
                            }
                          }
                        },
                        itemBuilder:
                            (_) => [
                              for (final k in ['edit', 'delete'])
                                PopupMenuItem(
                                  value: k,
                                  child: Text(context.cardio(k)),
                                ),
                            ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    context.cardio('templates'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                for (final code in CardioTraining.templateCodes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.cardio(code)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        () => _details(
                          context,
                          CardioTraining.template(
                            code,
                            p.profile,
                            context.cardio,
                          ),
                          template: true,
                        ),
                  ),
                for (final sport in CardioSport.values.where(
                  (s) => s != CardioSport.running,
                ))
                  ExpansionTile(
                    title: Text(context.cardio(sport.name)),
                    children: [
                      for (final code in ['easySession', 'intervalSession'])
                        ListTile(
                          title: Text(context.cardio(code)),
                          onTap:
                              () => _details(
                                context,
                                CardioTraining.template(
                                  code,
                                  p.profile,
                                  context.cardio,
                                  sport: sport,
                                  indoor:
                                      ![
                                        CardioSport.walking,
                                        CardioSport.cycling,
                                      ].contains(sport),
                                ),
                                template: true,
                              ),
                        ),
                    ],
                  ),
                ListTile(
                  title: Text(context.cardio('drills')),
                  leading: const Icon(Icons.accessibility_new),
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => CardioRoutinePlayer(
                                steps: CardioTraining.routine('drills'),
                                cooling: false,
                              ),
                        ),
                      ),
                ),
                for (final key in ['lower', 'upper'])
                  ListTile(
                    title: Text(
                      '${context.cardio('strength')} · ${context.cardio(key)}',
                    ),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => CardioRoutinePlayer(
                                  steps: CardioTraining.routine(key),
                                  cooling: false,
                                ),
                          ),
                        ),
                  ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                FilledButton.icon(
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CardioPlanScreen(),
                        ),
                      ),
                  icon: const Icon(Icons.calendar_month),
                  label: Text(context.cardio('newPlan')),
                ),
                if (p.occurrences.isNotEmpty)
                  TextButton(
                    onPressed: () => showAdaptation(context, p),
                    child: Text(context.cardio('adapt')),
                  ),
                for (final o in p.occurrences)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        o.status == 'completed'
                            ? Icons.check_circle_outline
                            : o.status == 'skipped'
                            ? Icons.skip_next
                            : Icons.directions_run,
                      ),
                      title: Text(o.workout.name),
                      subtitle: Text(
                        '${DateFormat.yMMMEd(locale).format(o.date)}${o.locked ? ' · ${context.cardio('locked')}' : ''}',
                      ),
                      onTap: () => _details(context, o.workout, occurrence: o),
                      trailing:
                          o.status == 'planned'
                              ? PopupMenuButton<String>(
                                onSelected: (k) async {
                                  if (k == 'move') {
                                    _move(context, o);
                                  } else if (k == 'edit') {
                                    _edit(context, o.workout, occurrence: o);
                                  } else {
                                    try {
                                      await p.repository.skipOccurrence(o.id);
                                      await p.load();
                                    } catch (_) {
                                      if (context.mounted) _error(context);
                                    }
                                  }
                                },
                                itemBuilder:
                                    (_) => [
                                      for (final key in [
                                        'move',
                                        'edit',
                                        'skip',
                                      ])
                                        PopupMenuItem(
                                          value: key,
                                          child: Text(context.cardio(key)),
                                        ),
                                    ],
                              )
                              : null,
                    ),
                  ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (p.history.isEmpty) Text(context.cardio('noData')),
                for (final r in p.history)
                  Card(
                    child: ListTile(
                      title: Text(
                        r['name_snapshot'] as String? ??
                            context.cardio('cardio'),
                      ),
                      subtitle: Text(
                        DateFormat.yMMMEd(locale).add_Hm().format(
                          DateTime.fromMillisecondsSinceEpoch(
                            r['started_at_utc'] as int,
                          ),
                        ),
                      ),
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => CardioSummaryScreen(
                                    runtime: cardioHistoryRuntime(r),
                                    snapshot:
                                        jsonDecode(r['snapshot_json'] as String)
                                            as Map<String, dynamic>,
                                  ),
                            ),
                          ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _details(
    BuildContext context,
    CardioWorkout workout, {
    bool template = false,
    ScheduledCardioWorkout? occurrence,
  }) async {
    final p = context.read<CardioProvider>();
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (ctx) => SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: .7,
              maxChildSize: .95,
              minChildSize: .3,
              builder:
                  (ctx, scroll) => ListView(
                    controller: scroll,
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        workout.name,
                        style: Theme.of(ctx).textTheme.headlineMedium,
                      ),
                      Text(
                        '${ctx.cardio(workout.sport.name)} · ${ctx.cardio(workout.indoor ? 'indoor' : 'outdoor')}',
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(ctx.cardio('warmup')),
                        subtitle: Text(
                          CardioUnits.clock(
                            workout.warmup.fold<int>(
                              0,
                              (int n, s) => n + s.seconds,
                            ),
                          ),
                        ),
                      ),
                      for (final s in workout.steps)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${s.repeat > 1 ? '${s.repeat} × ' : ''}${s.name.isEmpty ? ctx.cardio(s.intensity.name) : s.name}',
                          ),
                          subtitle: Text(
                            cardioStepDescription(s, p.profile.units, ctx),
                          ),
                        ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(ctx.cardio('cooldown')),
                        subtitle: Text(
                          CardioUnits.clock(
                            workout.cooldown.fold<int>(
                              0,
                              (int n, s) => n + s.seconds,
                            ),
                          ),
                        ),
                      ),
                      if (occurrence == null || occurrence.status == 'planned')
                        FilledButton.icon(
                          onPressed: () => Navigator.pop(ctx, 'start'),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(ctx.cardio('start')),
                        ),
                      if (occurrence == null || occurrence.status == 'planned')
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, 'edit'),
                          child: Text(ctx.cardio('edit')),
                        ),
                      if (template)
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, 'save'),
                          child: Text(ctx.cardio('save')),
                        ),
                    ],
                  ),
            ),
          ),
    );
    if (!context.mounted) return;
    if (action == 'start') {
      await startCardioWorkout(context, workout, occurrenceId: occurrence?.id);
    }
    if (action == 'edit') {
      if (!context.mounted) return;
      await _edit(context, workout, occurrence: occurrence);
    }
    if (action == 'save') {
      try {
        await p.repository.saveWorkout(workout);
        await p.load();
      } catch (_) {
        if (context.mounted) _error(context);
      }
    }
  }
}

class CardioPlanScreen extends StatelessWidget {
  const CardioPlanScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const TrainingPlanSetupScreen(initialSection: 'running');
}
