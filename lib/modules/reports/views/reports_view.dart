import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/models/ecg_record_model.dart';
import '../../../data/models/remote_report_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../pdf_viewer/controllers/pdf_viewer_controller.dart';
import '../controllers/reports_controller.dart';

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
              final cloud = controller.cloudRecords;
              if (items.isEmpty && cloud.isEmpty) {
                return Center(
                  child: Text(
                    controller.cloudError.value != null
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
                    _ReportTile(record: record),
                    const SizedBox(height: 10),
                  ],
                  if (cloud.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('From your account', style: Theme.of(context).textTheme.titleSmall),
                    ),
                    for (final report in cloud) ...[
                      _CloudReportTile(report: report),
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
  const _CloudReportTile({required this.report});
  final RemoteReportModel report;

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
          child: Row(
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
              const Icon(Icons.chevron_right, color: AppColors.muted2, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.record});
  final EcgRecordModel record;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Get.toNamed(AppRoutes.pdfViewer, arguments: record),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 34,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(9)),
                child: CustomPaint(painter: _MiniTracePainter(record.leadData.isNotEmpty ? record.leadData[1] : const [])),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.patient.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      '${record.patient.age} / ${record.patient.sex} · ${DateFormat('d MMM, h:mm a').format(record.dateTime)}',
                      style: const TextStyle(color: AppColors.muted2, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: record.syncStatus),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: AppColors.muted2, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    late Color fg, bg;
    late String label;
    switch (status) {
      case SyncStatus.synced:
        fg = AppColors.success;
        bg = AppColors.successBg;
        label = 'Synced';
        break;
      case SyncStatus.pending:
        fg = AppColors.pending;
        bg = AppColors.pendingBg;
        label = 'Pending';
        break;
      case SyncStatus.failed:
      case SyncStatus.offline:
        fg = AppColors.offline;
        bg = AppColors.offlineBg;
        label = 'Offline';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
  }
}

class _MiniTracePainter extends CustomPainter {
  _MiniTracePainter(this.samples);
  final List<double> samples;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final paint = Paint()
      ..color = AppColors.monitorTrace
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final path = Path();
    final window = samples.length > 60 ? samples.sublist(samples.length - 60) : samples;
    final dx = size.width / window.length;
    final midY = size.height / 2;
    for (var i = 0; i < window.length; i++) {
      final x = i * dx;
      final y = midY - (window[i] * 8).clamp(-midY, midY);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniTracePainter oldDelegate) => oldDelegate.samples != samples;
}
