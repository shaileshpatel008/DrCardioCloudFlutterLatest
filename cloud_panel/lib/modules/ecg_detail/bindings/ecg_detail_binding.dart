import 'package:get/get.dart';

import '../controllers/ecg_detail_controller.dart';

class EcgDetailBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(() => EcgDetailController());
}
