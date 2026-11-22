import 'package:get/get.dart';

import '../controllers/download_ecg_controller.dart';

class DownloadEcgBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(() => DownloadEcgController());
}
