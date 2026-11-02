import 'package:drcardio_flutter/core/services/ecg/lead_status_debouncer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeadStatusDebouncer', () {
    test('adopts the first reading immediately', () {
      final debouncer = LeadStatusDebouncer();
      final now = DateTime(2026);
      final result = debouncer.update([true, false, true], now);
      expect(result, [true, false, true]);
    });

    test('ignores a brief flip that reverts before enough off-exposure accumulates', () {
      final debouncer = LeadStatusDebouncer(onThresholdSeconds: 0.3);
      var now = DateTime(2026);
      debouncer.update([true, true], now); // initial: both on

      // Electrode 1 flips off for only 100ms, under the 0.3s threshold...
      now = now.add(const Duration(milliseconds: 100));
      var result = debouncer.update([true, false], now);
      expect(result, isNull, reason: 'a brief flip should not commit yet');

      // ...then flips back on before accumulating enough off-exposure.
      now = now.add(const Duration(milliseconds: 100));
      result = debouncer.update([true, true], now);
      expect(result, isNull, reason: 'reverting before the threshold should never commit the flip');
    });

    test('commits a change once accumulated off-exposure crosses the threshold', () {
      final debouncer = LeadStatusDebouncer(onThresholdSeconds: 0.3);
      var now = DateTime(2026);
      debouncer.update([true, true], now);

      now = now.add(const Duration(milliseconds: 200));
      var result = debouncer.update([true, false], now);
      expect(result, isNull);

      // 450ms of continuous off-exposure since the flip first appeared —
      // past the 0.3s threshold.
      now = now.add(const Duration(milliseconds: 450));
      result = debouncer.update([true, false], now);
      expect(result, [true, false]);
    });

    test('a continuously flickering electrode still commits to OFF eventually '
        '(the real bug a pure "wait for unbroken stability" design had: it '
        'never commits anything if the raw signal never holds still)', () {
      final debouncer = LeadStatusDebouncer(onThresholdSeconds: 0.3, capSeconds: 2.0);
      var now = DateTime(2026);
      debouncer.update([true], now);

      // Toggle off/on every 50ms, spending slightly more time off than on
      // each cycle (30ms off, 20ms on) — never once holding still for
      // anywhere near 300ms, the way a real marginal connection might.
      List<bool>? lastResult;
      for (var cycle = 0; cycle < 40; cycle++) {
        now = now.add(const Duration(milliseconds: 30));
        lastResult = debouncer.update([false], now) ?? lastResult;
        now = now.add(const Duration(milliseconds: 20));
        lastResult = debouncer.update([true], now) ?? lastResult;
      }

      expect(lastResult, [false], reason: 'sustained net off-exposure across many flickers should eventually flag the electrode off');
    });

    test('a single stray off reading amid solid connection never commits', () {
      final debouncer = LeadStatusDebouncer(onThresholdSeconds: 0.3);
      var now = DateTime(2026);
      debouncer.update([true], now);

      for (var i = 0; i < 20; i++) {
        now = now.add(const Duration(milliseconds: 50));
        final raw = i == 10 ? [false] : [true]; // one lone blip
        final result = debouncer.update(raw, now);
        expect(result, isNull, reason: 'a single isolated reading should never be enough to flip the committed state');
      }
    });

    test('recovering to attached needs off-exposure to decay back down, not just one good reading', () {
      final debouncer = LeadStatusDebouncer(onThresholdSeconds: 0.3, offThresholdSeconds: 0.0);
      var now = DateTime(2026);
      debouncer.update([true], now);

      // Drive it off first.
      now = now.add(const Duration(milliseconds: 400));
      final offResult = debouncer.update([false], now);
      expect(offResult, [false]);

      // One good reading right after shouldn't instantly clear 400ms of
      // accumulated exposure.
      now = now.add(const Duration(milliseconds: 10));
      final tooSoon = debouncer.update([true], now);
      expect(tooSoon, isNull, reason: 'exposure needs time to decay, not just a single on reading');

      // Sustained good contact for long enough to fully decay back to 0.
      now = now.add(const Duration(milliseconds: 500));
      final recovered = debouncer.update([true], now);
      expect(recovered, [true]);
    });

    test('tracks each electrode independently', () {
      final debouncer = LeadStatusDebouncer(onThresholdSeconds: 0.3);
      var now = DateTime(2026);
      debouncer.update([true, true, true], now);

      // Electrode 0 goes off and stays off; electrode 2 only flickers
      // briefly and recovers before accumulating enough exposure.
      now = now.add(const Duration(milliseconds: 100));
      debouncer.update([false, true, false], now);
      now = now.add(const Duration(milliseconds: 100));
      debouncer.update([false, true, true], now); // electrode 2 back on
      now = now.add(const Duration(milliseconds: 150));
      final result = debouncer.update([false, true, true], now);

      // Only electrode 0's change (350ms+ of continuous off-exposure)
      // should have committed; electrode 2 never held off long enough.
      expect(result, [false, true, true]);
    });
  });
}
