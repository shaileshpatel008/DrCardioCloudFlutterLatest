import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/services/storage_service.dart';
import '../../../routes/app_routes.dart';

class OnboardingPage {
  const OnboardingPage({required this.title, required this.description, required this.image});
  final String title;
  final String description;
  final String image;
}

/// Port of `walkthroughscreen.IntroductionActivity` — same three cards,
/// same copy, same illustrations, rebuilt as a Flutter `PageView` instead
/// of the `AhoyOnboarderActivity` library.
class OnboardingController extends GetxController {
  final RxInt page = 0.obs;

  /// Owned by the controller (not the view) so it survives view rebuilds —
  /// a `PageController` created inside `StatelessWidget.build()` is a
  /// fresh instance on every rebuild while `PageView`'s internal state
  /// still holds the previous one, which is exactly the kind of mismatch
  /// that produces bizarre layout corruption (seen here as a ~99000px
  /// RenderFlex overflow when replaying the walkthrough from Help, which
  /// navigates here with `Get.toNamed` — pushed on top — rather than the
  /// first-launch path's `Get.offAllNamed`).
  final PageController pageController = PageController();

  final List<OnboardingPage> pages = const [
    OnboardingPage(
      title: 'Place the electrode on chest',
      description: 'The portable ECG machine is lightweight and can be controlled with a smartphone.',
      image: AppAssets.onboarding1,
    ),
    OnboardingPage(
      title: 'Connect app and device via Bluetooth',
      description: 'It simultaneously acquires all 12 channels of ECG with clinical-grade accuracy.',
      image: AppAssets.onboarding2,
    ),
    OnboardingPage(
      title: 'Test and generate a report',
      description: 'Its easy handling makes it convenient for many customers. For a demonstration of the '
          'Dr. Cardio portable ECG machine, please contact Kavitul Technologies Pvt. Ltd.',
      image: AppAssets.onboarding3,
    ),
  ];

  void onPageChanged(int index) => page.value = index;

  void finish() {
    StorageService.instance.hasSeenOnboarding = true;
    final loggedIn = StorageService.instance.isUserLoggedIn;
    Get.offAllNamed(loggedIn ? AppRoutes.home : AppRoutes.login);
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
