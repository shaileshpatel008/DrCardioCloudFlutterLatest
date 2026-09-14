import 'package:get/get.dart';

import '../../../core/services/ecg/ecg_filter.dart';
import '../../../core/services/storage_service.dart';
import '../../../routes/app_routes.dart';

class SplashController extends GetxController {
  @override
  void onReady() {
    super.onReady();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(milliseconds: 900));
    final storage = StorageService.instance;
    EcgFilter.setFilter(storage.filter);

    if (!storage.hasSeenOnboarding) {
      Get.offAllNamed(AppRoutes.onboarding);
    } else if (storage.isUserLoggedIn) {
      Get.offAllNamed(AppRoutes.home);
    } else {
      Get.offAllNamed(AppRoutes.login);
    }
  }
}
