import 'package:flutter/material.dart';

class AnimatedFlameIcon extends StatefulWidget {
  final double size;
  const AnimatedFlameIcon({super.key, this.size = 24});

  @override
  State<AnimatedFlameIcon> createState() => _AnimatedFlameIconState();
}

class _AnimatedFlameIconState extends State<AnimatedFlameIcon>
    with SingleTickerProviderStateMixin {
  static const _flameColor = Color(0xFFFF6D00);

  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _rotation = Tween<double>(begin: -0.04, end: 0.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _flameColor.withValues(alpha: 0.3 * _scale.value),
                blurRadius: 8 * _scale.value,
              ),
            ],
          ),
          child: Transform.scale(
            scale: _scale.value,
            child: Transform.rotate(
              angle: _rotation.value,
              child: child,
            ),
          ),
        );
      },
      child: Icon(
        Icons.local_fire_department_rounded,
        size: widget.size,
        color: _flameColor,
      ),
    );
  }
}
