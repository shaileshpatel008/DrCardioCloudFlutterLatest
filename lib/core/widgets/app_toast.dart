import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_colors.dart';

enum ToastType { success, error, warning, info }

/// Color-coded, animated toast — replaces bare `Get.snackbar(...)` calls
/// (which use GetX's default near-transparent styling) with a floating,
/// rounded card that's colored by [ToastType] (success=green, error=red,
/// warning=orange, info=blue) so the message's severity is legible at a
/// glance, not just from its text.
class AppToast {
  AppToast._();

  static void show(String message, {String? title, ToastType type = ToastType.info}) {
    final IconData icon;
    final Color color;
    switch (type) {
      case ToastType.success:
        icon = Icons.check_circle_rounded;
        color = AppColors.toastSuccess;
        break;
      case ToastType.error:
        icon = Icons.error_rounded;
        color = AppColors.toastError;
        break;
      case ToastType.warning:
        icon = Icons.warning_rounded;
        color = AppColors.toastWarning;
        break;
      case ToastType.info:
        icon = Icons.info_rounded;
        color = AppColors.toastInfo;
        break;
    }

    Get.snackbar(
      title ?? _defaultTitle(type),
      message,
      snackPosition: SnackPosition.TOP,
      snackStyle: SnackStyle.FLOATING,
      backgroundColor: color,
      colorText: Colors.white,
      icon: Icon(icon, color: Colors.white, size: 26),
      shouldIconPulse: false,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 16,
      duration: const Duration(seconds: 3),
      animationDuration: const Duration(milliseconds: 350),
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
      boxShadows: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
    );
  }

  static void success(String message, {String? title}) => show(message, title: title, type: ToastType.success);
  static void error(String message, {String? title}) => show(message, title: title, type: ToastType.error);
  static void warning(String message, {String? title}) => show(message, title: title, type: ToastType.warning);
  static void info(String message, {String? title}) => show(message, title: title, type: ToastType.info);

  static String _defaultTitle(ToastType type) {
    switch (type) {
      case ToastType.success:
        return 'Success';
      case ToastType.error:
        return 'Error';
      case ToastType.warning:
        return 'Warning';
      case ToastType.info:
        return 'Info';
    }
  }
}
