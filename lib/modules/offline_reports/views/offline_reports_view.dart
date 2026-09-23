import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/models/ecg_record_model.dart';
import '../../../theme/app_colors.dart';
import '../controllers/offline_reports_controller.dart';

class OfflineReportsView extends GetView<OfflineReportsController> {
  const OfflineReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Offline Reports')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(() {
            if (controller.connectivity.isOnline.value) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: AppColors.pendingBg, border: Border.all(color: const Color(0xFFFBE1BB)), borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: AppColors.pending, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Obx(() => Text(
                          'No internet connection — ${controller.pending.length} report${controller.pending.length == 1 ? '' : 's'} queued to sync',
                          style: const TextStyle(color: Color(0xFF8A5000), fontWeight: FontWeight.w700, fontSize: 12.5),
                        )),
                  ),
                ],
              ),
            );
          }),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text('PENDING UPLOAD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted2, letterSpacing: 0.4)),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) return const Center(child: CircularProgressIndicator());
              if (controller.pending.isEmpty) {
                return const Center(child: Text('Nothing waiting to sync.', style: TextStyle(color: AppColors.muted)));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: controller.pending.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _PendingTile(record: controller.pending[index], onRetry: controller.retryOne),
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Obx(() => FilledButton.icon(
                  onPressed: controller.isRetrying.value ? null : controller.retryAll,
                  icon: controller.isRetrying.value
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync),
                  label: Text('Retry All (${controller.pending.length})'),
                )),
          ),
        ],
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.record, required this.onRetry});
  final EcgRecordModel record;
  final void Function(EcgRecordModel) onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = record.syncStatus == SyncStatus.failed;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: failed ? AppColors.errorBg : AppColors.pendingBg, borderRadius: BorderRadius.circular(11)),
            child: Icon(failed ? Icons.error_outline : Icons.cloud_upload_outlined, color: failed ? AppColors.error : AppColors.pending, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.patient.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  failed ? 'Upload failed · tap retry' : '${DateFormat('d MMM, h:mm a').format(record.dateTime)} · Waiting for network',
                  style: TextStyle(color: failed ? AppColors.error : AppColors.muted2, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => onRetry(record),
            icon: const Icon(Icons.refresh, color: AppColors.brandRed),
            style: IconButton.styleFrom(backgroundColor: AppColors.brandRedTint),
          ),
        ],
      ),
    );
  }
}
