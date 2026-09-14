import 'package:get/get.dart';

import '../../../routes/app_routes.dart';

class HelpController extends GetxController {
  void replayWalkthrough() => Get.toNamed(AppRoutes.onboarding);
}
