import 'package:flutter/foundation.dart';

/// Lightweight live R-peak detector for the on-screen heart-rate badge.
///
/// This is deliberately simple (adaptive-threshold local-maximum detection
/// with a physiological refractory period), not a port of
/// `ECGAnalysis`'s full post-recording QRS/interval analysis — that one
/// runs once, after acquisition stops, on the complete filtered buffer,
/// and its numbers go on the PDF report. This one runs sample-by-sample
/// while recording is live, purely to give a quick "is this roughly a
/// normal heart rate" glance; it is not diagnostic-grade and never feeds
/// the report.
class HeartRateEstimator {
  HeartRateEstimator({this.sampleRateHz = 500});

  final int sampleRateHz;

  /// Peaks closer together than this are the same QRS complex re-detected,
  /// not two heartbeats — 300ms caps the estimate at 200 bpm, above any
  /// physiologically plausible resting-to-exertion range this is meant to
  /// glance at.
  late final int _refractorySamples = (sampleRateHz * 0.3).round();

  double _recentPeak = 0;
  double _lastValue = 0;
  bool _wasRising = false;
  int? _lastPeakSample;
  final List<int> _recentIntervalsSamples = [];

  final ValueNotifier<int?> bpm = ValueNotifier<int?>(null);

  void addSample(int sampleIndex, double value) {
    // Decaying envelope of the recent peak amplitude — the adaptive
    // threshold below tracks signal amplitude instead of a fixed value,
    // since gain/filter settings change the raw scale.
    _recentPeak = value > _recentPeak ? value : _recentPeak * 0.999;

    final rising = value > _lastValue;
    final wasLocalMax = _wasRising && !rising;
    _wasRising = rising;
    final previousValue = _lastValue;
    _lastValue = value;

    if (!wasLocalMax || _recentPeak <= 0 || previousValue < _recentPeak * 0.5) return;

    final lastPeak = _lastPeakSample;
    if (lastPeak != null && sampleIndex - lastPeak < _refractorySamples) return;

    if (lastPeak != null) {
      final intervalSamples = sampleIndex - lastPeak;
      _recentIntervalsSamples.add(intervalSamples);
      if (_recentIntervalsSamples.length > 5) _recentIntervalsSamples.removeAt(0);
      final avgSamples = _recentIntervalsSamples.reduce((a, b) => a + b) / _recentIntervalsSamples.length;
      final estimate = (60 * sampleRateHz / avgSamples).round();
      // Outside this range it's almost certainly a noise/lead-off
      // artifact, not a real beat — better to hold the last good value
      // than to flash a nonsense number.
      if (estimate >= 30 && estimate <= 220) bpm.value = estimate;
    }
    _lastPeakSample = sampleIndex;
  }

  void reset() {
    _recentPeak = 0;
    _lastValue = 0;
    _wasRising = false;
    _lastPeakSample = null;
    _recentIntervalsSamples.clear();
    bpm.value = null;
  }

  void dispose() => bpm.dispose();
}
