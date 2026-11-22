import 'package:flutter/material.dart';

/// Design tokens from the approved redesign mockup. Brand red is the real
/// Dr. Cardio red (#C53827), the same value the mobile app uses.
class AppColors {
  AppColors._();

  // Brand
  static const Color brand = Color(0xFFC53827);
  static const Color brandDark = Color(0xFF9E2A1B);
  static const Color brandTint = Color(0xFFFDF0EE);
  static const Color brandSoft = Color(0xFFF2A99F);

  // Neutrals
  static const Color ink = Color(0xFF0F172A);
  static const Color ink2 = Color(0xFF1D2939);
  static const Color body = Color(0xFF344054);
  static const Color muted = Color(0xFF475467);
  static const Color subtle = Color(0xFF667085);
  static const Color faint = Color(0xFF98A2B3);
  static const Color line = Color(0xFFE4E7EC);
  static const Color lineSoft = Color(0xFFF2F4F7);
  static const Color field = Color(0xFFD0D5DD);
  static const Color ground = Color(0xFFF4F5F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF9FAFB);

  // Sidebar (dark)
  static const Color sidebar = Color(0xFF111318);
  static const Color sidebarRaised = Color(0xFF1A1D24);
  static const Color sidebarLine = Color(0xFF262A33);
  static const Color sidebarText = Color(0xFFC3C8D1);
  static const Color sidebarMuted = Color(0xFF8A919E);

  // Report status (each paired with a label + dot, never colour alone)
  static const Color pending = Color(0xFF2563EB);
  static const Color pendingBg = Color(0xFFEFF4FF);
  static const Color pendingText = Color(0xFF1E40AF);
  static const Color requested = Color(0xFFD97706);
  static const Color requestedBg = Color(0xFFFEF3C7);
  static const Color requestedText = Color(0xFF92400E);
  static const Color reported = Color(0xFF16A34A);
  static const Color reportedBg = Color(0xFFDCFCE7);
  static const Color reportedText = Color(0xFF166534);
  static const Color noCredit = Color(0xFF667085);
  static const Color noCreditBg = Color(0xFFF2F4F7);
  static const Color noCreditText = Color(0xFF344054);

  // Feedback
  static const Color danger = Color(0xFFD92D20);
  static const Color dangerText = Color(0xFFB42318);
  static const Color dangerBg = Color(0xFFFEF3F2);
  static const Color dangerLine = Color(0xFFFECDCA);
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFECFDF3);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color warningLine = Color(0xFFFDE68A);
  static const Color warningText = Color(0xFF78350F);
  static const Color info = Color(0xFF1D4ED8);
  static const Color infoBg = Color(0xFFEFF4FF);
  static const Color newTagBg = Color(0xFFEEF2FF);
  static const Color newTagText = Color(0xFF3730A3);

  // KPI icon tints
  static const Color blueTint = Color(0xFFEFF4FF);
  static const Color blue = Color(0xFF1D4ED8);
  static const Color greenTint = Color(0xFFECFDF3);
  static const Color green = Color(0xFF15803D);
  static const Color violetTint = Color(0xFFF4F3FF);
  static const Color violet = Color(0xFF5B21B6);
  static const Color amberTint = Color(0xFFFEF3C7);
  static const Color amber = Color(0xFF92400E);
}
