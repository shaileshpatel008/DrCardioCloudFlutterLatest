import 'package:get/get.dart';

import '../controllers/help_controller.dart';

class HelpBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<HelpController>()) {
      Get.lazyPut<HelpController>(() => HelpController());
    }
  }
}
