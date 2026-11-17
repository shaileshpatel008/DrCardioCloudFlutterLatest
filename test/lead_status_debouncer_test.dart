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

    test('recovering to attached needs a genuinely unbroken run of good readings, not just a brief good patch', () {
      final debouncer = LeadStatusDebouncer(onThresholdSeconds: 0.3, clearAfterSeconds: 1.0);
      var now = DateTime(2026);
      debouncer.update([true], now);

      // Drive it off first.
      now = now.add(const Duration(milliseconds: 400));
      final offResult = debouncer.update([false], now);
      expect(offResult, [false]);

      // A good patch shorter than clearAfterSeconds shouldn't clear it...
      now = now.add(const Duration(milliseconds: 500));
      final tooSoon = debouncer.update([true], now);
      expect(tooSoon, isNull, reason: 'a 500ms good patch is under the 1s unbroken-run requirement');

      // ...and so much as a single off reading resets that run, even this
      // close to the finish line.
      now = now.add(const Duration(milliseconds: 900));
      final interrupted = debouncer.update([false], now);
      expect(interrupted, isNull, reason: 'still off — a single bad reading at 1.4s in should not have let it clear just before this point');

      now = now.add(const Duration(milliseconds: 1100));
      final recovered = debouncer.update([true], now);
      expect(recovered, [true], reason: '1.1s of unbroken good contact since the last off reading clears it');
    });

    test('a connection that is mostly bad but has multi-second good-looking patches never fully clears '
        '(the real-world bug this fix targets: the previous design cleared during exactly such a patch, '
        'then re-committed off moments later — the banner visibly flickering every few seconds)', () {
      final debouncer = LeadStatusDebouncer(onThresholdSeconds: 0.2, clearAfterSeconds: 2.0);
      var now = DateTime(2026);
      debouncer.update([true], now);

      // Drive it off.
      now = now.add(const Duration(milliseconds: 300));
      final offResult = debouncer.update([false], now);
      expect(offResult, [false]);

      // A good-looking patch that's real but shorter than clearAfterSeconds
      // (1.8s, under the 2s requirement) — exactly the kind of patch that
      // cleared the old decay-to-zero design.
      List<bool>? sawRecovery;
      for (var ms = 0; ms < 1800; ms += 100) {
        now = now.add(const Duration(milliseconds: 100));
        sawRecovery = debouncer.update([true], now) ?? sawRecovery;
      }
      expect(sawRecovery, isNull, reason: 'an 1.8s good patch is still under the 2s unbroken-run requirement — must not clear yet');

      // The patch ends and it goes bad again before ever reaching 2s.
      now = now.add(const Duration(milliseconds: 100));
      final stillOff = debouncer.update([false], now);
      expect(stillOff, isNull, reason: 'it never cleared, so this is not a change');
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
