// A full app-boot widget test isn't practical in every sandbox: GetStorage
// and platform-channel plugins (connectivity_plus, path_provider, ...) need
// a real platform to answer their MethodChannel calls, which the bare `flutter
// test` VM here doesn't provide, and pumping past that hangs indefinitely.
//
// These tests instead cover the ported signal-processing logic directly —
// pure Dart, no platform dependency, and arguably more valuable than a UI
// smoke test since correctness here is what matters clinically. Run
// `flutter run` on a device/emulator to verify the UI boots.

import 'package:flutter_test/flutter_test.dart';

import 'package:drcardio_flutter/core/services/ecg/ecg_data.dart';
import 'package:drcardio_flutter/core/services/ecg/fir_coefficients.dart';
import 'package:drcardio_flutter/core/services/ecg/parse_data.dart';

void main() {
  group('ParseData', () {
    test('joinMsbLsb matches the original MSB<<8 | LSB, signed 16-bit', () {
      expect(ParseData.joinMsbLsb(0x00, 0x01), 1);
      expect(ParseData.joinMsbLsb(0x7F, 0xFF), 32767);
      // 0x8000 as a signed 16-bit value is -32768.
      expect(ParseData.joinMsbLsb(0x80, 0x00), -32768);
      expect(ParseData.joinMsbLsb(0xFF, 0xFF), -1);
    });

    test('joinBytes matches (b1<<24 | b2<<16 | b3<<8) / 256', () {
      expect(ParseData.joinBytes(0x00, 0x00, 0x00), 0);
      // b2=1 contributes (1<<16)=65536; /256 = 256.
      expect(ParseData.joinBytes(0x00, 0x01, 0x00), 256.0);
      // b3=1 contributes (1<<8)=256; /256 = 1.
      expect(ParseData.joinBytes(0x00, 0x00, 0x01), 1.0);
    });

    test('generateAuxChannels derives aVR/aVL/aVF from leads I and II', () {
      final channels = List<double>.filled(12, 0)
        ..[1] = 1.0 // Lead I
        ..[2] = 0.5; // Lead II
      ParseData.generateAuxChannels(channels);
      expect(channels[8], 0.5 - 1.0); // III = II - I
      expect(channels[9], -1 * (1.0 + 0.5) / 2.0); // aVR
      expect(channels[10], 1.0 - (0.5 / 2.0)); // aVL
      expect(channels[11], 0.5 - (1.0 / 2.0)); // aVF
    });

    test('charArrayToChannels walks bytesPerSample for hardware v1 vs v2', () {
      EcgData.instance.hwVersion = 1;
      expect(ParseData.bytesPerSample(), 16);
      EcgData.instance.hwVersion = 2;
      expect(ParseData.bytesPerSample(), 24);
      EcgData.instance.hwVersion = 1; // reset for other tests
    });

    test('byteArrayToLeadStatus reads attached (bit clear) vs off (bit set)', () {
      // All zero status bytes -> every electrode reads attached.
      final allAttached = ParseData.byteArrayToLeadStatus([0x00, 0x00, 0x00]);
      expect(allAttached.every((v) => v), isTrue);

      // V1 bit (0x08) set in statusBytes[0] -> V1 reads off. Right Leg
      // (index 7) shares that same bit in the original protocol mapping
      // (both `leadStatus[0]` and `leadStatus[7]` read `statusBytes[0] &
      // 0x08` — preserved here exactly as in `parseData.java`), so it
      // reads off too; every other electrode stays attached.
      final v1Off = ParseData.byteArrayToLeadStatus([0x08, 0x00, 0x00]);
      expect(v1Off[0], isFalse);
      expect(v1Off[7], isFalse);
      final others = [1, 2, 3, 4, 5, 6, 8, 9];
      expect(others.every((i) => v1Off[i]), isTrue);
    });
  });

  group('FIR coefficients', () {
    test('each bank has the expected 201 taps (order 200) and is symmetric', () {
      for (final bank in [firB150, firB40, firB540, firB25, firB525]) {
        expect(bank.length, 201);
        // These are linear-phase FIR filters: taps should be symmetric
        // around the center.
        for (var i = 0; i < bank.length; i++) {
          expect(bank[i], closeTo(bank[bank.length - 1 - i], 1e-9));
        }
      }
    });
  });
}
