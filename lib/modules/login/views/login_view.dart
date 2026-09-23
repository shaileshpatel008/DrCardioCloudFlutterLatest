import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_assets.dart';
import '../../../theme/app_colors.dart';
import '../controllers/login_controller.dart';

/// Redesign approved as "Option 3 · Bold Minimal": flat white background,
/// a labeled-field style (small caps label above a plain grey pill) instead
/// of Option 2's floating shadowed cards, and a full-bleed primary button —
/// a punchier, more clinical feel than the softer glow version. Carries the
/// same T&C agreement row and validation as before, restyled to match: a
/// filled checkbox with an explicit tick instead of a stock Material one.
class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Pinned to fixed bands at the very top/bottom edges rather than a
          // fraction of full screen height — the form is vertically centered,
          // so its actual position shifts with content/keyboard, and a
          // fraction-based placement drifted into the logo row and Sign In
          // button. These bands stay in the corner margins the centered
          // content leaves clear on every normal phone height.
          const Positioned(top: 0, left: 0, right: 0, height: 64, child: _EcgWatermark(band: _EcgBand.top)),
          const Positioned(bottom: 0, left: 0, right: 0, height: 56, child: _EcgWatermark(band: _EcgBand.bottom)),
          Positioned(
            top: -120,
            left: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(0x1FC53827), Color(0x00C53827)]),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: _AnimatedEntrance(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: AppColors.brandRed.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 6))],
                              ),
                              // Original app icon (its red disc is baked into the
                              // asset) rather than a re-tinted glyph in a custom
                              // colored chip — just lifted with a soft shadow.
                              child: Image.asset(AppAssets.logoMark, fit: BoxFit.contain),
                            ),
                            const SizedBox(width: 12),
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                                children: [
                                  TextSpan(text: 'Dr. ', style: TextStyle(color: AppColors.ink)),
                                  TextSpan(text: 'Cardio', style: TextStyle(color: AppColors.brandRed)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 6),
                        const Text(
                          'Sign in to capture and sync 12-lead ECGs',
                          style: TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 30),
                        Form(
                          key: controller.formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _LabeledField(
                                label: 'EMAIL ADDRESS',
                                controller: controller.emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                hintText: 'you@clinic.com',
                                prefixIcon: Icons.mail_outline_rounded,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
                              ),
                              const SizedBox(height: 16),
                              Obx(() => _LabeledField(
                                    label: 'PASSWORD',
                                    controller: controller.passwordController,
                                    obscureText: controller.obscurePassword.value,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => controller.login(),
                                    hintText: '••••••••',
                                    prefixIcon: Icons.lock_outline_rounded,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        controller.obscurePassword.value ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        color: AppColors.muted2,
                                        size: 20,
                                      ),
                                      onPressed: controller.toggleObscure,
                                    ),
                                    validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                                  )),
                              const SizedBox(height: 20),
                              _AgreementRow(controller: controller),
                              const SizedBox(height: 22),
                              Obx(() => AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: SizedBox(
                                      key: ValueKey(controller.isLoading.value),
                                      width: double.infinity,
                                      height: 54,
                                      child: FilledButton(
                                        onPressed: controller.isLoading.value ? null : controller.login,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.brandRed,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                        child: controller.isLoading.value
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                              )
                                            : const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                                      ),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.lock_clock_outlined, size: 13, color: AppColors.muted2),
                            SizedBox(width: 6),
                            Text(
                              'Encrypted sync · Works fully offline',
                              style: TextStyle(color: AppColors.muted2, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Bold Minimal's field style: a small-caps label sitting above a flat grey
/// pill, rather than Option 2's white shadowed card with an inline hint.
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.suffixIcon,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.4),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            hintText: hintText,
            hintStyle: const TextStyle(color: AppColors.placeholder, fontSize: 14, fontWeight: FontWeight.w600),
            prefixIcon: Icon(prefixIcon, color: AppColors.muted2, size: 20),
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.brandRed, width: 1.4)),
          ),
        ),
      ],
    );
  }
}

/// Port of `SignInActivity`'s `checkBoxAgreement`/`textViewAgreement`:
/// "Privacy Policy" and "Terms and Conditions" are tappable links (same
/// URLs as the original), and the checkbox must be checked before
/// `login()` will call the API. Styled here as a filled square with an
/// explicit tick (matching the approved mockup) rather than the stock
/// Material checkbox outline used in Option 2.
class _AgreementRow extends StatelessWidget {
  const _AgreementRow({required this.controller});
  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.4);
    const linkStyle = TextStyle(color: AppColors.brandRed, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.4);

    return Obx(() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => controller.setAgreedToTerms(!controller.agreedToTerms.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: controller.agreedToTerms.value ? AppColors.brandRed : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: controller.agreedToTerms.value ? AppColors.brandRed : AppColors.muted2, width: 1.6),
                    ),
                    child: controller.agreedToTerms.value
                        ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => controller.setAgreedToTerms(!controller.agreedToTerms.value),
                    behavior: HitTestBehavior.opaque,
                    child: Text.rich(
                      TextSpan(
                        style: baseStyle,
                        children: [
                          const TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: linkStyle,
                            recognizer: TapGestureRecognizer()..onTap = controller.openPrivacyPolicy,
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Terms and Conditions',
                            style: linkStyle,
                            recognizer: TapGestureRecognizer()..onTap = controller.openTermsAndConditions,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (controller.showAgreementError.value)
              const Padding(
                padding: EdgeInsets.only(left: 30, top: 5),
                child: Text(
                  'Please agree to continue.',
                  style: TextStyle(color: AppColors.error, fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ));
  }
}

/// One-shot fade + slide-up entrance for the whole card — no
/// AnimationController bookkeeping needed since it only plays once per
/// build of this (stateless) view.
class _AnimatedEntrance extends StatelessWidget {
  const _AnimatedEntrance({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, (1 - value) * 28), child: child),
        );
      },
      child: child,
    );
  }
}

enum _EcgBand { top, bottom }

/// Decorative, near-invisible ECG trace confined to a fixed-height band
/// pinned to the top or bottom screen edge — the "wow" touch the flat
/// Option 3 background was missing, kept strictly out of the form's own
/// vertical space so it never visually crosses the logo row or the Sign In
/// button. A soft red glow travels along the trace on a slow loop, like a
/// heartbeat monitor idling in the margin.
class _EcgWatermark extends StatefulWidget {
  const _EcgWatermark({required this.band});
  final _EcgBand band;

  @override
  State<_EcgWatermark> createState() => _EcgWatermarkState();
}

class _EcgWatermarkState extends State<_EcgWatermark> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _EcgWatermarkPainter(_controller.value, widget.band),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _EcgWatermarkPainter extends CustomPainter {
  _EcgWatermarkPainter(this.progress, this.band);
  final double progress;
  final _EcgBand band;

  static Path _tracePath(Size size, double mid, double amplitude) {
    final w = size.width;
    return Path()
      ..moveTo(0, mid)
      ..lineTo(w * 0.16, mid)
      ..lineTo(w * 0.21, mid)
      ..lineTo(w * 0.25, mid - amplitude * 0.4)
      ..lineTo(w * 0.29, mid + amplitude)
      ..lineTo(w * 0.33, mid - amplitude * 0.55)
      ..lineTo(w * 0.37, mid)
      ..lineTo(w * 0.44, mid)
      ..lineTo(w * 0.47, mid - amplitude * 0.25)
      ..lineTo(w * 0.5, mid + amplitude * 0.35)
      ..lineTo(w * 0.53, mid)
      ..lineTo(w, mid);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final amplitude = size.height * 0.28;
    final mid = band == _EcgBand.top ? size.height * 0.68 : size.height * 0.32;
    final path = _tracePath(size, mid, amplitude);

    final basePaint = Paint()
      ..color = AppColors.brandRed.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, basePaint);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final t = band == _EcgBand.bottom ? (progress + 0.5) % 1.0 : progress;
    final pulseCenter = metric.length * t;
    const trailLength = 34.0;
    final trailStart = (pulseCenter - trailLength).clamp(0.0, metric.length);
    if (pulseCenter > trailStart) {
      final trailPaint = Paint()
        ..color = AppColors.brandRed.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(metric.extractPath(trailStart, pulseCenter), trailPaint);
    }
    final tangent = metric.getTangentForOffset(pulseCenter);
    if (tangent != null) {
      final glowPaint = Paint()
        ..color = AppColors.brandRed.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(tangent.position, 3, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EcgWatermarkPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.band != band;
}
