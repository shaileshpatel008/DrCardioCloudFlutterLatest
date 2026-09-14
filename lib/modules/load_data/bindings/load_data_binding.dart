import 'package:get/get.dart';

import '../controllers/load_data_controller.dart';

class LoadDataBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LoadDataController>(() => LoadDataController());
  }
}
