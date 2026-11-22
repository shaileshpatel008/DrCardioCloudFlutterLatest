import 'package:get/get.dart';

import '../controllers/export_counts_controller.dart';

class ExportCountsBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(() => ExportCountsController());
}
