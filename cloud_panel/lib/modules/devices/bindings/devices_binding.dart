import 'package:get/get.dart';

import '../controllers/devices_controller.dart';

class DevicesBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(() => DevicesController());
}
