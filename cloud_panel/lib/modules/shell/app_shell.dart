import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/utils/responsive.dart';
import '../../theme/app_colors.dart';
import 'shell_controller.dart';
import 'widgets/sidebar.dart';
import 'widgets/top_bar.dart';

/// Frame for every signed-in screen.
///  - desktop: full dark sidebar (collapsible) + top bar
///  - tablet:  icon rail + top bar
///  - phone:   top bar with a menu button that opens the sidebar as a drawer
///
/// Sidebar, top bar and page are separate focus groups, so Tab moves through
/// a form's fields in order instead of jumping to sidebar links that happen
/// to sit at the same height on screen.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.active, required this.title, required this.child, this.floatingActionButton});

  final String active;
  final String title;
  final Widget child;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final shell = Get.find<ShellController>();
    final phone = Responsive.isPhone(context);
    final tablet = Responsive.isTablet(context);

    if (phone) {
      return Scaffold(
        backgroundColor: AppColors.ground,
        drawer: Drawer(
          width: 290,
          backgroundColor: AppColors.sidebar,
          child: SafeArea(child: Sidebar(active: active, collapsed: false, inDrawer: true)),
        ),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: TopBar(title: title, phone: true),
        ),
        floatingActionButton: floatingActionButton,
        body: SafeArea(top: false, child: FocusTraversalGroup(child: child)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.ground,
      floatingActionButton: floatingActionButton,
      // SafeArea keeps the sidebar and top bar clear of the status bar on
      // Android / iOS tablets (it adds nothing on the web).
      body: SafeArea(
        child: Row(
          children: [
            Obx(() {
              final collapsed = tablet || shell.sidebarCollapsed.value;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: collapsed ? 80 : 264,
                color: AppColors.sidebar,
                child: FocusTraversalGroup(
                  child: Sidebar(active: active, collapsed: collapsed, canToggle: !tablet),
                ),
              );
            }),
            Expanded(
              child: Column(
                children: [
                  FocusTraversalGroup(child: TopBar(title: title, phone: false)),
                  Expanded(child: FocusTraversalGroup(child: child)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
