import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/app_colors.dart';
import '../controllers/my_account_controller.dart';

/// Plain `AppBar` + list, same simple shape as My Profile/Manage Offline
/// Reports rather than a custom image-header — Profile/Load Data/Manage
/// Offline Reports/Settings are deliberately not repeated here since
/// they're already one tap away in Settings' ACCOUNT section.
class MyAccountView extends GetView<MyAccountController> {
  const MyAccountView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.brandRed,
                child: Text(
                  _initials(controller.storage.userName),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(controller.storage.userName, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(controller.storage.userEmail, style: const TextStyle(color: AppColors.muted2, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Group(children: [
            _Row(icon: Icons.help_outline, label: 'Help', onTap: controller.openHelp),
            _Row(icon: Icons.mail_outline, label: 'Send Feedback', onTap: controller.sendFeedback),
            _Row(icon: Icons.star_border, label: 'Rate this App', onTap: controller.rateApp),
            _Row(icon: Icons.share_outlined, label: 'Share App', onTap: controller.shareApp, isLast: true),
          ]),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: controller.signOut,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.brandRed, side: BorderSide.none, backgroundColor: AppColors.brandRedTint),
            child: const Text('Sign out'),
          ),
          const SizedBox(height: 18),
          Obx(() => Text(
                'Dr. Cardio ${controller.appVersion.value} · Kavitul Technologies Pvt. Ltd.',
                style: const TextStyle(color: AppColors.placeholder, fontSize: 11.5, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              )),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
        child: Column(children: children),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.onTap, this.isLast = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.brandRedTint, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 17, color: AppColors.brandRed),
          ),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.muted2),
        ),
        if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}
