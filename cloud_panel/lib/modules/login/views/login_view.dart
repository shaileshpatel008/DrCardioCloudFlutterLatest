import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/link_opener.dart';
import '../../../core/utils/navigation.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/ecg_trace.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../controllers/login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = Responsive.width(context) >= 980;
    final form = _LoginForm(controller: controller);

    return Scaffold(
      backgroundColor: Colors.white,
      body: wide
          ? SafeArea(
              child: Row(children: [
                const Expanded(flex: 11, child: _BrandPanel()),
                Expanded(flex: 9, child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(32), child: form))),
              ]),
            )
          // Phones: a fixed dark strip sits behind the status bar so the
          // page never scrolls underneath the clock / battery icons.
          : AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
              child: Column(children: [
                Container(height: MediaQuery.paddingOf(context).top, color: AppColors.sidebar),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(children: [
                      const _BrandPanel(compact: true),
                      Padding(padding: const EdgeInsets.fromLTRB(20, 28, 20, 40), child: form),
                    ]),
                  ),
                ),
              ]),
            ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (Icons.monitor_heart_outlined, 'Record', '12-lead ECG at clinic, lab or ambulance'),
      (Icons.cloud_outlined, 'Store', 'Secure cloud storage and admin access'),
      (Icons.favorite_border_rounded, 'Report', 'Cardiologist review with turnaround tracking'),
    ];
    return Container(
      color: AppColors.sidebar,
      padding: EdgeInsets.fromLTRB(compact ? 22 : 56, compact ? 24 : 48, compact ? 22 : 56, compact ? 22 : 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ClipOval(child: Image.asset('assets/images/logo_mark.png', width: 44, height: 44)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Dr.Cardio', style: AppTextStyles.display(20, color: Colors.white)),
            Text('ECG IN YOUR POCKET',
                style: AppTextStyles.body(size: 11, weight: FontWeight.w600, color: AppColors.brandSoft).copyWith(letterSpacing: 1.8)),
          ]),
        ]),
        SizedBox(height: compact ? 22 : 56),
        Text('Every heartbeat,\nreported faster.', style: AppTextStyles.display(compact ? 30 : 48, color: Colors.white).copyWith(height: 1.08))
            .animate()
            .fadeIn(duration: 500.ms)
            .slideY(begin: .15, end: 0, curve: Curves.easeOutCubic),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'ECG Cloud connects your Dr. Cardio devices, technicians and cardiologists in one secure workspace — from recording to signed report.',
            style: AppTextStyles.body(size: compact ? 14.5 : 17, color: const Color(0xFFC9CED8), height: 1.6),
          ),
        ).animate().fadeIn(duration: 500.ms, delay: 120.ms),
        SizedBox(height: compact ? 14 : 30),
        EcgTrace(height: compact ? 90 : 150, beats: compact ? 5 : 7),
        if (!compact) ...[
          const SizedBox(height: 28),
          LayoutBuilder(builder: (context, c) {
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < steps.length; i++)
                  SizedBox(
                    width: (c.maxWidth - 24) / 3,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181B22),
                        border: Border.all(color: AppColors.sidebarLine),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: const Color(0xFF2A1714), borderRadius: BorderRadius.circular(10)),
                          child: Icon(steps[i].$1, size: 19, color: const Color(0xFFF0604D)),
                        ),
                        const SizedBox(height: 10),
                        Text(steps[i].$2, style: AppTextStyles.body(size: 15, weight: FontWeight.w600, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(steps[i].$3, style: AppTextStyles.body(size: 13, color: const Color(0xFFAEB4C0), height: 1.45)),
                      ]),
                    ).animate().fadeIn(duration: 400.ms, delay: (250 + 120 * i).ms).slideY(begin: .2, end: 0),
                  ),
              ],
            );
          }),
          const SizedBox(height: 40),
          Wrap(spacing: 24, runSpacing: 8, children: [
            for (final t in ['+91 96383 81155 / +91 96383 81666', 'www.drcardio.in', 'info@drcardio.in'])
              Text(t, style: AppTextStyles.body(size: 13, color: const Color(0xFFAEB4C0))),
          ]),
        ],
      ]),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({required this.controller});
  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Form(
        key: controller.formKey,
        child: AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Welcome back', style: AppTextStyles.display(32)),
            const SizedBox(height: 8),
            Text('Sign in to start your session.', style: AppTextStyles.body(size: 15, color: AppColors.muted)),
            const SizedBox(height: 28),
            Obx(() => AppTextField(
                  label: 'Email',
                  controller: controller.email,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline_rounded,
                  validator: Validators.email,
                  serverError: controller.emailError.value,
                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                  textInputAction: TextInputAction.next,
                )),
            const SizedBox(height: 18),
            AppTextField(
              label: 'Password',
              controller: controller.password,
              password: true,
              prefixIcon: Icons.lock_outline_rounded,
              validator: (v) => (v == null || v.isEmpty) ? 'Password is required.' : null,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => controller.submit(),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Obx(() => Checkbox(value: controller.remember.value, onChanged: (v) => controller.remember.value = v ?? false)),
              GestureDetector(
                onTap: controller.remember.toggle,
                child: Text('Remember me', style: AppTextStyles.body(color: AppColors.body)),
              ),
              const Spacer(),
              TextButton(onPressed: () => _forgot(context), child: const Text('Forgot password?')),
            ]),
            Obx(() => AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: controller.error.value == null
                      ? const SizedBox(width: double.infinity)
                      : Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.dangerBg,
                            border: Border.all(color: AppColors.dangerLine),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.dangerText),
                            const SizedBox(width: 8),
                            Expanded(child: Text(controller.error.value!, style: AppTextStyles.body(size: 13.5, color: AppColors.dangerText))),
                          ]),
                        ).animate().shake(hz: 4, offset: const Offset(4, 0), duration: 350.ms),
                )),
            const SizedBox(height: 18),
            Obx(() => SizedBox(
                  height: 52,
                  child: PrimaryButton(
                    label: 'Sign in',
                    icon: Icons.arrow_forward_rounded,
                    loading: controller.loading.value,
                    onPressed: controller.submit,
                    expand: true,
                  ),
                )),
            const SizedBox(height: 26),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('Need help signing in?', style: AppTextStyles.caption),
              ),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _ContactTile(label: 'Remote support', value: ApiConstants.supportPhone, onTap: () => LinkOpener.call(ApiConstants.supportPhone))),
              const SizedBox(width: 10),
              Expanded(child: _ContactTile(label: 'Email', value: ApiConstants.supportEmail, onTap: () => LinkOpener.mail(ApiConstants.supportEmail))),
            ]),
          ]),
        ),
      ),
    ).animate().fadeIn(duration: 450.ms, delay: 150.ms).slideX(begin: .04, end: 0, curve: Curves.easeOutCubic);
  }

  void _forgot(BuildContext context) {
    final email = TextEditingController(text: controller.email.text);
    final key = GlobalKey<FormState>();
    final sending = false.obs;
    final sent = RxnString();
    final error = RxnString();

    AppDialogs.showAnimated(
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: key,
            child: Obx(() => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(14)),
                      child: Icon(sent.value == null ? Icons.lock_reset_rounded : Icons.mark_email_read_outlined, color: AppColors.brand),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(sent.value == null ? 'Forgot your password?' : 'Check your inbox', style: AppTextStyles.h2),
                  const SizedBox(height: 6),
                  Text(
                    sent.value ?? 'Enter your account email and we\'ll send you a reset link.',
                    style: AppTextStyles.muted,
                  ),
                  if (sent.value == null) ...[
                    const SizedBox(height: 18),
                    AppTextField(
                      label: 'Email',
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                      serverError: error.value,
                    ),
                    const SizedBox(height: 18),
                    PrimaryButton(
                      label: 'Send reset link',
                      expand: true,
                      loading: sending.value,
                      onPressed: () async {
                        error.value = null;
                        if (!(key.currentState?.validate() ?? false)) return;
                        sending.value = true;
                        try {
                          sent.value = await controller.sendReset(email.text);
                        } on ApiException catch (e) {
                          error.value = e.errorFor('email') ?? e.message;
                        } finally {
                          sending.value = false;
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextButton(onPressed: () => closeRoute(), child: const Text('← Back to sign in')),
                ])),
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFEAECF0)), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}
