import 'package:flutter/material.dart';

import '../../../core/widgets/ui_kit.dart';
import '../../shell/app_shell.dart';
import '../../shell/widgets/notifications_panel.dart';

/// Full-page notifications (phones and the Notifications menu item).
class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      active: 'notifications',
      title: 'Notifications',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: AppCard(padding: EdgeInsets.zero, clip: true, child: NotificationsPanel()),
          ),
        ),
      ),
    );
  }
}
