import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../controllers/settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 18),
        const _SectionLabel('SIGNAL PROCESSING'),
        _Card(children: [
          Obx(() => _DropdownRow(
                icon: Icons.show_chart,
                label: 'Filter',
                value: controller.filter.value,
                options: SettingsController.filterOptions,
                onChanged: controller.setFilter,
              )),
          const Divider(height: 1),
          Obx(() => _DropdownRow(
                icon: Icons.bar_chart,
                label: 'Gain',
                value: controller.gain.value,
                options: SettingsController.gainOptions,
                onChanged: controller.setGain,
              )),
          const Divider(height: 1),
          Obx(() => _DropdownRow(
                icon: Icons.speed,
                label: 'Paper speed',
                value: '${controller.xAxisScale.value} mm/s',
                options: const ['25 mm/s', '50 mm/s'],
                onChanged: (v) => controller.setXAxisScale(int.parse(v.split(' ').first)),
              )),
          const Divider(height: 1),
          Obx(() => _SwitchRow(
                icon: Icons.save_outlined,
                label: 'Auto-save recordings',
                value: controller.autoSave.value,
                onChanged: controller.setAutoSave,
              )),
          const Divider(height: 1),
          Obx(() => _SwitchRow(
                icon: Icons.medical_information_outlined,
                label: 'Auto-assign cardiologist',
                value: controller.autoAssignCardiologist.value,
                onChanged: controller.setAutoAssignCardiologist,
              )),
        ]),
        const SizedBox(height: 18),
        const _SectionLabel('ACCOUNT'),
        _Card(children: [
          _NavRow(icon: Icons.person_outline, label: 'My Profile', onTap: () => Get.toNamed(AppRoutes.myProfile)),
          const Divider(height: 1),
          _NavRow(icon: Icons.folder_open_outlined, label: 'Load Data', onTap: () => Get.toNamed(AppRoutes.loadData)),
          const Divider(height: 1),
          _NavRow(icon: Icons.cloud_off_outlined, label: 'Manage Offline Reports', onTap: () => Get.toNamed(AppRoutes.offlineReports)),
          const Divider(height: 1),
          _NavRow(icon: Icons.account_circle_outlined, label: 'My Account', onTap: () => Get.toNamed(AppRoutes.myAccount)),
        ]),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted2, letterSpacing: 0.4)),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: children),
      );
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: _IconChip(icon),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
        trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.muted2),
      );
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({required this.icon, required this.label, required this.value, required this.options, required this.onChanged});
  final IconData icon;
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _IconChip(icon),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
      trailing: DropdownButton<String>(
        value: options.contains(value) ? value : options.first,
        underline: const SizedBox.shrink(),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(color: AppColors.brandRed, fontWeight: FontWeight.w700)))).toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.icon, required this.label, required this.value, required this.onChanged});
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: _IconChip(icon),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
        trailing: Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.brandRed),
      );
}

class _IconChip extends StatelessWidget {
  const _IconChip(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: AppColors.brandRedTint, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 17, color: AppColors.brandRed),
      );
}
