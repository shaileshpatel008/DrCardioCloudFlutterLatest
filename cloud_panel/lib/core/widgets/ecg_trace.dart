import 'package:flutter/material.dart';

/// A looping, self-drawing ECG trace used on the sign-in screen and as a
/// decorative header. Pure CustomPainter, so it runs the same on web and
/// mobile.
class EcgTrace extends StatefulWidget {
  const EcgTrace({super.key, this.color = const Color(0xFFF0604D), this.beats = 7, this.strokeWidth = 2.6, this.height = 140});

  final Color color;
  final int beats;
  final double strokeWidth;
  final double height;

  @override
  State<EcgTrace> createState() => _EcgTraceState();
}

class _EcgTraceState extends State<EcgTrace> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(
            painter: _EcgPainter(progress: Curves.easeInOut.transform(_c.value), color: widget.color, beats: widget.beats, stroke: widget.strokeWidth),
          ),
        ),
      ),
    );
  }
}

class _EcgPainter extends CustomPainter {
  _EcgPainter({required this.progress, required this.color, required this.beats, required this.stroke});

  final double progress;
  final Color color;
  final int beats;
  final double stroke;

  Path _path(Size s) {
    final mid = s.height * .6;
    final w = s.width / beats;
    final h = s.height;
    final p = Path()..moveTo(0, mid);
    for (var i = 0; i < beats; i++) {
      final x = i * w;
      p
        ..lineTo(x + w * .13, mid)
        ..quadraticBezierTo(x + w * .21, mid - h * .08, x + w * .29, mid)
        ..lineTo(x + w * .40, mid)
        ..lineTo(x + w * .43, mid + h * .07)
        ..lineTo(x + w * .49, mid - h * .5)
        ..lineTo(x + w * .54, mid + h * .22)
        ..lineTo(x + w * .59, mid)
        ..lineTo(x + w * .71, mid)
        ..quadraticBezierTo(x + w * .81, mid - h * .14, x + w * .91, mid)
        ..lineTo(x + w, mid);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = Colors.white.withValues(alpha: .06)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height * .6), Offset(size.width, size.height * .6), base);

    final path = _path(size);
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress);

    final glow = Paint()
      ..color = color.withValues(alpha: .25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(drawn, glow);
    canvas.drawPath(drawn, line);

    final tip = metric.getTangentForOffset(metric.length * progress)?.position;
    if (tip != null) {
      canvas.drawCircle(tip, stroke * 2.2, Paint()..color = Colors.white);
      canvas.drawCircle(tip, stroke * 4.5, Paint()..color = color.withValues(alpha: .3));
    }
  }

  @override
  bool shouldRepaint(covariant _EcgPainter old) => old.progress != progress;
}
