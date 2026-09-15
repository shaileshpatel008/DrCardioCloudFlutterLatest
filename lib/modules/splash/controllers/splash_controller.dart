import 'package:get/get.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/ecg/ecg_filter.dart';
import '../../../core/services/storage_service.dart';
import '../../../routes/app_routes.dart';

class SplashController extends GetxController {
  @override
  void onReady() {
    super.onReady();
    AppLogger.d('SplashController.onReady — starting redirect');
    _redirect();
  }

  /// Uncaught errors thrown here used to just vanish into the zone error
  /// handler (logged, but with nothing left to act on it), leaving the
  /// splash screen spinning forever with no visible sign anything was
  /// wrong. Wrapping the whole body means a failure here still logs, but
  /// always falls through to a real screen instead of stranding the user.
  Future<void> _redirect() async {
    try {
      await Future.delayed(const Duration(milliseconds: 900));
      final storage = StorageService.instance;
      EcgFilter.setFilter(storage.filter);

      if (!storage.hasSeenOnboarding) {
        AppLogger.d('Splash redirect -> onboarding');
        Get.offAllNamed(AppRoutes.onboarding);
      } else if (storage.isUserLoggedIn) {
        AppLogger.d('Splash redirect -> home');
        Get.offAllNamed(AppRoutes.home);
      } else {
        AppLogger.d('Splash redirect -> login');
        Get.offAllNamed(AppRoutes.login);
      }
    } catch (e, st) {
      AppLogger.e('Splash redirect failed — falling back to login', e, st);
      Get.offAllNamed(AppRoutes.login);
    }
  }
}
