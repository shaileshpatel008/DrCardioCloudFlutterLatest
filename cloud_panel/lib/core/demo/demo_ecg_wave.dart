import 'dart:math' as math;

/// Synthetic 12-lead ECG used by the demo build for the recording view and
/// the sample export files. Each beat is a sum of Gaussian P, Q, R, S and T
/// waves with per-lead amplitudes (mV) close to a real recording.
class EcgWave {
  EcgWave({required this.hr, this.variant = EcgVariant.normal, this.seed = 0});

  /// Builds the trace for a demo ECG record (heart rate and findings come
  /// from the cardiologist's measurements and report when there are some).
  factory EcgWave.forRecord(Map<String, dynamic> r) {
    final id = (r['id'] as num?)?.toInt() ?? 0;
    final m = (r['measurements'] as Map?) ?? const {};
    final hr = double.tryParse('${m['hr']}') ?? (66 + (id * 7) % 22).toDouble();
    final report = '${r['cardiologist_report'] ?? ''}'.toLowerCase();
    final variant = report.contains('hypertrophy')
        ? EcgVariant.lvh
        : report.contains('t-wave inversion')
        ? EcgVariant.tInversion
        : EcgVariant.normal;
    return EcgWave(hr: hr.clamp(40, 160).toDouble(), variant: variant, seed: id);
  }

  final double hr;
  final EcgVariant variant;
  final int seed;

  /// Standard layout: 3 rows × 4 columns, then a lead II rhythm strip.
  static const layout = [
    ['I', 'aVR', 'V1', 'V4'],
    ['II', 'aVL', 'V2', 'V5'],
    ['III', 'aVF', 'V3', 'V6'],
  ];
  static const leads = ['I', 'II', 'III', 'aVR', 'aVL', 'aVF', 'V1', 'V2', 'V3', 'V4', 'V5', 'V6'];

  // P, Q, R, S, T amplitudes in mV.
  static const _amp = <String, List<double>>{
    'I': [0.10, -0.05, 0.85, -0.15, 0.25],
    'II': [0.15, -0.08, 1.20, -0.22, 0.35],
    'III': [0.06, -0.06, 0.45, -0.16, 0.12],
    'aVR': [-0.12, 0.05, -0.95, 0.12, -0.28],
    'aVL': [0.04, -0.06, 0.42, -0.10, 0.10],
    'aVF': [0.10, -0.07, 0.85, -0.18, 0.22],
    'V1': [0.08, 0.00, 0.25, -1.05, 0.10],
    'V2': [0.10, 0.00, 0.55, -1.35, 0.42],
    'V3': [0.10, -0.03, 0.95, -0.85, 0.46],
    'V4': [0.10, -0.06, 1.45, -0.50, 0.48],
    'V5': [0.10, -0.08, 1.30, -0.30, 0.40],
    'V6': [0.09, -0.08, 1.00, -0.15, 0.30],
  };

  double _g(double t, double mu, double sigma, double a) => a * math.exp(-((t - mu) * (t - mu)) / (2 * sigma * sigma));

  /// Voltage in mV of [lead] at [t] seconds.
  double value(String lead, double t) {
    final rr = 60 / hr;
    final offset = (seed % 7) * 0.037;
    final phase = (t + offset) % rr;
    final a = List<double>.of(_amp[lead]!);
    switch (variant) {
      case EcgVariant.lvh:
        if (['V5', 'V6', 'I', 'aVL'].contains(lead)) {
          a[2] *= 1.7;
          a[4] = -0.22;
        }
        if (['V1', 'V2'].contains(lead)) a[3] *= 1.6;
      case EcgVariant.tInversion:
        if (['V4', 'V5', 'V6'].contains(lead)) a[4] = -0.32;
      case EcgVariant.normal:
        break;
    }
    final tMu = 0.225 + 0.27 * math.sqrt(rr);
    var v =
        _g(phase, 0.10, 0.025, a[0]) +
        _g(phase, 0.205, 0.010, a[1]) +
        _g(phase, 0.225, 0.011, a[2]) +
        _g(phase, 0.247, 0.012, a[3]) +
        _g(phase, tMu, 0.045, a[4]);
    v += 0.035 * math.sin(2 * math.pi * 0.23 * t + seed);
    v += 0.008 * math.sin(2 * math.pi * 47 * t + seed * 1.3);
    return v;
  }
}

enum EcgVariant { normal, lvh, tInversion }
