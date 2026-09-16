import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/services/record_file_naming.dart';
import '../../../data/models/remote_report_model.dart';
import '../../../theme/app_colors.dart';

/// One server-side ("From your account") report's row — shared between
/// the Reports tab's full list and Home's "Recent Reports" preview, same
/// as [ReportTile] is for local records.
///
/// `api/ecg-list` never sends patient/age/sex fields for this
/// account-wide list (only document_name/status/assign flag), but
/// document_name is built with the same "<name>_<timestamp>" shape a
/// local record's file is, so this recovers a real name + time instead of
/// showing the raw filename.
class CloudReportTile extends StatelessWidget {
  const CloudReportTile({super.key, required this.report, required this.onTap, this.onShare, this.onAssign, this.assigningIds});
  final RemoteReportModel report;
  final VoidCallback onTap;

  /// Null hides the share button — Home's preview keeps the row compact.
  final VoidCallback? onShare;

  /// Null hides the "Send to Cardiologist" action entirely, regardless of
  /// [RemoteReportModel.assignedToCardiologist] — same compact-preview
  /// reasoning as [onShare].
  final VoidCallback? onAssign;

  /// Required alongside [onAssign] so the button can show its own
  /// in-flight state; unused when [onAssign] is null.
  final RxSet<String>? assigningIds;

  @override
  Widget build(BuildContext context) {
    final parsed = RecordFileNaming.parse(report.documentName);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
          ),
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
                  if (onShare != null) ...[
                    IconButton(
                      onPressed: onShare,
                      icon: const Icon(Icons.ios_share_rounded, size: 17, color: AppColors.muted),
                      tooltip: 'Share',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 6),
                  ],
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
              if (onAssign != null && !report.assignedToCardiologist) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  // A plain Material/InkWell pill, not OutlinedButton: the
                  // app's global OutlinedButtonThemeData forces
                  // minimumSize: Size.fromHeight(52) (full-width, 52 tall)
                  // for the app's primary outlined buttons, and that theme
                  // wins over a per-call minimumSize override — this
                  // sidesteps it entirely instead of fighting it.
                  child: Obx(() {
                    final assigning = assigningIds?.contains(report.ecgRecordId) ?? false;
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
