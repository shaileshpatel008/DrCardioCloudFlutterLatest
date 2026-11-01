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

    test('ignores a brief flip that reverts before the hold duration', () {
      final debouncer = LeadStatusDebouncer(holdDuration: const Duration(milliseconds: 400));
      var now = DateTime(2026);
      debouncer.update([true, true], now); // initial: both on

      // Electrode 1 flickers off for 150ms, well under the hold window...
      now = now.add(const Duration(milliseconds: 150));
      var result = debouncer.update([true, false], now);
      expect(result, isNull, reason: 'a brief flip should not commit yet');

      // ...then flickers back on before it ever held steady.
      now = now.add(const Duration(milliseconds: 100));
      result = debouncer.update([true, true], now);
      expect(result, isNull, reason: 'reverting before the hold window should never commit the flip');
    });

    test('commits a change once it holds steady for the full duration', () {
      final debouncer = LeadStatusDebouncer(holdDuration: const Duration(milliseconds: 400));
      var now = DateTime(2026);
      debouncer.update([true, true], now);

      now = now.add(const Duration(milliseconds: 200));
      var result = debouncer.update([true, false], now);
      expect(result, isNull);

      // Same reading keeps arriving; 450ms after the flip first appeared
      // (i.e. since `now.add(200ms)` above) is past the 400ms hold window.
      now = now.add(const Duration(milliseconds: 450));
      result = debouncer.update([true, false], now);
      expect(result, [true, false]);
    });

    test('tracks each electrode independently', () {
      final debouncer = LeadStatusDebouncer(holdDuration: const Duration(milliseconds: 400));
      var now = DateTime(2026);
      debouncer.update([true, true, true], now);

      // Electrode 0 goes off and stays off; electrode 2 flickers.
      now = now.add(const Duration(milliseconds: 100));
      debouncer.update([false, true, false], now);
      now = now.add(const Duration(milliseconds: 100));
      debouncer.update([false, true, true], now); // electrode 2 reverted
      now = now.add(const Duration(milliseconds: 450));
      final result = debouncer.update([false, true, true], now);

      // Only electrode 0's change (held since the first flip, ~650ms ago)
      // should have committed; electrode 2 never held steady long enough.
      expect(result, [false, true, true]);
    });
  });
}
