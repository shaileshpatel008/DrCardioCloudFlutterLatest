import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/link_opener.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../menu_items.dart';
import '../shell_controller.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.active, required this.collapsed, this.inDrawer = false, this.canToggle = true});

  final String active;
  final bool collapsed;
  final bool inDrawer;
  final bool canToggle;

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final shell = Get.find<ShellController>();

    return Obx(() {
      final user = auth.user.value;
      final items = kMenuItems.where((m) => user?.can(m.key) ?? false).toList();
      final sections = <String>[];
      for (final i in items) {
        if (!sections.contains(i.section)) sections.add(i.section);
      }

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(collapsed ? 0 : 20, 22, collapsed ? 0 : 12, 18),
          child: Row(
            mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              ClipOval(child: Image.asset('assets/images/logo_mark.png', width: 38, height: 38, fit: BoxFit.cover)),
              if (!collapsed) ...[
                const SizedBox(width: 11),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Dr.Cardio', style: AppTextStyles.display(18, color: Colors.white)),
                    Text('ECG CLOUD',
                        style: AppTextStyles.body(size: 10.5, weight: FontWeight.w600, color: AppColors.brandSoft).copyWith(letterSpacing: 1.6)),
                  ]),
                ),
                if (canToggle && !inDrawer)
                  IconButton(
                    tooltip: 'Collapse sidebar',
                    onPressed: shell.toggleSidebar,
                    icon: const Icon(Icons.keyboard_double_arrow_left_rounded, color: AppColors.sidebarMuted, size: 20),
                  ),
              ],
            ],
          ),
        ),
        if (collapsed && canToggle)
          Center(
            child: IconButton(
              tooltip: 'Expand sidebar',
              onPressed: shell.toggleSidebar,
              icon: const Icon(Icons.keyboard_double_arrow_right_rounded, color: AppColors.sidebarMuted, size: 20),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final section in sections) ...[
                if (!collapsed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                    child: Text(section,
                        style: AppTextStyles.body(size: 11, weight: FontWeight.w600, color: AppColors.sidebarMuted).copyWith(letterSpacing: 1.1)),
                  )
                else
                  const SizedBox(height: 14),
                for (final item in items.where((i) => i.section == section))
                  _NavTile(
                    item: item,
                    active: item.key == active,
                    collapsed: collapsed,
                    count: shell.countFor(item.countKey),
                    unread: item.key == 'notifications' ? shell.unread.value : null,
                    onTap: () {
                      if (inDrawer) Navigator.of(context).pop();
                      if (item.key != active) Get.offAllNamed(item.route);
                    },
                  ),
              ],
              const SizedBox(height: 4),
              _NavTile(
                item: const MenuItem('logout', 'Log out', Icons.logout_rounded, '', 'ACCOUNT'),
                active: false,
                collapsed: collapsed,
                onTap: () async {
                  final ok = await AppDialogs.confirm(
                    title: 'Log out?',
                    message: 'You will need to sign in again to use ECG Cloud.',
                    confirmLabel: 'Log out',
                    danger: false,
                    icon: Icons.logout_rounded,
                  );
                  if (ok) auth.logout();
                },
              ),
            ],
          ),
        ),
        if (!collapsed)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 18),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.sidebarRaised,
              border: Border.all(color: AppColors.sidebarLine),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Remote support', style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => LinkOpener.call(ApiConstants.supportPhone),
                child: Text(ApiConstants.supportPhone, style: AppTextStyles.body(size: 13, color: AppColors.brandSoft)),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => LinkOpener.mail(ApiConstants.supportEmail),
                child: Text(ApiConstants.supportEmail, style: AppTextStyles.body(size: 13, color: AppColors.brandSoft)),
              ),
            ]),
          ),
      ]);
    });
  }
}

class _NavTile extends StatefulWidget {
  const _NavTile({required this.item, required this.active, required this.collapsed, required this.onTap, this.count, this.unread});

  final MenuItem item;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;
  final int? count;
  final int? unread;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final fg = active ? Colors.white : AppColors.sidebarText;
    final tile = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(
        button: true,
        selected: active,
        label: widget.item.label,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            margin: const EdgeInsets.only(bottom: 4),
            height: 44,
            padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 0 : 12),
            decoration: BoxDecoration(
              color: active ? AppColors.brand : (_hover ? const Color(0xFF1C2028) : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              boxShadow: active ? [BoxShadow(color: AppColors.brand.withValues(alpha: .35), blurRadius: 14, offset: const Offset(0, 6))] : null,
            ),
            child: Row(
              mainAxisAlignment: widget.collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Badge(
                  isLabelVisible: widget.collapsed && (widget.unread ?? 0) > 0,
                  smallSize: 8,
                  backgroundColor: AppColors.brandSoft,
                  child: Icon(widget.item.icon, size: 20, color: fg),
                ),
                if (!widget.collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(child: Text(widget.item.label, style: AppTextStyles.body(weight: FontWeight.w500, color: fg))),
                  if (widget.count != null) _pill(Fmt.number(widget.count), active),
                  if ((widget.unread ?? 0) > 0) _pill('${widget.unread}', true, brand: !active),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return widget.collapsed ? Tooltip(message: widget.item.label, preferBelow: false, child: tile) : tile;
  }

  Widget _pill(String text, bool active, {bool brand = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: brand ? AppColors.brand : (active ? Colors.white.withValues(alpha: .2) : const Color(0xFF1F232B)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: AppTextStyles.body(size: 12, weight: FontWeight.w600, color: active || brand ? Colors.white : AppColors.sidebarText)),
    );
  }
}
