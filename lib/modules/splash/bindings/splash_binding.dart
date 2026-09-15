import 'package:get/get.dart';

import '../controllers/splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    // Must be `put`, not `lazyPut`: SplashView's build() never reads
    // `controller` (it's a static logo/spinner layout), so a lazy factory
    // would never actually be triggered — SplashController would never be
    // constructed, onInit()/onReady() would never fire, and the redirect
    // to onboarding/login/home would never run. `put` constructs it here,
    // as soon as the route binds, regardless of what the view references.
    Get.put<SplashController>(SplashController());
  }
}
