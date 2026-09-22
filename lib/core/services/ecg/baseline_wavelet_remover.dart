/// Exact port of the original app's `Baseline_remove1.jar` (a compiled,
/// source-unavailable dependency — decompiled with CFR to recover this
/// logic). A 10-level discrete wavelet decomposition/reconstruction that
/// discards the deepest-scale approximation coefficient (the signal's
/// baseline wander) before reconstructing, matching the exact filter
/// coefficients and 1-indexed loop bounds of the decompiled source so the
/// output lines up with `ECGAnalysisService`'s expectations, which were
/// tuned against this exact baseline-removal behavior.
///
/// Kept 1-indexed (arrays sized with a padding slot at index 0, mirroring
/// the Java) rather than translated to 0-indexed, since this algorithm's
/// correctness depends on exact off-by-one boundary handling that would be
/// easy to get subtly wrong translating index conventions by hand.
class BaselineWaveletRemover {
  BaselineWaveletRemover._();

  static const int _n1 = 6500;
  static const int _filtln = 8;
  static const int _scale = 10;
  static const int _arrLen = 13500;

  static const List<double> _g = [
    -0.230377813308855, 0.714846570552542, -0.63088076792959, -0.0279837694169839, //
    0.187034811718881, 0.030841381835987, -0.0328830116669829, -0.0105974017849973,
  ];
  static const List<double> _h = [
    -0.010597401784997, 0.0328830116669829, 0.030841381835987, -0.187034811718881, //
    -0.0279837694169839, 0.63088076792959, 0.714846570552542, 0.230377813308855,
  ];
  static const List<double> _k = [
    -0.0105974017849973, -0.0328830116669829, 0.030841381835987, 0.187034811718881, //
    -0.0279837694169839, -0.63088076792959, 0.714846570552542, -0.230377813308855,
  ];
  static const List<double> _hr = [
    0.230377813308855, 0.714846570552542, 0.63088076792959, -0.0279837694169839, //
    -0.187034811718881, 0.030841381835987, 0.0328830116669829, -0.0105974017849973,
  ];

  /// [dataarray] must have exactly 6500 samples. Returns 6500 baseline-removed
  /// samples in the same order.
  static List<double> remove(List<double> dataarray) {
    final h1 = List<double>.filled(15, 0);
    final g1 = List<double>.filled(15, 0);
    final hr1 = List<double>.filled(15, 0);
    final k1 = List<double>.filled(15, 0);
    final l = List<int>.filled(15, 0);

    var ys = List<double>.filled(_arrLen, 0);
    var ysPlus1 = List<double>.filled(_arrLen, 0);
    var wSPlus1 = List<double>.filled(_arrLen, 0);
    final array = List<double>.filled(_arrLen, 0);
    final data2 = List.generate(_arrLen, (_) => List<double>.filled(15, 0));

    int n1 = _n1;

    for (var i = 1; i < n1 + 1; i++) {
      ys[i] = dataarray[i - 1] - 0.0;
    }
    for (var j = 1; j < _filtln + 1; j++) {
      h1[j] = _h[_filtln - j];
      g1[j] = _g[_filtln - j];
      hr1[j] = _hr[_filtln - j];
      k1[j] = _k[_filtln - j];
    }

    for (var s = 1; s < _scale + 1; s++) {
      for (var j = 1; j < 2 * n1 + 1; j++) {
        ysPlus1[j] = 0.0;
        wSPlus1[j] = 0.0;
      }
      final dataln = n1;
      for (var i = 1; i < dataln + 2 * _filtln - 2 + 1; i++) {
        if (i <= _filtln - 1) {
          array[i] = ys[_filtln - i];
        } else if (i <= n1 + _filtln - 1) {
          array[i] = ys[i - _filtln + 1];
        } else {
          array[i] = array[2 * (n1 + _filtln - 1) + 1 - i];
        }
      }
      for (var j = 1; j < dataln + _filtln; j++) {
        var temp = 0.0;
        for (var i = 1; i < _filtln + 1; i++) {
          temp += g1[i] * array[i + j - 1];
        }
        wSPlus1[j] = temp;
      }
      for (var j = 1; j < dataln + _filtln; j++) {
        var temp = 0.0;
        for (var i = 1; i < _filtln + 1; i++) {
          temp += h1[i] * array[i + j - 1];
        }
        ysPlus1[j] = temp;
      }
      var counter = 0;
      for (var j = 2; j < dataln + _filtln; j += 2) {
        ys[j ~/ 2] = ysPlus1[j];
        data2[j ~/ 2][s] = wSPlus1[j];
        counter++;
      }
      n1 = counter;
      l[s] = counter;
    }

    const scaleR = 9;
    var yrS = List<double>.filled(_arrLen, 0);
    for (var j = 1; j < l[scaleR] + 1; j++) {
      yrS[j] = 0.0;
      yrS[2 * j] = 0.0;
    }
    yrS[2 * l[scaleR]] = 0.0;

    var ysMinus1 = List<double>.filled(_arrLen, 0);
    final arrayr = List<double>.filled(_arrLen, 0);

    for (var s = scaleR; s > 0; s--) {
      final n11 = l[s] * 2;
      var wS = List<double>.filled(_arrLen, 0);
      ysMinus1 = List<double>.filled(_arrLen, 0);
      final dataln = n11;
      final n2 = l[s];
      for (var j = 1; j < n2 + 1; j++) {
        wS[2 * j - 1] = data2[j][s];
      }
      wS[2 * n2] = 0.0;
      const nVal = 3;
      for (var i = 1; i < dataln + _filtln + 2; i++) {
        if (i <= nVal) {
          arrayr[i] = wS[nVal + 1 - i];
        } else if (i <= n11 + nVal) {
          arrayr[i] = wS[i - nVal];
        } else {
          arrayr[i] = arrayr[2 * (n11 + nVal) + 1 - i];
        }
      }
      for (var j = 3; j < n11 + 3; j++) {
        var tempr = 0.0;
        for (var i = 1; i < _filtln + 1; i++) {
          tempr += k1[i] * arrayr[i + j - 1];
        }
        ysMinus1[j - 2] = tempr;
      }
      for (var i = 1; i < dataln + _filtln + 2; i++) {
        if (i <= nVal) {
          arrayr[i] = yrS[nVal + 1 - i];
        } else if (i <= n11 + nVal) {
          arrayr[i] = yrS[i - nVal];
        } else {
          arrayr[i] = arrayr[2 * (n11 + nVal) + 1 - i];
        }
      }
      for (var j = 3; j < n11 + 3; j++) {
        var tempr = 0.0;
        for (var i = 1; i < _filtln + 1; i++) {
          tempr += hr1[i] * arrayr[i + j - 1];
        }
        ysMinus1[j - 2] = tempr + ysMinus1[j - 2];
      }
      for (var j = 1; j < n11 + 1; j++) {
        yrS[2 * j - 1] = ysMinus1[j];
      }
      yrS[2 * n11] = 0.0;
    }

    return List<double>.generate(6500, (i) => ysMinus1[i + 1]);
  }
}
