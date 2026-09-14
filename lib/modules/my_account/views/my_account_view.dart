import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_assets.dart';
import '../../../theme/app_colors.dart';
import '../controllers/my_account_controller.dart';

class MyAccountView extends GetView<MyAccountController> {
  const MyAccountView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              Image.asset(AppAssets.headerPattern, width: double.infinity, height: 210, fit: BoxFit.cover),
              Positioned(
                top: 16,
                left: 16,
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      IconButton(onPressed: () => Get.back(), icon: const Icon(Icons.arrow_back, color: Colors.white)),
                      const SizedBox(width: 4),
                      const Text('My Account', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 18,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 3)),
                      child: Center(
                        child: Text(
                          _initials(controller.storage.userName),
                          style: const TextStyle(color: AppColors.brandRed, fontWeight: FontWeight.w800, fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(controller.storage.userName, style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(controller.storage.userEmail, style: const TextStyle(color: Color(0xFFFFE4DE), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                _Group(children: [
                  _Row(icon: Icons.person_outline, label: 'My Profile', onTap: controller.openProfile),
                  _Row(icon: Icons.folder_open_outlined, label: 'Load Data', onTap: controller.openLoadData),
                  _Row(icon: Icons.cloud_off_outlined, label: 'Manage Offline Reports', onTap: controller.openOfflineReports),
                  _Row(icon: Icons.settings_outlined, label: 'Settings', onTap: controller.openSettings, isLast: true),
                ]),
                const SizedBox(height: 16),
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
                    )),
              ],
            ),
          ),
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
