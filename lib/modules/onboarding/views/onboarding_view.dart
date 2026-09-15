import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../theme/app_colors.dart';
import '../controllers/onboarding_controller.dart';

class OnboardingView extends GetView<OnboardingController> {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    final pageController = controller.pageController;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: controller.finish,
                child: const Text('Skip', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: pageController,
                itemCount: controller.pages.length,
                onPageChanged: controller.onPageChanged,
                itemBuilder: (context, index) {
                  final page = controller.pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(page.image, height: 260, fit: BoxFit.contain),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.muted, height: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Plain widget, not Obx — SmoothPageIndicator tracks the
            // current page via `controller` (the PageController) directly,
            // it doesn't read any .obs value, so wrapping it in Obx did
            // nothing but trigger GetX's "improper use of Obx" warning.
            SmoothPageIndicator(
              controller: pageController,
              count: controller.pages.length,
              effect: const ExpandingDotsEffect(
                activeDotColor: AppColors.brandRed,
                dotColor: AppColors.border,
                dotHeight: 8,
                dotWidth: 8,
              ),
              onDotClicked: (i) => pageController.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Obx(() {
                final isLast = controller.page.value == controller.pages.length - 1;
                return FilledButton(
                  onPressed: isLast
                      ? controller.finish
                      : () => pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                  child: Text(isLast ? 'Get Started' : 'Next'),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
