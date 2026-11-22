import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Plus Jakarta Sans for headings and big figures, Inter for everything else.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle display(double size, {Color color = AppColors.ink, FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, color: color, letterSpacing: -0.4, height: 1.15);

  static TextStyle get h1 => display(28);
  static TextStyle get h2 => display(20);
  static TextStyle get h3 => display(17);
  static TextStyle get figure => display(30);

  static TextStyle body({double size = 14, Color color = AppColors.ink, FontWeight weight = FontWeight.w400, double? height}) =>
      GoogleFonts.inter(fontSize: size, color: color, fontWeight: weight, height: height);

  static TextStyle get label => body(size: 14, weight: FontWeight.w600, color: AppColors.body);
  static TextStyle get caption => body(size: 12, color: AppColors.subtle);
  static TextStyle get muted => body(size: 14, color: AppColors.muted);
  static TextStyle get tableHeader =>
      body(size: 12, weight: FontWeight.w600, color: AppColors.subtle).copyWith(letterSpacing: 0.5);
  static TextStyle get mono => GoogleFonts.jetBrainsMono(fontSize: 13, color: AppColors.body, fontWeight: FontWeight.w500);
}
