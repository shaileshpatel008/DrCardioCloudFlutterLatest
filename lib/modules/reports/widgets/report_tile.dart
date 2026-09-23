import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/models/ecg_record_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';

/// One saved recording's row — shared between the Reports tab's full
/// list and Home's "Recent Reports" preview, so both stay visually
/// identical without duplicating this markup.
class ReportTile extends StatelessWidget {
  const ReportTile({super.key, required this.record, this.onShare});
  final EcgRecordModel record;

  /// Port of `ReportActivity`'s per-report "Share" action
  /// (`downloadAndSharePDF`) — null hides the share button entirely
  /// (Home's "Recent Reports" preview keeps the row compact; Reports'
  /// own list passes a callback).
  final VoidCallback? onShare;

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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
          ),
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
                    Text(record.patient.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      '${record.patient.age} / ${record.patient.sex} · ${DateFormat('d MMM, h:mm a').format(record.dateTime)}',
                      style: const TextStyle(color: AppColors.muted2, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: record.syncStatus),
              if (onShare != null) ...[
                const SizedBox(width: 2),
                IconButton(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded, size: 17, color: AppColors.muted),
                  tooltip: 'Share',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
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
      child: Text(label, style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.w600)),
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
