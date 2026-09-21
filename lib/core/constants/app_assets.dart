class AppAssets {
  AppAssets._();

  static const String logoFull = 'assets/images/logo_full.png';
  static const String logoMark = 'assets/images/logo_mark.png';
  static const String logoWhite = 'assets/images/logo_white.png';

  /// Just the outline heart+ECG ring from the app's own launcher icon
  /// (cropped from `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png`,
  /// with its baked-in "Dr.Cardio" wordmark cropped away since screens
  /// already render that as their own styled text) — the same icon a user
  /// sees on their home screen, rather than the solid-filled `logoMark`.
  static const String logoLauncherMark = 'assets/images/logo_launcher_mark.png';
  static const String headerPattern = 'assets/images/header_pattern.png';

  static const String onboarding1 = 'assets/images/onboarding_1.png';
  static const String onboarding2 = 'assets/images/onboarding_2.png';
  static const String onboarding3 = 'assets/images/onboarding_3.png';
}
