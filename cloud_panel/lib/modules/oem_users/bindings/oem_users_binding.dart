import 'package:get/get.dart';

import '../controllers/oem_users_controller.dart';

class OemUsersBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(() => OemUsersController());
}
