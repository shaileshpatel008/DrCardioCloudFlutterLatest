import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/services/storage_service.dart';
import '../../../routes/app_routes.dart';

class OnboardingPage {
  const OnboardingPage({required this.title, required this.description, required this.image, required this.icon, required this.step});
  final String title;
  final String description;
  final String image;

  /// Small icon badge reinforcing which step of the real app flow (place
  /// electrodes → pair over Bluetooth → generate a report) this page is,
  /// rather than the photo alone carrying that context.
  final IconData icon;
  final String step;
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
      step: 'STEP 1',
      icon: Icons.touch_app_rounded,
      title: 'Place the electrode on chest',
      description: 'The portable ECG machine is lightweight and can be controlled with a smartphone.',
      image: AppAssets.onboarding1,
    ),
    OnboardingPage(
      step: 'STEP 2',
      icon: Icons.bluetooth_rounded,
      title: 'Connect app and device via Bluetooth',
      description: 'It simultaneously acquires all 12 channels of ECG with clinical-grade accuracy.',
      image: AppAssets.onboarding2,
    ),
    OnboardingPage(
      step: 'STEP 3',
      icon: Icons.description_rounded,
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
