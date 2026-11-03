import 'dart:math';

import 'ecg_data.dart';

/// One suspected electrode-placement problem, named by which physical
/// electrodes are likely involved (not which displayed leads — a
/// technician fixes this by moving stickers, not by relabeling a chart).
class LeadPlacementWarning {
  const LeadPlacementWarning({required this.title, required this.message, required this.electrodes});

  final String title;
  final String message;
  final List<String> electrodes;
}

/// Flags ECGs that look like two electrodes were swapped on the patient —
/// a technician error, not an app bug — so a report generated from a
/// misplaced lead carries its own caveat instead of silently looking
/// "wrong" to whoever reads it later.
///
/// There is no ground truth to compare against (we never know the
/// patient's real anatomy), so this can only work off textbook signal
/// patterns well-documented clinically:
///
///  - Left Arm/Right Arm swap: lead I inverts and aVR turns upright — aVR
///    is normally the most negative lead on the whole chart, so a positive
///    aVR combined with a negative lead I is the single most-cited sign of
///    this specific swap in the literature.
///  - Right Arm/Left Leg swap: lead II inverts while lead I stays normal.
///  - Left Arm/Left Leg swap: lead III inverts while I and II stay normal.
///  - A chest (V1-V6) electrode swap: R-wave size is supposed to climb
///    fairly steadily from V1 to V6. A single lead whose R-wave suddenly
///    dips below both neighbours is the classic sign two adjacent chest
///    stickers were swapped.
///
/// None of these are certainties — a real lateral MI, dextrocardia, or
/// just an unusual but healthy heart can produce a similar-looking pattern
/// — so this is reported as an advisory for a human to double check, the
/// same way commercial ECG carts flag "suspect lead reversal" rather than
/// silently correcting it.
class LeadPlacementChecker {
  LeadPlacementChecker._();

  /// Below this many detected beats, amplitude medians are too noisy to
  /// say anything useful — stay silent rather than guess.
  static const int minBeats = 4;

  /// A disconnected electrode's raw input floats and rails to noise —
  /// [LeadPlacementChecker] has no way to tell that noise apart from a
  /// genuinely inverted lead, and I/II/III/aVR/aVL/aVF all share the same
  /// three limb electrodes, so one loose electrode could otherwise fire
  /// several false "swap" warnings at once. [electrodeStatus] (same
  /// convention as `EcgData.leadStatus`: index 0-5 = V1-V6, 6 = Left Leg,
  /// 7 = Right Leg, 8 = Left Arm, 9 = Right Arm; `true` = attached) lets
  /// this suppress whichever half of the check currently has no clean
  /// signal to work from — the existing "Electrode off" warning is the
  /// right one to show for that, not a misleading swap guess. Pass `null`
  /// (the default) to skip this guard, e.g. when the caller has already
  /// confirmed every relevant electrode was attached throughout.
  static List<LeadPlacementWarning> check(List<List<double>> leadSamples, {int sampleRateHz = 50, List<bool>? electrodeStatus}) {
    if (leadSamples.length < EcgData.noOfChannels) return const [];

    final limbElectrodesOk = electrodeStatus == null || (electrodeStatus.length > 9 && electrodeStatus[6] && electrodeStatus[8] && electrodeStatus[9]);
    final chestElectrodesOk = electrodeStatus == null || (electrodeStatus.length > 5 && electrodeStatus.sublist(0, 6).every((attached) => attached));
    if (!limbElectrodesOk && !chestElectrodesOk) return const [];

    final beats = _detectBeats(leadSamples[1], sampleRateHz); // lead II is the rhythm reference throughout this app
    if (beats.length < minBeats) return const [];

    // Half-width wide enough to contain a full QRS complex (~120ms) even
    // at this buffer's coarse ~20ms-per-sample display resolution.
    final halfWindow = max(1, (sampleRateHz * 0.1).round());

    final warnings = <LeadPlacementWarning>[];

    if (limbElectrodesOk) {
      final dominant = List.generate(
        4,
        (lead) => _median(beats.map((p) => _dominantDeflection(leadSamples[lead], p, halfWindow)).toList()),
      );
      final scale = dominant.fold<double>(0, (acc, d) => max(acc, d.abs()));
      if (scale > 0) {
        final deadzone = scale * 0.2;
        final ampI = dominant[0], ampII = dominant[1], ampIII = dominant[2], ampAvr = dominant[3];

        if (ampI < -deadzone && ampAvr > deadzone) {
          warnings.add(const LeadPlacementWarning(
            title: 'Possible Left/Right Arm Electrode Swap',
            message: 'Lead I is inverted and aVR is upright — this pattern usually means the Left Arm and Right Arm electrodes are on the wrong wrists.',
            electrodes: ['RA', 'LA'],
          ));
        } else if (ampII < -deadzone && ampI > deadzone / 2) {
          warnings.add(const LeadPlacementWarning(
            title: 'Possible Arm/Leg Electrode Swap',
            message: 'Lead II looks inverted while Lead I looks normal — consistent with the Right Arm and Left Leg electrodes being swapped.',
            electrodes: ['RA', 'LL'],
          ));
        } else if (ampIII < -deadzone && ampI > deadzone / 2 && ampII > deadzone / 2) {
          warnings.add(const LeadPlacementWarning(
            title: 'Possible Arm/Leg Electrode Swap',
            message: 'Lead III looks inverted while Leads I and II look normal — consistent with the Left Arm and Left Leg electrodes being swapped.',
            electrodes: ['LA', 'LL'],
          ));
        }
      }
    }

    if (chestElectrodesOk) {
      warnings.addAll(_checkPrecordialProgression(leadSamples, beats, halfWindow));
    }

    return warnings;
  }

  static List<LeadPlacementWarning> _checkPrecordialProgression(List<List<double>> leadSamples, List<int> beats, int halfWindow) {
    final rWave = List.generate(6, (i) => _median(beats.map((p) => _maxDeflection(leadSamples[6 + i], p, halfWindow)).toList()));
    final rScale = rWave.fold<double>(0, max);
    if (rScale <= 0) return const [];

    final inversions = <int>[];
    for (var i = 0; i < 5; i++) {
      if (rWave[i] > rWave[i + 1] + rScale * 0.25) inversions.add(i);
    }

    if (inversions.length == 1) {
      final i = inversions[0];
      const names = EcgData.leadName;
      return [
        LeadPlacementWarning(
          title: 'Possible Chest Electrode Swap',
          message: 'The R-wave size jumps unexpectedly between ${names[6 + i]} and ${names[7 + i]} — check those two chest electrodes are on the correct positions.',
          electrodes: [names[6 + i], names[7 + i]],
        ),
      ];
    }
    if (inversions.length > 1) {
      return const [
        LeadPlacementWarning(
          title: 'Possible Chest Electrode Placement Issue',
          message: 'The R-wave pattern across V1-V6 does not progress as expected — recheck all six chest electrode positions.',
          electrodes: ['V1', 'V2', 'V3', 'V4', 'V5', 'V6'],
        ),
      ];
    }
    return const [];
  }

  static List<int> _detectBeats(List<double> leadII, int sampleRateHz) {
    if (leadII.length < 10) return const [];
    final absVals = leadII.map((v) => v.abs()).toList();
    final maxAbs = absVals.fold<double>(0, max);
    if (maxAbs <= 0) return const [];

    final threshold = maxAbs * 0.4;
    final refractory = max(1, (sampleRateHz * 0.3).round());
    final peaks = <int>[];
    var lastPeak = -refractory;
    for (var i = 1; i < absVals.length - 1; i++) {
      if (absVals[i] < threshold) continue;
      if (absVals[i] >= absVals[i - 1] && absVals[i] >= absVals[i + 1] && i - lastPeak >= refractory) {
        peaks.add(i);
        lastPeak = i;
      }
    }
    return peaks;
  }

  /// The larger-magnitude of the max/min excursion around [peakIndex] —
  /// the dominant deflection of that beat's QRS complex on this lead,
  /// signed (positive = upright, negative = inverted).
  static double _dominantDeflection(List<double> lead, int peakIndex, int halfWindow) {
    final start = (peakIndex - halfWindow).clamp(0, lead.length - 1);
    final end = (peakIndex + halfWindow).clamp(0, lead.length - 1);
    var mx = lead[start], mn = lead[start];
    for (var i = start; i <= end; i++) {
      if (lead[i] > mx) mx = lead[i];
      if (lead[i] < mn) mn = lead[i];
    }
    return mx.abs() >= mn.abs() ? mx : mn;
  }

  /// The upward (R-wave) excursion specifically — used for the precordial
  /// progression check, which cares about R-wave size, not overall
  /// polarity.
  static double _maxDeflection(List<double> lead, int peakIndex, int halfWindow) {
    final start = (peakIndex - halfWindow).clamp(0, lead.length - 1);
    final end = (peakIndex + halfWindow).clamp(0, lead.length - 1);
    var mx = lead[start];
    for (var i = start; i <= end; i++) {
      if (lead[i] > mx) mx = lead[i];
    }
    return mx;
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
  }
}
