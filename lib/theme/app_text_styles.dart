import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Poppins (Google Fonts), bundled as a local asset and set as the app's
/// default `fontFamily` in [AppTheme] — see `pubspec.yaml`'s `fonts:`
/// entry for why it's bundled rather than fetched at runtime via the
/// `google_fonts` package (this app needs to work fully offline from
/// first launch). `fontFeatures: tabularFigures` is used on [mono] for
/// the elapsed-time readout / lead labels so digits don't jitter in
/// width without needing a separate monospace font asset.
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle _base = TextStyle(color: AppColors.ink);

  static TextStyle get h1 => _base.copyWith(fontSize: 26, fontWeight: FontWeight.w800);
  static TextStyle get h2 => _base.copyWith(fontSize: 22, fontWeight: FontWeight.w800);
  static TextStyle get h3 => _base.copyWith(fontSize: 18, fontWeight: FontWeight.w800);
  static TextStyle get titleMedium => _base.copyWith(fontSize: 15, fontWeight: FontWeight.w800);
  static TextStyle get body => _base.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600);
  static TextStyle get bodySmall => _base.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.muted);
  static TextStyle get label => _base.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.3);
  static TextStyle get button => _base.copyWith(fontSize: 15, fontWeight: FontWeight.w700);
  static TextStyle get mono => _base.copyWith(fontSize: 12, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]);
}
