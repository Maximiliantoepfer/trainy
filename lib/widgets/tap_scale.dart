import 'package:flutter/material.dart';

/// Wraps any child with a subtle scale-down animation on press.
///
/// Uses [Listener] (pointer events) instead of [GestureDetector] to avoid
/// competing with the child's gesture arena — Material [InkWell] ripple
/// effects remain fully functional.
class TapScale extends StatefulWidget {
  final Widget child;
  final double scaleEnd;
  final Duration duration;
  final Curve curve;

  const TapScale({
    super.key,
    required this.child,
    this.scaleEnd = 0.96,
    this.duration = const Duration(milliseconds: 120),
    this.curve = Curves.easeOut,
  });

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (!_pressed) setState(() => _pressed = true);
      },
      onPointerUp: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      onPointerCancel: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      child: AnimatedScale(
        scale: _pressed ? widget.scaleEnd : 1.0,
        duration: widget.duration,
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}
