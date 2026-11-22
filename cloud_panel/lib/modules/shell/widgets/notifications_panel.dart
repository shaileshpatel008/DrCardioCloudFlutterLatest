import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/utils/navigation.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../shell_controller.dart';

/// Unread notifications ("Staff1 New ECG Report Uploaded"), newest first.
/// Read one / Read all, like the web bell. Used as a side panel on wide
/// screens and as the Notifications page on phones.
class NotificationsPanel extends StatelessWidget {
  const NotificationsPanel({super.key, this.asPanel = false});
  final bool asPanel;

  @override
  Widget build(BuildContext context) {
    final shell = Get.find<ShellController>();
    final isCardiologist = Get.find<AuthService>().current?.isCardiologist ?? false;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: EdgeInsets.fromLTRB(20, asPanel ? 20 : 16, 12, 12),
        child: Row(children: [
          Expanded(
            child: Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Notifications', style: AppTextStyles.h2),
                    const SizedBox(width: 10),
                    if (shell.unread.value > 0) CountPill(shell.unread.value),
                  ]),
                  const SizedBox(height: 3),
                  Text('Refreshes every 60 seconds', style: AppTextStyles.caption),
                ])),
          ),
          Obx(() => TextButton(onPressed: shell.unread.value == 0 ? null : shell.markAllRead, child: const Text('Read all'))),
          if (asPanel) IconButton(tooltip: 'Close', onPressed: () => closeRoute(), icon: const Icon(Icons.close_rounded)),
        ]),
      ),
      const Divider(),
      Expanded(
        child: RefreshIndicator(
          onRefresh: shell.pollNotifications,
          child: Obx(() {
            final items = shell.notifications.toList();
            if (items.isEmpty) {
              return ListView(children: const [
                EmptyState(
                  icon: Icons.notifications_off_outlined,
                  title: 'You\'re all caught up',
                  message: 'New ECGs sent to you for review will appear here.',
                ),
              ]);
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final n = items[i];
                return InkWell(
                  onTap: () {
                    shell.markRead(n);
                    if (isCardiologist) {
                      if (asPanel) closeRoute();
                      Get.offAllNamed(AppRoutes.ecgRecords, parameters: {'status': 'requested'});
                    }
                  },
                  child: Container(
                    color: const Color(0xFFFFFBFA),
                    padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(n.title, style: AppTextStyles.body(weight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(n.date ?? '', style: AppTextStyles.caption),
                        ]),
                      ),
                      IconButton(
                        tooltip: 'Mark as read',
                        onPressed: () => shell.markRead(n),
                        icon: const Icon(Icons.done_rounded, size: 18, color: AppColors.subtle),
                      ),
                    ]),
                  ),
                ).animate().fadeIn(duration: 220.ms, delay: (30 * i).ms).slideX(begin: .04, end: 0);
              },
            );
          }),
        ),
      ),
    ]);
  }
}
