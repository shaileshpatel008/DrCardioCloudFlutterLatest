import 'package:flutter/material.dart';

import 'app_colors.dart';

/// No custom font family here (or in [AppTheme]) — text renders in the
/// platform's own default (Roboto on Android, San Francisco on iOS),
/// same as WhatsApp, rather than a bundled display face. Weights were
/// also brought down a step from the previous Nunito/Poppins scale
/// (headings were w700/w800, now w600/w700) since a geometric display
/// font reads noticeably bolder than the platform default at the same
/// declared weight — the old scale looked overweight once rendered in
/// Roboto/San Francisco. `fontFeatures: tabularFigures` is used on
/// [mono] for the elapsed-time readout / lead labels so digits don't
/// jitter in width without needing a separate monospace font asset.
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle _base = TextStyle(color: AppColors.ink);

  static TextStyle get h1 => _base.copyWith(fontSize: 26, fontWeight: FontWeight.w700);
  static TextStyle get h2 => _base.copyWith(fontSize: 22, fontWeight: FontWeight.w700);
  static TextStyle get h3 => _base.copyWith(fontSize: 18, fontWeight: FontWeight.w700);
  static TextStyle get titleMedium => _base.copyWith(fontSize: 15, fontWeight: FontWeight.w700);
  static TextStyle get body => _base.copyWith(fontSize: 14.5, fontWeight: FontWeight.w500);
  static TextStyle get bodySmall => _base.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.muted);
  static TextStyle get label => _base.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.3);
  static TextStyle get button => _base.copyWith(fontSize: 15, fontWeight: FontWeight.w600);
  static TextStyle get mono => _base.copyWith(fontSize: 12, fontWeight: FontWeight.w500, fontFeatures: const [FontFeature.tabularFigures()]);
}
