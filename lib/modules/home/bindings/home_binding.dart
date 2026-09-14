import 'package:get/get.dart';

import '../../help/controllers/help_controller.dart';
import '../../reports/controllers/reports_controller.dart';
import '../../settings/controllers/settings_controller.dart';
import '../controllers/home_controller.dart';

/// The bottom nav's four tabs (New ECG / Reports / Help / Settings — the
/// real tab set from `act_menu_new.xml`) live under one Home route, same
/// as the original single-Activity + fragment-swap design, so their
/// controllers are all provided here.
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController());
    Get.lazyPut<ReportsController>(() => ReportsController());
    Get.lazyPut<HelpController>(() => HelpController());
    Get.lazyPut<SettingsController>(() => SettingsController());
  }
}
