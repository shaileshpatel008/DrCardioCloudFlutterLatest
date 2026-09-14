import 'package:flutter/material.dart';

/// Brand palette, taken directly from the live Android app's
/// `res/values/colors.xml` (colorPrimary/colorSecondary/colorAccent =
/// #C53827) so the Flutter rebuild carries the same brand identity, not a
/// new invented one.
class AppColors {
  AppColors._();

  static const Color brandRed = Color(0xFFC53827);
  static const Color brandRedDark = Color(0xFF9E2A1B);
  static const Color brandRedTint = Color(0xFFFBEAE7);

  static const Color ink = Color(0xFF201F1E);
  static const Color muted = Color(0xFF6B6B6B);
  static const Color muted2 = Color(0xFF9E9E9E);
  static const Color placeholder = Color(0xFFB3B3B3);
  static const Color border = Color(0xFFECECEC);
  static const Color surface = Color(0xFFF7F7F7);
  static const Color card = Color(0xFFFFFFFF);

  // Status colors — same hues as the original app's colors.xml
  // (green_active, orange_active, grey_active).
  static const Color success = Color(0xFF2E7D32);
  static const Color successBg = Color(0xFFE8F5E9);
  static const Color pending = Color(0xFFB36B00);
  static const Color pendingBg = Color(0xFFFFF3E0);
  static const Color offline = Color(0xFF6B6B6B);
  static const Color offlineBg = Color(0xFFFAFAFA);
  static const Color error = brandRed;
  static const Color errorBg = Color(0xFFFDECEA);

  // ECG monitor panel — black background, yellow trace, matching the
  // original MPAndroidChart configuration exactly
  // (`chart.setBackgroundColor(Color.BLACK)`, `set.setColor(Color.YELLOW)`).
  static const Color monitorBg = Color(0xFF000000);
  static const Color monitorGrid = Color(0xFF231F1A);
  static const Color monitorTrace = Color(0xFFFFFF00);
}
