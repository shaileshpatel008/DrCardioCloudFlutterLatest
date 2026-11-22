import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../utils/navigation.dart';
import 'ui_kit.dart';

class AppDialogs {
  AppDialogs._();

  /// Delete / destructive confirmation. Always names the item.
  static Future<bool> confirm({
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    bool danger = true,
    IconData icon = Icons.delete_outline_rounded,
  }) async {
    final result = await showAnimated<bool>(
      Builder(builder: (context) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: danger ? const Color(0xFFFEE4E2) : AppColors.brandTint,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: danger ? AppColors.dangerBg : AppColors.brandTint, spreadRadius: 8)],
                ),
                child: Icon(icon, color: danger ? AppColors.dangerText : AppColors.brand),
              ),
              const SizedBox(height: 22),
              Text(title, style: AppTextStyles.body(size: 18, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(message, style: AppTextStyles.body(color: AppColors.muted, height: 1.55)),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: SecondaryButton(label: 'Cancel', onPressed: () => closeRoute(false))),
                const SizedBox(width: 10),
                Expanded(child: PrimaryButton(label: confirmLabel, danger: danger, onPressed: () => closeRoute(true))),
              ]),
            ]),
          ),
        );
      }),
    );
    return result ?? false;
  }

  /// Opens [child] in a dialog that scales and fades in.
  static Future<T?> showAnimated<T>(Widget child, {bool dismissible = true}) {
    return Get.generalDialog<T>(
      barrierDismissible: dismissible,
      barrierLabel: 'Close',
      barrierColor: const Color(0x73111318),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, _, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            elevation: 24,
            shadowColor: const Color(0x40101828),
            child: child,
          ),
        ),
      ),
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: .94, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }

  /// Right-side panel on wide screens, full-height sheet on phones.
  static Future<T?> showSidePanel<T>(Widget child, {double width = 480}) {
    final wide = (Get.context != null) && MediaQuery.sizeOf(Get.context!).width >= 760;
    if (!wide) {
      return Get.bottomSheet<T>(
        Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(Get.context!).height * .92),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        enterBottomSheetDuration: const Duration(milliseconds: 280),
      );
    }
    return Get.generalDialog<T>(
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0x73111318),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, _) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.white,
          elevation: 24,
          child: SizedBox(width: width, height: double.infinity, child: child),
        ),
      ),
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(curved), child: child);
      },
    );
  }
}

/// Standard header + scrolling body + footer used by dialogs and side panels.
class PanelScaffold extends StatelessWidget {
  const PanelScaffold({super.key, required this.title, this.subtitle, required this.body, this.footer, this.header});

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? footer;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTextStyles.h2),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: AppTextStyles.body(size: 13, color: AppColors.muted)),
              ],
            ]),
          ),
          IconAction(icon: Icons.close_rounded, tooltip: 'Close', onPressed: () => closeRoute()),
        ]),
      ),
      const Divider(),
      ?header,
      Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: body)),
      if (footer != null) ...[
        const Divider(),
        Padding(padding: const EdgeInsets.fromLTRB(22, 14, 22, 18), child: footer!),
      ],
    ]);
  }
}
