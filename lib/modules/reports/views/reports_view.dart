import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/services/record_file_naming.dart';
import '../../../data/models/remote_report_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../pdf_viewer/controllers/pdf_viewer_controller.dart';
import '../controllers/reports_controller.dart';
import '../widgets/report_tile.dart';

class ReportsView extends GetView<ReportsController> {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.reload,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('Reports', style: Theme.of(context).textTheme.headlineSmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: TextField(
              onChanged: controller.setSearchQuery,
              decoration: const InputDecoration(
                hintText: 'Search by patient name or ID…',
                prefixIcon: Icon(Icons.search, color: AppColors.muted2),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: Obx(() => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: ['All', 'Synced', 'Pending', 'Offline'].map((f) {
                    final selected = controller.filter.value == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: selected,
                        onSelected: (_) => controller.setFilter(f),
                        selectedColor: AppColors.brandRed,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : AppColors.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.border),
                      ),
                    );
                  }).toList(),
                )),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = controller.filtered;
              final cloud = controller.filteredCloudRecords;
              if (items.isEmpty && cloud.isEmpty) {
                final searching = controller.searchQuery.value.trim().isNotEmpty;
                return Center(
                  child: Text(
                    searching
                        ? 'No reports match your search.'
                        : controller.cloudError.value != null
                            ? 'No recordings on this device, and could not reach the server:\n${controller.cloudError.value}'
                            : 'No recordings yet.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  for (final record in items) ...[
                    ReportTile(record: record, onShare: () => controller.shareLocalRecord(record)),
                    const SizedBox(height: 10),
                  ],
                  if (cloud.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('From your account', style: Theme.of(context).textTheme.titleSmall),
                    ),
                    for (final report in cloud) ...[
                      _CloudReportTile(
                        report: report,
                        onShare: () => controller.shareRemoteReport(report),
                        onAssign: () => controller.assignToCardiologist(report.ecgRecordId),
                        assigningIds: controller.assigningIds,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _CloudReportTile extends StatelessWidget {
  const _CloudReportTile({required this.report, required this.onShare, required this.onAssign, required this.assigningIds});
  final RemoteReportModel report;
  final VoidCallback onShare;
  final VoidCallback onAssign;
  final RxSet<String> assigningIds;

  @override
  Widget build(BuildContext context) {
    // `api/ecg-list` never sends patient/age/sex fields for this
    // account-wide list (only document_name/status/assign flag) — but
    // document_name is built with the same "<name>_<timestamp>" shape a
    // local record's file is, so this recovers a real name + time instead
    // of showing the raw filename, matching a local ReportTile's look.
    final parsed = RecordFileNaming.parse(report.documentName);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Get.toNamed(
          AppRoutes.pdfViewer,
          arguments: RemotePdfArgs(url: report.documentPath, fileName: '${report.documentName}.pdf'),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 34,
                    decoration: BoxDecoration(color: AppColors.brandRedTint, borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.cloud_outlined, color: AppColors.brandRed, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(parsed.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          parsed.dateTime != null ? DateFormat('d MMM, h:mm a').format(parsed.dateTime!) : 'From your account',
                          style: const TextStyle(color: AppColors.muted2, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  _CloudStatusBadge(report: report),
                  IconButton(
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share_rounded, size: 17, color: AppColors.muted),
                    tooltip: 'Share',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, color: AppColors.muted2, size: 18),
                ],
              ),
              // Port of `ItemListViewAdapter`'s `btnAssign`: visible whenever
              // the server says this report isn't assigned yet, independent
              // of the "Reported" status above (a report can be Reported and
              // still unassigned) and independent of the Settings
              // "Auto-assign cardiologist" toggle (that only decides what a
              // NEW recording sends automatically at upload time). Compact
              // and right-aligned rather than a full-width bar, so it reads
              // as a small secondary action, not another primary CTA.
              if (!report.assignedToCardiologist) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  // A plain Material/InkWell pill, not OutlinedButton: the
                  // app's global OutlinedButtonThemeData forces
                  // minimumSize: Size.fromHeight(52) (full-width, 52 tall)
                  // for the primary "Sign out"/form buttons elsewhere, and
                  // that theme silently won over a per-call minimumSize
                  // override here — this sidesteps it entirely instead of
                  // fighting it.
                  child: Obx(() {
                    final assigning = assigningIds.contains(report.ecgRecordId);
                    return Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: assigning ? null : onAssign,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.brandRed),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (assigning)
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandRed),
                                )
                              else
                                const Icon(Icons.medical_information_outlined, size: 14, color: AppColors.brandRed),
                              const SizedBox(width: 6),
                              Text(
                                assigning ? 'Sending…' : 'Send to Cardiologist',
                                style: const TextStyle(color: AppColors.brandRed, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CloudStatusBadge extends StatelessWidget {
  const _CloudStatusBadge({required this.report});
  final RemoteReportModel report;

  @override
  Widget build(BuildContext context) {
    late Color fg, bg;
    late String label;
    if (report.isReported && report.assignedToCardiologist) {
      fg = AppColors.success;
      bg = AppColors.successBg;
      label = 'Assigned';
    } else if (report.isReported) {
      fg = AppColors.pending;
      bg = AppColors.pendingBg;
      label = 'Reported';
    } else {
      fg = AppColors.muted2;
      bg = AppColors.offlineBg;
      label = 'Pending';
    }
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

