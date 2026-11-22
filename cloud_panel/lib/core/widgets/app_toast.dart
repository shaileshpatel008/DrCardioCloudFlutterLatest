import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Short confirmations and errors, shown bottom-right on wide screens and
/// at the bottom on phones.
class AppToast {
  AppToast._();

  static void success(String message, {String? title}) => _show(message, title: title, kind: _Kind.success);
  static void error(String message, {String? title}) => _show(message, title: title, kind: _Kind.error);
  static void info(String message, {String? title}) => _show(message, title: title, kind: _Kind.info);

  static void _show(String message, {String? title, required _Kind kind}) {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
    final ctx = Get.context;
    final wide = ctx != null && MediaQuery.sizeOf(ctx).width >= 760;
    final (Color dot, IconData icon) = switch (kind) {
      _Kind.success => (AppColors.success, Icons.check_rounded),
      _Kind.error => (AppColors.danger, Icons.priority_high_rounded),
      _Kind.info => (AppColors.info, Icons.info_outline_rounded),
    };

    Get.showSnackbar(GetSnackBar(
      messageText: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Text(title, style: AppTextStyles.body(color: Colors.white, weight: FontWeight.w700)),
                Text(message, style: AppTextStyles.body(color: const Color(0xFFE5E7EB), size: 13.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.sidebar,
      borderRadius: 14,
      margin: wide ? const EdgeInsets.only(right: 24, bottom: 24, left: 600) : const EdgeInsets.all(12),
      maxWidth: 440,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      snackPosition: SnackPosition.BOTTOM,
      snackStyle: SnackStyle.FLOATING,
      duration: Duration(milliseconds: kind == _Kind.error ? 4500 : 3000),
      animationDuration: const Duration(milliseconds: 320),
      forwardAnimationCurve: Curves.easeOutCubic,
      boxShadows: const [BoxShadow(color: Color(0x33101828), blurRadius: 28, offset: Offset(0, 12))],
      isDismissible: true,
    ));
  }
}

enum _Kind { success, error, info }
