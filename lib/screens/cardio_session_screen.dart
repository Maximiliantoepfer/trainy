import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/cardio_route_view.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../l10n/cardio_l10n.dart';
import '../models/cardio.dart';
import '../providers/cardio_provider.dart';
import 'cardio_editor_screen.dart';

Future<void> startCardioWorkout(
  BuildContext context,
  CardioWorkout original, {
  String? occurrenceId,
}) async {
  final provider = context.read<CardioProvider>();
  var workout = original;
  try {
    if (provider.active) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CardioSessionScreen()));
      return;
    }
    if (workout.indoor &&
        workout.steps.any((s) => s.goal == StepGoal.distance)) {
      final convert = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(ctx.cardio('indoor')),
              content: Text(ctx.cardio('indoorInfo')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(ctx.cardio('cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(ctx.cardio('convert')),
                ),
              ],
            ),
      );
      if (convert != true || !context.mounted) return;
      workout = workout.timeReplacement();
    }
    if (workout.indoor && provider.capabilities['indoorBackground'] != true) {
      final proceed = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(ctx.cardio('indoor')),
              content: Text(ctx.cardio('backgroundLimited')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(ctx.cardio('cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(ctx.cardio('continueLabel')),
                ),
              ],
            ),
      );
      if (proceed != true || !context.mounted) return;
    }
    final permission = await provider.prepare(
      workout,
      Localizations.localeOf(context).toLanguageTag(),
    );
    if (!context.mounted) return;
    if (permission == 'ready_silent') {
      final proceed = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(ctx.cardio('audioUnavailable')),
              content: Text(ctx.cardio('audioSetup')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(ctx.cardio('cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(ctx.cardio('continueLabel')),
                ),
              ],
            ),
      );
      if (proceed != true || !context.mounted) return;
    } else if (permission != 'ready') {
      await showDialog<void>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(ctx.cardio('locationDenied')),
              content: Text(
                Localizations.localeOf(ctx).languageCode == 'de'
                    ? (permission == 'location_disabled'
                        ? 'Aktiviere den Standortdienst, um draußen eine Route aufzuzeichnen.'
                        : permission == 'approximate'
                        ? 'Für Tempo und Strecke benötigt Trainy den genauen Standort. Aktiviere „Genauer Standort“ in den App-Berechtigungen.'
                        : 'Erlaube den Standortzugriff für das Training. Indoor-Training bleibt ohne GPS möglich.')
                    : (permission == 'location_disabled'
                        ? 'Enable location services to record an outdoor route.'
                        : permission == 'approximate'
                        ? 'Speed and distance require precise location. Enable it in the app permissions.'
                        : 'Allow location access for this workout. Indoor training remains available without GPS.'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(ctx.cardio('cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    provider.api.openSettings();
                    Navigator.pop(ctx);
                  },
                  child: Text(ctx.cardio('openSettings')),
                ),
              ],
            ),
      );
      return;
    }
    if (workout.warmup.isNotEmpty) {
      final ready = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder:
              (_) => CardioRoutinePlayer(steps: workout.warmup, cooling: false),
        ),
      );
      if (ready != true || !context.mounted) return;
    }
    final t = context.cardio;
    final locale = Localizations.localeOf(context).toLanguageTag();
    await provider.start(workout, t, locale, occurrenceId: occurrenceId);
    if (context.mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CardioSessionScreen()));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.cardio('startError'))));
    }
  }
}

/// Routines intentionally have no repository: they are guided preparation, not tracked efforts.
class CardioRoutinePlayer extends StatefulWidget {
  const CardioRoutinePlayer({
    super.key,
    required this.steps,
    required this.cooling,
  });
  final List<RoutineStep> steps;
  final bool cooling;
  @override
  State<CardioRoutinePlayer> createState() => _RoutinePlayerState();
}

class _RoutinePlayerState extends State<CardioRoutinePlayer>
    with WidgetsBindingObserver {
  int _index = 0;
  double _seconds = 0;
  bool _playing = false;
  final _watch = Stopwatch();
  Timer? _timer;
  VideoPlayerController? _video;
  int _videoGeneration = 0;
  RoutineStep get _step => widget.steps[_index];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.steps.isNotEmpty) _loadVideo();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!_playing || !mounted) return;
      setState(() => _seconds = _watch.elapsedMilliseconds / 1000);
      if (_seconds >= _step.seconds) _next();
    });
  }

  Future<void> _loadVideo() async {
    final generation = ++_videoGeneration;
    final old = _video;
    _video = null;
    await old?.dispose();
    final asset = 'assets/cardio/videos/${_step.exercise}.mp4';
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      if (!manifest.listAssets().contains(asset)) return;
      final video = VideoPlayerController.asset(asset);
      await video.initialize();
      await video.setLooping(true);
      if (!mounted || generation != _videoGeneration) {
        await video.dispose();
        return;
      }
      setState(() => _video = video);
      if (_playing) await video.play();
    } catch (_) {
      /* Optional media must never block an offline routine. */
    }
  }

  void _toggle() => setState(() {
    _playing = !_playing;
    if (_playing) {
      _watch.start();
      _video?.play();
    } else {
      _watch.stop();
      _video?.pause();
    }
  });
  void _next() {
    if (_index + 1 >= widget.steps.length) {
      _watch.stop();
      _playing = false;
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _index++;
      _seconds = 0;
      _watch.reset();
    });
    _loadVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _playing) _toggle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _watch.stop();
    _videoGeneration++;
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.cardio(widget.cooling ? 'cooldown' : 'warmup')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.cardio('skip')),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '${_index + 1} / ${widget.steps.length}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            Text(
              _step.customName.isNotEmpty
                  ? _step.customName
                  : context.cardio(_step.exercise),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            if (_video != null)
              AspectRatio(
                aspectRatio: _video!.value.aspectRatio,
                child: VideoPlayer(_video!),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.accessibility_new, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        _step.exercise == 'custom'
                            ? _step.instructions
                            : context.cardio('${_step.exercise}Instruction'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.cardio('mediaPending'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              CardioUnits.clock(math.max(0, _step.seconds - _seconds)),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (_seconds / _step.seconds).clamp(0, 1),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _toggle,
              icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
              label: Text(context.cardio(_playing ? 'pause' : 'start')),
            ),
            TextButton(onPressed: _next, child: Text(context.cardio('next'))),
            Text(context.cardio('routineInfo')),
          ],
        ),
      ),
    );
  }
}

class CardioSessionScreen extends StatefulWidget {
  const CardioSessionScreen({super.key});
  @override
  State<CardioSessionScreen> createState() => _SessionState();
}

class _SessionState extends State<CardioSessionScreen> {
  Timer? _hold;
  bool _holding = false, _busy = false;
  Future<void> _finish() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _holding = false;
    });
    try {
      await context.read<CardioProvider>().finish();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.cardio('error'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accessibleFinish() async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(ctx.cardio('confirmFinish')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.cardio('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.cardio('finish')),
              ),
            ],
          ),
    );
    if (yes == true) await _finish();
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CardioProvider>();
    final r = provider.runtime;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.cardio('noData'))),
      );
    }
    if (r['status'] == 'completed') return CardioSummaryScreen(runtime: r);
    final steps =
        (r['steps'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
    final i = (r['index'] as num?)?.toInt() ?? 0;
    final step = CardioStep.fromJson(steps[i]);
    final progress =
        (r[step.goal == StepGoal.distance ? 'stepMeters' : 'stepSeconds']
                as num?)
            ?.toDouble() ??
        0;
    final remaining = math.max(0.0, step.amount - progress);
    final paused = r['status'] == 'paused';
    final units = provider.profile.units;
    return Scaffold(
      appBar: AppBar(
        title: Text(r['name'] as String? ?? context.cardio('cardio')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(context.cardio(paused ? 'paused' : 'active'))),
                if (r['indoor'] != true)
                  Chip(
                    avatar: const Icon(Icons.gps_fixed, size: 18),
                    label: Text(
                      context.cardio(r['gps'] as String? ?? 'gpsWaiting'),
                    ),
                  ),
                if (r['recovered'] == true)
                  Chip(label: Text(context.cardio('recovered'))),
              ],
            ),
            if (r['audioUnavailable'] == true)
              Text(
                context.cardio('audioUnavailable'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (r['storageError'] == true || provider.error != null)
              Text(
                context.cardio('storageError'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 24),
            Text(
              '${i + 1} / ${steps.length}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              steps[i]['displayName'] as String? ??
                  context.cardio(step.intensity.name),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            Text(context.cardio('remaining')),
            Text(
              step.goal == StepGoal.time
                  ? CardioUnits.clock(remaining)
                  : CardioUnits.distance(remaining, units),
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (progress / step.amount).clamp(0, 1),
            ),
            const SizedBox(height: 24),
            if ((r['countdown'] as num? ?? 0) > 0)
              Text(
                '${(r['countdown'] as num).ceil()}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge,
              ),
            Text(
              '${context.cardio('target')}: ${cardioStepDescription(step, units, context)}',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                _Metric(
                  context.cardio('activeTime'),
                  CardioUnits.clock(r['activeSeconds'] as num? ?? 0),
                ),
                if (r['indoor'] != true)
                  _Metric(
                    context.cardio('distance'),
                    CardioUnits.distance(
                      (r['distanceMeters'] as num? ?? 0).toDouble(),
                      units,
                    ),
                  ),
                _Metric(
                  context.cardio(r['sport'] == 'cycling' ? 'speed' : 'pace'),
                  r['sport'] == 'cycling'
                      ? CardioUnits.speed(
                        (r['speed'] as num?)?.toDouble(),
                        units,
                      )
                      : CardioUnits.pace(
                        (r['speed'] as num?)?.toDouble(),
                        units,
                      ),
                ),
              ],
            ),
            if (i + 1 < steps.length)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '${context.cardio('next')}: ${steps[i + 1]['startCue']}',
                ),
              ),
            OutlinedButton.icon(
              onPressed:
                  _busy
                      ? null
                      : () async {
                        try {
                          if (paused) {
                            await provider.resume();
                          } else {
                            await provider.pause();
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.cardio('error'))),
                            );
                          }
                        }
                      },
              icon: Icon(paused ? Icons.play_arrow : Icons.pause),
              label: Text(context.cardio(paused ? 'resume' : 'pause')),
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: context.cardio('finishAccessible'),
              onTap: _accessibleFinish,
              child: ExcludeSemantics(
                child: GestureDetector(
                  onLongPressStart: (_) {
                    setState(() => _holding = true);
                    _hold = Timer(const Duration(seconds: 2), _finish);
                  },
                  onLongPressEnd: (_) {
                    _hold?.cancel();
                    if (mounted) setState(() => _holding = false);
                  },
                  onLongPressCancel: () {
                    _hold?.cancel();
                    if (mounted) setState(() => _holding = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Theme.of(context).colorScheme.errorContainer,
                    ),
                    child: Column(
                      children: [
                        Text(
                          context.cardio('holdFinish'),
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                        if (_holding)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: _accessibleFinish,
              child: Text(context.cardio('finishAccessible')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Text(value, style: Theme.of(context).textTheme.headlineSmall),
    ],
  );
}

class CardioSummaryScreen extends StatefulWidget {
  const CardioSummaryScreen({super.key, required this.runtime, this.snapshot});
  final Map<String, dynamic> runtime;
  final Map<String, dynamic>? snapshot;
  @override
  State<CardioSummaryScreen> createState() => _SummaryState();
}

class _SummaryState extends State<CardioSummaryScreen> {
  double _effort = 5;
  bool _discomfort = false, _saved = false;
  bool? _talkComfort;
  String? _recovery, _runType;
  String _environment = 'unknown';
  late final Future<List<Map<String, dynamic>>> _route;
  @override
  void initState() {
    super.initState();
    _route = context.read<CardioProvider>().repository.route(
      widget.runtime['sessionId'] as String,
    );
    final feedback = widget.snapshot?['feedback'] as Map?;
    _effort = (feedback?['rpe'] as num?)?.toDouble() ?? 5;
    _discomfort = feedback?['discomfort'] == true;
    _talkComfort = feedback?['talkComfort'] as bool?;
    _recovery = feedback?['recovery'] as String?;
    _environment = feedback?['environment'] as String? ?? 'unknown';
    _runType = feedback?['runType'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.runtime;
    final p = context.read<CardioProvider>();
    final seconds = (r['activeSeconds'] as num? ?? 0).toDouble(),
        meters = (r['distanceMeters'] as num? ?? 0).toDouble();
    final cooldown =
        (r['cooldown'] as List? ?? [])
            .map(
              (v) => RoutineStep.fromJson(Map<String, dynamic>.from(v as Map)),
            )
            .toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.cardio('summary'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            r['name'] as String? ?? context.cardio('completed'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _Metric(
                context.cardio(
                  r['durationBasis'] == 'elapsed' ? 'elapsed' : 'activeTime',
                ),
                CardioUnits.clock(seconds),
              ),
              if (r['indoor'] != true || r['distanceMeasured'] == true)
                _Metric(
                  context.cardio('distance'),
                  CardioUnits.distance(meters, p.profile.units),
                ),
              if (seconds > 0 && meters > 0)
                _Metric(
                  context.cardio('average'),
                  CardioUnits.pace(meters / seconds, p.profile.units),
                ),
              if (r['averageHeartRate'] != null)
                _Metric(
                  context.cardio('heartRate'),
                  '${(r['averageHeartRate'] as num).round()} bpm',
                ),
            ],
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _route,
            builder:
                (c, s) =>
                    !s.hasData
                        ? const SizedBox.shrink()
                        : CardioRouteView(samples: s.data!),
          ),
          if (cooldown.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text(context.cardio('cooldown')),
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => CardioRoutinePlayer(
                              steps: cooldown,
                              cooling: true,
                            ),
                      ),
                    ),
              ),
            ),
          for (final raw in r['results'] as List? ?? [])
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text((raw as Map)['name'] as String? ?? ''),
              subtitle: Text(
                '${CardioUnits.clock(raw['seconds'] as num? ?? 0)} · ${CardioUnits.distance((raw['meters'] as num? ?? 0).toDouble(), p.profile.units)}',
              ),
            ),
          const Divider(),
          Text('${context.cardio('rpe')}: ${_effort.round()} / 10'),
          Slider(
            value: _effort,
            min: 1,
            max: 10,
            divisions: 9,
            label: '${_effort.round()}',
            onChanged:
                (v) => setState(() {
                  _effort = v;
                  _saved = false;
                }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.cardio('discomfort')),
            value: _discomfort,
            onChanged:
                (v) => setState(() {
                  _discomfort = v;
                  _saved = false;
                }),
          ),
          const SizedBox(height: 16),
          Text(context.running('talkComfort')),
          Wrap(
            spacing: 8,
            children: [
              for (final value in [true, false])
                ChoiceChip(
                  label: Text(context.running(value ? 'yes' : 'no')),
                  selected: _talkComfort == value,
                  onSelected:
                      (_) => setState(() {
                        _talkComfort = value;
                        _saved = false;
                      }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(context.running('recovery')),
          Wrap(
            spacing: 8,
            children: [
              for (final value in ['ready', 'tired', 'poor'])
                ChoiceChip(
                  label: Text(context.running(value)),
                  selected: _recovery == value,
                  onSelected:
                      (_) => setState(() {
                        _recovery = value;
                        _saved = false;
                      }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(context.running('environment')),
          Wrap(
            spacing: 8,
            children: [
              for (final value in ['unknown', 'flat', 'hills', 'heat'])
                ChoiceChip(
                  label: Text(context.running(value)),
                  selected: _environment == value,
                  onSelected:
                      (_) => setState(() {
                        _environment = value;
                        _saved = false;
                      }),
                ),
            ],
          ),
          if (widget.snapshot?['health'] != null) ...[
            const SizedBox(height: 16),
            Text(context.running('runType')),
            Wrap(
              spacing: 8,
              children: [
                for (final value in ['easy', 'otherRun'])
                  ChoiceChip(
                    label: Text(context.running(value)),
                    selected: _runType == value,
                    onSelected:
                        (_) => setState(() {
                          _runType = value;
                          _saved = false;
                        }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed:
                _saved
                    ? null
                    : () async {
                      try {
                        await p.repository.feedback(
                          r['sessionId'] as String,
                          _effort.round(),
                          _discomfort,
                          talkComfort: _talkComfort,
                          recovery: _recovery,
                          environment: _environment,
                          runType: _runType,
                        );
                        await p.load();
                        if (mounted) setState(() => _saved = true);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.cardio('error'))),
                          );
                        }
                      }
                    },
            child: Text(context.cardio(_saved ? 'saved' : 'save')),
          ),
          if (r['indoor'] != true && r['source'] == null) ...[
            const SizedBox(height: 16),
            Text(
              '${context.cardio('sensorCoverage')}: ${seconds == 0 ? 0 : (((r['gpsCoveredSeconds'] as num? ?? 0) / seconds).clamp(0, 1) * 100).round()}% GPS',
            ),
          ],
        ],
      ),
    );
  }
}

Map<String, dynamic> cardioHistoryRuntime(Map<String, Object?> row) =>
    jsonDecode(row['runtime_json'] as String? ?? '{}') as Map<String, dynamic>;
