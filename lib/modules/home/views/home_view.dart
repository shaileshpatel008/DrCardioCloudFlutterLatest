import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/app_colors.dart';
import '../../help/views/help_view.dart';
import '../../reports/views/reports_view.dart';
import '../../settings/views/settings_view.dart';
import '../controllers/home_controller.dart';
import '../widgets/dashboard_tab.dart';

/// The app's single bottom-nav shell — New ECG / Reports / Help / Settings
/// — matching `act_menu_new.xml`'s real 4-tab set.
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Obx(() => IndexedStack(
              index: controller.tabIndex.value,
              children: const [
                DashboardTab(),
                ReportsView(),
                HelpView(),
                SettingsView(),
              ],
            )),
      ),
      bottomNavigationBar: Obx(() => NavigationBar(
            selectedIndex: controller.tabIndex.value,
            onDestinationSelected: controller.changeTab,
            backgroundColor: Colors.white,
            indicatorColor: AppColors.brandRedTint,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.monitor_heart_outlined), selectedIcon: Icon(Icons.monitor_heart, color: AppColors.brandRed), label: 'New ECG'),
              NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description, color: AppColors.brandRed), label: 'Reports'),
              NavigationDestination(icon: Icon(Icons.help_outline), selectedIcon: Icon(Icons.help, color: AppColors.brandRed), label: 'Help'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings, color: AppColors.brandRed), label: 'Settings'),
            ],
          )),
    );
  }
}
