import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../pdf_viewer/controllers/pdf_viewer_controller.dart';
import '../controllers/reports_controller.dart';
import '../widgets/cloud_report_tile.dart';
import '../widgets/report_tile.dart';

/// Port of `ReportActivity`: online shows the account's server report
/// history; offline shows this device's own saved recordings instead —
/// one list at a time (see `ReportsController`'s doc comment), so the
/// sync-status filter chips (an addition with no equivalent in the
/// original) only make sense, and only show, alongside the offline/local
/// list they filter.
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
          Obx(() {
            if (controller.connectivity.isOnline.value) return const SizedBox.shrink();
            return SizedBox(
              height: 44,
              child: ListView(
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
              ),
            );
          }),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final online = controller.connectivity.isOnline.value;
              final searching = controller.searchQuery.value.trim().isNotEmpty;

              if (online) {
                final cloud = controller.filteredCloudRecords;
                if (cloud.isEmpty) {
                  return Center(
                    child: Text(
                      searching
                          ? 'No reports match your search.'
                          : controller.cloudError.value != null
                              ? 'Could not reach the server:\n${controller.cloudError.value}'
                              : 'No reports found for your account yet.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    for (final report in cloud) ...[
                      CloudReportTile(
                        report: report,
                        onTap: () => Get.toNamed(
                          AppRoutes.pdfViewer,
                          arguments: RemotePdfArgs(url: report.documentPath, fileName: '${report.documentName}.pdf'),
                        ),
                        onShare: () => controller.shareRemoteReport(report),
                        onAssign: () => controller.assignToCardiologist(report.ecgRecordId),
                        assigningIds: controller.assigningIds,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              }

              final items = controller.filtered;
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    searching ? 'No reports match your search.' : 'No recordings saved on this device yet.',
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
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
