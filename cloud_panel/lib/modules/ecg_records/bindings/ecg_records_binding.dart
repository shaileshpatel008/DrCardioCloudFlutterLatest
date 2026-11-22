import 'package:get/get.dart';

import '../controllers/ecg_records_controller.dart';

class EcgRecordsBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(() => EcgRecordsController());
}
