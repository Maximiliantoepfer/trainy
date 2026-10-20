import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/training_program.dart';
import '../l10n/plan_l10n.dart';
import '../providers/cardio_provider.dart';
import '../providers/training_profile_provider.dart';
import '../providers/training_program_provider.dart';
import '../widgets/training_profile_settings_card.dart';
import '../widgets/plan_controls.dart';
import 'cardio_profile_screen.dart';
import 'cardio_health_screen.dart';
import 'strength_profile_screen.dart';

class UserTrainingProfileScreen extends StatefulWidget {
  const UserTrainingProfileScreen({
    super.key,
    this.strengthOnly = false,
    this.setup = false,
  });
  final bool strengthOnly;
  final bool setup;
  @override
  State<UserTrainingProfileScreen> createState() =>
      _UserTrainingProfileScreenState();
}

class _UserTrainingProfileScreenState extends State<UserTrainingProfileScreen> {
  UserTrainingProfile? _profile;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p =
          await context
              .read<TrainingProgramProvider>()
              .repository
              .userProfile();
      if (mounted) setState(() => _profile = p);
    } catch (_) {
      if (mounted) setState(() => _error = 'error');
    }
  }

  Future<void> _update(Map<String, dynamic> changes) async {
    setState(() => _busy = true);
    try {
      final repo = context.read<TrainingProgramProvider>().repository;
      final latest = await repo.userProfile();
      final p = UserTrainingProfile.fromJson({
        ...latest.toJson(),
        ...changes,
      });
      await repo.saveUserProfile(p);
      if (!mounted) return;
      await context.read<CardioProvider>().load();
      if (mounted) {
        setState(() {
          _profile = p;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'savingError');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.strengthOnly) return const StrengthProfileScreen();
    final p = _profile;
    return Scaffold(
      bottomNavigationBar:
          widget.setup
              ? SafeArea(
                minimum: const EdgeInsets.all(20),
                child: FilledButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: Text(context.plan('next')),
                ),
              )
              : null,
      appBar: AppBar(
        title: Text(
          context.plan(widget.strengthOnly ? 'strengthProfile' : 'profile'),
        ),
      ),
      body:
          p == null
              ? Center(
                child: TextButton(
                  onPressed: _load,
                  child: Text(context.plan('retry')),
                ),
              )
              : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (!widget.strengthOnly) ...[
                    Text(
                      context.plan('interests'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in ['strength', 'running', 'mobility'])
                          FilterChip(
                            label: Text(context.plan(s)),
                            selected:
                                p.interests.contains(s) ||
                                (s == 'running' &&
                                    p.interests.contains('cardio')),
                            onSelected:
                                _busy
                                    ? null
                                    : (v) {
                                      final values =
                                          p.interests
                                              .map(
                                                (s) =>
                                                    s == 'cardio'
                                                        ? 'running'
                                                        : s,
                                              )
                                              .toSet();
                                      v ? values.add(s) : values.remove(s);
                                      _update({'interests': values.toList()});
                                    },
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: ListTile(
                        title: Text(context.plan('units')),
                        subtitle: Text(context.plan(p.units.name)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap:
                            _busy
                                ? null
                                : () async {
                                  final v = await choosePlanValue(
                                    context,
                                    'units',
                                    ['metric', 'imperial'],
                                    p.units.name,
                                  );
                                  if (v != null && mounted) {
                                    await _update({'units': v});
                                  }
                                },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.directions_run),
                            title: Text(context.plan('runningProfile')),
                            trailing: const Icon(Icons.chevron_right),
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => CardioProfileScreen(
                                          provider:
                                              context.read<CardioProvider>(),
                                        ),
                                  ),
                                ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.fitness_center),
                            title: Text(context.plan('strengthProfile')),
                            trailing: const Icon(Icons.chevron_right),
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => const UserTrainingProfileScreen(
                                          strengthOnly: true,
                                        ),
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Card(
                      child: ListTile(
                        title: Text(context.plan('level')),
                        subtitle: Text(context.plan(p.strengthLevel)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap:
                            _busy
                                ? null
                                : () async {
                                  final v =
                                      await choosePlanValue(context, 'level', [
                                        'starting',
                                        'beginner',
                                        'intermediate',
                                        'experienced',
                                      ], p.strengthLevel);
                                  if (v != null && mounted) {
                                    await _update({'strengthLevel': v});
                                  }
                                },
                      ),
                    ),
                    const SizedBox(height: 24),
                    TrainingProfileSettingsCard(
                      store: context.read<TrainingProfileProvider>(),
                    ),
                  ],
                  if (_error != null) PlanError(_error!),
                ],
              ),
    );
  }
}

class TrainingConnectionsCard extends StatefulWidget {
  const TrainingConnectionsCard({super.key});
  @override
  State<TrainingConnectionsCard> createState() =>
      _TrainingConnectionsCardState();
}

class _TrainingConnectionsCardState extends State<TrainingConnectionsCard> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final p = context.watch<CardioProvider>();
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: Text(context.plan('health')),
            subtitle: Text(
              context.plan(
                p.profile.healthEnabled ? 'connected' : 'healthHint',
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CardioHealthScreen()),
                ),
          ),
          SwitchListTile(
            title: Text(context.plan('sensorBackup')),
            subtitle: Text(context.plan('sensorHint')),
            value: p.profile.backupSensorData,
            onChanged:
                _busy
                    ? null
                    : (v) async {
                      setState(() => _busy = true);
                      try {
                        final repo =
                            context.read<TrainingProgramProvider>().repository;
                        final current = await repo.userProfile();
                        await repo.saveUserProfile(
                          UserTrainingProfile.fromJson({
                            ...current.toJson(),
                            'backupSensorData': v,
                          }),
                        );
                        await p.load();
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.plan('savingError')),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
          ),
        ],
      ),
    );
  }
}
