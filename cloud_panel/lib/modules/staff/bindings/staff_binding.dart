import 'package:get/get.dart';

import '../controllers/staff_controller.dart';

class AdminStaffBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(() => StaffController(mine: false));
}

class MyStaffBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(() => StaffController(mine: true));
}
