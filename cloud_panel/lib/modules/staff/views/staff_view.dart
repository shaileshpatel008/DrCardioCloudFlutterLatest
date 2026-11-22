import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/data_table.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/network_models.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../shell/app_shell.dart';
import '../controllers/staff_controller.dart';

class StaffView extends GetView<StaffController> {
  const StaffView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final mine = c.mine;
    return AppShell(
      active: mine ? 'client_staffs' : 'admin_staffs',
      title: mine ? 'My Staff' : 'Staff',
      floatingActionButton: mine && Responsive.isPhone(context)
          ? FloatingActionButton.extended(
              onPressed: c.add,
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_rounded),
              label: const Text('Add staff'),
            )
          : null,
      child: PageBody(onRefresh: c.refreshList, children: [
        Obx(() => PageHeader(
              breadcrumb: 'Network / ${mine ? 'My Staff' : 'Staff'}',
              title: mine ? 'My staff' : 'Staff',
              count: c.total.value,
              subtitle: mine
                  ? 'Technicians who record ECGs for you, and the cardiologist their ECGs go to.'
                  : 'Technicians who record ECGs for each client. New staff are added from a client\'s page.',
              actions: [
                if (mine && !Responsive.isPhone(context)) PrimaryButton(label: 'Add staff', icon: Icons.person_add_alt_rounded, onPressed: c.add),
                if (!mine) SecondaryButton(label: 'Go to clients to add staff', icon: Icons.arrow_forward_rounded, onPressed: () => Get.offAllNamed(AppRoutes.clients)),
              ],
            )),
        PagedListCard<StaffModel>(
          controller: c,
          minTableWidth: 940,
          emptyTitle: 'No staff found',
          emptyMessage: mine ? 'Add the technicians who use your Dr. Cardio devices.' : 'Try another search.',
          emptyIcon: Icons.groups_2_outlined,
          toolbar: SizedBox(
            width: Responsive.isPhone(context) ? double.infinity : 380,
            child: SearchBox(hint: 'Search name, email, phone…', onChanged: c.setSearch),
          ),
          columns: [
            TableCol(
              title: 'Name',
              flex: 4,
              sortKey: 'name',
              cell: (s) => Row(children: [
                InitialsAvatar(s.name, size: 36, radius: 18, tintIndex: 3),
                const SizedBox(width: 10),
                Flexible(child: Text(s.name, style: AppTextStyles.body(weight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              ]),
            ),
            if (!mine)
              TableCol(
                title: 'Client',
                flex: 4,
                cell: (s) => s.clientName == null
                    ? Text('—', style: AppTextStyles.muted)
                    : ActionChip(
                        label: Text(s.clientName!, overflow: TextOverflow.ellipsis),
                        labelStyle: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: AppColors.body),
                        backgroundColor: AppColors.lineSoft,
                        side: BorderSide.none,
                        onPressed: () => c.openClient(s),
                      ),
              ),
            if (mine) TableCol(title: 'Cardiologist', flex: 3, cell: (s) => Text(s.cardiologistName ?? 'Default', style: AppTextStyles.muted)),
            TableCol(title: 'Email', flex: 4, sortKey: 'email', cell: (s) => Text(s.email, style: AppTextStyles.muted, overflow: TextOverflow.ellipsis)),
            TableCol(title: 'Phone', flex: 3, cell: (s) => Text(s.phoneNumber ?? '—', style: AppTextStyles.muted)),
            TableCol(title: 'Updated', flex: 2, sortKey: 'date', cell: (s) => Text(Fmt.date(s.updatedAt), style: AppTextStyles.muted)),
            TableCol(
              title: 'Actions',
              flex: 2,
              alignEnd: true,
              cell: (s) => Wrap(spacing: 6, children: [
                IconAction(icon: Icons.edit_outlined, tooltip: 'Edit staff', onPressed: () => c.edit(s)),
                IconAction(icon: Icons.delete_outline_rounded, tooltip: 'Delete staff', danger: true, onPressed: () => c.delete(s)),
              ]),
            ),
          ],
          mobileCard: (s) => Row(children: [
            InitialsAvatar(s.name, size: 42, radius: 21, tintIndex: 3),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, style: AppTextStyles.body(size: 15, weight: FontWeight.w700)),
                Text(s.email, style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
                Text(mine ? (s.cardiologistName ?? 'Default cardiologist') : (s.clientName ?? ''), style: AppTextStyles.caption),
              ]),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? c.edit(s) : c.delete(s),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.dangerText))),
              ],
            ),
          ]),
        ),
      ]),
    );
  }
}
