import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/services/bluetooth/bluetooth_service.dart';
import '../../../theme/app_colors.dart';
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
      // Registered alongside HomeController under the same HomeBinding, so
      // it's already alive by the time this tab renders.
      final isTestMode = Get.find<SettingsController>().testMode.value;

      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Image.asset(AppAssets.logoMark, width: 34, height: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('GOOD MORNING', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.muted2)),
                    Text(
                      controller.storage.userName.isEmpty ? 'Clinician' : controller.storage.userName,
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.brandRed,
                child: Text(
                  _initials(controller.storage.userName),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
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
              onTap: controller.connectDevice,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                child: connected
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
                                  style: TextStyle(color: AppColors.muted, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  controller.bluetoothService.connectedDeviceName.value,
                                  style: const TextStyle(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.w800),
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
                                    const Text('Change', style: TextStyle(color: AppColors.brandRed, fontSize: 12, fontWeight: FontWeight.w700)),
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
                                Text('No device connected', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink)),
                                SizedBox(height: 2),
                                Text('Tap to connect your ECG device', style: TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
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
          Opacity(
            opacity: connected ? 1 : 0.45,
            child: IgnorePointer(
              ignoring: !connected,
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
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16.5)),
                              const SizedBox(height: 2),
                              Text(
                                isTestMode ? 'Device calibration waveform · not a patient signal' : '12-lead capture · ~90 sec',
                                style: const TextStyle(color: Color(0xFFFBD9D2), fontSize: 12.5, fontWeight: FontWeight.w600),
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
                          style: const TextStyle(color: AppColors.pending, fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            );
          }),
          Obx(() {
            final recent = controller.recentRecords;
            if (recent.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('RECENT REPORTS',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted2, letterSpacing: 0.4)),
                    TextButton(
                      onPressed: controller.viewAllReports,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('View All', style: TextStyle(color: AppColors.brandRed, fontSize: 12.5, fontWeight: FontWeight.w800)),
                          Icon(Icons.chevron_right, color: AppColors.brandRed, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
}
