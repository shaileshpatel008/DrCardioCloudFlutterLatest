import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../theme/app_colors.dart';
import '../controllers/onboarding_controller.dart';

/// Redesign: the previous version was a bare white screen with a plain
/// clipped photo, a title and a paragraph — functional but generic, no
/// different from a stock template. This one carries the same soft-glow,
/// brand-red visual language already used for Splash/Login/Home: a
/// decorative gradient backdrop, a lifted/framed photo with a step-number
/// badge that ties each page back to the real app flow (place electrodes →
/// pair over Bluetooth → generate a report) instead of the photo standing
/// alone, and a scale/fade parallax as you swipe instead of a static cut
/// between pages.
class OnboardingView extends GetView<OnboardingController> {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    final pageController = controller.pageController;
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
      body: Stack(
        children: [
          const Positioned(top: -140, right: -100, child: _GlowBlob(size: 340)),
          const Positioned(bottom: -160, left: -120, child: _GlowBlob(size: 320)),
          SafeArea(
            child: _AnimatedEntrance(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8, top: 4),
                      child: TextButton(
                        onPressed: controller.finish,
                        child: const Text('Skip', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: pageController,
                      itemCount: controller.pages.length,
                      onPageChanged: controller.onPageChanged,
                      itemBuilder: (context, index) {
                        final page = controller.pages[index];
                        return AnimatedBuilder(
                          animation: pageController,
                          builder: (context, child) {
                            final current = pageController.hasClients ? (pageController.page ?? controller.page.value.toDouble()) : controller.page.value.toDouble();
                            var t = current - index;
                            t = t.clamp(-1.0, 1.0);
                            final scale = 1 - (t.abs() * 0.12);
                            final opacity = 1 - (t.abs() * 0.55);
                            return Opacity(
                              opacity: opacity.clamp(0.0, 1.0),
                              child: Transform.scale(scale: scale, child: child),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _FramedPhoto(image: page.image),
                                const SizedBox(height: 28),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: AppColors.brandRedTint, borderRadius: BorderRadius.circular(999)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(page.icon, size: 14, color: AppColors.brandRed),
                                      const SizedBox(width: 6),
                                      Text(page.step,
                                          style: const TextStyle(
                                              color: AppColors.brandRed, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  page.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.ink),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  page.description,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.muted, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Plain widget, not Obx — SmoothPageIndicator tracks the
                  // current page via `controller` (the PageController)
                  // directly, it doesn't read any .obs value, so wrapping
                  // it in Obx did nothing but trigger GetX's "improper use
                  // of Obx" warning.
                  SmoothPageIndicator(
                    controller: pageController,
                    count: controller.pages.length,
                    effect: const ExpandingDotsEffect(
                      activeDotColor: AppColors.brandRed,
                      dotColor: AppColors.border,
                      dotHeight: 8,
                      dotWidth: 8,
                      spacing: 6,
                    ),
                    onDotClicked: (i) => pageController.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
                    child: Obx(() {
                      final isLast = controller.page.value == controller.pages.length - 1;
                      return SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: FilledButton.icon(
                            key: ValueKey(isLast),
                            onPressed: isLast
                                ? controller.finish
                                : () => pageController.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic),
                            icon: Icon(isLast ? Icons.check_rounded : Icons.arrow_forward_rounded, size: 19),
                            label: Text(isLast ? 'Get Started' : 'Next'),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Same soft radial-glow decoration used behind Splash/Login's logo —
/// carried here so the walkthrough reads as part of the same app rather
/// than a bolted-on library screen.
class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [Color(0x1FC53827), Color(0x00C53827)]),
        ),
      ),
    );
  }
}

/// Lifts the photo off the flat background with a white card, rounded
/// corners and a soft shadow — the previous bare `ClipRRect` made the
/// photo look pasted onto the page rather than a deliberate part of it.
class _FramedPhoto extends StatelessWidget {
  const _FramedPhoto({required this.image});
  final String image;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.10), blurRadius: 28, offset: const Offset(0, 14))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(image, height: 230, width: double.infinity, fit: BoxFit.cover),
      ),
    );
  }
}

/// One-shot fade + slide-up entrance for the whole screen, same pattern
/// used on Splash/Login so the walkthrough doesn't just snap into view.
class _AnimatedEntrance extends StatelessWidget {
  const _AnimatedEntrance({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, (1 - value) * 18), child: child),
        );
      },
      child: child,
    );
  }
}
