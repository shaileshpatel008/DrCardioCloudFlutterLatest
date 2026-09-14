import 'package:flutter/foundation.dart';

/// Port of `Model.ecgData` (Java). Holds acquisition buffers, lead layout
/// and per-session patient metadata for one recording, kept as a
/// singleton the way the original used static fields.
class EcgData {
  EcgData._();
  static final EcgData instance = EcgData._();

  static const int noOfChannels = 12;

  int sampleRatePerSec = 500;
  int downSamplingRate = 10;
  int sampleDataSec = 3;
  int get sampleDataLength => sampleDataSec * sampleRatePerSec;

  int sampleDataCount = 0;
  List<List<double>> sampleData = [];
  List<double> dcShift = List.filled(noOfChannels, 0);

  List<List<double>> rawData = [];
  List<List<double>> dcCorrectedData = [];
  List<List<double>> filteredData = [];

  List<double> preIirX = List.filled(noOfChannels, 0);
  List<double> preIirY = List.filled(noOfChannels, 0);

  /// 1 for the original 2-byte-per-channel hardware, 2 for the newer
  /// 3-byte-per-channel hardware — set by `BluetoothService.checkHwVersion()`
  /// from the device's response right after connecting, matching
  /// `MainActivity.checkHwVersion()`/`setVersionSettings()`.
  int hwVersion = 1;

  /// ADC-counts-per-millivolt calibration constant (`SupportClass.settings
  /// .val_per_mv` in the original — "54.61 in data corresponds to 1mV in
  /// firmware v1"). Used for chart axis scaling, waveform measurement
  /// (R/P/Q/S/T amplitudes), and PDF/CSV export; derived from [hwVersion]
  /// rather than stored separately, since the two are never set independently
  /// in the original either.
  double get valPerMv => hwVersion == 2 ? 3495 : 54.61;

  int rawDataCount = 0;
  int displayDataCount = 0;

  int get displayDataRangeX => 13 * sampleRatePerSec ~/ downSamplingRate;

  String dateTime = '';

  String patientId = '';
  String patientName = '';
  String patientAge = '';
  String patientSex = '';
  String patientMedications = '';
  String patientBloodPressure = '';
  String patientDob = '';
  String patientHeight = '';
  String patientWeight = '';
  String patientComments = '';
  String patientDeviceId = '';

  static const List<int> leadArrange = [1, 2, 8, 9, 10, 11, 7, 3, 5, 4, 6, 0];
  static const List<String> leadName = ['I', 'II', 'III', 'aVR', 'aVL', 'aVF', 'V1', 'V2', 'V3', 'V4', 'V5', 'V6'];

  double graphScale = 1;
  String? deviceName;

  bool isReading = false;

  /// Per-lead sample buffers ready for charting (already down-sampled,
  /// DC-corrected and filtered). Index: [leadIndex][sampleIndex].
  final List<List<double>> chartData = List.generate(noOfChannels, (_) => <double>[]);

  /// Per-electrode lead-off status, refreshed from the status bytes on
  /// every SORa packet (index meaning matches `parseData.byteArrayToLeadStatus`:
  /// V1,V2,V3,V4,V5,V6,LeftLeg,RightLeg,LeftArm,RightArm). `true` = attached.
  final ValueNotifier<List<bool>> leadStatus = ValueNotifier<List<bool>>(List.filled(10, true));

  void resetEcgData() {
    patientId = '';
    patientName = '';
    patientAge = '';
    patientSex = '';
    patientMedications = '';
    patientBloodPressure = '';
    patientDob = '';
    patientHeight = '';
    patientWeight = '';
    patientComments = '';
    dateTime = DateTime.now().toIso8601String();
  }

  void initDataWithLength({required int maxReadSeconds}) {
    final int len = maxReadSeconds * sampleRatePerSec;
    displayDataCount = 0;
    sampleDataCount = 0;
    rawDataCount = 0;
    rawData = List.generate(len, (_) => List.filled(noOfChannels, 0.0));
    dcCorrectedData = List.generate(len, (_) => List.filled(noOfChannels, 0.0));
    filteredData = List.generate(len, (_) => List.filled(noOfChannels, 0.0));
    sampleData = List.generate(noOfChannels, (_) => List.filled(sampleDataLength, 0.0));
    dcShift = List.filled(noOfChannels, 0);
    preIirX = List.filled(noOfChannels, 0);
    preIirY = List.filled(noOfChannels, 0);
    for (final ch in chartData) {
      ch.clear();
    }
  }

  static double calcAvg(List<double> channel) {
    if (channel.isEmpty) return 0;
    final total = channel.fold<double>(0, (a, b) => a + b);
    return (total / channel.length).truncateToDouble();
  }
}
