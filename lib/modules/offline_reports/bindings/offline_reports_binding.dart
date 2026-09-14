import 'package:get/get.dart';

import '../controllers/offline_reports_controller.dart';

class OfflineReportsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<OfflineReportsController>(() => OfflineReportsController());
  }
}
