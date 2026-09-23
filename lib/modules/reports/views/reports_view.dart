import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../pdf_viewer/controllers/pdf_viewer_controller.dart';
import '../controllers/reports_controller.dart';
import '../widgets/cloud_report_tile.dart';
import '../widgets/report_tile.dart';

/// Port of `ReportActivity`: online shows the account's server report
/// history; offline shows this device's own saved recordings instead —
/// one list at a time (see `ReportsController`'s doc comment). The status
/// and date filters (both additions with no equivalent in the original)
/// live in one "Filters" sheet reachable from the header, rather than
/// permanently-visible chips, since which status options make sense
/// depends on which list is currently showing.
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
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
            child: Row(
              children: [
                Expanded(child: Text('Reports', style: Theme.of(context).textTheme.headlineSmall)),
                Obx(() => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          onPressed: () => _showFilterSheet(context),
                          icon: const Icon(Icons.filter_list, color: AppColors.ink),
                          tooltip: 'Filters',
                        ),
                        if (controller.hasActiveFilters)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: AppColors.brandRed, shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    )),
                Obx(() => IconButton(
                      onPressed: controller.isLoading.value ? null : controller.reload,
                      icon: controller.isLoading.value
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.muted2))
                          : const Icon(Icons.refresh, color: AppColors.ink),
                      tooltip: 'Refresh',
                    )),
              ],
            ),
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
            if (!controller.hasActiveFilters) return const SizedBox.shrink();
            final online = controller.connectivity.isOnline.value;
            final statusValue = online ? controller.cloudStatusFilter.value : controller.filter.value;
            final chips = <Widget>[
              if (statusValue != 'All')
                _ActiveFilterChip(
                  label: statusValue,
                  onClear: () => online ? controller.setCloudStatusFilter('All') : controller.setFilter('All'),
                ),
              if (controller.dateFilter.value != ReportDateFilter.all)
                _ActiveFilterChip(
                  label: _dateFilterLabel(controller.dateFilter.value, controller.customDateRange.value),
                  onClear: () => controller.setDateFilter(ReportDateFilter.all),
                ),
            ];
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: chips),
            );
          }),
          const SizedBox(height: 4),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final online = controller.connectivity.isOnline.value;
              final searching = controller.searchQuery.value.trim().isNotEmpty || controller.hasActiveFilters;

              if (online) {
                final cloud = controller.filteredCloudRecords;
                if (cloud.isEmpty) {
                  return Center(
                    child: Text(
                      searching
                          ? 'No reports match your search/filters.'
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
                    searching ? 'No reports match your search/filters.' : 'No recordings saved on this device yet.',
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

  String _dateFilterLabel(ReportDateFilter preset, DateTimeRange? customRange) {
    switch (preset) {
      case ReportDateFilter.all:
        return 'All Time';
      case ReportDateFilter.today:
        return 'Today';
      case ReportDateFilter.yesterday:
        return 'Yesterday';
      case ReportDateFilter.last7Days:
        return 'Last 7 Days';
      case ReportDateFilter.last30Days:
        return 'Last 30 Days';
      case ReportDateFilter.last3Months:
        return 'Last 3 Months';
      case ReportDateFilter.lastYear:
        return 'Last Year';
      case ReportDateFilter.custom:
        if (customRange == null) return 'Custom';
        final f = DateFormat('d MMM yyyy');
        return '${f.format(customRange.start)} – ${f.format(customRange.end)}';
    }
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SingleChildScrollView(
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filters', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Obx(() => controller.hasActiveFilters
                        ? TextButton(
                            onPressed: controller.clearFilters,
                            child: const Text('Clear all', style: TextStyle(color: AppColors.brandRed, fontWeight: FontWeight.w700)),
                          )
                        : const SizedBox.shrink()),
                  ],
                ),
                const SizedBox(height: 8),
                const _SheetLabel('STATUS'),
                Obx(() {
                  final online = controller.connectivity.isOnline.value;
                  final options = online ? ReportsController.cloudStatusOptions : ReportsController.localStatusOptions;
                  final value = online ? controller.cloudStatusFilter.value : controller.filter.value;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((o) {
                      final selected = value == o;
                      return ChoiceChip(
                        label: Text(o),
                        selected: selected,
                        onSelected: (_) => online ? controller.setCloudStatusFilter(o) : controller.setFilter(o),
                        selectedColor: AppColors.brandRed,
                        labelStyle: TextStyle(color: selected ? Colors.white : AppColors.muted, fontWeight: FontWeight.w700, fontSize: 12.5),
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                      );
                    }).toList(),
                  );
                }),
                const SizedBox(height: 18),
                const _SheetLabel('DATE RANGE'),
                Obx(() => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final preset in ReportDateFilter.values.where((p) => p != ReportDateFilter.custom))
                          _presetChip(context, preset),
                        _customRangeChip(context),
                      ],
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _presetChip(BuildContext context, ReportDateFilter preset) {
    final selected = controller.dateFilter.value == preset;
    return ChoiceChip(
      label: Text(_dateFilterLabel(preset, null)),
      selected: selected,
      onSelected: (_) => controller.setDateFilter(preset),
      selectedColor: AppColors.brandRed,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.muted, fontWeight: FontWeight.w700, fontSize: 12.5),
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
    );
  }

  Widget _customRangeChip(BuildContext context) {
    final selected = controller.dateFilter.value == ReportDateFilter.custom;
    return ChoiceChip(
      avatar: const Icon(Icons.date_range, size: 16),
      label: Text(selected ? _dateFilterLabel(ReportDateFilter.custom, controller.customDateRange.value) : 'Custom Range'),
      selected: selected,
      onSelected: (_) async {
        final now = DateTime.now();
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 5),
          lastDate: now,
          initialDateRange: controller.customDateRange.value,
        );
        if (range != null) controller.setCustomDateRange(range);
      },
      selectedColor: AppColors.brandRed,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.muted, fontWeight: FontWeight.w700, fontSize: 12.5),
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted2, letterSpacing: 0.4)),
      );
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(color: AppColors.brandRedTint, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: AppColors.brandRed, fontWeight: FontWeight.w700, fontSize: 12)),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onClear,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: AppColors.brandRed),
            ),
          ),
        ],
      ),
    );
  }
}
