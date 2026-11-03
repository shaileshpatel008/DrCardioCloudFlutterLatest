import 'package:drcardio_flutter/core/services/ecg/lead_placement_checker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a synthetic 12-lead buffer (index order matches [EcgData.leadName]:
/// I, II, III, aVR, aVL, aVF, V1..V6) with a clean, regularly spaced "beat"
/// — a single spike per lead per beat is enough, since the checker only
/// measures the max/min excursion in a window around each detected beat,
/// not real QRS morphology.
List<List<double>> _synthetic({
  required List<double> limbAmps, // [I, II, III, aVR, aVL, aVF]
  required List<double> precordialR, // [V1..V6], all >= 0
  int beatCount = 8,
  int beatIntervalSamples = 40,
}) {
  final length = beatIntervalSamples * (beatCount + 2);
  final leads = List.generate(12, (_) => List<double>.filled(length, 0.0));
  for (var b = 0; b < beatCount; b++) {
    final idx = beatIntervalSamples * (b + 1);
    for (var l = 0; l < 6; l++) {
      leads[l][idx] = limbAmps[l];
      leads[6 + l][idx] = precordialR[l];
    }
  }
  return leads;
}

const _normalLimb = [8.0, 12.0, 4.0, -10.0, 2.0, 8.0]; // I, II, III, aVR, aVL, aVF
const _normalPrecordial = [1.0, 2.0, 4.0, 7.0, 10.0, 12.0]; // V1..V6, increasing R-wave

void main() {
  group('LeadPlacementChecker', () {
    test('a normal-looking 12-lead ECG raises no warnings', () {
      final samples = _synthetic(limbAmps: _normalLimb, precordialR: _normalPrecordial);
      expect(LeadPlacementChecker.check(samples), isEmpty);
    });

    test('too few beats to say anything stays silent even with an abnormal-looking pattern', () {
      final samples = _synthetic(limbAmps: const [-8, 12, 4, 10, 2, 8], precordialR: _normalPrecordial, beatCount: 2);
      expect(LeadPlacementChecker.check(samples), isEmpty);
    });

    test('Left Arm/Right Arm swap: inverted lead I + upright aVR', () {
      final samples = _synthetic(limbAmps: const [-8, 12, 4, 10, 2, 8], precordialR: _normalPrecordial);
      final warnings = LeadPlacementChecker.check(samples);
      expect(warnings, hasLength(1));
      expect(warnings.single.title, contains('Left/Right Arm'));
      expect(warnings.single.electrodes, containsAll(['RA', 'LA']));
    });

    test('Right Arm/Left Leg swap: inverted lead II with a normal lead I', () {
      final samples = _synthetic(limbAmps: const [8, -12, 4, -10, 2, 8], precordialR: _normalPrecordial);
      final warnings = LeadPlacementChecker.check(samples);
      expect(warnings, hasLength(1));
      expect(warnings.single.title, contains('Arm/Leg'));
      expect(warnings.single.electrodes, containsAll(['RA', 'LL']));
    });

    test('Left Arm/Left Leg swap: inverted lead III with normal leads I and II', () {
      final samples = _synthetic(limbAmps: const [8, 12, -4, -10, 2, 8], precordialR: _normalPrecordial);
      final warnings = LeadPlacementChecker.check(samples);
      expect(warnings, hasLength(1));
      expect(warnings.single.title, contains('Arm/Leg'));
      expect(warnings.single.electrodes, containsAll(['LA', 'LL']));
    });

    test('a swapped adjacent chest pair shows up as a single R-wave progression dip', () {
      // Normal progression would be ...4, 7, 10... — here V3 and V4's
      // R-waves are swapped relative to that.
      final samples = _synthetic(limbAmps: _normalLimb, precordialR: const [1, 2, 9, 3, 10, 12]);
      final warnings = LeadPlacementChecker.check(samples);
      expect(warnings, hasLength(1));
      expect(warnings.single.title, contains('Chest Electrode Swap'));
      expect(warnings.single.electrodes, containsAll(['V3', 'V4']));
    });

    test('a scrambled chest progression (more than one dip) raises the generic placement warning instead of guessing a pair', () {
      final samples = _synthetic(limbAmps: _normalLimb, precordialR: const [10, 2, 9, 3, 10, 2]);
      final warnings = LeadPlacementChecker.check(samples);
      expect(warnings, hasLength(1));
      expect(warnings.single.title, contains('Chest Electrode Placement Issue'));
      expect(warnings.single.electrodes, hasLength(6));
    });

    test('limb and chest warnings can both fire at once, independently', () {
      final samples = _synthetic(limbAmps: const [-8, 12, 4, 10, 2, 8], precordialR: const [1, 2, 9, 3, 10, 12]);
      final warnings = LeadPlacementChecker.check(samples);
      expect(warnings, hasLength(2));
      expect(warnings.map((w) => w.title), containsAll(['Possible Left/Right Arm Electrode Swap', 'Possible Chest Electrode Swap']));
    });

    // Electrode status convention matches EcgData.leadStatus:
    // index 0-5 = V1-V6, 6 = Left Leg, 7 = Right Leg, 8 = Left Arm, 9 = Right Arm.
    const allAttached = [true, true, true, true, true, true, true, true, true, true];

    test('a disconnected limb electrode suppresses the arm-swap warning instead of misreading the noise as a swap', () {
      final samples = _synthetic(limbAmps: const [-8, 12, 4, 10, 2, 8], precordialR: _normalPrecordial);
      final raOff = [...allAttached];
      raOff[9] = false; // Right Arm off
      expect(LeadPlacementChecker.check(samples, electrodeStatus: raOff), isEmpty);
    });

    test('a disconnected limb electrode does not suppress an independent chest-swap warning', () {
      final samples = _synthetic(limbAmps: const [-8, 12, 4, 10, 2, 8], precordialR: const [1, 2, 9, 3, 10, 12]);
      final raOff = [...allAttached];
      raOff[9] = false;
      final warnings = LeadPlacementChecker.check(samples, electrodeStatus: raOff);
      expect(warnings, hasLength(1));
      expect(warnings.single.title, contains('Chest Electrode Swap'));
    });

    test('a disconnected chest electrode suppresses the chest-swap check but not an independent limb warning', () {
      final samples = _synthetic(limbAmps: const [-8, 12, 4, 10, 2, 8], precordialR: const [1, 2, 9, 3, 10, 12]);
      final v3Off = [...allAttached];
      v3Off[2] = false; // V3 off
      final warnings = LeadPlacementChecker.check(samples, electrodeStatus: v3Off);
      expect(warnings, hasLength(1));
      expect(warnings.single.title, contains('Left/Right Arm'));
    });

    test('an unspecified electrode status (null, the default) runs the check unguarded', () {
      final samples = _synthetic(limbAmps: const [-8, 12, 4, 10, 2, 8], precordialR: _normalPrecordial);
      final warnings = LeadPlacementChecker.check(samples);
      expect(warnings, hasLength(1));
    });
  });
}
