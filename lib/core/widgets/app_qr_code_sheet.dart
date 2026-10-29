import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../constants/app_assets.dart';

/// Port of `MainActivity.showQRCodeDialog()` (`dialog_qr_code.xml`) — a
/// "Scan & Pay" heading above the company's UPI QR code image, shown as a
/// bottom sheet instead of a centered AlertDialog to match every other
/// confirmation/notice in this rebuild (see [AppConfirmSheet]). The QR
/// image itself is the same static, pre-made asset the original switched
/// to (its dynamically-generated ZXing version was already commented out
/// and unused there) — not generated at runtime.
class AppQrCodeSheet {
  AppQrCodeSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
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
              const Text('Scan & Pay', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(AppAssets.kavitulUpiQr, width: 260, fit: BoxFit.contain),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('OK', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
