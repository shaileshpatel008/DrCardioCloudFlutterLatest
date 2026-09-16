import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_assets.dart';
import '../../../theme/app_colors.dart';
import '../controllers/splash_controller.dart';

/// Redesign approved as "Option 2 · Soft Glow": the previous version was
/// just the logo/wordmark centered on flat white, which read as an
/// unfinished blank screen given how much empty space that leaves above
/// and below on a real phone. A soft blurred red glow behind the logo,
/// the logo lifted onto a shadowed white disc, and a small hand-drawn-
/// style ECG trace under the wordmark give the same content actual
/// visual weight instead of just centering it in empty space.
class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF9),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 340,
            height: 340,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Color(0x29C53827), Color(0x00C53827)]),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.10), blurRadius: 40, offset: const Offset(0, 16))],
                ),
                padding: const EdgeInsets.all(24),
                child: Image.asset(AppAssets.logoMark, fit: BoxFit.contain),
              ),
              const SizedBox(height: 26),
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                  children: [
                    TextSpan(text: 'Dr.', style: TextStyle(color: AppColors.ink)),
                    TextSpan(text: 'Cardio', style: TextStyle(color: AppColors.brandRed)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const SizedBox(width: 120, height: 20, child: CustomPaint(painter: _EcgSquigglePainter())),
              const SizedBox(height: 10),
              const Text(
                'ECG IN YOUR POCKET',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted2, letterSpacing: 2.2),
              ),
              const SizedBox(height: 44),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.brandRed, backgroundColor: AppColors.border),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small heartbeat-trace flourish under the wordmark — same idea as the
/// report list's mini waveform preview, just decorative here rather than
/// driven by real sample data.
class _EcgSquigglePainter extends CustomPainter {
  const _EcgSquigglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brandRed.withValues(alpha: 0.55)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final midY = size.height / 2;
    final path = Path()
      ..moveTo(0, midY)
      ..lineTo(size.width * 0.25, midY)
      ..lineTo(size.width * 0.32, midY - size.height * 0.35)
      ..lineTo(size.width * 0.39, midY + size.height * 0.5)
      ..lineTo(size.width * 0.46, midY - size.height * 0.15)
      ..lineTo(size.width * 0.53, midY)
      ..lineTo(size.width, midY);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EcgSquigglePainter oldDelegate) => false;
}
