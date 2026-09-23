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
        const _SectionLabel('QUICK ACCESS'),
        _QuickAccessGrid(items: [
          _QuickAccessItem(icon: Icons.folder_open_outlined, label: 'Load Data', onTap: () => Get.toNamed(AppRoutes.loadData)),
          _QuickAccessItem(icon: Icons.cloud_off_outlined, label: 'Offline Reports', onTap: () => Get.toNamed(AppRoutes.offlineReports)),
          _QuickAccessItem(icon: Icons.person_outline, label: 'My Profile', onTap: () => Get.toNamed(AppRoutes.myProfile)),
          _QuickAccessItem(icon: Icons.account_circle_outlined, label: 'My Account', onTap: () => Get.toNamed(AppRoutes.myAccount)),
        ]),
        const SizedBox(height: 18),
        const _SectionLabel('ACQUISITION MODE'),
        _Card(children: [
          Obx(() => _DropdownRow(
                icon: Icons.science_outlined,
                label: 'Mode',
                value: controller.testMode.value ? 'Test' : 'ECG',
                options: SettingsController.modeOptions,
                onChanged: controller.setMode,
              )),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: Obx(() => Text(
                controller.testMode.value
                    ? 'Test mode acquires the device\'s built-in fixed calibration waveform instead of a patient\'s ECG — use it to verify the device and app, not for diagnosis.'
                    : 'ECG mode acquires live signal from the patient through the connected device.',
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w500, height: 1.4),
              )),
        ),
        const SizedBox(height: 18),
        const _SectionLabel('WORKFLOW'),
        _Card(children: [
          Obx(() => _SwitchRow(
                icon: Icons.swap_vert,
                label: 'Patient info before recording',
                value: controller.patientInfoFirst.value,
                onChanged: controller.setPatientInfoFirst,
              )),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: Obx(() => Text(
                controller.patientInfoFirst.value
                    ? 'On: fill in patient details, then record. Turn off to record first and enter patient details afterward, right before the report is generated.'
                    : 'Off: start recording right away; patient details are collected afterward, right before the report is generated.',
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w500, height: 1.4),
              )),
        ),
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
                label: 'Plot speed',
                value: '${controller.xAxisScale.value} mm/s',
                options: const ['25 mm/s', '50 mm/s'],
                onChanged: (v) => controller.setXAxisScale(int.parse(v.split(' ').first)),
              )),
          const Divider(height: 1),
          Obx(() => _SwitchRow(
                icon: Icons.medical_information_outlined,
                label: 'Auto Sent to Reporting',
                value: controller.autoAssignCardiologist.value,
                onChanged: controller.setAutoAssignCardiologist,
              )),
        ]),
        const SizedBox(height: 18),
        const _SectionLabel('REPORT'),
        _Card(children: [
          _ReportTypeRow(controller: controller),
          const Divider(height: 1),
          Obx(() => _DropdownRow(
                icon: Icons.timeline,
                label: 'Long lead',
                value: controller.longLead.value,
                options: SettingsController.longLeadOptions,
                onChanged: controller.setLongLead,
              )),
        ]),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: Text(
            'Report type controls the PDF\'s lead layout — one page is generated per selected type. '
            'Long lead is which lead the full-width rhythm strip at the bottom plots.',
            style: TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w500, height: 1.4),
          ),
        ),
        // Hidden for now (asked to keep the code, not remove it) — DIAGNOSTICS
        // section with the "Share Debug Logs" row. controller.shareDebugLogs
        // is untouched, so this is just re-adding these two widgets back in.
        // const SizedBox(height: 18),
        // const _SectionLabel('DIAGNOSTICS'),
        // _Card(children: [
        //   _NavRow(icon: Icons.bug_report_outlined, label: 'Share Debug Logs', onTap: controller.shareDebugLogs),
        // ]),
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

/// Port of `alert_report`'s "{n} selected" row — tapping opens the
/// multi-select checklist (`openReportTypesSelectionDialog()`'s
/// `setMultiChoiceItems`) as a bottom sheet instead of an AlertDialog,
/// matching this app's sheet-based pattern elsewhere.
class _ReportTypeRow extends StatelessWidget {
  const _ReportTypeRow({required this.controller});
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() => ListTile(
          leading: const _IconChip(Icons.picture_as_pdf_outlined),
          title: const Text('Report type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          subtitle: Text(
            '${controller.reportTypes.length} selected · ${controller.reportTypes.join(', ')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted2, fontWeight: FontWeight.w600),
          ),
          trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.muted2),
          onTap: () => _showReportTypeSheet(context),
        ));
  }

  void _showReportTypeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('Report Type', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              const Text(
                'Generate one PDF page per selected layout',
                style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Obx(() => Column(
                    children: SettingsController.reportTypeOptions
                        .map((type) => CheckboxListTile(
                              value: controller.reportTypes.contains(type),
                              onChanged: (v) => controller.toggleReportType(type, v ?? false),
                              title: Text(type, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              activeColor: AppColors.brandRed,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ))
                        .toList(),
                  )),
            ],
          ),
        ),
      ),
    );
  }
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

class _QuickAccessItem {
  const _QuickAccessItem({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Pinned to the very top of Settings — Option A from the client mockup:
/// Load Data, Manage Offline Reports, My Profile and My Account used to sit
/// under an ACCOUNT section at the bottom of a long scroll; these are
/// destinations clinicians reach for constantly (Load Data especially), not
/// tunable preferences, so they get a shortcut grid up front instead.
class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid({required this.items});
  final List<_QuickAccessItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.6,
      children: items.map((item) => _QuickAccessTile(item: item)).toList(),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({required this.item});
  final _QuickAccessItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandRedTint,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
                child: Icon(item.icon, size: 15, color: AppColors.brandRed),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: AppColors.ink, height: 1.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
