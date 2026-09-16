import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/widgets/app_confirm_sheet.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../theme/app_colors.dart';
import '../../help/views/help_view.dart';
import '../../reports/views/reports_view.dart';
import '../../settings/views/settings_view.dart';
import '../controllers/home_controller.dart';
import '../widgets/dashboard_tab.dart';

/// The app's single bottom-nav shell — New ECG / Reports / Help / Settings
/// — matching `act_menu_new.xml`'s real 4-tab set.
///
/// Back-button behavior ports `MainActivity.onBackPressed()`: from any tab
/// other than New ECG (the "Home" tab), back returns to New ECG instead of
/// exiting; from the New ECG tab itself, back shows the same "exit app?"
/// confirmation the original did (`"Are you sure you want to exit from the
/// app?"`, Yes/No), rather than exiting immediately.
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    // Explicit, not relying on the app-wide default set once at startup:
    // none of the 4 tabs has its own AppBar, so without this the status
    // bar style would just carry over — leaking, say, the red AppBar
    // screens' white icons here after visiting one and coming back, which
    // then read as invisible against this light-background shell.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (controller.tabIndex.value != 0) {
          controller.changeTab(0);
          return;
        }
        _confirmExit(context);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
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
        bottomNavigationBar: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const OfflineBanner(),
              Obx(() => NavigationBar(
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
            ],
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final confirmed = await AppConfirmSheet.show(
      context,
      icon: Icons.exit_to_app_rounded,
      title: 'Exit App?',
      message: 'Are you sure you want to exit from the app?',
      confirmText: 'Yes, Exit',
      isDismissible: false,
    );
    if (confirmed) SystemNavigator.pop();
  }
}
