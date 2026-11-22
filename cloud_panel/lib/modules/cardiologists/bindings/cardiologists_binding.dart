import 'package:get/get.dart';

import '../controllers/cardiologists_controller.dart';

class CardiologistsBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(() => CardiologistsController());
}
