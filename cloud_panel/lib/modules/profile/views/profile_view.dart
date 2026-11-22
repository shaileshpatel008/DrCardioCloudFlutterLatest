import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/responsive.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../shell/app_shell.dart';
import '../controllers/profile_controller.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return AppShell(
      active: 'profile',
      title: 'My Profile',
      child: Obx(() {
        if (c.loading.value) return const Center(child: CircularProgressIndicator());
        final u = c.user;
        if (u == null) return const SizedBox.shrink();
        final wide = Responsive.width(context) >= 1000;
        final details = _DetailsCard(controller: c);
        final password = _PasswordCard(controller: c);
        return PageBody(maxWidth: 1100, children: [
          const PageHeader(breadcrumb: 'Account / My profile', title: 'My profile'),
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Wrap(spacing: 20, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(20)),
                child: Text(u.initials, style: AppTextStyles.display(26, color: Colors.white)),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(u.name, style: AppTextStyles.display(22)),
                Text(u.email, style: AppTextStyles.muted),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.sidebar, borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.shield_outlined, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(u.roleLabel, style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: Colors.white)),
                ]),
              ),
            ]),
          ),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: details),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: password),
            ])
          else ...[details, password],
        ]);
      }),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.controller});
  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final u = c.user!;
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: c.formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Personal details', subtitle: 'Shown in the top bar and on your reports.'),
          const SizedBox(height: 20),
          Obx(() => AppTextField(label: 'Name', controller: c.name, required: true, serverError: c.errors['name'])),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Email',
            controller: TextEditingController(text: u.email),
            readOnly: true,
            helper: 'Your sign-in email. Contact support to change it.',
          ),
          const SizedBox(height: 14),
          AppTextField(label: 'Phone number', controller: TextEditingController(text: u.phoneNumber ?? ''), readOnly: true),
          if (u.isClient) ...[
            const SizedBox(height: 14),
            Obx(() => AppTextField(label: 'Hospital name', controller: c.hospital, required: true, serverError: c.errors['hospital_name'])),
            const SizedBox(height: 14),
            AppTextField(label: 'Doctor name', controller: c.doctor),
          ],
          if (u.isClient || u.isCardiologist) ...[
            const SizedBox(height: 14),
            AppTextField(label: 'Address', controller: c.address, required: u.isCardiologist),
          ],
          if (u.isCardiologist) ...[
            const SizedBox(height: 22),
            const SectionTitle('Report letterhead', subtitle: 'Printed on every report you publish.'),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth > 520 ? (box.maxWidth - 14) / 2 : box.maxWidth;
              return Wrap(spacing: 14, runSpacing: 14, children: [
                SizedBox(
                  width: w,
                  child: Obx(() => _ImagePick(
                        label: 'Logo',
                        url: c.logoUrl.value,
                        picked: c.newLogo.value?.bytes,
                        onPick: c.pickLogo,
                        onRemove: (c.logoUrl.value != null || c.newLogo.value != null) ? c.removeLogo : null,
                      )),
                ),
                SizedBox(
                  width: w,
                  child: Obx(() => _ImagePick(
                        label: 'Signature with stamp',
                        url: c.signatureUrl.value,
                        picked: c.newSignature.value?.bytes,
                        onPick: c.pickSignature,
                        onRemove: (c.signatureUrl.value != null || c.newSignature.value != null) ? c.removeSignature : null,
                      )),
                ),
              ]);
            }),
            const SizedBox(height: 14),
            AppTextField(label: 'Footer', controller: c.footer, maxLines: 3, hint: 'e.g. MD, DM (Cardiology) · Reg. No. …'),
          ],
          if (u.isOem) ...[
            const SizedBox(height: 22),
            const SectionTitle('Branding', subtitle: 'Your logo and theme colour.'),
            const SizedBox(height: 16),
            Obx(() => _ImagePick(
                  label: 'Logo',
                  url: c.logoUrl.value,
                  picked: c.newLogo.value?.bytes,
                  onPick: c.pickLogo,
                  onRemove: c.newLogo.value != null ? c.removeLogo : null,
                )),
            const SizedBox(height: 14),
            AppTextField(label: 'Theme colour', controller: c.themeColor, hint: '#C53827', mono: true),
          ],
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerRight,
            child: Obx(() => PrimaryButton(label: 'Save details', icon: Icons.check_rounded, loading: c.saving.value, onPressed: c.saveDetails)),
          ),
        ]),
      ),
    );
  }
}

class _PasswordCard extends StatelessWidget {
  const _PasswordCard({required this.controller});
  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: c.passwordKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Change password', subtitle: 'Saved separately, so updating your details never asks for a password.'),
          const SizedBox(height: 20),
          Obx(() => AppTextField(
                label: 'New password',
                controller: c.password,
                password: true,
                required: true,
                validator: Validators.password,
                serverError: c.errors['password'],
              )),
          PasswordStrength(controller: c.password),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Confirm password',
            controller: c.confirm,
            password: true,
            required: true,
            validator: (v) => Validators.confirm(v, c.password.text),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerRight,
            child: Obx(() => SecondaryButton(
                  label: c.savingPassword.value ? 'Updating…' : 'Update password',
                  icon: Icons.lock_reset_rounded,
                  onPressed: c.savingPassword.value ? null : c.savePassword,
                )),
          ),
        ]),
      ),
    );
  }
}

class _ImagePick extends StatelessWidget {
  const _ImagePick({required this.label, required this.onPick, this.url, this.picked, this.onRemove});
  final String label;
  final String? url;
  final List<int>? picked;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    Widget preview;
    if (picked != null) {
      preview = Image.memory(Uint8List.fromList(picked!), fit: BoxFit.contain);
    } else if (url != null) {
      preview = Image.network(url!, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: AppColors.faint));
    } else {
      preview = const Icon(Icons.image_outlined, size: 30, color: AppColors.faint);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTextStyles.label),
      const SizedBox(height: 8),
      Container(
        height: 110,
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: preview),
      ),
      const SizedBox(height: 8),
      Row(children: [
        TextButton.icon(onPressed: onPick, icon: const Icon(Icons.upload_rounded, size: 18), label: Text(url == null && picked == null ? 'Upload' : 'Replace')),
        if (onRemove != null)
          TextButton.icon(
            onPressed: onRemove,
            style: TextButton.styleFrom(foregroundColor: AppColors.dangerText),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Remove'),
          ),
        if (picked != null) Text('Not saved yet', style: AppTextStyles.caption),
      ]),
    ]);
  }
}
