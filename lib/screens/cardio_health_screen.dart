import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/cardio_l10n.dart';
import '../l10n/l10n.dart';
import '../models/cardio.dart';
import '../providers/cardio_provider.dart';
import '../services/cardio_health_service.dart';
import '../widgets/running_recommendation_card.dart';

class CardioHealthScreen extends StatefulWidget {
  const CardioHealthScreen({super.key});
  @override
  State<CardioHealthScreen> createState() => _HealthState();
}

class _HealthState extends State<CardioHealthScreen> {
  List<Map<String, dynamic>> _pending = [];
  bool _busy = false;
  bool _includeRoute = false;
  String? _error;
  late final CardioHealthService _service;
  @override
  void initState() {
    super.initState();
    _service = CardioHealthService(context.read<CardioProvider>().repository);
    _load();
  }

  Future<void> _load() async {
    final pending = await _service.pending();
    if (mounted) setState(() => _pending = pending);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _load();
      if (mounted) await context.read<CardioProvider>().load();
    } catch (error) {
      final code = error.toString();
      if (mounted) {
        setState(
          () =>
              _error = context.l10n.healthStatus(
                code.contains('unavailable')
                    ? 'unavailable'
                    : code.contains('permission') || code.contains('denied')
                    ? 'denied'
                    : 'failed',
              ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(Map<String, dynamic> record) async {
    final p = context.read<CardioProvider>();
    final candidates =
        p.history.where((s) => CardioHealthService.matches(s, record)).toList();
    final date = DateTime.fromMillisecondsSinceEpoch(record['start'] as int);
    final scheduled =
        p.occurrences
            .where(
              (o) =>
                  o.status == 'planned' &&
                  o.date.year == date.year &&
                  o.date.month == date.month &&
                  o.date.day == date.day &&
                  o.workout.sport.name == record['sport'],
            )
            .toList();
    final selected = await showDialog<String>(
      context: context,
      builder:
          (ctx) => SimpleDialog(
            title: Text(ctx.cardio('importConfirm')),
            children: [
              for (final s in candidates)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, 'session:${s['id']}'),
                  child: Text('${ctx.cardio('link')}: ${s['name_snapshot']}'),
                ),
              for (final o in scheduled)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, 'plan:${o.id}'),
                  child: Text('${ctx.cardio('plan')}: ${o.workout.name}'),
                ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 'new'),
                child: Text(ctx.cardio('import')),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ctx.cardio('cancel')),
              ),
            ],
          ),
    );
    if (selected == null || !mounted) return;
    final name =
        '${context.cardio(record['sport'] as String)} · ${record['sourceName']}';
    await _run(
      () => _service.accept(
        record,
        name: name,
        includeRoute: _includeRoute,
        linkSessionId:
            selected.startsWith('session:') ? selected.substring(8) : null,
        occurrenceId:
            selected.startsWith('plan:') ? selected.substring(5) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CardioProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(context.cardio('health'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(context.cardio('healthInfo')),
          const RunningRecommendationCard(showFeedback: true),
          const SizedBox(height: 16),
          Text(context.cardio('privacyBody')),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.healthStatus('route')),
            value: _includeRoute,
            onChanged:
                _busy ? null : (value) => setState(() => _includeRoute = value),
          ),
          if (_service.accessState != null)
            Text(context.l10n.healthStatus(_service.accessState!.readState)),
          if (_service.syncState != 'idle')
            Text(context.l10n.healthStatus(_service.syncState)),
          if (_service.routeState != null && _service.routeState != 'available')
            Text(context.l10n.healthStatus('routeFailed')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed:
                _busy
                    ? null
                    : () => _run(() async {
                      await _service.connect();
                      await _service.refresh();
                    }),
            child: Text(context.cardio('healthPermission')),
          ),
          if (p.profile.healthEnabled) ...[
            TextButton(
              onPressed: _busy ? null : () => _run(_service.refresh),
              child: Text(context.cardio('refresh')),
            ),
            TextButton(
              onPressed:
                  _busy
                      ? null
                      : () => _run(() async {
                        await p.repository.saveProfile(
                          AthleteRunningProfile.fromJson({
                            ...p.profile.toJson(),
                            'healthEnabled': false,
                          }),
                        );
                      }),
              child: Text(context.cardio('disconnect')),
            ),
          ],
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          for (final r in _pending)
            Card(
              child: ListTile(
                title: Text(
                  '${context.cardio(r['sport'] as String)} · ${r['sourceName']}',
                ),
                subtitle: Text(
                  DateFormat.yMMMd(
                    Localizations.localeOf(context).toString(),
                  ).add_Hm().format(
                    DateTime.fromMillisecondsSinceEpoch(r['start'] as int),
                  ),
                ),
                onTap: _busy ? null : () => _accept(r),
                trailing: IconButton(
                  tooltip: context.cardio('dismiss'),
                  icon: const Icon(Icons.close),
                  onPressed:
                      _busy ? null : () => _run(() => _service.dismiss(r)),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            context.cardio('export'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final s in p.history.where((s) => s['source'] == 'manual'))
            ListTile(
              title: Text(s['name_snapshot'] as String),
              subtitle: Text(
                DateFormat.yMMMd(
                  Localizations.localeOf(context).toString(),
                ).format(
                  DateTime.fromMillisecondsSinceEpoch(
                    s['started_at_utc'] as int,
                  ),
                ),
              ),
              trailing:
                  (jsonDecode(s['snapshot_json'] as String)
                                  as Map)['healthExport'] ==
                              'done' &&
                          (!_includeRoute ||
                              (jsonDecode(s['snapshot_json'] as String)
                                      as Map)['healthRouteExport'] ==
                                  'done')
                      ? const Icon(Icons.check)
                      : IconButton(
                        tooltip: context.cardio('export'),
                        icon: const Icon(Icons.upload_outlined),
                        onPressed:
                            _busy
                                ? null
                                : () => _run(
                                  () => _service.export(
                                    s,
                                    includeRoute: _includeRoute,
                                  ),
                                ),
                      ),
            ),
        ],
      ),
    );
  }
}
