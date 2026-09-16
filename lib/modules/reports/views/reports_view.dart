import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
                  const Icon(Icons.cloud_outlined, color: AppColors.muted2),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(report.documentName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          report.isReported
                              ? (report.assignedToCardiologist ? 'Reported · Assigned' : 'Reported')
                              : 'Pending review',
                          style: const TextStyle(color: AppColors.muted2, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share_rounded, size: 17, color: AppColors.muted),
                    tooltip: 'Share',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.chevron_right, color: AppColors.muted2, size: 18),
                ],
              ),
              // Port of `ItemListViewAdapter`'s `btnAssign`: visible whenever
              // the server says this report isn't assigned yet, independent
              // of the "Reported" status above (a report can be Reported and
              // still unassigned) and independent of the Settings
              // "Auto-assign cardiologist" toggle (that only decides what a
              // NEW recording sends automatically at upload time).
              if (!report.assignedToCardiologist) ...[
                const SizedBox(height: 10),
                Obx(() {
                  final assigning = assigningIds.contains(report.ecgRecordId);
                  return SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: assigning ? null : onAssign,
                      icon: assigning
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandRed),
                            )
                          : const Icon(Icons.medical_information_outlined, size: 16),
                      label: Text(assigning ? 'Sending…' : 'Send to Cardiologist'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.brandRed, side: const BorderSide(color: AppColors.brandRed)),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

