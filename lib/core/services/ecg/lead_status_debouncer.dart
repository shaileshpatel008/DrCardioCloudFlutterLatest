/// Smooths the raw per-electrode lead-off status before it reaches the UI
/// (the "Electrode off" banner and each lead chart's "LEAD OFF" overlay —
/// see `EcgData.leadStatus`/`isLeadOff`).
///
/// The device reports lead status on every incoming packet — tens of
/// times a second while recording. A marginal/noisy electrode contact can
/// flip that bit on and off from one packet to the next even though
/// nothing about the physical connection actually changed, and wiring
/// that straight into the UI made the banner and the affected chart row
/// blink in lockstep with it: visibly distracting, and worrying for
/// anyone watching a patient's screen.
///
/// Committing to OFF is a leaky-integrator/hysteresis filter, not a "wait
/// for N ms of unbroken agreement" one — that simpler approach was tried
/// first and had a real failure mode a continuously-flickering electrode
/// (one that never actually settles, just keeps toggling for the whole
/// recording) exposed: requiring an *unbroken* run of the new reading
/// before committing means a signal that never holds still for that long
/// never commits *anything*, so a genuinely bad electrode could flicker
/// forever and the "LEAD OFF" warning would never actually show — worse
/// than the original blinking, since now nothing warns the user at all.
/// Each electrode instead accumulates net "off exposure" in seconds (+dt
/// per packet while the raw reading is off, -dt while it's on, clamped to
/// [0, _capSeconds]), and commits to OFF once that crosses
/// [onThresholdSeconds] — so sustained or majority flickering still
/// reliably commits to OFF, while a single stray off packet amid a solid
/// connection doesn't flip anything by itself.
///
/// Clearing back to attached is deliberately the *opposite* shape: a
/// plain unbroken-run requirement, not exposure decay. A first version of
/// this class cleared once net exposure decayed back to (near) zero, which
/// is too easy to satisfy on a real bad connection — a lead that's mostly
/// off but has the occasional multi-second run of "attached" readings
/// mixed in (observed on real hardware: a loose chest electrode reporting
/// several seconds of "on" every so often) could decay its exposure to
/// zero during exactly that run, clear the warning, then re-accumulate
/// and re-warn moments later — the banner visibly flickering on/off every
/// few seconds even though the connection never actually got fixed. An
/// unbroken-run requirement has no unsafe failure mode *here* the way it
/// did for committing OFF above: the worst case is staying in the
/// cautious "still off" state a little longer than strictly necessary
/// after a real reconnection, never silently failing to warn.
class LeadStatusDebouncer {
  LeadStatusDebouncer({
    this.onThresholdSeconds = 0.2,
    this.clearAfterSeconds = 2.0,
    double capSeconds = 2.0,
  }) : _capSeconds = capSeconds;

  /// Accumulated off-exposure (seconds) needed to flag a connected
  /// electrode as off.
  final double onThresholdSeconds;

  /// Seconds of a *genuinely unbroken* run of "attached" readings needed
  /// before an already-flagged electrode clears back to attached — not
  /// net exposure decay (see the class doc for why that was too easy to
  /// satisfy on a still-bad connection). Reset to zero the instant a
  /// single "off" reading appears.
  final double clearAfterSeconds;

  final double _capSeconds;

  List<bool>? _committed;
  List<double> _offExposure = const [];
  List<double> _consecutiveOnSeconds = const [];
  DateTime? _lastUpdate;

  /// Feeds one raw reading in; returns the new committed status list only
  /// on the packet where a per-electrode change actually takes effect
  /// (`null` otherwise), so the caller only has to write/notify when
  /// something genuinely settled.
  List<bool>? update(List<bool> raw, DateTime now) {
    final lastUpdate = _lastUpdate;
    _lastUpdate = now;

    if (_committed == null || _committed!.length != raw.length) {
      // First reading (or the electrode count changed, which never
      // happens in practice) — adopt it immediately rather than holding
      // the UI at a meaningless default while exposure accumulates.
      _committed = List<bool>.from(raw);
      _offExposure = List<double>.filled(raw.length, 0);
      _consecutiveOnSeconds = List<double>.filled(raw.length, 0);
      return List<bool>.from(_committed!);
    }

    // Guards a clock going backwards (shouldn't happen with DateTime.now())
    // and the implausibly-long gap a debugger pause/backgrounded app could
    // produce — neither should swing exposure by a huge, unbounded jump.
    final dtSeconds = lastUpdate == null ? 0.0 : now.difference(lastUpdate).inMilliseconds / 1000.0;
    final dt = dtSeconds.clamp(0.0, 1.0);

    final committed = _committed!;
    var changed = false;
    final next = List<bool>.from(committed);
    for (var i = 0; i < raw.length; i++) {
      _offExposure[i] = (_offExposure[i] + (raw[i] ? -dt : dt)).clamp(0.0, _capSeconds);
      _consecutiveOnSeconds[i] = raw[i] ? _consecutiveOnSeconds[i] + dt : 0.0;

      if (committed[i] && _offExposure[i] >= onThresholdSeconds) {
        next[i] = false; // electrode newly flagged off
        changed = true;
      } else if (!committed[i] && _consecutiveOnSeconds[i] >= clearAfterSeconds) {
        next[i] = true; // electrode recovered, for real this time
        changed = true;
        _offExposure[i] = 0; // fresh start so a future flicker isn't judged against stale exposure
      }
    }
    if (!changed) return null;
    _committed = next;
    return List<bool>.from(next);
  }
}
