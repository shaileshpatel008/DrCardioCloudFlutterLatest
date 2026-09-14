import 'package:get/get.dart';

import '../controllers/device_scan_controller.dart';

class DeviceScanBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DeviceScanController>(() => DeviceScanController());
  }
}
