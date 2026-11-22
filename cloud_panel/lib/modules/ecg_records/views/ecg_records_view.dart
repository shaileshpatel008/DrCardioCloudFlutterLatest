import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/link_opener.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/data_table.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/select_field.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/ecg_record_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../shell/app_shell.dart';
import '../controllers/ecg_records_controller.dart';

class EcgRecordsView extends GetView<EcgRecordsController> {
  const EcgRecordsView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return AppShell(
      active: 'ecg_records',
      title: 'ECG Records',
      child: PageBody(
        onRefresh: c.reload,
        children: [
          Obx(
            () => PageHeader(
              breadcrumb: 'Clinical / ECG Records',
              title: c.isCardiologist ? 'My ECG worklist' : 'ECG Records',
              count: c.summary.value.all,
              subtitle: c.isCardiologist
                  ? 'ECGs assigned to you. Open a requested ECG to write and publish the report.'
                  : 'Every ECG uploaded from your devices, with its reporting status and cardiologist.',
              actions: [
                SecondaryButton(label: 'Refresh', icon: Icons.refresh_rounded, onPressed: c.reload),
                if (c.user?.can('download_ecg') ?? false)
                  PrimaryButton(label: 'Export', icon: Icons.download_rounded, onPressed: () => Get.offAllNamed(AppRoutes.downloadEcg)),
              ],
            ),
          ),
          _StatusTabs(controller: c),
          PagedListCard<EcgRecord>(
            controller: c,
            toolbar: _FilterBar(controller: c),
            minTableWidth: 1000,
            onRowTap: c.openDetail,
            emptyTitle: 'No ECG records match',
            emptyMessage: 'Try a wider date range or clear a filter.',
            emptyIcon: Icons.monitor_heart_outlined,
            columns: [
              TableCol(title: 'ECG file', flex: 5, sortKey: 'file', cell: (r) => _FileCell(r)),
              TableCol(title: 'Staff · Hospital', flex: 4, sortKey: 'hospital', cell: (r) => _TwoLine(r.staffName ?? '—', r.hospitalName ?? '—')),
              if (!c.isCardiologist)
                TableCol(
                  title: 'Cardiologist',
                  flex: 3,
                  cell: (r) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.cardiologistName ?? '—', style: AppTextStyles.body(size: 13.5)),
                      if (r.isReassigned) ...[const SizedBox(height: 4), _miniTag('Re-assigned')],
                    ],
                  ),
                ),
              TableCol(title: 'Device ID', flex: 3, sortKey: 'device', cell: (r) => _DeviceChip(r.instrumentId)),
              if (Responsive.width(context) >= 1560)
                TableCol(
                  title: 'Live location',
                  flex: 3,
                  cell: (r) => Text(
                    r.address ?? (r.hasLocation ? '${r.latitude}, ${r.longitude}' : 'Not captured'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(size: 13, color: AppColors.muted, height: 1.4),
                  ),
                ),
              TableCol(title: 'Date & time', flex: 3, sortKey: 'date', cell: (r) => _TwoLine(Fmt.date(r.updatedAt), Fmt.time(r.updatedAt))),
              TableCol(title: 'Status', flex: 3, sortKey: 'status', cell: (r) => _StatusCell(r)),
              TableCol(
                title: 'Actions',
                flex: 5,
                alignEnd: true,
                cell: (r) => _RowActions(record: r, controller: c),
              ),
            ],
            mobileCard: (r) => _MobileCard(record: r, controller: c),
          ),
        ],
      ),
    );
  }

  static Widget _miniTag(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    decoration: BoxDecoration(color: AppColors.lineSoft, borderRadius: BorderRadius.circular(999)),
    child: Text(
      t,
      style: AppTextStyles.body(size: 11, weight: FontWeight.w600, color: AppColors.muted),
    ),
  );
}

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({required this.controller});
  final EcgRecordsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final active = controller.filters.value.status;
      final s = controller.summary.value;
      return Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final t in controller.tabs)
                _Tab(label: t?.label ?? 'All', count: s.forStatus(t), active: t == active, onTap: () => controller.setTab(t)),
            ],
          ),
        ),
      );
    });
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.count, required this.active, required this.onTap});
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: active ? AppColors.brand : Colors.transparent, width: 2)),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: AppTextStyles.body(weight: FontWeight.w600, color: active ? AppColors.brand : AppColors.muted),
            ),
            const SizedBox(width: 8),
            CountPill(count, active: active),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.controller});
  final EcgRecordsController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Obx(() {
      final f = c.filters.value;
      final phone = Responsive.isPhone(context);
      final buttons = <Widget>[
        FilterButton(label: 'Hospital', value: f.hospital?.name ?? 'All', active: f.hospital != null, onTap: c.pickHospital),
        if (!c.isCardiologist)
          Tooltip(
            message: f.hospital == null ? 'Choose a hospital first' : '',
            child: FilterButton(label: 'Staff', value: f.staff?.name ?? 'All', active: f.staff != null, onTap: c.pickStaff),
          ),
        if (c.isAdminSide) ...[
          Tooltip(
            message: f.hospital == null ? 'Choose a hospital first' : '',
            child: FilterButton(label: 'Device', value: f.device?.name ?? 'All', active: f.device != null, onTap: c.pickDevice),
          ),
          FilterButton(label: 'Cardiologist', value: f.cardiologist?.name ?? 'All', active: f.cardiologist != null, onTap: c.pickCardiologist),
        ],
        FilterButton(label: 'Date', value: f.dateLabel, active: f.datePreset != null, onTap: () => c.pickDate(context)),
        FilterButton(
          label: 'ECG',
          value: f.ecgStatus == null ? 'Any' : (f.ecgStatus == 'normal' ? 'Normal' : 'Abnormal'),
          active: f.ecgStatus != null,
          onTap: c.pickEcgStatus,
        ),
      ];

      final chips = <Widget>[
        if (f.hospital != null) _chip('Hospital: ${f.hospital!.name}', c.clearHospital),
        if (f.staff != null) _chip('Staff: ${f.staff!.name}', c.clearStaff),
        if (f.device != null) _chip('Device: ${f.device!.name}', c.clearDevice),
        if (f.cardiologist != null) _chip('Cardiologist: ${f.cardiologist!.name}', c.clearCardiologist),
        if (f.datePreset != null) _chip('Date: ${f.dateLabel}', c.clearDate),
        if (f.ecgStatus != null) _chip('ECG: ${f.ecgStatus}', c.clearEcgStatus),
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: phone ? double.infinity : 300,
                child: SearchBox(initial: c.search.value, hint: 'Search file, patient, staff, device, location…', onChanged: c.setSearch),
              ),
              if (phone)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [for (final b in buttons) Padding(padding: const EdgeInsets.only(right: 8), child: b)],
                  ),
                )
              else
                ...buttons,
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: chips.isEmpty
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Active filters:', style: AppTextStyles.body(size: 13, color: AppColors.subtle)),
                        ...chips,
                        TextButton(onPressed: c.clearAll, child: const Text('Clear all')),
                      ],
                    ),
                  ),
          ),
        ],
      );
    });
  }

  Widget _chip(String label, VoidCallback onRemove) => Container(
    padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
    decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: AppColors.brandDark),
        ),
        const SizedBox(width: 2),
        InkWell(
          onTap: onRemove,
          customBorder: const CircleBorder(),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.close_rounded, size: 15, color: AppColors.brandDark),
          ),
        ),
      ],
    ),
  );
}

class _FileCell extends StatelessWidget {
  const _FileCell(this.r);
  final EcgRecord r;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.monitor_heart_outlined, size: 18, color: AppColors.brand),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.displayName,
                style: AppTextStyles.body(weight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(r.fileName, style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
              if (r.ecgStatus != null) ...[const SizedBox(height: 4), EcgTag(r.ecgStatus)],
            ],
          ),
        ),
      ],
    );
  }
}

class _TwoLine extends StatelessWidget {
  const _TwoLine(this.top, this.bottom);
  final String top;
  final String bottom;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        top,
        style: AppTextStyles.body(weight: FontWeight.w500),
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 2),
      Text(
        bottom,
        style: AppTextStyles.body(size: 13, color: AppColors.muted),
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

class _DeviceChip extends StatelessWidget {
  const _DeviceChip(this.id);
  final String? id;

  @override
  Widget build(BuildContext context) {
    if (id == null) return Text('—', style: AppTextStyles.muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.ground, borderRadius: BorderRadius.circular(6)),
      child: Text(id!, style: AppTextStyles.mono.copyWith(fontSize: 12.5), overflow: TextOverflow.ellipsis),
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell(this.r);
  final EcgRecord r;

  @override
  Widget build(BuildContext context) {
    String? sub;
    if (r.status == ReportStatus.reported && r.tatMinutes != null) sub = 'TAT ${Fmt.minutes(r.tatMinutes)}';
    if (r.status == ReportStatus.requested && r.requestedAt != null) sub = 'Waiting ${Fmt.ago(r.requestedAt).replaceAll(' ago', '')}';
    if (r.status == ReportStatus.noCredit) sub = 'Client balance is 0';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusBadge(status: r.status, label: r.statusLabel),
        if (sub != null) ...[const SizedBox(height: 5), Text(sub, style: AppTextStyles.body(size: 12, color: AppColors.muted))],
      ],
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.record, required this.controller});
  final EcgRecord record;
  final EcgRecordsController controller;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final a = r.actions;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        if (a.diagnose) PrimaryButton(label: 'Diagnose', icon: Icons.edit_note_rounded, onPressed: () => controller.openDiagnose(r)),
        if (a.editReport) IconAction(icon: Icons.edit_note_rounded, tooltip: 'Edit report', onPressed: () => controller.openDiagnose(r)),
        if (a.viewReport)
          IconAction(
            icon: Icons.visibility_outlined,
            tooltip: 'View report',
            color: AppColors.reportedText,
            onPressed: () => LinkOpener.open(r.reportPdfUrl),
          ),
        if (a.reassign) IconAction(icon: Icons.swap_horiz_rounded, tooltip: 'Re-assign cardiologist', onPressed: () => controller.reassign(r)),
        if (a.assign) IconAction(icon: Icons.send_rounded, tooltip: 'Send to cardiologist', onPressed: () => controller.assign(r)),
        IconAction(icon: Icons.picture_as_pdf_outlined, tooltip: 'Open ECG PDF', onPressed: () => LinkOpener.open(r.ecgPdfUrl)),
        if (a.delete) IconAction(icon: Icons.delete_outline_rounded, tooltip: 'Delete', danger: true, onPressed: () => controller.delete(r)),
      ],
    );
  }
}

class _MobileCard extends StatelessWidget {
  const _MobileCard({required this.record, required this.controller});
  final EcgRecord record;
  final EcgRecordsController controller;

  @override
  Widget build(BuildContext context) {
    final r = record;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                r.displayName,
                style: AppTextStyles.body(size: 15, weight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            StatusBadge(status: r.status, label: r.statusLabel, dense: true),
          ],
        ),
        const SizedBox(height: 6),
        Text('${r.hospitalName ?? '—'} · ${r.staffName ?? '—'}', style: AppTextStyles.body(size: 13, color: AppColors.muted)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text(r.instrumentId ?? '—', style: AppTextStyles.mono.copyWith(fontSize: 12))),
            if (r.ecgStatus != null) ...[EcgTag(r.ecgStatus), const SizedBox(width: 8)],
            Text(Fmt.ago(r.updatedAt), style: AppTextStyles.caption),
          ],
        ),
        if (r.actions.diagnose || r.actions.editReport || r.actions.reassign || r.actions.assign) ...[
          const SizedBox(height: 10),
          _RowActions(record: r, controller: controller),
        ],
      ],
    );
  }
}
