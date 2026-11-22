import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/data_table.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/network_models.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../shell/app_shell.dart';
import '../controllers/oem_users_controller.dart';

class OemUsersView extends GetView<OemUsersController> {
  const OemUsersView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return AppShell(
      active: 'oem_users',
      title: 'OEM Users',
      floatingActionButton: Responsive.isPhone(context)
          ? FloatingActionButton.extended(
              onPressed: c.add,
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add OEM user'),
            )
          : null,
      child: PageBody(onRefresh: c.refreshList, children: [
        Obx(() => PageHeader(
              breadcrumb: 'Network / OEM Users',
              title: 'OEM Users',
              count: c.total.value,
              subtitle: 'Partner and distributor accounts. Each manages its own clients, cardiologists and devices.',
              actions: [if (!Responsive.isPhone(context)) PrimaryButton(label: 'Add OEM user', icon: Icons.add_rounded, onPressed: c.add)],
            )),
        PagedListCard<OemUserModel>(
          controller: c,
          onRowTap: c.view,
          minTableWidth: 780,
          emptyTitle: 'No OEM users yet',
          emptyIcon: Icons.verified_user_outlined,
          toolbar: SizedBox(
            width: Responsive.isPhone(context) ? double.infinity : 380,
            child: SearchBox(hint: 'Search name, email, phone…', onChanged: c.setSearch),
          ),
          columns: [
            TableCol(
              title: 'Name',
              flex: 4,
              sortKey: 'name',
              cell: (u) => Row(children: [
                InitialsAvatar(u.name, size: 36, radius: 10, tintIndex: 0),
                const SizedBox(width: 10),
                Flexible(child: Text(u.name, style: AppTextStyles.body(weight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              ]),
            ),
            TableCol(title: 'Email', flex: 4, sortKey: 'email', cell: (u) => Text(u.email, style: AppTextStyles.muted, overflow: TextOverflow.ellipsis)),
            TableCol(title: 'Phone', flex: 3, cell: (u) => Text(u.phoneNumber ?? '—', style: AppTextStyles.muted)),
            TableCol(title: 'Clients', flex: 2, cell: (u) => CountPill(u.clientsCount, active: u.clientsCount > 0)),
            TableCol(title: 'Updated', flex: 2, sortKey: 'date', cell: (u) => Text(Fmt.date(u.updatedAt), style: AppTextStyles.muted)),
            TableCol(
              title: 'Actions',
              flex: 3,
              alignEnd: true,
              cell: (u) => Wrap(spacing: 6, children: [
                IconAction(icon: Icons.visibility_outlined, tooltip: 'View', onPressed: () => c.view(u)),
                IconAction(icon: Icons.edit_outlined, tooltip: 'Edit', onPressed: () => c.edit(u)),
                IconAction(icon: Icons.delete_outline_rounded, tooltip: 'Delete', danger: true, onPressed: () => c.delete(u)),
              ]),
            ),
          ],
          mobileCard: (u) => Row(children: [
            InitialsAvatar(u.name, size: 44, tintIndex: 0),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.name, style: AppTextStyles.body(size: 15, weight: FontWeight.w700)),
                Text(u.email, style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
                Text('${u.clientsCount} clients', style: AppTextStyles.caption),
              ]),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? c.edit(u) : c.delete(u),
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
