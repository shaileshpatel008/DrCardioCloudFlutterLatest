import 'package:get/get.dart';

import '../controllers/diagnose_controller.dart';

class DiagnoseBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(() => DiagnoseController());
}
