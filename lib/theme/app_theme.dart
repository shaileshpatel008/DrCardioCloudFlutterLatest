import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      // Deliberately no custom `fontFamily` override — WhatsApp doesn't
      // bundle a display font either, it just renders in the platform's
      // own default (Roboto on Android, San Francisco on iOS), which
      // reads noticeably lighter than a geometric display face like
      // Nunito/Poppins at the same declared weights. Leaving this unset
      // lets Flutter's Material theme fall back to that same default.
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandRed,
        primary: AppColors.brandRed,
        surface: AppColors.surface,
      ),
      textTheme: TextTheme(
        headlineMedium: AppTextStyles.h1,
        headlineSmall: AppTextStyles.h2,
        titleLarge: AppTextStyles.h3,
        titleMedium: AppTextStyles.titleMedium,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.button,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.brandRed,
        surfaceTintColor: AppColors.brandRed,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: AppTextStyles.h3.copyWith(color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandRed,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: AppTextStyles.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: AppTextStyles.button,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.brandRed, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1.8),
        ),
        labelStyle: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500),
        floatingLabelStyle: const TextStyle(color: AppColors.brandRed, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: AppColors.placeholder),
        errorStyle: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w500, fontSize: 12),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    );
  }
}
