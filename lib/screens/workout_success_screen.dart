import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

import '../utils/duration_utils.dart';
import '../l10n/l10n.dart';

class WorkoutSuccessScreen extends StatefulWidget {
  final String workoutName;
  final int durationSeconds;
  final int exerciseCount;
  final int totalSets;
  final Future<void> Function()? finalizeLocally;

  const WorkoutSuccessScreen({
    super.key,
    required this.workoutName,
    required this.durationSeconds,
    required this.exerciseCount,
    required this.totalSets,
    this.finalizeLocally,
  });

  @override
  State<WorkoutSuccessScreen> createState() => _WorkoutSuccessScreenState();
}

class _WorkoutSuccessScreenState extends State<WorkoutSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final ConfettiController _confettiController;

  bool _showStats = false;
  bool _showMessage = false;
  bool _showButton = false;
  bool _isFinalizing = false;
  bool _saved = false;
  Object? _saveError;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _confettiController.play();

    WidgetsBinding.instance.addPostFrameCallback((_) => _finalize());

    // Staggered entrance
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showStats = true);
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showMessage = true);
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showButton = true);
    });
  }

  Future<void> _finalize() async {
    if (_isFinalizing || _saved) return;
    final finalize = widget.finalizeLocally;
    if (finalize == null) {
      setState(() => _saved = true);
      return;
    }
    setState(() {
      _isFinalizing = true;
      _saveError = null;
    });
    try {
      await finalize();
      if (mounted) setState(() => _saved = true);
    } catch (error) {
      if (mounted) setState(() => _saveError = error);
    } finally {
      if (mounted) setState(() => _isFinalizing = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _scaleAnim,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: scheme.tertiary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 48,
                          color: scheme.tertiary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      context.l10n.workoutCompleted,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.workoutName,
                      style: textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    AnimatedOpacity(
                      opacity: _showStats ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: AnimatedSlide(
                        offset:
                            _showStats ? Offset.zero : const Offset(0, 0.15),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            _StatChip(
                              icon: Icon(
                                Icons.timer_outlined,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                              label: localizedDuration(
                                context,
                                widget.durationSeconds,
                              ),
                            ),
                            _StatChip(
                              icon: ImageIcon(
                                const AssetImage('assets/icons/hantel.png'),
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                              label: context.l10n.exercisesCount(
                                widget.exerciseCount,
                              ),
                            ),
                            if (widget.totalSets > 0)
                              _StatChip(
                                icon: Icon(
                                  Icons.layers_rounded,
                                  size: 16,
                                  color: scheme.onSurfaceVariant,
                                ),
                                label: context.l10n.setsCount(widget.totalSets),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child:
                          _saveError != null
                              ? Column(
                                key: const ValueKey('workoutSaveError'),
                                children: [
                                  Text(
                                    context.l10n.workoutSaveFailed,
                                    style: TextStyle(color: scheme.error),
                                    textAlign: TextAlign.center,
                                  ),
                                  TextButton.icon(
                                    onPressed: _finalize,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: Text(context.l10n.retry),
                                  ),
                                ],
                              )
                              : Row(
                                key: ValueKey(_saved),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isFinalizing)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.offline_pin_rounded,
                                      size: 18,
                                      color: scheme.primary,
                                    ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _saved
                                        ? context.l10n.savedLocally
                                        : context.l10n.finishingLocally,
                                  ),
                                ],
                              ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedOpacity(
                      opacity: _showMessage ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: Text(
                        context.l10n.greatWork,
                        style: textTheme.titleMedium?.copyWith(
                          color: scheme.tertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    AnimatedOpacity(
                      opacity: _showButton ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: AnimatedSlide(
                        offset:
                            _showButton ? Offset.zero : const Offset(0, 0.3),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            onPressed:
                                _saved
                                    ? () => Navigator.of(context).pop()
                                    : null,
                            child: Text(context.l10n.done),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 30,
              maxBlastForce: 20,
              minBlastForce: 8,
              gravity: 0.2,
              colors: [
                scheme.primary,
                scheme.tertiary,
                const Color(0xFFFF6D00),
                scheme.secondary,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final Widget icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
