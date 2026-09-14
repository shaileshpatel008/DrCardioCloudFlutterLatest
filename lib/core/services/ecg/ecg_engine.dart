import 'dart:async';

import 'package:flutter/foundation.dart';

import '../bluetooth/bluetooth_service.dart';
import '../bluetooth/bt_frame_parser.dart';
import '../storage_service.dart';
import 'ecg_data.dart';
import 'ecg_filter.dart';
import 'parse_data.dart';

/// Port of `SupportClass.DataHandlerThread`: turns parsed frames into 12
/// channel samples and runs baseline-capture -> DC-correction -> FIR
/// filter -> high-pass filter -> down-sample, same order as the original.
///
/// Two things this port deliberately does differently, both because the
/// original ran into real bugs from them (confirmed by this repo's own
/// later fixes to the same file):
///  - The elapsed-seconds tick used `x % sampleRatePerSec == 500`, which
///    can never be true — ported here as `== 0` so it actually fires.
///  - The original mutated MPAndroidChart's `LineData` directly from this
///    background-thread-equivalent, which is exactly what caused a real
///    `NegativeArraySizeException` once throughput increased (their fix:
///    queue values, drain on the main thread). Flutter's widget model
///    sidesteps this entirely: this class never touches a widget — it
///    only appends to a plain `List<double>` and bumps [revision], and the
///    chart widget reads that list when *it* rebuilds, on the UI isolate,
///    so there's no cross-thread mutation to race in the first place.
class EcgEngine {
  EcgEngine(this.bluetoothService) {
    _sub = bluetoothService.frameParser.onPacket.listen(_handlePacket);
  }

  final BluetoothService bluetoothService;
  late final StreamSubscription<EcgFramePacket> _sub;

  DateTime _lastStopAttempt = DateTime.now();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final StreamController<int> _secondTickController = StreamController<int>.broadcast();
  Stream<int> get onSecondTick => _secondTickController.stream;

  void _handlePacket(EcgFramePacket packet) {
    if (!packet.isValid) return;
    final ecg = EcgData.instance;
    final settings = StorageService.instance;

    if (!ecg.isReading) {
      final now = DateTime.now();
      if (_lastStopAttempt.add(const Duration(milliseconds: 100)).isBefore(now)) {
        bluetoothService.sendStop();
        _lastStopAttempt = now;
      }
      return;
    }

    if (packet.statusBytes.length >= 3) {
      ecg.leadStatus.value = ParseData.byteArrayToLeadStatus(packet.statusBytes);
    }

    final gain = double.tryParse(settings.actualGain) ?? 1;
    final bytesPerSample = ParseData.bytesPerSample();
    // A single payload can carry more than one sample back-to-back (seen
    // on BLE, which batches notifications); classic SPP always sends one
    // sample per SOR/EOR frame, so this loop runs once there.
    final sampleCount = packet.dataBytes.length ~/ bytesPerSample;

    for (var s = 0; s < sampleCount; s++) {
      final offset = s * bytesPerSample;
      final channels = ParseData.charArrayToChannels(packet.dataBytes, false, offset: offset);

      if (ecg.sampleDataCount < ecg.sampleDataLength) {
        for (var ch = 0; ch < EcgData.noOfChannels; ch++) {
          ecg.sampleData[ch][ecg.sampleDataCount] = channels[ch] / gain;
          if (ecg.sampleDataCount + 1 == ecg.sampleDataLength) {
            ecg.dcShift[ch] = EcgData.calcAvg(ecg.sampleData[ch]);
          }
        }
        ecg.sampleDataCount++;
        continue;
      }

      if (ecg.rawDataCount < ecg.rawData.length) {
        ecg.rawData[ecg.rawDataCount] = channels;
        _addEntry(ecg.rawDataCount, channels, gain);
        ecg.rawDataCount++;
      }
    }
    if (sampleCount > 0) revision.value++;
  }

  void _addEntry(int x, List<double> channels, double gain) {
    final ecg = EcgData.instance;
    if (x > ecg.filteredData.length) return;

    for (var chi = 0; chi < EcgData.noOfChannels; chi++) {
      final ch = EcgData.leadArrange[chi];
      final currVal = channels[ch] / gain;
      _prepareEntryPerChannel(chi, x, currVal);
    }

    if (x % ecg.sampleRatePerSec == 0 && x > 0) {
      _secondTickController.add(x ~/ ecg.sampleRatePerSec);
    }

    if (ecg.rawDataCount % ecg.downSamplingRate == 0) {
      ecg.displayDataCount++;
    }
  }

  void _prepareEntryPerChannel(int chi, int x, double currVal) {
    final ecg = EcgData.instance;
    final ch = EcgData.leadArrange[chi];

    ecg.dcCorrectedData[x][ch] = currVal - ecg.dcShift[ch];
    ecg.filteredData[x][ch] = EcgFilter.filter(ch, x, ecg.dcCorrectedData[x][ch]);
    final hpfVal = EcgFilter.highPassFilter(ch, x, ecg.filteredData[x][ch]);

    if (ecg.rawDataCount % ecg.downSamplingRate == 0) {
      final scaledValue = ecg.graphScale * hpfVal;
      ecg.chartData[chi].add(scaledValue);
    }
  }

  void dispose() {
    _sub.cancel();
    _secondTickController.close();
    revision.dispose();
  }
}
