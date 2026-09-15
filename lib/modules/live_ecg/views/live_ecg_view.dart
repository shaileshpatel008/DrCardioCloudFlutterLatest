import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/ecg/ecg_data.dart';
import '../../../theme/app_colors.dart';
import '../controllers/live_ecg_controller.dart';
import '../widgets/ecg_lead_chart.dart';

const _leadStatusLabels = ['V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'Left Leg', 'Right Leg', 'Left Arm', 'Right Arm'];

class LiveEcgView extends GetView<LiveEcgController> {
  const LiveEcgView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151312),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(controller.patient.name, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800)),
                        Text('ID ${controller.patient.patientId} · ${controller.patient.age} / ${controller.patient.sex}',
                            style: const TextStyle(color: Color(0xFF9A928E), fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (controller.isTestMode) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.brandRed.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
                      child: const Text('TEST MODE',
                          style: TextStyle(color: AppColors.brandRed, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Obx(() => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.monitorTrace.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.monitorTrace, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(_formatElapsed(controller.elapsedSeconds.value),
                                style: const TextStyle(color: AppColors.monitorTrace, fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            ValueListenableBuilder<List<bool>>(
              valueListenable: controller.leadStatus,
              builder: (context, status, _) {
                // Port of `DataHandlerThread.SHOW_LEAD_STATUS &&
                // test_mode==false`: a fixed calibration waveform has no
                // real electrodes to report on, so lead-off warnings are
                // meaningless (and would just be noise) in Test Mode.
                if (controller.isTestMode) return const SizedBox.shrink();
                final off = <String>[];
                for (var i = 0; i < status.length && i < _leadStatusLabels.length; i++) {
                  if (!status[i]) off.add(_leadStatusLabels[i]);
                }
                if (off.isEmpty || !controller.isReading.value) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.brandRed.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.brandRed, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Electrode off: ${off.join(', ')}',
                            style: const TextStyle(color: AppColors.brandRed, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: controller.revision,
                builder: (context, _, __) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFF0E2A28), borderRadius: BorderRadius.circular(16)),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: EcgData.noOfChannels,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            childAspectRatio: 1.85,
                          ),
                          itemBuilder: (context, index) => EcgLeadChart(leadIndex: index, visibleSamples: EcgData.instance.displayDataRangeX),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFF0E2A28), borderRadius: BorderRadius.circular(14)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 4),
                              child: Text('RHYTHM · LEAD II',
                                  style: TextStyle(color: AppColors.monitorTrace, fontSize: 10.5, fontWeight: FontWeight.w700)),
                            ),
                            EcgLeadChart(leadIndex: 1, visibleSamples: EcgData.instance.displayDataRangeX, height: 90, showLabel: false),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Obx(() => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ControlButton(
                        icon: Icons.play_arrow,
                        label: 'Start',
                        enabled: !controller.isReading.value,
                        onTap: controller.startRecording,
                        primary: !controller.isReading.value,
                      ),
                      _ControlButton(
                        icon: Icons.stop,
                        label: 'Stop',
                        enabled: controller.isReading.value,
                        onTap: controller.stopRecording,
                        primary: controller.isReading.value,
                        pulsing: controller.isReading.value,
                      ),
                      _ControlButton(
                        icon: Icons.save_outlined,
                        label: 'Save',
                        enabled: !controller.isReading.value && !controller.isSaving.value && EcgData.instance.rawDataCount > 0,
                        onTap: controller.saveAndExit,
                        loading: controller.isSaving.value,
                      ),
                    ],
                  )),
            ),
          ],
        ),
      ),
    );
  }

  String _formatElapsed(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.primary = false,
    this.pulsing = false,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool primary;
  final bool pulsing;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final size = primary ? 72.0 : 52.0;
    return Column(
      children: [
        Opacity(
          opacity: enabled ? 1 : 0.4,
          child: InkWell(
            borderRadius: BorderRadius.circular(size / 2),
            onTap: enabled ? onTap : null,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: primary ? AppColors.brandRed : Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(icon, color: Colors.white, size: primary ? 28 : 20),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
