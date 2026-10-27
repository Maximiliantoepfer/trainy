import 'package:flutter/material.dart';
import 'dart:async';
import '../l10n/cardio_l10n.dart';

/// One accessible control. The three seconds start on pointer down, not after
/// the platform's additional long-press recognition delay.
class HoldToFinishButton extends StatefulWidget {
  const HoldToFinishButton({
    super.key,
    required this.onFinish,
    required this.onAccessibleFinish,
    this.busy = false,
  });
  final VoidCallback onFinish, onAccessibleFinish;
  final bool busy;
  @override
  State<HoldToFinishButton> createState() => _HoldState();
}

class _HoldState extends State<HoldToFinishButton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int? _pointer;
  Timer? _hold;
  void _cancel() {
    _pointer = null;
    _hold?.cancel();
    _progress.reset();
  }

  late final _progress = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
    animationBehavior: AnimationBehavior.preserve,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _cancel();
  }

  @override
  void didUpdateWidget(covariant HoldToFinishButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.busy) _cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hold?.cancel();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: !widget.busy,
    label: context.cardio('finishAccessible'),
    onTap: widget.busy ? null : widget.onAccessibleFinish,
    child: FocusableActionDetector(
      enabled: !widget.busy,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onAccessibleFinish();
            return null;
          },
        ),
      },
      child: ExcludeSemantics(
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown:
              widget.busy
                  ? null
                  : (e) {
                    if (_pointer == null) {
                      _pointer = e.pointer;
                      _progress.forward(from: 0);
                      _hold = Timer(const Duration(seconds: 3), () {
                        if (mounted && _pointer != null && !widget.busy) {
                          widget.onFinish();
                        }
                      });
                    }
                  },
          onPointerUp: (e) {
            if (_pointer == e.pointer) _cancel();
          },
          onPointerCancel: (e) {
            if (_pointer == e.pointer) _cancel();
          },
          onPointerMove: (event) {
            final box = context.findRenderObject() as RenderBox?;
            if (_pointer == event.pointer &&
                box != null &&
                !(Offset.zero & box.size).contains(
                  box.globalToLocal(event.position),
                )) {
              _cancel();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.cardio('holdFinish'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _progress,
                  builder:
                      (_, _) => LinearProgressIndicator(
                        value: _progress.value,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
