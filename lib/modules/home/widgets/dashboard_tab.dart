import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/services/bluetooth/bluetooth_service.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
import '../../pdf_viewer/controllers/pdf_viewer_controller.dart';
import '../../reports/widgets/cloud_report_tile.dart';
import '../../reports/widgets/report_tile.dart';
import '../../settings/controllers/settings_controller.dart';
import '../controllers/home_controller.dart';
import 'ripple_pulse.dart';

/// The "New ECG" dashboard tab: device-connection card + primary CTA +
/// a Recent Reports preview.
///
/// Per the approved redesign, the device-status card is now a calm,
/// neutral white card in BOTH connected and disconnected states — the
/// bold red gradient used to be spent on connection status too, which
/// made it and the primary CTA below blend into each other with no
/// hierarchy. Red is now reserved for the one thing that should draw the
/// eye: the CTA. The whole status card (not just the icon or the
/// "Change" chip) is a single tap target through to Device Scan, in both
/// states — previously the disconnected ripple icon and the connected
/// "Change device" button were two separate, much smaller targets.
class DashboardTab extends GetView<HomeController> {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = controller.bluetoothService.state.value;
      final connected = state == BtConnectionState.connected;
      // Distinguished from "disconnected" so a connection attempt in
      // progress reads as "Connecting…" instead of the misleading "No
      // device connected" — a connect() call can legitimately take a few
      // seconds (bonding, service discovery), and lumping it in with
      // "disconnected" made it look like nothing was happening at all.
      final connecting = state == BtConnectionState.connecting;
      // Registered alongside HomeController under the same HomeBinding, so
      // it's already alive by the time this tab renders.
      final isTestMode = Get.find<SettingsController>().testMode.value;

      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppColors.brandRedTint, borderRadius: BorderRadius.circular(13)),
                alignment: Alignment.center,
                child: Image.asset(AppAssets.logoMark, width: 24, height: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.muted2)),
                    Text(
                      controller.storage.userName.isEmpty ? 'Clinician' : controller.storage.userName,
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                  ],
                ),
              ),
              if (controller.reportLimitEnabled.value) ...[
                _EcgLeftBadge(count: controller.reportLimit.value),
                const SizedBox(width: 10),
              ],
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.brandRed,
                child: Text(
                  _initials(controller.storage.userName),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              // While a connection attempt is already in flight, opening
              // Device Scan again would let a second connect() race the
              // first one against the same BluetoothService.
              onTap: connecting ? null : controller.connectDevice,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  // Connected reads at a glance from the border color alone
                  // (green) instead of needing to read the "DEVICE
                  // CONNECTED" label — background stays plain white either
                  // way, so it never competes with the red CTA below it.
                  border: Border.all(
                    color: connected ? AppColors.success : (connecting ? AppColors.brandRed : AppColors.border),
                    width: connected || connecting ? 1.6 : 1,
                  ),
                  boxShadow: connected || connecting
                      ? [BoxShadow(color: AppColors.ink.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))]
                      : null,
                ),
                child: connecting
                    ? Row(
                        children: [
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.brandRed),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Connecting…', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.ink)),
                                SizedBox(height: 2),
                                Text('Reaching your ECG device', style: TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      )
                    : connected
                        ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              const Text('DEVICE CONNECTED',
                                  style: TextStyle(color: AppColors.muted, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  controller.bluetoothService.connectedDeviceName.value,
                                  style: const TextStyle(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(color: AppColors.brandRedTint, borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.swap_horiz, size: 16, color: AppColors.brandRed),
                                    const SizedBox(width: 6),
                                    const Text('Change', style: TextStyle(color: AppColors.brandRed, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          RipplePulse(
                            color: AppColors.brandRed,
                            size: 44,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(color: AppColors.brandRed, shape: BoxShape.circle),
                              child: const Icon(Icons.bluetooth, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('No device connected', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.ink)),
                                SizedBox(height: 2),
                                Text('Tap to connect your ECG device', style: TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.muted2, size: 18),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Dimmed (not disabled) when nothing's connected — still tappable,
          // same as the original app's "Acquire New ECG": tapping this
          // without a connected device jumps straight to Device Scan
          // instead of doing nothing (see HomeController.startNewEcg()).
          Opacity(
            opacity: connected ? 1 : 0.45,
            child: Material(
              color: AppColors.brandRed,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: controller.startNewEcg,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
                        child: Icon(isTestMode ? Icons.science_outlined : Icons.add, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isTestMode ? 'Test ECG Recording' : 'New ECG Recording',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16.5)),
                            const SizedBox(height: 2),
                            Text(
                              isTestMode ? 'Device calibration waveform · not a patient signal' : '12-lead capture · ~90 sec',
                              style: const TextStyle(color: Color(0xFFFBD9D2), fontSize: 12.5, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Obx(() {
            final pending = controller.pendingSyncCount.value;
            if (pending == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.pendingBg, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, color: AppColors.pending, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('$pending recording${pending == 1 ? '' : 's'} waiting to sync',
                          style: const TextStyle(color: AppColors.pending, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            );
          }),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('RECENT REPORTS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted2, letterSpacing: 0.4)),
              TextButton(
                onPressed: controller.viewAllReports,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View All', style: TextStyle(color: AppColors.brandRed, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    Icon(Icons.chevron_right, color: AppColors.brandRed, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Obx(() {
            // Same exclusive online/offline source as the Reports tab —
            // online previews the account's server history, offline
            // previews this device's own saved recordings, never both.
            if (controller.connectivity.isOnline.value) {
              final recent = controller.recentCloudRecords;
              if (recent.isEmpty) {
                return const _EmptyRecentReports(message: 'No reports found for your account yet.');
              }
              return Column(
                children: [
                  for (final report in recent) ...[
                    CloudReportTile(
                      report: report,
                      onTap: () => Get.toNamed(
                        AppRoutes.pdfViewer,
                        arguments: RemotePdfArgs(url: report.documentPath, fileName: '${report.documentName}.pdf'),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            }

            final recent = controller.recentRecords;
            if (recent.isEmpty) {
              return const _EmptyRecentReports(message: 'Your saved ECGs will show up here.');
            }
            return Column(
              children: [
                for (final record in recent) ...[
                  ReportTile(record: record),
                  const SizedBox(height: 10),
                ],
              ],
            );
          }),
        ],
      );
    });
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  /// Was hardcoded to "GOOD MORNING" regardless of when the app was opened.
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }
}

class _EmptyRecentReports extends StatelessWidget {
  const _EmptyRecentReports({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          const Icon(Icons.description_outlined, color: AppColors.muted2, size: 28),
          const SizedBox(height: 10),
          const Text('No recordings yet.', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 13.5)),
          const SizedBox(height: 3),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted2, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Port of `MainActivity`'s "ECG Left" plan-count indicator
/// (`layout_plan_count`/`tvCount`) — redesigned from a bulky red square
/// (which read like a warning stamp sitting next to the avatar) into a
/// slim pill that sits naturally in the header row instead of competing
/// with it.
class _EcgLeftBadge extends StatelessWidget {
  const _EcgLeftBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 7, 10, 7),
      decoration: BoxDecoration(color: AppColors.brandRedTint, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monitor_heart_outlined, size: 15, color: AppColors.brandRed),
          const SizedBox(width: 5),
          Text('$count', style: const TextStyle(color: AppColors.brandRedDark, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 3),
          Text('LEFT', style: TextStyle(color: AppColors.brandRed.withValues(alpha: 0.75), fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        ],
      ),
    );
  }
}
