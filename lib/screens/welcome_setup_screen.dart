import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/l10n.dart';
import '../l10n/plan_l10n.dart';
import '../providers/cloud_sync_provider.dart';
import '../providers/cardio_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/training_profile_provider.dart';
import '../providers/training_program_provider.dart';
import '../widgets/health_connection_status.dart';
import '../services/settings_database.dart';
import '../widgets/appearance_picker.dart';
import '../widgets/language_preference_picker.dart';
import '../widgets/plan_controls.dart';
import 'training_plan_screen.dart';
import 'training_plan_setup_screen.dart';

class WelcomeSetupScreen extends StatefulWidget {
  const WelcomeSetupScreen({super.key, this.completeSetup});
  final Future<void> Function()? completeSetup;
  @override
  State<WelcomeSetupScreen> createState() => _WelcomeSetupScreenState();
}

class _WelcomeSetupScreenState extends State<WelcomeSetupScreen> {
  static const _stages = ['language', 'look', 'backup', 'interests', 'health'];
  int _step = 0;
  bool _busy = false, _restoring = false, _ready = false;
  String? _error;
  Future<void> _writes = Future.value();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final state = context.read<TrainingProgramProvider>();
      await state.load();
      final draft = await state.repository.draft('onboarding');
      if (mounted) {
        setState(() {
          // Old drafts used indices before language became the first stage.
          // Stable names keep resumes at the same decision after future inserts.
          final stage = _stages.indexOf(draft?['stage'] as String? ?? '');
          final legacyStep = draft?['step'];
          _step =
              stage >= 0
                  ? stage
                  : legacyStep is int
                  ? legacyStep.clamp(0, 3) + 1
                  : 0;
          _ready = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'error');
    }
  }

  void _go(int step) {
    setState(() {
      _step = step;
      _error = null;
    });
    final repo = context.read<TrainingProgramProvider>().repository;
    _writes = _writes
        .then((_) => repo.saveDraft('onboarding', {'stage': _stages[step]}))
        .catchError((Object e) {
          if (mounted) setState(() => _error = 'savingError');
        });
  }

  void _language(AppLanguagePreference value) {
    final save = context.read<LocaleProvider>().setPreference(value);
    _writes = Future.wait([_writes, save]).then<void>((_) {}).catchError((
      Object e,
    ) {
      if (mounted) setState(() => _error = 'savingError');
    });
  }

  Future<void> _finish() async {
    if (_restoring) return;
    try {
      final repo = context.read<TrainingProgramProvider>().repository;
      await _writes;
      await (widget.completeSetup?.call() ??
          SettingsDatabase.instance.setOnboardingDone(true));
      await repo.clearDraft('onboarding');
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'savingError');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.plan('savingError'))));
      }
    }
  }

  Future<void> _backup() async {
    setState(() => _busy = true);
    final cloud = context.read<CloudSyncProvider>();
    try {
      await cloud.signInWithGoogle();
      if (!mounted || !cloud.isSignedIn || _step != 2) return;
      final exists = await cloud.remoteBackupExists();
      if (!mounted || _step != 2) return;
      if (exists) {
        final restore = await showDialog<bool>(
          context: context,
          builder:
              (c) => AlertDialog(
                title: Text(c.plan('backupFound')),
                content: Text(c.plan('restoreHint')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(c.plan('keepLocal')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(c.plan('restore')),
                  ),
                ],
              ),
        );
        if (restore == true && mounted) {
          setState(() => _restoring = true);
          await cloud.restoreNow();
          if (!mounted) return;
          await context.read<TrainingProfileProvider>().reload();
          if (!mounted) return;
          await context.read<WorkoutProvider>().loadWorkouts();
          if (!mounted) return;
          await context.read<ExerciseProvider>().loadExercises();
          if (!mounted) return;
          await context.read<ProgressProvider>().loadData();
          if (!mounted) return;
          await context.read<CardioProvider>().load();
          if (!mounted) return;
          await context.read<TrainingProgramProvider>().load();
        }
      }
      if (mounted && _step == 2) _go(3);
    } catch (_) {
      if (mounted) setState(() => _error = 'error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _restoring = false;
        });
      }
    }
  }

  Future<void> _health() async {
    setState(() => _busy = true);
    try {
      final p = context.read<CardioProvider>();
      await p.health.connect();
      await p.load();
      await p.syncHealth(allowRoutePrompt: true);
    } catch (_) {
      if (mounted) setState(() => _error = 'error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainingProgramProvider>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_restoring) {
          if (_step > 0) {
            _go(_step - 1);
          } else {
            _finish();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading:
              _step == 0
                  ? null
                  : IconButton(
                    tooltip: context.plan('back'),
                    onPressed: _restoring ? null : () => _go(_step - 1),
                    icon: const Icon(Icons.arrow_back),
                  ),
          title: const Text('Trainy'),
          actions: [
            TextButton(
              onPressed: _restoring ? null : _finish,
              child: Text(context.plan('later')),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(20),
          child: FilledButton(
            onPressed:
                !_ready || _restoring
                    ? null
                    : () =>
                        _step == _stages.length - 1
                            ? _finish()
                            : _go(_step + 1),
            child: Text(
              context.plan(_step == _stages.length - 1 ? 'done' : 'next'),
            ),
          ),
        ),
        body:
            !_ready
                ? Center(
                  child: TextButton(
                    onPressed: _load,
                    child: Text(context.plan('retry')),
                  ),
                )
                : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    LinearProgressIndicator(
                      value: (_step + 1) / _stages.length,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _step == 0
                          ? context.l10n.language
                          : context.plan(_stages[_step]),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    if (_step == 0)
                      LanguagePreferencePicker(
                        showAllOptions: true,
                        preference: context.watch<LocaleProvider>().preference,
                        onChanged: _language,
                      ),
                    if (_step == 1) ...[
                      Text(context.plan('lookHint')),
                      const SizedBox(height: 24),
                      const AppearancePicker(),
                    ],
                    if (_step == 2) ...[
                      Text(context.plan('backupHint')),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _backup,
                        icon: const Icon(Icons.cloud_outlined),
                        label: Text(context.l10n.signInWithGoogle),
                      ),
                    ],
                    if (_step == 3) ...[
                      Text(context.plan('planHint')),
                      const SizedBox(height: 24),
                      if (state.active != null ||
                          state.plans.any((p) => p.status == 'active'))
                        const TrainingPlanCard()
                      else
                        OutlinedButton.icon(
                          onPressed: () async {
                            final saved = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TrainingPlanSetupScreen(),
                              ),
                            );
                            await state.load();
                            if (saved == true && mounted) _go(4);
                          },
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text(
                            context.plan(
                              state.pendingDraft == null
                                  ? 'createPlan'
                                  : 'resumePlan',
                            ),
                          ),
                        ),
                    ],
                    if (_step == 4) ...[
                      Text(context.plan('healthHint')),
                      const SizedBox(height: 8),
                      const HealthConnectionStatus(),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _health,
                        icon: const Icon(Icons.favorite_outline),
                        label: Text(
                          context.plan(
                            context
                                    .watch<CardioProvider>()
                                    .profile
                                    .healthEnabled
                                ? 'connected'
                                : 'connect',
                          ),
                        ),
                      ),
                    ],
                    if (_error != null) PlanError(_error!),
                  ],
                ),
      ),
    );
  }
}
