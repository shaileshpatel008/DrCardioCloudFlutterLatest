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
/// anyone watching a patient's screen. Real bedside monitors don't have
/// this problem because they never report a status change until it's
/// held steady for a short window; this is the same idea, per electrode
/// (so one flickering lead can't hold up a real, solid change on another
/// one) — a change only takes effect once the new reading has been
/// consistent for [holdDuration].
class LeadStatusDebouncer {
  LeadStatusDebouncer({this.holdDuration = const Duration(milliseconds: 400)});

  final Duration holdDuration;

  List<bool>? _committed;
  List<bool> _pending = const [];
  List<DateTime> _pendingSince = const [];

  /// Feeds one raw reading in; returns the new committed status list only
  /// on the packet where a per-electrode change actually takes effect
  /// (`null` otherwise), so the caller only has to write/notify when
  /// something genuinely settled.
  List<bool>? update(List<bool> raw, DateTime now) {
    if (_committed == null || _committed!.length != raw.length) {
      // First reading (or the electrode count changed, which never
      // happens in practice) — adopt it immediately rather than holding
      // the UI at a meaningless default for `holdDuration`.
      _committed = List<bool>.from(raw);
      _pending = List<bool>.from(raw);
      _pendingSince = List<DateTime>.filled(raw.length, now);
      return List<bool>.from(_committed!);
    }

    final committed = _committed!;
    var changed = false;
    final next = List<bool>.from(committed);
    for (var i = 0; i < raw.length; i++) {
      if (raw[i] == committed[i]) {
        _pending[i] = committed[i];
        continue;
      }
      if (_pending[i] != raw[i]) {
        _pending[i] = raw[i];
        _pendingSince[i] = now;
      } else if (now.difference(_pendingSince[i]) >= holdDuration) {
        next[i] = raw[i];
        changed = true;
      }
    }
    if (!changed) return null;
    _committed = next;
    return List<bool>.from(next);
  }
}
