import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/app_colors.dart';
import '../controllers/device_scan_controller.dart';

class DeviceScanView extends GetView<DeviceScanController> {
  const DeviceScanView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect ECG Device')),
      body: Stack(
        children: [
          Column(
            children: [
              Obx(() => controller.isScanning.value ? const LinearProgressIndicator(color: AppColors.brandRed) : const SizedBox.shrink()),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Turn on the device and keep it nearby. We’ll list any Dr.Cardio recorder in range.',
                  style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              Expanded(
                child: Obx(() {
                  if (controller.error.value != null) {
                    return Center(child: Text(controller.error.value!, style: const TextStyle(color: AppColors.error)));
                  }
                  if (controller.devices.isEmpty) {
                    return Center(
                      child: Text(controller.isScanning.value ? 'Scanning…' : 'No devices found yet.', style: const TextStyle(color: AppColors.muted)),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: controller.devices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final device = controller.devices[index];
                      final connecting = controller.connectingId.value == device.id;
                      final isConnected = controller.isCurrentlyConnected(device);
                      // Any connection attempt in progress locks the whole
                      // list, not just the tapped row — tapping a different
                      // device mid-connect would otherwise race two
                      // connect() calls against the same BluetoothService.
                      final locked = controller.connectingId.value != null;
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: locked ? null : () => controller.connect(device),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isConnected ? AppColors.success : (connecting ? AppColors.brandRed : AppColors.border),
                                width: isConnected || connecting ? 1.5 : 1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(color: AppColors.brandRedTint, borderRadius: BorderRadius.circular(12)),
                                  child: Icon(isConnected ? Icons.bluetooth_connected : Icons.bluetooth, color: AppColors.brandRed),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(device.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                                      const SizedBox(height: 2),
                                      Text(
                                        isConnected
                                            ? 'Connected'
                                            : connecting
                                                ? 'Connecting…'
                                                : (device.isBonded ? 'Previously paired' : 'Available'),
                                        style: TextStyle(
                                          color: isConnected ? AppColors.success : (connecting ? AppColors.brandRed : AppColors.muted2),
                                          fontWeight: isConnected || connecting ? FontWeight.w700 : FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (connecting)
                                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                                else if (isConnected)
                                  const Icon(Icons.check_circle, color: AppColors.success, size: 20)
                                else
                                  const Icon(Icons.chevron_right, color: AppColors.muted2, size: 17),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
          Obx(() {
            final id = controller.connectingId.value;
            if (id == null) return const SizedBox.shrink();
            final device = controller.devices.firstWhereOrNull((d) => d.id == id);
            return _ConnectingOverlay(deviceName: device?.name ?? 'device');
          }),
        ],
      ),
    );
  }
}

/// Full-screen blocking overlay while a connection attempt is in flight
/// (pairing can take several seconds if the device isn't already bonded)
/// — makes it unambiguous that the app is working, not stuck.
class _ConnectingOverlay extends StatelessWidget {
  const _ConnectingOverlay({required this.deviceName});
  final String deviceName;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: 1,
      child: Container(
        color: Colors.black.withOpacity(0.45),
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.brandRed),
              ),
              const SizedBox(height: 16),
              Text(
                'Connecting to $deviceName…',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
              const SizedBox(height: 4),
              const Text(
                'This can take a few seconds, especially the first time.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
