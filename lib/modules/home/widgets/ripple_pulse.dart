import 'package:flutter/material.dart';

/// Port of the original's `layout_ripplepulse` (a `PulsatorLayout` /
/// ripple-pulse background behind the connect action) — draws expanding,
/// fading rings behind [child] to draw the eye to "tap to connect" while
/// no device is paired.
class RipplePulse extends StatefulWidget {
  const RipplePulse({super.key, required this.child, required this.color, this.size = 64});

  final Widget child;
  final Color color;
  final double size;

  @override
  State<RipplePulse> createState() => _RipplePulseState();
}

class _RipplePulseState extends State<RipplePulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.8,
      height: widget.size * 1.8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _Ring(controller: _controller, delay: 0, color: widget.color, maxSize: widget.size * 1.8),
          _Ring(controller: _controller, delay: 0.5, color: widget.color, maxSize: widget.size * 1.8),
          widget.child,
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.controller, required this.delay, required this.color, required this.maxSize});
  final AnimationController controller;
  final double delay;
  final Color color;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = (controller.value + delay) % 1.0;
        return Opacity(
          opacity: (1 - t).clamp(0.0, 1.0) * 0.5,
          child: Container(
            width: maxSize * 0.55 + maxSize * 0.45 * t,
            height: maxSize * 0.55 + maxSize * 0.45 * t,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
          ),
        );
      },
    );
  }
}
