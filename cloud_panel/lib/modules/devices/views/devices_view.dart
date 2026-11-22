import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/data_table.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/select_field.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/network_models.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../shell/app_shell.dart';
import '../controllers/devices_controller.dart';

class DevicesView extends GetView<DevicesController> {
  const DevicesView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return AppShell(
      active: 'devices',
      title: 'Devices',
      floatingActionButton: Responsive.isPhone(context)
          ? FloatingActionButton.extended(
              onPressed: c.add,
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add device'),
            )
          : null,
      child: PageBody(onRefresh: c.refreshList, children: [
        Obx(() => PageHeader(
              breadcrumb: 'Network / Devices',
              title: 'Devices',
              count: c.total.value,
              subtitle: 'Dr. Cardio ECG devices and the client each one belongs to.',
              actions: [if (!Responsive.isPhone(context)) PrimaryButton(label: 'Add device', icon: Icons.add_rounded, onPressed: c.add)],
            )),
        PagedListCard<DeviceModel>(
          controller: c,
          minTableWidth: 700,
          emptyTitle: 'No devices found',
          emptyMessage: 'Try another search or hospital.',
          emptyIcon: Icons.developer_board_rounded,
          toolbar: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: Responsive.isPhone(context) ? double.infinity : 320,
              child: SearchBox(hint: 'Search device ID or hospital…', onChanged: c.setSearch),
            ),
            Obx(() => FilterButton(label: 'Hospital', value: c.hospital.value?.name ?? 'All', active: c.hospital.value != null, onTap: c.pickHospital)),
          ]),
          columns: [
            TableCol(
              title: 'Device ID',
              flex: 4,
              sortKey: 'device',
              cell: (d) => Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: AppColors.greenTint, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.developer_board_rounded, size: 18, color: AppColors.green),
                ),
                const SizedBox(width: 10),
                Flexible(child: SelectableText(d.instrumentId, style: AppTextStyles.mono.copyWith(fontWeight: FontWeight.w600))),
              ]),
            ),
            TableCol(
              title: 'Hospital',
              flex: 4,
              sortKey: 'hospital',
              cell: (d) => d.clientUserId == null
                  ? Text(d.hospitalName ?? '—', style: AppTextStyles.body())
                  : InkWell(
                      onTap: () => Get.toNamed(AppRoutes.clientPath(d.clientUserId!)),
                      child: Text(d.hospitalName ?? '—', style: AppTextStyles.body(weight: FontWeight.w500, color: AppColors.ink2)),
                    ),
            ),
            TableCol(title: 'Updated', flex: 2, sortKey: 'date', cell: (d) => Text(Fmt.date(d.updatedAt), style: AppTextStyles.muted)),
            TableCol(
              title: 'Actions',
              flex: 2,
              alignEnd: true,
              cell: (d) => Wrap(spacing: 6, children: [
                IconAction(icon: Icons.edit_outlined, tooltip: 'Edit device', onPressed: () => c.edit(d)),
                IconAction(icon: Icons.delete_outline_rounded, tooltip: 'Delete device', danger: true, onPressed: () => c.delete(d)),
              ]),
            ),
          ],
          mobileCard: (d) => Row(children: [
            const Icon(Icons.developer_board_rounded, color: AppColors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.instrumentId, style: AppTextStyles.mono.copyWith(fontWeight: FontWeight.w700)),
                Text(d.hospitalName ?? '—', style: AppTextStyles.caption),
              ]),
            ),
            IconAction(icon: Icons.edit_outlined, tooltip: 'Edit device', onPressed: () => c.edit(d)),
            const SizedBox(width: 6),
            IconAction(icon: Icons.delete_outline_rounded, tooltip: 'Delete device', danger: true, onPressed: () => c.delete(d)),
          ]),
        ),
      ]),
    );
  }
}
