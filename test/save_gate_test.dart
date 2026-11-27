import 'package:drcardio_flutter/core/services/ecg/ecg_analysis_service.dart';
import 'package:drcardio_flutter/modules/live_ecg/controllers/live_ecg_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveEcgController.saveBlockedReasonFor', () {
    const enoughSamples = EcgAnalysisService.minSamplesForReport;

    test('under 20s of real recording time is too short', () {
      expect(LiveEcgController.saveBlockedReasonFor(recordedSeconds: 19, rawSamples: enoughSamples), contains('too short'));
    });

    test('30s of real time is never "too short", even when the sample count alone would read under 20s '
        '(regression: 3s baseline capture + dropped packets made a real 30s recording count as <20s)', () {
      const samplesWorthOnly17s = 17 * 500;
      expect(LiveEcgController.saveBlockedReasonFor(recordedSeconds: 30, rawSamples: samplesWorthOnly17s), isNull);
    });

    test('long enough in time but too little data received points at the connection instead', () {
      final reason = LiveEcgController.saveBlockedReasonFor(recordedSeconds: 30, rawSamples: enoughSamples - 1);
      expect(reason, isNotNull);
      expect(reason, isNot(contains('too short')));
      expect(reason, contains('connection'));
    });

    test('exactly the minimum time and data is saveable', () {
      expect(LiveEcgController.saveBlockedReasonFor(recordedSeconds: LiveEcgController.minRecordingSeconds, rawSamples: enoughSamples), isNull);
    });
  });
}
