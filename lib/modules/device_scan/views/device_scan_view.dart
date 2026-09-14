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
      body: Column(
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
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: connecting ? null : () => controller.connect(device),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(color: connecting ? AppColors.brandRed : AppColors.border, width: connecting ? 1.5 : 1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(color: AppColors.brandRedTint, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.bluetooth, color: AppColors.brandRed),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(device.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                                  const SizedBox(height: 2),
                                  Text(
                                    connecting ? 'Connecting…' : (device.isBonded ? 'Previously paired' : 'Available'),
                                    style: TextStyle(
                                      color: connecting ? AppColors.brandRed : AppColors.muted2,
                                      fontWeight: connecting ? FontWeight.w700 : FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (connecting)
                              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
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
    );
  }
}
