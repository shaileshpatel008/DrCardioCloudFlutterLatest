import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_assets.dart';
import '../../../theme/app_colors.dart';
import '../controllers/login_controller.dart';

/// Redesign approved as "Option 2 · Soft Glow", matching the splash
/// screen's language: the previous version was a form floating in a sea
/// of flat grey with no background treatment, which read as unfinished/
/// blank. A soft blurred red glow behind the logo and shadowed (rather
/// than flat-filled) input fields give it the same lift.
class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF9),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [Color(0x24C53827), Color(0x00C53827)]),
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
              child: _AnimatedEntrance(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.10), blurRadius: 30, offset: const Offset(0, 12))],
                          ),
                          child: Image.asset(AppAssets.logoMark, fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text('Welcome back', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in to capture and sync 12-lead ECGs',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 32),
                      Form(
                        key: controller.formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _GlowField(
                              controller: controller.emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              hintText: 'Email address',
                              prefixIcon: Icons.mail_outline_rounded,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
                            ),
                            const SizedBox(height: 14),
                            Obx(() => _GlowField(
                                  controller: controller.passwordController,
                                  obscureText: controller.obscurePassword.value,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => controller.login(),
                                  hintText: 'Password',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      controller.obscurePassword.value ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      color: AppColors.muted2,
                                    ),
                                    onPressed: controller.toggleObscure,
                                  ),
                                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                                )),
                            const SizedBox(height: 18),
                            _AgreementRow(controller: controller),
                            const SizedBox(height: 22),
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
                      const SizedBox(height: 26),
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
          ],
        ),
      ),
    );
  }
}

/// A form field styled to sit on the soft-glow background — white fill
/// with a light drop shadow instead of the flat grey fill the rest of the
/// app's fields use, since a flat fill would disappear against this
/// screen's own light background instead of reading as a distinct field.
class _GlowField extends StatelessWidget {
  const _GlowField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: hintText,
          prefixIcon: Icon(prefixIcon, color: AppColors.muted2),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

/// Port of `SignInActivity`'s `checkBoxAgreement`/`textViewAgreement`:
/// "Privacy Policy" and "Terms and Conditions" are tappable links (same
/// URLs as the original), and the checkbox must be checked before
/// `login()` will call the API — an unchecked submit shows both a toast
/// and this inline error, same information the original's Toast alone
/// gave, just also visible next to the control that needs it.
class _AgreementRow extends StatelessWidget {
  const _AgreementRow({required this.controller});
  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.4);
    const linkStyle = TextStyle(color: AppColors.brandRed, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.4);

    return Obx(() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: controller.agreedToTerms.value,
                    onChanged: (v) => controller.setAgreedToTerms(v ?? false),
                    activeColor: AppColors.brandRed,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => controller.setAgreedToTerms(!controller.agreedToTerms.value),
                    behavior: HitTestBehavior.opaque,
                    child: Text.rich(
                      TextSpan(
                        style: baseStyle,
                        children: [
                          const TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: linkStyle,
                            recognizer: TapGestureRecognizer()..onTap = controller.openPrivacyPolicy,
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Terms and Conditions',
                            style: linkStyle,
                            recognizer: TapGestureRecognizer()..onTap = controller.openTermsAndConditions,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (controller.showAgreementError.value)
              const Padding(
                padding: EdgeInsets.only(left: 34, top: 4),
                child: Text(
                  'Please agree to continue.',
                  style: TextStyle(color: AppColors.error, fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ));
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
