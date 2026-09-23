import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Bottom-sheet confirmation used in place of a centered `AlertDialog` for
/// every "are you sure?" moment (log out, exit the app, discard a
/// recording) and for simple must-acknowledge notices — drag handle, an
/// outlined icon, a bold title, a muted description, a full-width filled
/// primary action and a plain-text dismiss underneath, matching the
/// approved reference design.
class AppConfirmSheet {
  AppConfirmSheet._();

  /// Resolves to `true` only when the primary action was tapped —
  /// `false` for Cancel, a swipe-to-dismiss, or a tap outside the sheet.
  /// Pass `cancelText: null` for a single-button acknowledgement (e.g. an
  /// "OK" notice) instead of a yes/no choice.
  static Future<bool> show(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String confirmText,
    String? cancelText = 'Cancel',
    Color confirmColor = AppColors.brandRed,
    bool isDismissible = true,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              Icon(icon, size: 34, color: confirmColor),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w400, color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: confirmColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    confirmText.toUpperCase(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3),
                  ),
                ),
              ),
              if (cancelText != null) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: Text(cancelText, style: const TextStyle(color: AppColors.muted, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }
}
