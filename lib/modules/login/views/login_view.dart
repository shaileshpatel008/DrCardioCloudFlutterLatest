import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_assets.dart';
import '../../../theme/app_colors.dart';
import '../controllers/login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: _AnimatedEntrance(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: AppColors.brandRed.withOpacity(0.14), blurRadius: 24, offset: const Offset(0, 10)),
                          ],
                        ),
                        child: Image.asset(AppAssets.logoMark, fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in to capture and sync 12-lead ECGs',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 36),
                    Form(
                      key: controller.formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: controller.emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(Icons.mail_outline_rounded, color: AppColors.muted2),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
                          ),
                          const SizedBox(height: 16),
                          Obx(() => TextFormField(
                                controller: controller.passwordController,
                                obscureText: controller.obscurePassword.value,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => controller.login(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.muted2),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      controller.obscurePassword.value ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      color: AppColors.muted2,
                                    ),
                                    onPressed: controller.toggleObscure,
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                              )),
                          const SizedBox(height: 28),
                          Obx(() => AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: FilledButton(
                                  key: ValueKey(controller.isLoading.value),
                                  onPressed: controller.isLoading.value ? null : controller.login,
                                  child: controller.isLoading.value
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                        )
                                      : const Text('Sign In'),
                                ),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.lock_clock_outlined, size: 14, color: AppColors.muted2),
                        SizedBox(width: 6),
                        Text(
                          'Encrypted sync · Works fully offline',
                          style: TextStyle(color: AppColors.muted2, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One-shot fade + slide-up entrance for the whole card — no
/// AnimationController bookkeeping needed since it only plays once per
/// build of this (stateless) view.
class _AnimatedEntrance extends StatelessWidget {
  const _AnimatedEntrance({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, (1 - value) * 28), child: child),
        );
      },
      child: child,
    );
  }
}
