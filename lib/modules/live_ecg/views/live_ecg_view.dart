import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/ecg/ecg_data.dart';
import '../../../theme/app_colors.dart';
import '../../settings/controllers/settings_controller.dart';
import '../controllers/live_ecg_controller.dart';
import '../widgets/ecg_lead_chart.dart';

const _leadStatusLabels = ['V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'Left Leg', 'Right Leg', 'Left Arm', 'Right Arm'];

/// Rhythm strip is disabled, not removed — flip this back to `true` to
/// bring it back. Requested to be hidden for now to give the single-column
/// 12-lead stack the full remaining screen height, same as the original
/// app's layout (which never had a rhythm strip on this screen at all).
const _kShowRhythmStrip = false;

class LiveEcgView extends GetView<LiveEcgController> {
  const LiveEcgView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF151312),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _handleBack,
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(controller.patient.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                        Text('ID ${controller.patient.patientId} · ${controller.patient.age} / ${controller.patient.sex}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF9A928E), fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (controller.isTestMode)
                    const _Chip(label: 'TEST MODE', color: AppColors.brandRed)
                  else
                    ValueListenableBuilder<int?>(
                      valueListenable: controller.heartRateBpm,
                      builder: (context, bpm, _) {
                        if (bpm == null) return const SizedBox.shrink();
                        return _Chip(label: '$bpm bpm', color: AppColors.monitorTrace, icon: Icons.favorite);
                      },
                    ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => _showAcquisitionSettingsSheet(context),
                    icon: const Icon(Icons.tune, color: Colors.white70, size: 20),
                    tooltip: 'Filter & Gain',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 6),
                  Obx(() => _Chip(
                        label: _formatElapsed(controller.elapsedSeconds.value),
                        color: AppColors.monitorTrace,
                        dot: true,
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
                  margin: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.brandRed.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.brandRed, size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Electrode off: ${off.join(', ')}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.brandRed, fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Single-column, full-remaining-height stack of all 12 leads —
            // matches `act_new_ecg.xml`'s graph_container (a vertical
            // LinearLayout, weightSum=12, each chart layout_weight=1,
            // layout_height=match_parent) instead of the boxed 3-column
            // grid this screen used to show.
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: controller.revision,
                builder: (context, _, __) {
                  return Container(
                    margin: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF0E2A28), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: List.generate(
                        EcgData.noOfChannels,
                        (index) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1.5),
                            child: EcgLeadChart(leadIndex: index, visibleSamples: EcgData.instance.displayDataRangeX),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_kShowRhythmStrip)
              ValueListenableBuilder<int>(
                valueListenable: controller.revision,
                builder: (context, _, __) => Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
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
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 20),
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
                      _SaveButton(controller: controller),
                    ],
                  )),
            ),
          ],
        ),
      ),
      ),
    );
  }

  /// Port of `NewEcgActivity.onBackPressed()`: pop straight back when
  /// nothing is being captured, otherwise confirm first so a recording in
  /// progress isn't discarded by an accidental back-press.
  void _handleBack() {
    if (!controller.isReading.value) {
      Get.back();
      return;
    }
    Get.dialog(
      AlertDialog(
        title: const Text('Are you sure you want to stop reading and return to main screen?'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('No')),
          TextButton(
            onPressed: () {
              Get.back(); // dismiss the dialog
              controller.stopRecording();
              Get.back(); // leave the screen
            },
            child: const Text('Yes'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  String _formatElapsed(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showAcquisitionSettingsSheet(BuildContext context) {
    final settings = Get.find<SettingsController>();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1B1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const Text('Acquisition Settings', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                Obx(() => _SheetDropdownRow(
                      label: 'Filter',
                      value: settings.filter.value,
                      options: SettingsController.filterOptions,
                      onChanged: controller.changeFilter,
                    )),
                const SizedBox(height: 10),
                Obx(() => _SheetDropdownRow(
                      label: 'Gain',
                      value: settings.gain.value,
                      options: SettingsController.gainOptions,
                      onChanged: controller.changeGain,
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, this.icon, this.dot = false});
  final String label;
  final Color color;
  final IconData? icon;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ] else if (icon != null) ...[
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

class _SheetDropdownRow extends StatelessWidget {
  const _SheetDropdownRow({required this.label, required this.value, required this.options, required this.onChanged});
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
        DropdownButton<String>(
          value: options.contains(value) ? value : options.first,
          dropdownColor: const Color(0xFF262524),
          underline: const SizedBox.shrink(),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(color: AppColors.brandRed, fontWeight: FontWeight.w700))))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
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

/// Save, ringed by an animated progress indicator that fills over the
/// minimum recording window (port of `NewEcgActivity.min_saved_seconds`
/// — the original just silently withheld the report; this makes the wait
/// visible instead of leaving Save looking randomly disabled).
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.controller});
  final LiveEcgController controller;

  static const _size = 52.0;
  static const _ringSize = 64.0;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // recordedSeconds itself isn't Rx (it's derived from a plain
      // EcgData field) — reading elapsedSeconds here just gives this Obx
      // a once-a-second Rx tick to rebuild on while recording, so the
      // ring animates continuously instead of only jumping at Start/Stop.
      controller.elapsedSeconds.value;
      final progress = (controller.recordedSeconds / LiveEcgController.minRecordingSeconds).clamp(0.0, 1.0);
      final ready = controller.canSave;
      return Column(
        children: [
          SizedBox(
            width: _ringSize,
            height: _ringSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: _ringSize,
                  height: _ringSize,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, animatedProgress, _) => CircularProgressIndicator(
                      value: animatedProgress,
                      strokeWidth: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation(ready ? const Color(0xFF3DDC84) : AppColors.brandRed),
                    ),
                  ),
                ),
                Opacity(
                  opacity: ready ? 1 : 0.4,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(_size / 2),
                    onTap: ready ? controller.saveAndExit : null,
                    child: Container(
                      width: _size,
                      height: _size,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
                      child: Center(
                        child: controller.isSaving.value
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_outlined, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ready ? 'Save' : 'Save · ${controller.secondsUntilSaveReady}s',
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      );
    });
  }
}
