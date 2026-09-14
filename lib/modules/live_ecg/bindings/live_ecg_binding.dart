import 'package:get/get.dart';

import '../controllers/live_ecg_controller.dart';

class LiveEcgBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LiveEcgController>(() => LiveEcgController());
  }
}
