import 'dart:math' as math;

import 'baseline_wavelet_remover.dart';

/// The eight values the report prints — port of `PdfGenerator
/// .getEcgAnalysis()`'s exact formatting of `ECGAnalysis.analysisArray[1]`
/// (row 1 = Lead II, the app's fixed reference lead for every one of these
/// figures, matching the printed "R(II)" label).
class EcgAnalysisMeasurements {
  const EcgAnalysisMeasurements({
    required this.heartRateBpm,
    required this.rAmplitudeMv,
    required this.rrIntervalMs,
    required this.prIntervalMs,
    required this.qrsDurationMs,
    required this.qtIntervalMs,
    required this.qtcMs,
    required this.qtOverQtc,
  });

  final int heartRateBpm;
  final double rAmplitudeMv;
  final int rrIntervalMs;
  final int prIntervalMs;
  final int qrsDurationMs;
  final int qtIntervalMs;
  final int qtcMs;
  final double qtOverQtc;
}

/// Port of `SupportClass.ECGAnalysis` — the original's QRS/P/T-wave
/// delineation pipeline (Pan-Tompkins-style fiducial detection, then
/// threshold/slope-based search windows for each wave's onset/offset), the
/// source of every "HR/R/RR/PR/QRS/QT/QTc" figure the report prints. The
/// original ships two copies of this class in one file — an entire early
/// version kept as a dead block comment, and the real, separately patched
/// ("SP CHANGES") active class after it; this ports the active one only.
///
/// This is a straight line-by-line translation, not a rewrite: Java's
/// `float[]`/`int[]` become `List<double>`/`List<int>` (both reference
/// types in their respective languages, so in-place mutation through a
/// function parameter behaves identically); scalar `int`/`float` locals
/// translate to Dart `int`/`double` locals with the same value semantics.
/// Kept this literal deliberately — this is a clinical measurement, and
/// there is no Dart/Flutter toolchain or real ECG fixture available to
/// compile-check or numerically verify a "cleaner" rewrite against the
/// original's output, so line-by-line fidelity to source neither of us can
/// re-run is the only available way to trust this port at all.
class EcgAnalysisService {
  EcgAnalysisService._();

  static const int _maxEcgSamples = 2400;
  static const int _tempMaxEcgSamples = 2500;
  static const double _samplingRate = 500;
  static const int _windowSizeMovAvg = 75;
  static const int _pWindow = 130;
  static const int _qrsWindow = 60;
  static const int _qWindow = 40;
  static const int _sWindow = 40;
  static const int _pStartWindow = 30;
  static const int _tStartWindow = 60;
  static const int _tEndWindow = 60;
  static const double _fiducialThreshold = 50;
  static const int _skipCount = 20;
  static const int _lead = 1; // Lead II — the app's fixed reference lead.
  static const int _rIndex = 0;
  static const int _qIndex = 1;
  static const int _sIndex = 2;
  static const int _qrsStIndex = 3;
  static const int _qrsEnIndex = 4;
  static const int _pIndex = 5;
  static const int _pStIndex = 6;
  static const int _pEnIndex = 7;
  static const int _tIndex = 8;
  static const int _tStIndex = 9;
  static const int _tEnIndex = 10;
  static const double _qtc = 0.55;
  static const double _scaleFactorForData = 20;
  static const int _reportDataLength = 6500;

  /// Port of `NewEcgActivity.generateReport()`'s `new
  /// ECGAnalysis(ecgData.filtered_data, pos, gain).analyse()` (with
  /// `pos` fixed at 0 — the original's seek-bar-driven analysis window
  /// offset has no equivalent UI in this app, which always analyzes from
  /// the start of the recording) plus `PdfGenerator.getEcgAnalysis()`'s
  /// formatting, folded into one call since nothing else needs the raw
  /// per-lead analysisArray.
  ///
  /// [filteredData] is the full, un-downsampled 500Hz filtered buffer —
  /// `EcgData.filteredData`, raw-hardware-channel-indexed exactly like the
  /// original's `ecgData.filtered_data` — and [leadArrange] is
  /// `EcgData.leadArrange` (clinical lead index -> raw channel index),
  /// needed to read it in clinical order. This deliberately does NOT take
  /// `EcgRecordModel.leadData`/`EcgData.chartData`: those are downsampled
  /// 10x for charting/storage and additionally high-pass filtered for
  /// display, neither of which matches what this algorithm was tuned
  /// against.
  ///
  /// Returns null wherever the original would have shown one of its "Data
  /// not ready"/"Unable to detect peaks" toasts and then gone on to print
  /// HR:0/RR:0/etc. anyway (`analysisArray` stays zero-filled when
  /// `analyse()` returns early) — printing zeroes on a clinical report is a
  /// bug worth not reproducing, so this leaves the fields blank (the PDF
  /// renders that as "—") instead.
  static EcgAnalysisMeasurements? analyze({
    required List<List<double>> filteredData,
    required int rawDataCount,
    required List<int> leadArrange,
    required double valPerMv,
  }) {
    if (rawDataCount < _reportDataLength) return null;

    try {
      final ecgDataArray = List.generate(12, (_) => List<double>.filled(_tempMaxEcgSamples, 0.0));
      for (var chi = 0; chi < 12; chi++) {
        final ch = leadArrange[chi];
        final raw = List<double>.generate(_reportDataLength, (i) => filteredData[i][ch]);
        final baselineRemoved = BaselineWaveletRemover.remove(raw);
        for (var j = 0; j < _tempMaxEcgSamples; j++) {
          ecgDataArray[chi][j] = baselineRemoved[j + 250] * _scaleFactorForData;
        }
      }

      final analyzer = _Analyzer(ecgDataArray, valPerMv);
      final error = analyzer.analyse();
      if (error != 0) return null;

      final row = analyzer.analysisArray[_lead];
      final hr = row[0];
      final rAmp = row[1];
      final qrsSec = row[6];
      final prSec = row[7];
      final qtSec = row[8];
      final qtOverQtc = row[11];
      if (hr <= 0 || qtOverQtc <= 0) return null;

      final qtcSec = qtSec / qtOverQtc;

      return EcgAnalysisMeasurements(
        heartRateBpm: hr.toInt(),
        rAmplitudeMv: rAmp,
        rrIntervalMs: (60000 / hr).round(),
        prIntervalMs: (prSec * 1000).round(),
        qrsDurationMs: (qrsSec * 1000).round(),
        qtIntervalMs: (qtSec * 1000).round(),
        qtcMs: (qtcSec * 1000).round(),
        qtOverQtc: qtOverQtc,
      );
    } catch (_) {
      // Matches NewEcgActivity's own try/catch around ecgAnalysis.analyse()
      // ("Unknown error in ECG Analysis") — any unexpected failure in a
      // best-effort clinical estimate should fall back to blank fields,
      // never crash the save flow.
      return null;
    }
  }
}

class _Analyzer {
  _Analyzer(this._ecgDataArray, this._valPerMv);

  final List<List<double>> _ecgDataArray;
  final double _valPerMv;

  final List<List<List<int>>> multiLeadData = List.generate(12, (_) => List.generate(12, (_) => List<int>.filled(12, 0)));
  final List<List<double>> analysisArray = List.generate(12, (_) => List<double>.filled(12, 0));
  final List<List<int>> _flagRegister = List.generate(12, (_) => List<int>.filled(12, 0));

  int analyse() {
    var ecgVal = _ecgDataArray[EcgAnalysisService._lead];
    final peakIndex = _fiducialPeakDetection(ecgVal);
    final rPeakIndex = _rPeaks(ecgVal, peakIndex);
    var avgHeartRate = _rrIntervalHr(rPeakIndex);
    final noOfPks = _peakCount(rPeakIndex);
    var dispeak = noOfPks - 2;

    if (noOfPks < 3) return 2;

    var fEcgVal = _lpfEcg40(ecgVal);
    var minVal = _minimum(fEcgVal);
    var maxVal = _maximum(fEcgVal);
    var simVal = _derivativeBpf(fEcgVal);
    var leadData = List.generate(12, (_) => List<int>.filled(12, 0));
    leadData[EcgAnalysisService._qIndex] = _qPeakDetect(fEcgVal, EcgAnalysisService._qWindow, simVal, rPeakIndex);
    leadData[EcgAnalysisService._qrsStIndex] = _qrsStart(leadData[EcgAnalysisService._qIndex], simVal);
    var rrFactor = _computeRrFactor(avgHeartRate);
    var pwindow = (EcgAnalysisService._pWindow / rrFactor).toInt();
    leadData[EcgAnalysisService._pIndex] = _ppeakDetect(fEcgVal, maxVal, minVal, rPeakIndex, pwindow, leadData[EcgAnalysisService._qrsStIndex]);
    leadData[EcgAnalysisService._sIndex] = _sPeakDetect(fEcgVal, simVal, EcgAnalysisService._sWindow, rPeakIndex);
    leadData[EcgAnalysisService._pStIndex] = _pStart(leadData[EcgAnalysisService._pIndex], fEcgVal, rPeakIndex, simVal, leadData[EcgAnalysisService._qrsStIndex]);
    leadData[EcgAnalysisService._pEnIndex] = _pEnd(leadData[EcgAnalysisService._pIndex], fEcgVal, rPeakIndex, leadData[EcgAnalysisService._qrsStIndex], simVal);
    leadData[EcgAnalysisService._qrsEnIndex] = _qrsEnd(leadData[EcgAnalysisService._sIndex], fEcgVal, simVal);
    var twindow = _tWindowCorrection(rPeakIndex, noOfPks).toInt();
    leadData[EcgAnalysisService._tIndex] = _tpeakDetect(maxVal, minVal, fEcgVal, rPeakIndex, twindow, leadData[EcgAnalysisService._qrsEnIndex], leadData[EcgAnalysisService._qrsStIndex], noOfPks);
    leadData[EcgAnalysisService._tStIndex] = _tStart(leadData[EcgAnalysisService._tIndex], fEcgVal, simVal, leadData[EcgAnalysisService._qrsEnIndex]);
    leadData[EcgAnalysisService._tEnIndex] = _tEnd(leadData[EcgAnalysisService._tIndex], fEcgVal, simVal, leadData[EcgAnalysisService._qrsEnIndex], leadData[EcgAnalysisService._pStIndex]);

    leadData[EcgAnalysisService._rIndex] = rPeakIndex;
    multiLeadData[EcgAnalysisService._lead] = leadData;

    for (var lead = 0; lead < 12; lead++) {
      ecgVal = _ecgDataArray[lead];
      fEcgVal = _lpfEcg40(ecgVal);
      leadData = List.generate(12, (_) => List<int>.filled(12, 0));
      minVal = _minimum(fEcgVal);
      maxVal = _maximum(fEcgVal);
      var stLevel = 0.0;
      var stSegSlope = 0.0;
      var interval = 0;
      var pqAvgInterval = 0.0;
      var qrsAvgInterval = 0.0;
      var qtAvgInterval = 0.0;
      var qAmp = 0.0, pAmp = 0.0, rAmp = 0.0, sAmp = 0.0, tAmp = 0.0;

      if (noOfPks != 0) {
        simVal = _derivativeBpf(fEcgVal);
        leadData[EcgAnalysisService._qIndex] = _qPeakDetect(fEcgVal, EcgAnalysisService._qWindow, simVal, rPeakIndex);
        leadData[EcgAnalysisService._qrsStIndex] = _qrsStart(leadData[EcgAnalysisService._qIndex], simVal);
        avgHeartRate = _rrIntervalHr(rPeakIndex);
        rrFactor = _computeRrFactor(avgHeartRate);
        pwindow = (EcgAnalysisService._pWindow / rrFactor).toInt();
        leadData[EcgAnalysisService._pIndex] = _ppeakDetect(fEcgVal, maxVal, minVal, rPeakIndex, pwindow, leadData[EcgAnalysisService._qrsStIndex]);
        leadData[EcgAnalysisService._pStIndex] = _pStart(leadData[EcgAnalysisService._pIndex], fEcgVal, rPeakIndex, simVal, leadData[EcgAnalysisService._qrsStIndex]);
        leadData[EcgAnalysisService._pEnIndex] = _pEnd(leadData[EcgAnalysisService._pIndex], fEcgVal, rPeakIndex, leadData[EcgAnalysisService._qrsStIndex], simVal);
        leadData[EcgAnalysisService._sIndex] = _sPeakDetect(fEcgVal, simVal, EcgAnalysisService._sWindow, rPeakIndex);
        leadData[EcgAnalysisService._qrsEnIndex] = _qrsEnd(leadData[EcgAnalysisService._sIndex], fEcgVal, simVal);
        twindow = _tWindowCorrection(rPeakIndex, noOfPks).toInt();
        leadData[EcgAnalysisService._tIndex] = _tpeakDetect(maxVal, minVal, fEcgVal, rPeakIndex, twindow, leadData[EcgAnalysisService._qrsEnIndex], leadData[EcgAnalysisService._qrsStIndex], noOfPks);
        leadData[EcgAnalysisService._tStIndex] = _tStart(leadData[EcgAnalysisService._tIndex], fEcgVal, simVal, leadData[EcgAnalysisService._qrsEnIndex]);
        leadData[EcgAnalysisService._tEnIndex] = _tEnd(leadData[EcgAnalysisService._tIndex], fEcgVal, simVal, leadData[EcgAnalysisService._qrsEnIndex], leadData[EcgAnalysisService._pStIndex]);

        final avgDc = _isoelectricLine(dispeak, fEcgVal, leadData[EcgAnalysisService._pStIndex], leadData[EcgAnalysisService._pEnIndex], leadData[EcgAnalysisService._qrsStIndex], leadData[EcgAnalysisService._qrsEnIndex], leadData[EcgAnalysisService._tEnIndex]);
        stLevel = _stSegment(fEcgVal, leadData[EcgAnalysisService._qrsEnIndex], leadData[EcgAnalysisService._tStIndex], avgDc, noOfPks);
        stSegSlope = _stSlope(fEcgVal, leadData[EcgAnalysisService._qrsEnIndex], leadData[EcgAnalysisService._tStIndex], noOfPks);
        rAmp = _peakAmplitude(rPeakIndex, fEcgVal, dispeak, noOfPks, leadData[EcgAnalysisService._pStIndex], leadData[EcgAnalysisService._pEnIndex], leadData[EcgAnalysisService._qrsStIndex], leadData[EcgAnalysisService._qrsEnIndex], leadData[EcgAnalysisService._tEnIndex]);
        interval = rPeakIndex[noOfPks - 1] - rPeakIndex[noOfPks - 2];

        multiLeadData[lead] = leadData;
        for (var i = 0; i < 12; i++) {
          if (leadData[EcgAnalysisService._qIndex][i] != 0 &&
              leadData[EcgAnalysisService._sIndex][i] != 0 &&
              leadData[EcgAnalysisService._pIndex][i] != 0 &&
              leadData[EcgAnalysisService._tIndex][i] != 0) {
            _flagRegister[lead][i] = 1;
          }
        }
        if (_flagRegister[lead][noOfPks - 2] == 1) {
          dispeak = noOfPks - 2;
        } else if (_flagRegister[lead][noOfPks - 3] == 1) {
          dispeak = noOfPks - 3;
        }

        pqAvgInterval = _avgPeakInterval(leadData[EcgAnalysisService._qrsStIndex], leadData[EcgAnalysisService._pStIndex], dispeak);
        qrsAvgInterval = _avgPeakInterval(leadData[EcgAnalysisService._qrsEnIndex], leadData[EcgAnalysisService._qrsStIndex], dispeak);
        qtAvgInterval = _avgPeakInterval(leadData[EcgAnalysisService._tEnIndex], leadData[EcgAnalysisService._qrsStIndex], dispeak);

        qAmp = _peakAmplitude(leadData[EcgAnalysisService._qIndex], fEcgVal, dispeak, noOfPks, leadData[EcgAnalysisService._pStIndex], leadData[EcgAnalysisService._pEnIndex], leadData[EcgAnalysisService._qrsStIndex], leadData[EcgAnalysisService._qrsEnIndex], leadData[EcgAnalysisService._tEnIndex]);
        pAmp = _peakAmplitude(leadData[EcgAnalysisService._pIndex], fEcgVal, dispeak, noOfPks, leadData[EcgAnalysisService._pStIndex], leadData[EcgAnalysisService._pEnIndex], leadData[EcgAnalysisService._qrsStIndex], leadData[EcgAnalysisService._qrsEnIndex], leadData[EcgAnalysisService._tEnIndex]);
        sAmp = _peakAmplitude(leadData[EcgAnalysisService._sIndex], fEcgVal, dispeak, noOfPks, leadData[EcgAnalysisService._pStIndex], leadData[EcgAnalysisService._pEnIndex], leadData[EcgAnalysisService._qrsStIndex], leadData[EcgAnalysisService._qrsEnIndex], leadData[EcgAnalysisService._tEnIndex]);
        tAmp = _peakAmplitude(leadData[EcgAnalysisService._tIndex], fEcgVal, dispeak, noOfPks, leadData[EcgAnalysisService._pStIndex], leadData[EcgAnalysisService._pEnIndex], leadData[EcgAnalysisService._qrsStIndex], leadData[EcgAnalysisService._qrsEnIndex], leadData[EcgAnalysisService._tEnIndex]);

        final qtC = qtAvgInterval * 0.002 / math.sqrt(interval * 0.002);
        final ratioQtQtc = qtAvgInterval * 0.002 / qtC;

        analysisArray[lead][0] = avgHeartRate;
        analysisArray[lead][1] = rAmp / (_valPerMv * EcgAnalysisService._scaleFactorForData);
        analysisArray[lead][2] = pAmp / (_valPerMv * EcgAnalysisService._scaleFactorForData);
        analysisArray[lead][3] = qAmp / (_valPerMv * EcgAnalysisService._scaleFactorForData);
        analysisArray[lead][4] = sAmp / (_valPerMv * EcgAnalysisService._scaleFactorForData);
        analysisArray[lead][5] = tAmp / (_valPerMv * EcgAnalysisService._scaleFactorForData);
        analysisArray[lead][6] = qrsAvgInterval * 0.002;
        analysisArray[lead][7] = pqAvgInterval * 0.002;
        analysisArray[lead][8] = qtAvgInterval * 0.002;
        analysisArray[lead][9] = stLevel / (_valPerMv * EcgAnalysisService._scaleFactorForData);
        analysisArray[lead][10] = stSegSlope / 0.002;
        analysisArray[lead][11] = ratioQtQtc;
      }
    }

    return 0;
  }

  List<int> _fiducialPeakDetection(List<double> ecgVal1) {
    final bpfVal = _casacadedBpf(ecgVal1);
    final deriVal = _derivativeBpf(bpfVal);
    final squareVal = _squareValuesInArray(deriVal);
    final mavgVal = _movAvgWindow(EcgAnalysisService._windowSizeMovAvg, squareVal);
    return _fiducialPeakDetect(EcgAnalysisService._fiducialThreshold, EcgAnalysisService._skipCount, mavgVal);
  }

  List<double> _casacadedBpf(List<double> ecgVal) => _lpf(_hpf(ecgVal));

  List<double> _lpf(List<double> ecgVal) {
    final lpfVal = List<double>.filled(EcgAnalysisService._maxEcgSamples, 0);
    final x = List<double>.filled(EcgAnalysisService._maxEcgSamples + 2, 0);
    final y = List<double>.filled(EcgAnalysisService._maxEcgSamples + 2, 0);
    for (var i = 2; i < EcgAnalysisService._maxEcgSamples + 2; i++) {
      x[i] = ecgVal[i - 2];
    }
    for (var i = 2; i < EcgAnalysisService._maxEcgSamples + 2; i++) {
      y[i] = (1.6128 * y[i - 1]) - (0.6764 * y[i - 2]) + (0.0159 * x[i]) + (0.0159 * 2 * x[i - 1]) + (0.0159 * x[i - 2]); // 22Hz with gain
    }
    for (var i = 2; i < EcgAnalysisService._maxEcgSamples + 2; i++) {
      lpfVal[i - 2] = y[i];
    }
    return lpfVal;
  }

  List<double> _hpf(List<double> ecgVal) {
    final hpfVal = List<double>.filled(EcgAnalysisService._maxEcgSamples, 0);
    final x = List<double>.filled(EcgAnalysisService._tempMaxEcgSamples + 2, 0);
    final y = List<double>.filled(EcgAnalysisService._tempMaxEcgSamples + 2, 0);
    for (var i = 2; i < EcgAnalysisService._tempMaxEcgSamples + 2; i++) {
      x[i] = ecgVal[i - 2];
    }
    for (var i = 2; i < EcgAnalysisService._tempMaxEcgSamples + 2; i++) {
      y[i] = (0.8989 * x[i]) - (0.8989 * 2 * x[i - 1]) + (0.8989 * x[i - 2]) + (1.7874 * y[i - 1]) - (0.8080 * y[i - 2]); // 12Hz with gain
    }
    for (var i = 0; i < EcgAnalysisService._tempMaxEcgSamples - 100; i++) {
      hpfVal[i] = y[i + 102];
    }
    return hpfVal;
  }

  List<double> _derivativeBpf(List<double> bpfVal) {
    final deriVal = List<double>.filled(EcgAnalysisService._maxEcgSamples + 4, 0);
    final x = List<double>.filled(EcgAnalysisService._maxEcgSamples + 4, 0);
    final y = List<double>.filled(EcgAnalysisService._maxEcgSamples + 4, 0);
    for (var i = 4; i < EcgAnalysisService._maxEcgSamples + 4; i++) {
      x[i] = bpfVal[i - 4];
    }
    for (var i = 4; i < EcgAnalysisService._maxEcgSamples + 4; i++) {
      y[i] = ((2 * x[i]) + x[i - 1] - x[i - 3] - (2 * x[i - 4])) / 8;
    }
    for (var i = 4; i < EcgAnalysisService._maxEcgSamples + 4; i++) {
      deriVal[i - 4] = y[i];
    }
    return deriVal;
  }

  List<double> _squareValuesInArray(List<double> arr) {
    final sqArr = List<double>.filled(arr.length, 0);
    for (var i = 0; i < EcgAnalysisService._maxEcgSamples; i++) {
      sqArr[i] = arr[i] * arr[i];
    }
    return sqArr;
  }

  List<double> _movAvgWindow(int windowSize, List<double> squval) {
    final mwVal = List<double>.filled(EcgAnalysisService._maxEcgSamples, 0);
    final tempval = List<double>.filled(EcgAnalysisService._maxEcgSamples + EcgAnalysisService._windowSizeMovAvg, 0);
    for (var i = 0; i < EcgAnalysisService._maxEcgSamples; i++) {
      tempval[i] = squval[i];
    }
    var sum = 0.0;
    for (var i = 0; i < EcgAnalysisService._maxEcgSamples - 5; i++) {
      if (i == 0) {
        for (var j = i; j <= windowSize + i; j++) {
          sum += tempval[j];
        }
      } else {
        sum += tempval[windowSize + i];
        sum -= tempval[i - 1];
      }
      mwVal[i] = sum / windowSize;
    }
    return mwVal;
  }

  /// Pan-Tompkins-style adaptive-threshold peak detection — see the
  /// original's own inline comment: "spk=0.125*peak_val+0.875*spk;
  /// npk=0.125*peak_val+0.875*npk; threshold=npk+0.5*(spk+npk)".
  List<int> _fiducialPeakDetect(double threshold, int skipcount, List<double> simVal) {
    var spk = 0.0, npk = 0.0;
    var i = 0, j = 0;
    final peakindex = List<int>.filled(EcgAnalysisService._maxEcgSamples, 0);

    while (i < EcgAnalysisService._maxEcgSamples - 2) {
      i = i + 1;
      if (simVal[i] <= simVal[i - 1] && simVal[i] > threshold) {
        var peakIndex = i - 1;
        var skipFlag = true;
        final tempPk = 0.5 * simVal[peakIndex];
        var count = skipcount;
        while (count > 0) {
          if (simVal[i + 1] < (simVal[i] + 0.05) && simVal[i + 1] > threshold) {
            final tempval = simVal[i];
            if (tempval >= simVal[peakIndex]) peakIndex = i;
            count--;
            i++;
          } else {
            break;
          }
        }
        while (skipFlag && i < EcgAnalysisService._maxEcgSamples) {
          if (simVal[i] <= simVal[i - 1]) {
            i++;
            if (count > 0) count--;
            if (i >= EcgAnalysisService._maxEcgSamples - 2) break;
          } else {
            var count1 = 1;
            while (simVal[i] >= simVal[i - 1]) {
              final tempval = simVal[i];
              if (tempval >= simVal[peakIndex]) peakIndex = i;
              count1++;
              i++;
              if (i >= EcgAnalysisService._maxEcgSamples - 2) break;
            }
            if (count1 >= 10) skipFlag = false;
          }
        }
        if (i < EcgAnalysisService._maxEcgSamples - 2 && (simVal[i + 1] <= tempPk || count == 0)) {
          final peakVal = simVal[peakIndex];
          if (peakVal > threshold) {
            spk = 0.125 * peakVal + 0.875 * spk;
            peakindex[j] = peakIndex;
            j++;
          } else {
            npk = 0.125 * peakVal + 0.875 * npk;
          }
          threshold = npk + 0.5 * (spk + npk);
        }
      }
    }
    return peakindex;
  }

  List<int> _rPeaks(List<double> ecgval, List<int> peakindex) {
    final lpfVal = _lpfEcg40(ecgval);
    return _peakDetectQrs(lpfVal, EcgAnalysisService._qrsWindow, peakindex);
  }

  List<double> _lpfEcg40(List<double> ecgVal) {
    final lpfEcgval = List<double>.filled(EcgAnalysisService._maxEcgSamples + 2, 0);
    final x = List<double>.filled(EcgAnalysisService._tempMaxEcgSamples + 2, 0);
    final y = List<double>.filled(EcgAnalysisService._tempMaxEcgSamples + 2, 0);
    for (var i = 2; i < EcgAnalysisService._tempMaxEcgSamples + 2; i++) {
      x[i] = ecgVal[i - 2];
    }
    for (var i = 2; i < EcgAnalysisService._tempMaxEcgSamples + 2; i++) {
      y[i] = (1.3073 * y[i - 1]) - (0.4918 * y[i - 2]) + (0.0461 * x[i]) + (0.0461 * 2 * x[i - 1]) + (0.0461 * x[i - 2]);
    }
    for (var i = 0; i < EcgAnalysisService._tempMaxEcgSamples - 100; i++) {
      lpfEcgval[i] = y[i + 102];
    }
    return lpfEcgval;
  }

  List<int> _peakDetectQrs(List<double> ecgVal, int win1, List<int> peakindex1) {
    const q = 2;
    final rPeakIndex = List<int>.filled(12, 0);
    var minval = 0.0;
    for (var j = 0; j < EcgAnalysisService._maxEcgSamples; j++) {
      if (ecgVal[j] < minval) minval = ecgVal[j];
    }
    for (var j = 0; j < 12; j++) {
      if (peakindex1[j] > 0) {
        var k = peakindex1[j];
        var maxval = minval;
        for (var m = 1; m <= win1; m++) {
          if (k < EcgAnalysisService._maxEcgSamples - q && k > q + 9 && ecgVal.length > (k - q + 9)) {
            if (ecgVal[k - q] < ecgVal[k - q + 1] && ecgVal[k - q] > ecgVal[k - q - 1]) {
              if (ecgVal[k - q + 1] > maxval && ecgVal[k - q + 1] > (ecgVal[k - q + 9] + 5) && ecgVal[k - q + 1] > (ecgVal[k - q - 7] + 5)) {
                maxval = ecgVal[k - q + 1];
                rPeakIndex[j] = k - q + 1;
              }
            } else if (ecgVal[k - q] > ecgVal[k - q + 1] && ecgVal[k - q] > ecgVal[k - q - 1]) {
              if (ecgVal[k - q] > maxval && ecgVal[k - q] > (ecgVal[k - q + 8] + 5) && ecgVal[k - q] > (ecgVal[k - q - 8] + 5)) {
                maxval = ecgVal[k - q];
                rPeakIndex[j] = k - q;
              }
            } else if (ecgVal[k - q] > ecgVal[k - q + 1] && ecgVal[k - q] < ecgVal[k - q - 1]) {
              if (ecgVal[k - q - 1] > maxval && ecgVal[k - q - 1] > (ecgVal[k - q + 7] + 5) && ecgVal[k - q - 1] > (ecgVal[k - q - 9] + 5)) {
                maxval = ecgVal[k - q - 1];
                rPeakIndex[j] = k - q - 1;
              }
            }
            k++;
          }
        }
      }
    }
    return rPeakIndex;
  }

  /// "SP CHANGES"-patched version from the live source (differs from the
  /// original app's own dead first-draft copy of this file): keeps only
  /// the last 5 valid RR intervals for the initial average/mininterval
  /// estimate, and discards any post-cleanup interval outside 0.5x-1.5x of
  /// that average when computing the final per-cycle heart rates, instead
  /// of using every cycle unconditionally.
  double _rrIntervalHr(List<int> rPeakIndex) {
    var mininterval = 0.0;
    var rrAvg = 0.0;
    final rPeaks = List<int>.filled(12, 0);
    final hRate = List<double>.filled(12, 0);
    final rrInt = List<double>.filled(12, 0);
    var avgHRate = 0.0;

    var validCount = 0;
    var rrSum = 0.0;
    for (var i = 11; i > 0; i--) {
      if (rPeakIndex[i] > 0 && rPeakIndex[i - 1] > 0) {
        final rr = (rPeakIndex[i] - rPeakIndex[i - 1]).toDouble();
        rrSum += rr;
        validCount++;
        if (validCount == 5) break;
      }
    }
    if (validCount > 0) {
      rrAvg = rrSum / validCount;
      mininterval = 0.6 * rrAvg;
    }

    var j = -1;
    for (var i = 11; i > 0; i--) {
      if (rPeakIndex[i] > 0) {
        var k = 1;
        j++;
        while (j + 1 < rPeaks.length && rPeaks[j + 1] == 0 && i >= k) {
          if (i >= k && (rPeakIndex[i] - rPeakIndex[i - k]) > mininterval) {
            rPeaks[j] = rPeakIndex[i];
            if (j + 1 < rPeaks.length) rPeaks[j + 1] = rPeakIndex[i - k];
            break;
          } else {
            while (i >= k && (rPeakIndex[i] - rPeakIndex[i - k]) < mininterval) {
              rPeakIndex[i - k] = 0;
              k++;
            }
          }
        }
      }
    }

    for (var i = 0; i < 12; i++) {
      rPeakIndex[i] = 0;
      hRate[i] = 0;
      rrInt[i] = 0;
    }
    j = 0;
    for (var i = 11; i >= 0; i--) {
      if (rPeaks[i] > 0) {
        rPeakIndex[j] = rPeaks[i];
        j++;
      }
    }
    for (var i = 0; i < 11; i++) {
      if (rPeakIndex[i] > 0) {
        rrInt[i] = (rPeakIndex[i + 1] - rPeakIndex[i]).toDouble();
        if (rrInt[i] > (0.5 * rrAvg) && rrInt[i] < (1.5 * rrAvg)) {
          hRate[i] = 60.0 / (rrInt[i] / EcgAnalysisService._samplingRate);
        } else {
          hRate[i] = 0;
        }
      }
    }

    var hrCount = 0;
    var sumRate = 0.0;
    for (var i = 0; i < 12; i++) {
      if (hRate[i] > 0) {
        sumRate += hRate[i];
        hrCount++;
      }
    }
    if (hrCount > 0) avgHRate = sumRate / hrCount;
    return avgHRate;
  }

  int _peakCount(List<int> peakindex1) {
    var count = 0;
    for (var i = 0; i < 12; i++) {
      if (peakindex1[i] > 0) count++;
    }
    return count;
  }

  double _minimum(List<double> ecgVal) {
    var minval = 0.0;
    for (var i = 0; i < EcgAnalysisService._maxEcgSamples; i++) {
      if (ecgVal[i] < minval) minval = ecgVal[i];
    }
    return minval;
  }

  double _maximum(List<double> ecgVal) {
    var maxval = 0.0;
    for (var i = 0; i < EcgAnalysisService._maxEcgSamples; i++) {
      if (ecgVal[i] > maxval) maxval = ecgVal[i];
    }
    return maxval;
  }

  List<int> _qPeakDetect(List<double> ecgVal, int win1, List<double> ecgDer, List<int> rpeakindex1) {
    final qpeakIndex = List<int>.filled(12, 0);
    for (var j = 0; j < 12; j++) {
      if (rpeakindex1[j] > 0) {
        var k = rpeakindex1[j];
        if (ecgDer[k - 3] > 0) {
          while (k > 1 && ecgDer[k] > 0) {
            k--;
          }
          qpeakIndex[j] = k - 1;
          var minQ = ecgVal[qpeakIndex[j]];
          while (k > 1 && ecgVal[qpeakIndex[j]] > 0.3 * ecgVal[rpeakindex1[j]] && k > (rpeakindex1[j] - win1)) {
            while (k > 1 && ecgDer[k] > 0) {
              k--;
            }
            if (ecgVal[k - 1] < minQ) {
              qpeakIndex[j] = k - 1;
              minQ = ecgVal[qpeakIndex[j]];
            }
            k--;
          }
        } else if (ecgDer[k - 3] < 0) {
          while (k > 1 && ecgDer[k] < 0) {
            k--;
          }
          qpeakIndex[j] = k - 1;
          var minQ = ecgVal[qpeakIndex[j]];
          while (k > 1 && ecgVal[qpeakIndex[j]] > 0.3 * ecgVal[rpeakindex1[j]] && k > (rpeakindex1[j] - win1)) {
            while (k > 1 && ecgDer[k] < 0) {
              k--;
            }
            if (ecgVal[k - 1] > minQ) {
              qpeakIndex[j] = k - 1;
              minQ = ecgVal[qpeakIndex[j]];
            }
            k--;
          }
        }
      }
    }
    return qpeakIndex;
  }

  List<int> _qrsStart(List<int> qminindex, List<double> ecgDer) {
    final qrsStart = List<int>.filled(12, 0);
    final qrsStart1 = List<int>.filled(12, 0);
    final qrsStart2 = List<int>.filled(12, 0);

    for (var j = 0; j < 12; j++) {
      if (qminindex[j] > 0) {
        var k = qminindex[j];
        if (k > 10) {
          var pkecgDer = ecgDer[k];
          for (var c = 1; c < 10; c++) {
            if (ecgDer[k - c] < pkecgDer) pkecgDer = ecgDer[k - c];
          }
          var flag1 = 1;
          k = qminindex[j];
          flag1 = 1;
          while (k > 3 && flag1 == 1) {
            if (ecgDer[k] < ecgDer[k + 1] && ecgDer[k] <= ecgDer[k - 1]) {
              final maxval = ecgDer[k];
              const constant = 1.8;
              final threshold = maxval / constant;
              while (k > 3 && flag1 == 1) {
                if (ecgDer[k] < threshold) {
                  flag1 = 1;
                  k--;
                } else {
                  flag1 = 0;
                }
              }
              qrsStart1[j] = k - 3;
            }
            k--;
          }

          k = qminindex[j];
          flag1 = 1;
          while (k > 3 && flag1 == 1) {
            if (ecgDer[k] > ecgDer[k + 1] && ecgDer[k] >= ecgDer[k - 1]) {
              final maxval = ecgDer[k];
              const constant = 1.8;
              final threshold = maxval / constant;
              while (k > 3 && flag1 == 1) {
                if (ecgDer[k] > threshold) {
                  flag1 = 1;
                  k--;
                } else {
                  flag1 = 0;
                }
              }
              qrsStart2[j] = k - 3;
            }
            k--;
          }

          qrsStart[j] = qrsStart1[j] > qrsStart2[j] ? qrsStart1[j] : qrsStart2[j];
        }
      }
    }
    return qrsStart;
  }

  double _computeRrFactor(double avgHRate) => avgHRate < 130 ? avgHRate / 72 : avgHRate / 30;

  List<int> _ppeakDetect(List<double> ecgVal, double max, double min, List<int> rpeakindex1, int win1Init, List<int> qstartindex) {
    final ppeakindex = List<int>.filled(12, 0);
    final mxindex = List<int>.filled(12, 0);
    final mnindex = List<int>.filled(12, 0);

    for (var j = 0; j < 12; j++) {
      var win1 = win1Init;
      var sum1 = 0.0;
      var dcLength = 0;
      var avgDc1 = 0.0;
      if (qstartindex[j] > 15) {
        for (var i = 0; i < 15; i++) {
          sum1 += ecgVal[qstartindex[j] - i];
          dcLength++;
        }
      }
      if (dcLength > 0) avgDc1 = sum1 / dcLength;

      final peakVal = _calculateAvgLevel(ecgVal[rpeakindex1[j]], avgDc1);
      final threshold = 0.01 * peakVal.abs();

      if (qstartindex[j] > 0) {
        int k;
        if (multiLeadData[1][EcgAnalysisService._pIndex][j] > 0) {
          k = multiLeadData[1][EcgAnalysisService._pIndex][j] + 20;
          win1 = 40;
        } else {
          k = qstartindex[j] - 10;
        }

        var maxval = min;
        var mxpeakarea = 0.0;
        for (var m = 1; m <= win1; m++) {
          if (k > 15 && k < EcgAnalysisService._maxEcgSamples - 15) {
            if (ecgVal[k] > maxval && ecgVal[k] > (ecgVal[k + 15] + threshold) && ecgVal[k] > (ecgVal[k - 15] + threshold)) {
              maxval = ecgVal[k];
              mxindex[j] = k;
            }
          }
          k--;
        }
        if (mxindex[j] != 0) {
          mxpeakarea = _peakArea(ecgVal, mxindex[j], qstartindex[j], rpeakindex1[j]);
        }

        if (multiLeadData[1][EcgAnalysisService._pIndex][j] > 0) {
          k = multiLeadData[1][EcgAnalysisService._pIndex][j] + 15;
          win1 = 40;
        } else {
          k = qstartindex[j] - 10;
        }
        var minval = max;
        var mnpeakarea = 0.0;
        for (var m = 1; m <= win1; m++) {
          if (k > 15 && k < EcgAnalysisService._maxEcgSamples - 15) {
            if (ecgVal[k] < minval && ecgVal[k] < (ecgVal[k + 15] - threshold) && ecgVal[k] < (ecgVal[k - 15] - threshold)) {
              minval = ecgVal[k];
              mnindex[j] = k;
            }
          }
          k--;
        }
        if (mnindex[j] != 0) {
          mnpeakarea = _peakArea(ecgVal, mnindex[j], qstartindex[j], rpeakindex1[j]);
        }

        if (mxindex[j] > 0 && mnindex[j] == 0) ppeakindex[j] = mxindex[j];
        if (mnindex[j] > 0 && mxindex[j] == 0) ppeakindex[j] = mnindex[j];
        if (ppeakindex[j] == 0) {
          ppeakindex[j] = mxpeakarea >= mnpeakarea - threshold ? mxindex[j] : mnindex[j];
        }
      }
    }
    return ppeakindex;
  }

  double _calculateAvgLevel(double ecgVal, double avgDc) {
    if (avgDc >= 0) {
      return ecgVal >= 0 ? ecgVal - avgDc : -(ecgVal.abs() + avgDc);
    } else {
      return ecgVal >= 0 ? ecgVal + avgDc.abs() : ecgVal - avgDc;
    }
  }

  double _peakArea(List<double> ecgVal1, int mxindex, int qstartindex, int rpeakindex1) {
    var avg = 0.0, pkArea = 0.0, sum = 0.0;
    final minVal = _minimum(ecgVal1);
    final ecgVal = List<double>.generate(EcgAnalysisService._maxEcgSamples, (i) => ecgVal1[i] - minVal);

    var sum1 = 0.0;
    var dcLength = 0;
    if (qstartindex > 15) {
      for (var i = 0; i < 15; i++) {
        sum1 += ecgVal[qstartindex - i];
        dcLength++;
      }
    }
    final avgDc1 = dcLength > 0 ? sum1 / dcLength : 0.0;
    final peakVal = _calculateAvgLevel(ecgVal[rpeakindex1], avgDc1);
    final threshold = 0.01 * peakVal.abs();

    final avgVal = (ecgVal[mxindex + 15] + ecgVal[mxindex - 15]) / 2;

    if (ecgVal[mxindex] > (ecgVal[mxindex + 15] + threshold) && ecgVal[mxindex] > (ecgVal[mxindex - 15] + threshold)) {
      for (var i = mxindex - 15; i <= mxindex + 15; i++) {
        sum += ecgVal[i] < avgVal ? avgVal : ecgVal[i];
        avg += avgVal;
      }
      pkArea = (sum.abs() - avg.abs()).abs();
    } else if (ecgVal[mxindex] < (ecgVal[mxindex + 15] - threshold) && ecgVal[mxindex] < (ecgVal[mxindex - 15] - threshold)) {
      for (var i = mxindex - 15; i <= mxindex + 15; i++) {
        sum += ecgVal[i] > avgVal ? avgVal : ecgVal[i];
        avg += avgVal;
      }
      pkArea = (avg.abs() - sum.abs()).abs();
    }
    return pkArea;
  }

  List<int> _sPeakDetect(List<double> fEcgVal, List<double> ecgDer, int win1, List<int> rpeakindex1) {
    final sminindex = List<int>.filled(12, 0);
    for (var j = 0; j < 12; j++) {
      if (rpeakindex1[j] > 0) {
        var k = rpeakindex1[j];
        while (k < EcgAnalysisService._maxEcgSamples - 1 && ecgDer[k] > 0) {
          k++;
        }
        sminindex[j] = k + 1;
        var minval = fEcgVal[sminindex[j]];
        while (k < EcgAnalysisService._maxEcgSamples - 1 && fEcgVal[sminindex[j]] > 0.3 * fEcgVal[rpeakindex1[j]] && k < (rpeakindex1[j] + win1)) {
          while (k < EcgAnalysisService._maxEcgSamples - 1 && ecgDer[k] > 0) {
            k++;
          }
          if (fEcgVal[k + 1] < minval) {
            sminindex[j] = k + 1;
            minval = fEcgVal[sminindex[j]];
          }
          k++;
        }
      }
    }
    return sminindex;
  }

  List<int> _pStart(List<int> ppeakindex1, List<double> ecgVal, List<int> maxindex1, List<double> ecgDer, List<int> qrsStart) {
    final pStart = List<int>.filled(12, 0);
    const constant = 1.35;
    final pStartWindow = EcgAnalysisService._pStartWindow;

    for (var j = 0; j < 12; j++) {
      if (ppeakindex1[j] > 0 && ppeakindex1[j] > 11) {
        final peakVal = _calculateAvgLevel(ecgVal[ppeakindex1[j]], ecgVal[qrsStart[j]]);
        var k = ppeakindex1[j] + 2;
        var flag1 = true;

        if (ecgVal[ppeakindex1[j]] > ecgVal[ppeakindex1[j] - 15] && ecgVal[ppeakindex1[j]] > ecgVal[ppeakindex1[j] + 15]) {
          while (k > 0 && flag1 && k > (ppeakindex1[j] - pStartWindow)) {
            if (ecgDer[k] > ecgDer[k + 1] && ecgDer[k] >= ecgDer[k - 1]) {
              flag1 = _checkPosPeakstart(pStartWindow, ppeakindex1, ecgDer, j, k, constant, pStart);
              var pstartEcgVal = _calculateAvgLevel(ecgVal[k], ecgVal[qrsStart[j]]);
              while (k > 0 && pstartEcgVal > 0.1 * peakVal && k > (ppeakindex1[j] - pStartWindow)) {
                flag1 = true;
                while (k > 0 && flag1 && k > (ppeakindex1[j] - pStartWindow)) {
                  if (ecgDer[k] > ecgDer[k + 1] && ecgDer[k] >= ecgDer[k - 1]) {
                    flag1 = _checkPosPeakstart(pStartWindow, ppeakindex1, ecgDer, j, k, constant, pStart);
                  }
                  pstartEcgVal = _calculateAvgLevel(ecgVal[k], ecgVal[qrsStart[j]]);
                  k--;
                }
                k--;
              }
            }
            k--;
          }
          if (k < 0) pStart[j] = 1;
        }

        if (ecgVal[ppeakindex1[j]] < ecgVal[ppeakindex1[j] - 15] && ecgVal[ppeakindex1[j]] < ecgVal[ppeakindex1[j] + 15]) {
          while (k > 0 && flag1 && k > (ppeakindex1[j] - pStartWindow)) {
            if (ecgDer[k] < ecgDer[k + 1] && ecgDer[k] <= ecgDer[k - 1]) {
              flag1 = _checkNegPeakstart(pStartWindow, ppeakindex1, ecgDer, j, k, constant, pStart);
              var pstartEcgVal = _calculateAvgLevel(ecgVal[k], ecgVal[qrsStart[j]]);
              while (k > 0 && pstartEcgVal < 0.1 * peakVal && k > (ppeakindex1[j] - pStartWindow)) {
                flag1 = true;
                while (k > 0 && flag1 && k > (ppeakindex1[j] - pStartWindow)) {
                  if (ecgDer[k] < ecgDer[k + 1] && ecgDer[k] <= ecgDer[k - 1]) {
                    flag1 = _checkNegPeakstart(pStartWindow, ppeakindex1, ecgDer, j, k, constant, pStart);
                  }
                  pstartEcgVal = _calculateAvgLevel(ecgVal[k], ecgVal[qrsStart[j]]);
                  k--;
                }
                k--;
              }
            }
            k--;
          }
          if (k < 0) pStart[j] = 1;
        }
      }
    }
    return pStart;
  }

  bool _checkPosPeakstart(int startwindow, List<int> peakindex1, List<double> ecgDer, int j, int k, double constant, List<int> pkStart) {
    final maxval = ecgDer[k];
    final threshold = maxval / constant;
    var flag1 = true;
    while (k > 0 && flag1 && k > (peakindex1[j] - startwindow)) {
      if (ecgDer[k] >= threshold) {
        k--;
      } else {
        flag1 = false;
      }
    }
    if (k > (peakindex1[j] - startwindow)) {
      pkStart[j] = k - 2;
    } else {
      pkStart[j] = k - 2;
      flag1 = false;
    }
    return flag1;
  }

  bool _checkNegPeakstart(int startwindow, List<int> peakindex1, List<double> ecgDer, int j, int k, double constant, List<int> pkStart) {
    final maxval = ecgDer[k];
    final threshold = maxval / constant;
    var flag1 = true;
    while (k > 0 && flag1 && k > (peakindex1[j] - startwindow)) {
      if (ecgDer[k] <= threshold) {
        k--;
      } else {
        flag1 = false;
      }
    }
    if (k > (peakindex1[j] - startwindow)) {
      pkStart[j] = k - 2;
    } else {
      pkStart[j] = k - 2;
      flag1 = false;
    }
    return flag1;
  }

  List<int> _pEnd(List<int> ppeakindex1, List<double> ecgVal, List<int> maxindex1, List<int> qrsStart, List<double> ecgDer) {
    const constant = 2.0;
    final pEnd = List<int>.filled(12, 0);

    for (var j = 0; j < 12; j++) {
      if (ppeakindex1[j] > 0 && qrsStart[j] > 0 && ppeakindex1[j] > 11) {
        final peakVal = _calculateAvgLevel(ecgVal[ppeakindex1[j]], ecgVal[qrsStart[j]]);
        var k = ppeakindex1[j] + 2;
        var flag1 = 1;

        if (ecgVal[ppeakindex1[j]] > ecgVal[ppeakindex1[j] - 10] && ecgVal[ppeakindex1[j]] > ecgVal[ppeakindex1[j] + 10]) {
          while (flag1 == 1 && k < EcgAnalysisService._maxEcgSamples - 1) {
            if (ecgDer[k] < ecgDer[k + 1] && ecgDer[k] <= ecgDer[k - 1]) {
              flag1 = _checkPosPeakend(qrsStart, ecgDer, j, k, constant, pEnd);
              var pendEcgVal = _calculateAvgLevel(ecgVal[k], ecgVal[qrsStart[j]]);
              while (k < EcgAnalysisService._maxEcgSamples - 1 && pendEcgVal > 0.1 * peakVal) {
                flag1 = 1;
                while (flag1 == 1 && k < EcgAnalysisService._maxEcgSamples - 1) {
                  if (ecgDer[k] < ecgDer[k + 1] && ecgDer[k] <= ecgDer[k - 1]) {
                    flag1 = _checkPosPeakend(qrsStart, ecgDer, j, k, constant, pEnd);
                  }
                  pEnd[j] = pEnd[j] - 2;
                  k++;
                }
                pendEcgVal = _calculateAvgLevel(ecgVal[k], ecgVal[qrsStart[j]]);
                k++;
              }
            }
            k++;
          }
        }
        if (flag1 == 0) {
          var i = pEnd[j];
          while (i < (qrsStart[j] - 4) && i < EcgAnalysisService._maxEcgSamples - 1) {
            if ((ecgVal[i] == ecgVal[i + 1] && ecgVal[i] < ecgVal[i + 2]) || ecgVal[i] < ecgVal[i + 1]) {
              pEnd[j] = i;
              break;
            }
            i++;
          }
        }
        if (ecgVal[ppeakindex1[j]] < ecgVal[ppeakindex1[j] - 10] && ecgVal[ppeakindex1[j]] < ecgVal[ppeakindex1[j] + 10]) {
          while (flag1 == 1 && k < EcgAnalysisService._maxEcgSamples - 1) {
            if (ecgDer[k] > ecgDer[k + 1] && ecgDer[k] >= ecgDer[k - 1]) {
              flag1 = _checkNegPeakend(qrsStart, ecgDer, j, k, constant, pEnd);
              var pendEcgVal = _calculateAvgLevel(ecgVal[k], ecgVal[qrsStart[j]]);
              while (k < EcgAnalysisService._maxEcgSamples - 1 && pendEcgVal < 0.1 * peakVal) {
                flag1 = 1;
                while (flag1 == 1 && k < EcgAnalysisService._maxEcgSamples - 1) {
                  if (ecgDer[k] > ecgDer[k + 1] && ecgDer[k] >= ecgDer[k - 1]) {
                    flag1 = _checkNegPeakend(qrsStart, ecgDer, j, k, constant, pEnd);
                  }
                  pEnd[j] = pEnd[j] - 2;
                  k++;
                }
                pendEcgVal = _calculateAvgLevel(ecgVal[k], ecgVal[qrsStart[j]]);
                k++;
              }
            }
            k++;
          }
          if (flag1 == 0) {
            var i = pEnd[j];
            while (i < (qrsStart[j] - 4) && i < EcgAnalysisService._maxEcgSamples - 1) {
              if ((ecgVal[i] == ecgVal[i + 1] && ecgVal[i] > ecgVal[i + 2]) || ecgVal[i] > ecgVal[i + 1]) {
                pEnd[j] = i;
                break;
              }
              i++;
            }
          }
        }
      }
    }
    return pEnd;
  }

  int _checkPosPeakend(List<int> index, List<double> ecgDer, int j, int k, double constant, List<int> pkEnd) {
    final maxval = ecgDer[k];
    final threshold = maxval / constant;
    var flag1 = 1;
    while (flag1 == 1 && k < EcgAnalysisService._maxEcgSamples - 1) {
      if (ecgDer[k] < threshold) {
        k++;
      } else {
        flag1 = 0;
      }
    }
    if (k < index[j]) {
      pkEnd[j] = k + 2;
    } else {
      pkEnd[j] = index[j];
      flag1 = 0;
    }
    return flag1;
  }

  int _checkNegPeakend(List<int> index, List<double> ecgDer, int j, int k, double constant, List<int> pkEnd) {
    final maxval = ecgDer[k];
    final threshold = maxval / constant;
    var flag1 = 1;
    while (flag1 == 1 && k < EcgAnalysisService._maxEcgSamples - 1) {
      if (ecgDer[k] > threshold) {
        k++;
      } else {
        flag1 = 0;
      }
    }
    if (k < index[j]) {
      pkEnd[j] = k + 2;
    } else {
      pkEnd[j] = index[j];
      flag1 = 0;
    }
    return flag1;
  }

  List<int> _qrsEnd(List<int> sminindex, List<double> ecgVal, List<double> ecgDer) {
    final qrsEnd = List<int>.filled(12, 0);
    for (var j = 0; j < 12; j++) {
      if (sminindex[j] > 0) {
        var k = sminindex[j] + 2;
        var flag1 = 1;
        if (k > 40) {
          var pkecgDer = ecgDer[k];
          for (var c = 1; c < 40; c++) {
            if (ecgDer[k - c] > pkecgDer) pkecgDer = ecgDer[k - c];
          }
          while (k < EcgAnalysisService._maxEcgSamples - 1 && flag1 == 1) {
            if (ecgDer[k] > ecgDer[k + 1] && ecgDer[k] >= ecgDer[k - 1]) {
              final maxval = ecgDer[k];
              var constant = (maxval * 10) / pkecgDer;
              if (constant <= 4) {
                constant = 3;
              } else if (constant > 4 && constant <= 4.75) {
                constant = 8;
              } else if (constant > 4.75 && constant < 6.20) {
                constant = 9;
              } else if (constant >= 6.20) {
                constant = 12;
              }
              final threshold = maxval / constant;
              while (k < EcgAnalysisService._maxEcgSamples - 1 && flag1 == 1) {
                if (ecgDer[k] > threshold) {
                  flag1 = 1;
                  k++;
                } else {
                  flag1 = 0;
                }
              }
              qrsEnd[j] = k - 2;
            }
            k++;
          }
        }
      }
    }
    return qrsEnd;
  }

  double _tWindowCorrection(List<int> rPeakIndex, int noOfPks) {
    final rrInt = (rPeakIndex[noOfPks - 2] - rPeakIndex[noOfPks - 3]) / 500.0;
    return EcgAnalysisService._qtc * math.sqrt(rrInt) * 500;
  }

  List<int> _tpeakDetect(double max, double minimumVal, List<double> ecgVal, List<int> rPeakIndex, int win1, List<int> qendindex, List<int> qstartindex, int noOfPks) {
    final tpeakindex = List<int>.filled(12, 0);
    final mxindex = List<int>.filled(12, 0);
    final mnindex = List<int>.filled(12, 0);

    for (var j = 0; j < 12; j++) {
      var sum1 = 0.0;
      var dcLength = 0;
      if (qendindex[j] < EcgAnalysisService._maxEcgSamples - 25) {
        for (var i = 0; i < 25; i++) {
          sum1 += ecgVal[qendindex[j] + i];
          dcLength++;
        }
      }
      final avgDc1 = dcLength > 0 ? sum1 / dcLength : 0.0;
      final peakVal = _calculateAvgLevel(ecgVal[rPeakIndex[j]], avgDc1);
      final threshold = 0.04 * peakVal.abs();

      if (qendindex[j] > 0) {
        var k = qendindex[j] + 22;
        var maxval = minimumVal;
        final win = win1 - ((qendindex[j] + 20) - qstartindex[j]);
        for (var m = 1; m <= win; m++) {
          if (k > 0 && k < EcgAnalysisService._maxEcgSamples - 25) {
            if (ecgVal[k] > maxval && ecgVal[k] > (ecgVal[k + 25] + threshold) && ecgVal[k] > (ecgVal[k - 25] + threshold)) {
              maxval = ecgVal[k];
              mxindex[j] = k;
            }
          }
          k++;
        }

        k = qendindex[j] + 22;
        var minval = max;
        for (var m = 1; m <= win; m++) {
          if (k > 0 && k < EcgAnalysisService._maxEcgSamples - 25) {
            if (ecgVal[k] < minval && ecgVal[k] < (ecgVal[k + 25] - threshold) && ecgVal[k] < (ecgVal[k - 25] - threshold)) {
              minval = ecgVal[k];
              mnindex[j] = k;
            }
          }
          k++;
        }

        if (mxindex[j] > 0 && mnindex[j] == 0) tpeakindex[j] = mxindex[j];
        if (mnindex[j] > 0 && mxindex[j] == 0) tpeakindex[j] = mnindex[j];

        final rrInt = (rPeakIndex[noOfPks - 2] - rPeakIndex[noOfPks - 3]) / 500.0;
        final refIndex = (qstartindex[j] + ((0.33 * math.sqrt(rrInt)) * 500)).toInt();

        if (mxindex[j] > 0 && mnindex[j] > 0) {
          tpeakindex[j] = (refIndex - mxindex[j]).abs() < (refIndex - mnindex[j]).abs() ? mxindex[j] : mnindex[j];
        }
      }
    }
    return tpeakindex;
  }

  List<int> _tStart(List<int> tpeakindex1, List<double> ecgVal, List<double> ecgDer, List<int> qrsend) {
    final tStart = List<int>.filled(12, 0);
    const constant = 2.0;
    final tStartWindow = EcgAnalysisService._tStartWindow;

    for (var j = 0; j < 12; j++) {
      if (tpeakindex1[j] > 0 && tpeakindex1[j] < (EcgAnalysisService._maxEcgSamples - 11)) {
        final peakVal = _calculateAvgLevel(ecgVal[tpeakindex1[j]], ecgVal[qrsend[j]]);
        var k = tpeakindex1[j] + 2;
        var flag1 = true;

        if (ecgVal[tpeakindex1[j]] > ecgVal[tpeakindex1[j] - 10] && ecgVal[tpeakindex1[j]] >= ecgVal[tpeakindex1[j] + 10]) {
          while (flag1 && k > (tpeakindex1[j] - tStartWindow)) {
            if (ecgDer[k] > ecgDer[k + 1] && ecgDer[k] >= ecgDer[k - 1]) {
              flag1 = _checkPosPeakstart(tStartWindow, tpeakindex1, ecgDer, j, k, constant, tStart);
              if (tStart[j] < qrsend[j]) tStart[j] = qrsend[j];
              var tstartEcgVal = _calculateAvgLevel(ecgVal[k], ecgVal[qrsend[j]]);
              while (k > (tpeakindex1[j] - tStartWindow) && tstartEcgVal > 0.1 * peakVal) {
                flag1 = true;
                while (flag1 && k > (tpeakindex1[j] - tStartWindow)) {
                  if (ecgDer[k] > ecgDer[k + 1] && ecgDer[k] >= ecgDer[k - 1]) {
                    flag1 = _checkPosPeakstart(tStartWindow, tpeakindex1, ecgDer, j, k, constant, tStart);
                  }
                  if (tStart[j] < qrsend[j]) tStart[j] = qrsend[j];
                  tstartEcgVal = _calculateAvgLevel(ecgVal[k], ecgVal[qrsend[j]]);
                  k--;
                }
                k--;
              }
            }
            k--;
          }
        }
        if (ecgVal[tpeakindex1[j]] < ecgVal[tpeakindex1[j] - 10] && ecgVal[tpeakindex1[j]] <= ecgVal[tpeakindex1[j] + 10]) {
          while (flag1 && k > (tpeakindex1[j] - tStartWindow)) {
            if (ecgDer[k] < ecgDer[k + 1] && ecgDer[k] <= ecgDer[k - 1]) {
              flag1 = _checkNegPeakstart(tStartWindow, tpeakindex1, ecgDer, j, k, constant, tStart);
              if (tStart[j] < qrsend[j]) tStart[j] = qrsend[j];
              var tstartEcgVal = _calculateAvgLevel(ecgVal[k], ecgVal[qrsend[j]]);
              while (k > (tpeakindex1[j] - tStartWindow) && tstartEcgVal < 0.1 * peakVal) {
                flag1 = true;
                while (flag1 && k > (tpeakindex1[j] - tStartWindow)) {
                  if (ecgDer[k] < ecgDer[k + 1] && ecgDer[k] <= ecgDer[k - 1]) {
                    flag1 = _checkNegPeakstart(tStartWindow, tpeakindex1, ecgDer, j, k, constant, tStart);
                  }
                  if (tStart[j] < qrsend[j]) tStart[j] = qrsend[j];
                  tstartEcgVal = _calculateAvgLevel(ecgVal[k], ecgVal[qrsend[j]]);
                  k--;
                }
                k--;
              }
            }
            k--;
          }
        }
      }
    }
    return tStart;
  }

  List<int> _tEnd(List<int> tpeakindex1, List<double> ecgVal, List<double> ecgDer, List<int> qrsend, List<int> pStart) {
    var tEnd = List<int>.filled(12, 0);
    final tEndWindow = EcgAnalysisService._tEndWindow;

    for (var j = 0; j < 12; j++) {
      if (tpeakindex1[j] > 0 && tpeakindex1[j] < (EcgAnalysisService._maxEcgSamples - tEndWindow)) {
        final peakVal = _calculateAvgLevel(ecgVal[tpeakindex1[j]], ecgVal[qrsend[j]]);
        final k = tpeakindex1[j] + 2;
        var pkecgDer = ecgDer[k];
        for (var c = 1; c < 100; c++) {
          if (ecgDer[k - c] > pkecgDer) pkecgDer = ecgDer[k - c];
        }

        if (ecgVal[tpeakindex1[j]] > ecgVal[tpeakindex1[j] - 10] && ecgVal[tpeakindex1[j]] >= ecgVal[tpeakindex1[j] + 10]) {
          tEnd = _checkPostvTend(tpeakindex1, ecgVal, ecgDer, pStart, k, j, pkecgDer, peakVal, qrsend);
        }
        if (ecgVal[tpeakindex1[j]] < ecgVal[tpeakindex1[j] - 10] && ecgVal[tpeakindex1[j]] <= ecgVal[tpeakindex1[j] + 10]) {
          tEnd = _checkNegtvTend(tpeakindex1, ecgVal, ecgDer, pStart, k, j, pkecgDer, peakVal, qrsend);
        }
      }
    }
    return tEnd;
  }

  List<int> _checkPostvTend(List<int> tpeakindex1, List<double> ecgVal, List<double> ecgDer, List<int> pStart, int kInit, int jval, double pkecgDer, double peakVal, List<int> qrsend) {
    final tEnd = List<int>.filled(12, 0);
    final tEndWindow = EcgAnalysisService._tEndWindow;
    var flag1 = 1;
    final j = jval;
    var k = kInit;

    while (flag1 == 1 && k < (tpeakindex1[j] + tEndWindow) && k < EcgAnalysisService._maxEcgSamples - 1) {
      if (ecgDer[k] < ecgDer[k + 1] && ecgDer[k] <= ecgDer[k - 1]) {
        var threshold = _computeThreshold(pkecgDer, ecgDer[k]);
        while (flag1 == 1 && k < (tpeakindex1[j] + tEndWindow) && k < EcgAnalysisService._maxEcgSamples - 1) {
          if (ecgDer[k] < threshold) {
            flag1 = 1;
            k++;
          } else {
            flag1 = 0;
          }
        }
        if (k < (tpeakindex1[j] + tEndWindow)) {
          tEnd[j] = k + 2;
        } else {
          tEnd[j] = k + 2;
          flag1 = 0;
        }
        if (j < pStart.length - 1) {
          if (pStart[j + 1] > 0) {
            if (pStart[j + 1] > 0 && tEnd[j] > pStart[j + 1]) tEnd[j] = pStart[j + 1];
          }
        }
        var tendEcgVal = _calculateAvgLevel(ecgVal[k], ecgVal[qrsend[j]]);
        while (k < EcgAnalysisService._maxEcgSamples - 1 && tendEcgVal > 0.1 * peakVal) {
          flag1 = 1;
          while (flag1 == 1 && k < (tpeakindex1[j] + tEndWindow) && k < EcgAnalysisService._maxEcgSamples - 1) {
            if (ecgDer[k] < ecgDer[k + 1] && ecgDer[k] <= ecgDer[k - 1]) {
              threshold = _computeThreshold(pkecgDer, ecgDer[k]);
              while (flag1 == 1 && k < (tpeakindex1[j] + tEndWindow) && k < EcgAnalysisService._maxEcgSamples - 1) {
                if (ecgDer[k] < threshold) {
                  flag1 = 1;
                  k++;
                } else {
                  flag1 = 0;
                }
              }
              if (k < (tpeakindex1[j] + tEndWindow)) {
                tEnd[j] = k;
              } else {
                tEnd[j] = k;
                flag1 = 0;
              }
              if (j + 1 < pStart.length && pStart[j + 1] > 0 && tEnd[j] > pStart[j + 1]) {
                tEnd[j] = pStart[j + 1];
              }
            }
            tendEcgVal = _calculateAvgLevel(ecgVal[k], ecgVal[qrsend[j]]);
            k++;
          }
          k++;
        }
      }
      k++;
    }
    return tEnd;
  }

  List<int> _checkNegtvTend(List<int> tpeakindex1, List<double> ecgVal, List<double> ecgDer, List<int> pStart, int kInit, int jval, double pkecgDer, double peakVal, List<int> qrsend) {
    final tEnd = List<int>.filled(12, 0);
    final tEndWindow = EcgAnalysisService._tEndWindow;
    var flag1 = 1;
    final j = jval;
    var k = kInit;

    while (flag1 == 1 && k < (tpeakindex1[j] + tEndWindow) && k < EcgAnalysisService._maxEcgSamples - 1) {
      if (ecgDer[k] > ecgDer[k + 1] && ecgDer[k] >= ecgDer[k - 1]) {
        var threshold = _computeThreshold(pkecgDer, ecgDer[k]);
        while (flag1 == 1 && k < (tpeakindex1[j] + tEndWindow) && k < EcgAnalysisService._maxEcgSamples - 1) {
          if (ecgDer[k] > threshold) {
            flag1 = 1;
            k++;
          } else {
            flag1 = 0;
          }
        }
        if (k < (tpeakindex1[j] + tEndWindow)) {
          tEnd[j] = k + 2;
        } else {
          tEnd[j] = k + 2;
          flag1 = 0;
        }
        if (j + 1 < pStart.length && pStart[j + 1] > 0 && tEnd[j] > pStart[j + 1]) {
          tEnd[j] = pStart[j + 1];
        }
        var tendEcgVal = _calculateAvgLevel(ecgVal[k], ecgVal[qrsend[j]]);
        while (k < EcgAnalysisService._maxEcgSamples - 1 && tendEcgVal < 0.1 * peakVal) {
          flag1 = 1;
          while (flag1 == 1 && k < (tpeakindex1[j] + tEndWindow) && k < EcgAnalysisService._maxEcgSamples - 1) {
            if (ecgDer[k] > ecgDer[k + 1] && ecgDer[k] >= ecgDer[k - 1]) {
              threshold = _computeThreshold(pkecgDer, ecgDer[k]);
              while (flag1 == 1 && k < (tpeakindex1[j] + tEndWindow) && k < EcgAnalysisService._maxEcgSamples - 1) {
                if (ecgDer[k] > threshold) {
                  flag1 = 1;
                  k++;
                } else {
                  flag1 = 0;
                }
              }
              if (k < (tpeakindex1[j] + tEndWindow)) {
                tEnd[j] = k + 2;
              } else {
                tEnd[j] = k + 2;
                flag1 = 0;
              }
              if (j + 1 < pStart.length && pStart[j + 1] > 0 && tEnd[j] > pStart[j + 1]) {
                tEnd[j] = pStart[j + 1];
              }
            }
            tendEcgVal = _calculateAvgLevel(ecgVal[k], ecgVal[qrsend[j]]);
            k++;
          }
          k++;
        }
      }
      k++;
    }
    return tEnd;
  }

  double _computeThreshold(double pkecgDer, double maxval) {
    var constant = (maxval * 10) / pkecgDer;
    if (constant <= 0.13) {
      constant = 4.0;
    } else if (constant > 0.13 && constant <= 0.20) {
      constant = 5.0;
    } else if (constant > 0.20 && constant <= 0.41) {
      constant = 6.0;
    } else if (constant > 0.41) {
      constant = 7.0;
    }
    return maxval / constant;
  }

  double _peakAmplitude(List<int> peakindex, List<double> ecgVal, int dispeak, int noOfPks, List<int> pStart, List<int> pEnd, List<int> qrsStart, List<int> qrsEnd, List<int> tEnd) {
    final peakAmp = List<double>.filled(12, 0);
    for (var i = 1; i < noOfPks - 1; i++) {
      if (peakindex[i] > 0) {
        double avgDc1;
        if (multiLeadData[1][EcgAnalysisService._tIndex][i] > 0 && multiLeadData[1][EcgAnalysisService._pIndex][i] > 0) {
          if ((peakindex[i] - multiLeadData[1][EcgAnalysisService._tIndex][i]).abs() < (peakindex[i] - multiLeadData[1][EcgAnalysisService._pIndex][i]).abs()) {
            avgDc1 = _isoelectricLine(i, ecgVal, pStart, pEnd, qrsStart, qrsEnd, tEnd);
          } else {
            avgDc1 = _isoelectricLine(i - 1, ecgVal, pStart, pEnd, qrsStart, qrsEnd, tEnd);
          }
        } else {
          avgDc1 = _isoelectricLine(i, ecgVal, pStart, pEnd, qrsStart, qrsEnd, tEnd);
        }
        peakAmp[i] = avgDc1 >= 0 ? ecgVal[peakindex[i]] - avgDc1 : ecgVal[peakindex[i]] + avgDc1.abs();
      }
    }
    if (dispeak < 0 || dispeak >= 12) return 0;
    return peakAmp[dispeak];
  }

  double _isoelectricLine(int i, List<double> fecgval, List<int> pStart, List<int> pEnd, List<int> qrsStart, List<int> qrsEnd, List<int> tEnd) {
    var sum1 = 0.0;
    var dcLength = 0;
    var avgDc1 = 0.0;
    final ecgVal = fecgval;

    var startCount = 0;
    var endCount = 0;

    if (i + 1 >= pStart.length) return 0;

    if (tEnd[i] > 0) {
      if (pStart[i + 1] > 0) {
        startCount = tEnd[i];
        endCount = pStart[i + 1];
      } else if (pStart[i + 1] == 0 && qrsStart[i] > 0) {
        startCount = tEnd[i];
        endCount = qrsStart[i + 1];
      }
    } else if (tEnd[i] == 0 && qrsEnd[i] > 0) {
      if (pStart[i + 1] > 0) {
        startCount = qrsEnd[i];
        endCount = pStart[i + 1];
      } else if (pStart[i + 1] == 0 && qrsStart[i] > 0) {
        startCount = qrsEnd[i];
        endCount = qrsStart[i + 1];
      }
    }

    if (!(startCount == 0 || endCount == 0)) {
      if (startCount == endCount) endCount = startCount + 10;

      if (startCount > 0 && endCount > 0 && endCount < ecgVal.length - 1 && startCount > 0) {
        for (var n = startCount; n <= endCount; n++) {
          if (n > 0 && n < ecgVal.length - 1 && ecgVal[n] == ecgVal[n - 1] && ecgVal[n] == ecgVal[n + 1]) {
            sum1 += ecgVal[n];
            dcLength++;
          }
        }
        if (dcLength > 0) avgDc1 = sum1 / dcLength;
      }

      if (dcLength < 10) {
        sum1 = 0;
        dcLength = 0;
        for (var n = startCount; n <= endCount && n < ecgVal.length; n++) {
          sum1 += ecgVal[n];
          dcLength++;
        }
        if (dcLength > 0) avgDc1 = sum1 / dcLength;
      }
    }
    return avgDc1;
  }

  double _stSegment(List<double> ecgVal, List<int> qrsEnd, List<int> tStart, double avgDc, int noOfPks) {
    final stLevel = List<double>.filled(12, 0);
    final stLevelIndex = List<int>.filled(12, 0);
    for (var j = 0; j < 12; j++) {
      if (qrsEnd[j] > 0) {
        final k = qrsEnd[j] + 35;
        stLevelIndex[j] = k < tStart[j] ? k : tStart[j];
        stLevel[j] = _calculateAvgLevel(ecgVal[stLevelIndex[j]], avgDc);
      }
    }
    final idx = noOfPks - 2;
    return idx >= 0 && idx < 12 ? stLevel[idx] : 0;
  }

  double _stSlope(List<double> ecgVal, List<int> qrsEnd, List<int> tStart, int noOfPks) {
    final stSlope = List<double>.filled(12, 0);
    for (var j = 0; j < 12; j++) {
      if (qrsEnd[j] > 0) {
        final slopeEnd = tStart[j] > 0 ? tStart[j] : qrsEnd[j] + 60;
        if (slopeEnd < ecgVal.length && slopeEnd != qrsEnd[j]) {
          stSlope[j] = (ecgVal[slopeEnd] - ecgVal[qrsEnd[j]]) / (slopeEnd - qrsEnd[j]);
        }
      }
    }
    final idx = noOfPks - 2;
    return idx >= 0 && idx < 12 ? stSlope[idx] : 0;
  }

  double _avgPeakInterval(List<int> peakindex1, List<int> peakindex2, int dispeak) {
    var interval = 0.0;
    var count = 0.0;
    for (var i = 0; i < 12; i++) {
      if (peakindex1[i] > 0 && peakindex2[i] > 0) {
        interval += (peakindex1[i] - peakindex2[i]);
        count += 1;
      }
    }
    return count > 0 ? interval / count : 0;
  }
}
