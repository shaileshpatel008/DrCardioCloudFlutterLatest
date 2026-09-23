import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    // No AppBar on this screen to carry its own status-bar style, so set
    // it explicitly rather than relying on whatever the previous screen
    // (or the app-wide startup default) happened to leave behind.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
      backgroundColor: const Color(0xFFFCFAF9),
      // Positioned.fill makes the glow a positioned child, so it plays no
      // part in sizing the Stack. That leaves Center as the Stack's only
      // non-positioned child, and Center under bounded incoming
      // constraints always grows to fill them and then centers its own
      // child within that full space — no reliance on SizedBox.expand or
      // StackFit.expand (both of which force-stretch every non-positioned
      // child, which is what left the Column pinned to the top before).
      body: Stack(
        children: [
          const Positioned.fill(
            child: Center(
              child: _GlowCircle(),
            ),
          ),
          Center(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.10), blurRadius: 40, offset: const Offset(0, 16))],
                ),
                // The app's own launcher icon (the outline heart+ECG ring
                // a user already recognizes from their home screen)
                // instead of the solid-filled logoMark — lifted onto this
                // white disc rather than reusing the launcher's own white
                // background square.
                padding: const EdgeInsets.all(22),
                child: Image.asset(AppAssets.logoLauncherMark, fit: BoxFit.contain),
              ),
              const SizedBox(height: 26),
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                  children: [
                    TextSpan(text: 'Dr. ', style: TextStyle(color: AppColors.ink)),
                    TextSpan(text: 'Cardio', style: TextStyle(color: AppColors.brandRed)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const SizedBox(width: 120, height: 20, child: CustomPaint(painter: _EcgSquigglePainter())),
              const SizedBox(height: 10),
              const Text(
                'ECG IN YOUR POCKET',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted2, letterSpacing: 2.2),
              ),
              const SizedBox(height: 44),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.brandRed, backgroundColor: AppColors.border),
              ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 340,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [Color(0x29C53827), Color(0x00C53827)]),
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
