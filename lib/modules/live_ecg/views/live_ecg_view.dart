import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/services/ecg/ecg_data.dart';
import '../../../core/widgets/app_confirm_sheet.dart';
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // This screen has no AppBar to carry its own status-bar style, so
      // without this it would inherit the app-wide default of dark icons —
      // invisible against this screen's near-black background.
      value: SystemUiOverlayStyle.light,
      child: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack(context);
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
                      onPressed: () => _handleBack(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Obx(() {
                      // Empty when opened via Settings' "Patient info
                      // before recording" off — the patient is collected
                      // after Stop/Save instead of before this screen ever
                      // opens, so there's nothing to show here yet.
                      final name = controller.patient.value.name;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.isEmpty ? 'New Recording' : name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                          if (name.isNotEmpty)
                            Text('ID ${controller.patient.value.patientId} · ${controller.patient.value.age} / ${controller.patient.value.sex}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF9A928E), fontSize: 11, fontWeight: FontWeight.w600))
                          else
                            const Text('Patient details added after saving',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Color(0xFF9A928E), fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      );
                    }),
                  ),
                  const SizedBox(width: 6),
                  if (controller.isLoadedMode)
                    const _Chip(label: 'LOADED', color: AppColors.monitorTrace, icon: Icons.folder_open_outlined)
                  else if (controller.isTestMode)
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
                  // Filter/Gain only affect samples as they're being
                  // captured — loaded data is already filtered, so
                  // reopening this here would change nothing and just
                  // mislead.
                  if (!controller.isLoadedMode)
                    IconButton(
                      onPressed: () => _showAcquisitionSettingsSheet(context),
                      icon: const Icon(Icons.tune, color: Colors.white70, size: 20),
                      tooltip: 'Filter & Gain',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 6),
                  if (controller.isLoadedMode)
                    _Chip(label: _formatDate(controller.loadedRecord!.dateTime), color: AppColors.monitorTrace, icon: Icons.event_outlined)
                  else
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
                            child: EcgLeadChart(
                              leadIndex: index,
                              visibleSamples: EcgData.instance.displayDataRangeX,
                              // Test Mode's fixed calibration waveform has no
                              // real electrodes to report on (same condition
                              // as the lead-off banner above), and a lead
                              // only reads as off while actively capturing.
                              isOff: controller.isReading.value &&
                                  !controller.isTestMode &&
                                  EcgData.instance.isLeadOff(index),
                            ),
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
                      EcgLeadChart(
                        leadIndex: 1,
                        visibleSamples: EcgData.instance.displayDataRangeX,
                        height: 90,
                        showLabel: false,
                        isOff: controller.isReading.value && !controller.isTestMode && EcgData.instance.isLeadOff(1),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
              // isLoadedMode never changes over this screen's lifetime, so
              // the branch itself stays outside any Obx — each branch
              // widget owns whatever reactivity it needs internally.
              child: Center(
                child: controller.isLoadedMode
                    // Both buttons now carry their own label — bare icons
                    // for "edit" vs "save" looked almost identical and
                    // didn't communicate what either one did.
                    ? _LoadedModeActions(controller: controller)
                    // Shows exactly one primary action at a time (Start,
                    // Stop or Save) instead of all three sitting side by
                    // side at equal weight the whole time — a first-time
                    // user had no cue, once a recording stopped, that the
                    // next step was to tap Save. Button taps and
                    // validation (the 20s minimum, etc.) are unchanged;
                    // only what's visible and how it's emphasized is.
                    : _LiveControlFlow(controller: controller),
              ),
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }

  /// Port of `NewEcgActivity.onBackPressed()`: pop straight back when
  /// nothing is being captured, otherwise confirm first so a recording in
  /// progress isn't discarded by an accidental back-press.
  Future<void> _handleBack(BuildContext context) async {
    if (!controller.isReading.value) {
      Get.back();
      return;
    }
    final confirmed = await AppConfirmSheet.show(
      context,
      icon: Icons.stop_circle_outlined,
      title: 'Stop Reading?',
      message: 'Are you sure you want to stop reading and return to main screen?',
      confirmText: 'Yes, Stop',
      isDismissible: false,
    );
    if (confirmed) {
      controller.stopRecording();
      Get.back(); // leave the screen
    }
  }

  String _formatElapsed(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDate(DateTime dateTime) => DateFormat('d MMM, h:mm a').format(dateTime);

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

/// Loaded Data's two actions — "Edit Patient" and "Save" — each carrying
/// its own label. Bare icons for these two looked near-identical and
/// didn't communicate what either one did; Edit Patient stays a plain
/// secondary pill while Save mirrors [_StoppedState]'s Save Report button
/// (green once actionable, i.e. whenever not already mid-save — Loaded
/// Data has no minimum-duration gate, so `canSave` is only ever false
/// while `isSaving` is true).
class _LoadedModeActions extends StatelessWidget {
  const _LoadedModeActions({required this.controller});
  final LiveEcgController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: controller.changePatientData,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(999)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Edit Patient', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Obx(() {
          final ready = controller.canSave;
          final saving = controller.isSaving.value;
          return InkWell(
            borderRadius: BorderRadius.circular(28),
            // Always tappable, even mid-save-attempt race — handleSaveTap()
            // is a no-op by then anyway; only an actual in-flight save
            // (isSaving) disables the tap, same as the Save Report button.
            onTap: saving ? null : controller.handleSaveTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
              decoration: BoxDecoration(
                color: ready ? _kReadyGreen : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (saving)
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  else
                    Icon(Icons.save_outlined, color: ready ? _kReadyGreenInk : Colors.white, size: 19),
                  const SizedBox(width: 9),
                  Text('Save', style: TextStyle(color: ready ? _kReadyGreenInk : Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

const _kMutedCaption = Color(0xFF70686F);
const _kReadyGreen = Color(0xFF3DDC84);
const _kReadyGreenInk = Color(0xFF0E2A1B);

/// Picks which of [_IdleState]/[_RecordingState]/[_StoppedState] to show —
/// the entire reason this exists is that `recordedSeconds` (cumulative
/// across every Start/Stop this screen visit) only ever needs checking
/// right when [LiveEcgController.isReading] flips, so one outer `Obx` on
/// that is enough to pick the branch; each branch below owns its own
/// `Obx` for anything that needs finer-grained ticking (the ring, the
/// Save spinner).
class _LiveControlFlow extends StatelessWidget {
  const _LiveControlFlow({required this.controller});
  final LiveEcgController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isReading.value) return _RecordingState(controller: controller);
      if (controller.recordedSeconds > 0) return _StoppedState(controller: controller);
      return _IdleState(controller: controller);
    });
  }
}

/// Nothing captured yet — only Start is shown. Stop and Save would do
/// nothing right now, so they're left off entirely instead of sitting
/// there dimmed.
class _IdleState extends StatelessWidget {
  const _IdleState({required this.controller});
  final LiveEcgController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: controller.startRecording,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            decoration: BoxDecoration(color: AppColors.brandRed, borderRadius: BorderRadius.circular(999)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow, color: Colors.white, size: 20),
                SizedBox(width: 9),
                Text('Start Recording', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Attach the leads, then tap Start', style: TextStyle(color: _kMutedCaption, fontSize: 10.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Capturing — only Stop is shown, ringed by an animated progress
/// indicator counting the minimum recording window down (port of
/// `NewEcgActivity.min_saved_seconds`'s "the original just silently
/// withheld the report" problem). Starts full the moment a recording
/// begins and drains to empty once [LiveEcgController.minRecordingSeconds]
/// is reached, turning green to match [_StoppedState]'s "ready" color
/// once it does.
class _RecordingState extends StatelessWidget {
  const _RecordingState({required this.controller});
  final LiveEcgController controller;

  static const _size = 54.0;
  static const _ringSize = 70.0;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // recordedSeconds itself isn't Rx (it's derived from a plain
      // EcgData field) — reading elapsedSeconds here just gives this Obx
      // a once-a-second Rx tick to rebuild on while recording, so the
      // ring animates continuously instead of only jumping at Start/Stop.
      controller.elapsedSeconds.value;
      final remaining = (1 - controller.recordedSeconds / LiveEcgController.minRecordingSeconds).clamp(0.0, 1.0);
      final reachedMinimum = controller.recordedSeconds >= LiveEcgController.minRecordingSeconds;
      return Column(
        mainAxisSize: MainAxisSize.min,
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
                    tween: Tween(begin: 1, end: remaining),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, animatedValue, _) => CircularProgressIndicator(
                      value: animatedValue,
                      strokeWidth: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation(reachedMinimum ? _kReadyGreen : AppColors.brandRed),
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(_size / 2),
                  onTap: controller.stopRecording,
                  child: Container(
                    width: _size,
                    height: _size,
                    decoration: const BoxDecoration(color: AppColors.brandRed, shape: BoxShape.circle),
                    child: const Icon(Icons.stop, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text('Recording - needs at least ${LiveEcgController.minRecordingSeconds}s',
              style: TextStyle(color: _kMutedCaption, fontSize: 10.5, fontWeight: FontWeight.w600)),
        ],
      );
    });
  }
}

/// Stopped, with something captured — a confirmation banner appears
/// immediately (green once the minimum duration was met, red/amber if
/// the recording was too short) and Save becomes a big labeled button,
/// unmistakable instead of one small icon among three. Start recedes to
/// a small "Record again" icon next to it — still one tap away for a
/// retake, never removed. Tapping Save before the minimum, or while
/// still recording, still surfaces the same explanatory toast as before
/// (see `LiveEcgController.handleSaveTap()`) — this only changes what's
/// visible and how much weight each action carries.
class _StoppedState extends StatelessWidget {
  const _StoppedState({required this.controller});
  final LiveEcgController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ready = controller.canSave;
      final saving = controller.isSaving.value;
      final tint = ready ? _kReadyGreen : AppColors.brandRed;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: tint.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(ready ? Icons.check_circle_outline : Icons.warning_amber_rounded, color: tint, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    ready
                        ? 'Recording captured - tap Save to generate the report'
                        : 'Recording too short - needs at least ${LiveEcgController.minRecordingSeconds}s',
                    style: TextStyle(color: tint, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Record again',
                child: InkWell(
                  borderRadius: BorderRadius.circular(21),
                  onTap: controller.startRecording,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
                    child: const Icon(Icons.refresh, color: Colors.white, size: 19),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Opacity(
                opacity: ready ? 1 : 0.5,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  // Always tappable, even while dimmed/"not ready" — a
                  // disabled (onTap: null) button here just did nothing
                  // when tapped, which looked broken. handleSaveTap()
                  // tells the user why instead.
                  onTap: saving ? null : controller.handleSaveTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                    decoration: BoxDecoration(
                      color: ready ? _kReadyGreen : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (saving)
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        else
                          Icon(Icons.save_outlined, color: ready ? _kReadyGreenInk : Colors.white, size: 19),
                        const SizedBox(width: 9),
                        Text('Save Report',
                            style: TextStyle(color: ready ? _kReadyGreenInk : Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    });
  }
}
