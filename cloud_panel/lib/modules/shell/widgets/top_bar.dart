import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/demo/demo_mode.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../shell_controller.dart';
import 'notifications_panel.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, required this.phone});

  final String title;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final shell = Get.find<ShellController>();

    return Container(
      height: phone ? 64 + MediaQuery.paddingOf(context).top : 72,
      padding: EdgeInsets.fromLTRB(phone ? 8 : 32, phone ? MediaQuery.paddingOf(context).top : 0, phone ? 10 : 28, 0),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.line))),
      child: Row(children: [
        if (phone) ...[
          Builder(
            builder: (ctx) => IconButton(
              tooltip: 'Open menu',
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              icon: const Icon(Icons.menu_rounded, color: AppColors.body),
            ),
          ),
          ClipOval(child: Image.asset('assets/images/logo_mark.png', width: 28, height: 28)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: AppTextStyles.display(17), overflow: TextOverflow.ellipsis)),
        ] else
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Obx(() => (auth.user.value?.can('ecg_records') ?? false) ? const _GlobalSearch() : const SizedBox.shrink()),
            ),
          ),
        if (kDemoMode) ...[
          Tooltip(
            message: 'Sample data. Changes reset when the app restarts.',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFF6D5CF))),
              child: Text('DEMO', style: AppTextStyles.body(size: 11, weight: FontWeight.w800, color: AppColors.brand).copyWith(letterSpacing: 1)),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Obx(() {
          final unread = shell.unread.value;
          return Tooltip(
            message: unread > 0 ? '$unread unread notifications' : 'Notifications',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => phone
                  ? Get.toNamed(AppRoutes.notifications)
                  : AppDialogs.showSidePanel(const NotificationsPanel(asPanel: true), width: 420),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
                child: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(unread > 99 ? '99+' : '$unread'),
                  backgroundColor: AppColors.brand,
                  offset: const Offset(6, -6),
                  child: const Icon(Icons.notifications_none_rounded, color: AppColors.body),
                ),
              ),
            ),
          );
        }),
        const SizedBox(width: 10),
        Obx(() {
          final u = auth.user.value;
          if (u == null) return const SizedBox.shrink();
          return PopupMenuButton<String>(
            tooltip: 'Account',
            offset: const Offset(0, 54),
            onSelected: (v) async {
              if (v == 'profile') Get.offAllNamed(AppRoutes.profile);
              if (v == 'logout') {
                final ok = await AppDialogs.confirm(
                  title: 'Log out?',
                  message: 'You will need to sign in again to use ECG Cloud.',
                  confirmLabel: 'Log out',
                  danger: false,
                  icon: Icons.logout_rounded,
                );
                if (ok) auth.logout();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.name, style: AppTextStyles.body(weight: FontWeight.w700)),
                  Text('${u.email} · ${u.roleLabel}', style: AppTextStyles.caption),
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'profile', child: ListTile(dense: true, leading: Icon(Icons.person_outline_rounded), title: Text('My profile'))),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.logout_rounded, color: AppColors.dangerText),
                  title: Text('Log out', style: AppTextStyles.body(color: AppColors.dangerText, weight: FontWeight.w600)),
                ),
              ),
            ],
            child: Container(
              padding: EdgeInsets.fromLTRB(4, 4, phone ? 4 : 10, 4),
              decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                InitialsAvatar(u.name, size: 36, radius: 9, tintIndex: 1),
                if (!phone) ...[
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(u.name, style: AppTextStyles.body(size: 13, weight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    ),
                    Text(u.roleLabel, style: AppTextStyles.caption),
                  ]),
                  const SizedBox(width: 6),
                  const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.subtle),
                ],
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

/// Search box in the top bar: jumps to ECG Records filtered by the term.
class _GlobalSearch extends StatefulWidget {
  const _GlobalSearch();

  @override
  State<_GlobalSearch> createState() => _GlobalSearchState();
}

class _GlobalSearchState extends State<_GlobalSearch> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _go(String v) {
    final term = v.trim();
    if (term.isEmpty) return;
    Get.offAllNamed(AppRoutes.ecgRecords, parameters: {'search': term});
    _c.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 46),
      child: TextField(
        controller: _c,
        onSubmitted: _go,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search ECG records — patient, file, device, staff…',
          filled: true,
          fillColor: AppColors.ground,
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.subtle),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEAECF0))),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Center(
              widthFactor: 1,
              child: Text('Enter ↵', style: AppTextStyles.body(size: 11, weight: FontWeight.w600, color: AppColors.faint)),
            ),
          ),
        ),
      ),
    );
  }
}
