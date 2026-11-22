import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/data_table.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/select_field.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/network_models.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../shell/app_shell.dart';
import '../controllers/clients_controller.dart';

class ClientsView extends GetView<ClientsController> {
  const ClientsView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return AppShell(
      active: 'clients',
      title: 'Clients',
      floatingActionButton: Responsive.isPhone(context)
          ? FloatingActionButton.extended(
              onPressed: c.add,
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add client'),
            )
          : null,
      child: PageBody(
        onRefresh: c.refreshList,
        children: [
          Obx(() => PageHeader(
                breadcrumb: 'Network / Clients',
                title: 'Clients',
                count: c.total.value,
                subtitle: 'Hospitals, labs and clinics using Dr. Cardio devices.',
                actions: [if (!Responsive.isPhone(context)) PrimaryButton(label: 'Add client', icon: Icons.add_rounded, onPressed: c.add)],
              )),
          PagedListCard<ClientModel>(
            controller: c,
            onRowTap: c.open,
            minTableWidth: 1080,
            emptyTitle: 'No clients found',
            emptyMessage: 'Try another search, or add your first client.',
            emptyIcon: Icons.apartment_rounded,
            toolbar: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                width: Responsive.isPhone(context) ? double.infinity : 320,
                child: SearchBox(hint: 'Search name, email, hospital, doctor…', onChanged: c.setSearch),
              ),
              Obx(() => FilterButton(
                    label: 'Cardiologist',
                    value: c.cardiologist.value?.name ?? 'All',
                    active: c.cardiologist.value != null,
                    onTap: c.pickCardiologist,
                  )),
            ]),
            columns: [
              TableCol(
                title: 'Client',
                flex: 5,
                sortKey: 'name',
                cell: (r) => Row(children: [
                  InitialsAvatar(r.hospitalName),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.name, style: AppTextStyles.body(weight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                      Text(r.email, style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ]),
              ),
              TableCol(title: 'Hospital', flex: 4, sortKey: 'hospital', cell: (r) => Text(r.hospitalName, style: AppTextStyles.body(weight: FontWeight.w500))),
              TableCol(title: 'Doctor', flex: 3, sortKey: 'doctor', cell: (r) => Text(r.doctorName ?? '—', style: AppTextStyles.muted)),
              TableCol(title: 'ECG balance', flex: 2, cell: (r) => _Balance(r)),
              TableCol(title: 'Cardiologist', flex: 3, cell: (r) => Text(r.cardiologistName ?? 'Not assigned', style: AppTextStyles.body(size: 13.5, color: r.cardiologistName == null ? AppColors.subtle : AppColors.ink2))),
              TableCol(title: 'Created', flex: 2, sortKey: 'date', cell: (r) => Text(Fmt.date(r.createdAt), style: AppTextStyles.muted)),
              TableCol(
                title: 'Actions',
                flex: 3,
                alignEnd: true,
                cell: (r) => Wrap(spacing: 6, children: [
                  IconAction(icon: Icons.visibility_outlined, tooltip: 'View', onPressed: () => c.open(r)),
                  IconAction(icon: Icons.edit_outlined, tooltip: 'Edit', onPressed: () => c.edit(r)),
                  IconAction(icon: Icons.delete_outline_rounded, tooltip: 'Delete', danger: true, onPressed: () => c.delete(r)),
                ]),
              ),
            ],
            mobileCard: (r) => Row(children: [
              InitialsAvatar(r.hospitalName, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.hospitalName, style: AppTextStyles.body(size: 15, weight: FontWeight.w700)),
                  Text(r.email, style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(children: [_Balance(r), const SizedBox(width: 8), Flexible(child: Text(r.cardiologistName ?? '', style: AppTextStyles.caption, overflow: TextOverflow.ellipsis))]),
                ]),
              ),
              PopupMenuButton<String>(
                onSelected: (v) => v == 'edit' ? c.edit(r) : c.delete(r),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.dangerText))),
                ],
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance(this.c);
  final ClientModel c;

  @override
  Widget build(BuildContext context) {
    final b = c.ecgBalance;
    final (bg, fg, label) = b == null
        ? (AppColors.lineSoft, AppColors.body, 'Unlimited')
        : b == 0
            ? (AppColors.dangerBg, AppColors.dangerText, '0 left')
            : (AppColors.successBg, AppColors.reportedText, '${Fmt.number(b)} left');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: AppTextStyles.body(size: 12, weight: FontWeight.w600, color: fg)),
    );
  }
}
