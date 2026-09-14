import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_assets.dart';
import '../../../theme/app_colors.dart';
import '../controllers/splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(AppAssets.logoMark, width: 108, height: 108),
            const SizedBox(height: 22),
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                children: [
                  TextSpan(text: 'Dr.', style: TextStyle(color: AppColors.ink)),
                  TextSpan(text: 'Cardio', style: TextStyle(color: AppColors.brandRed)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'ECG IN YOUR POCKET',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 2),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.brandRed),
            ),
          ],
        ),
      ),
    );
  }
}
