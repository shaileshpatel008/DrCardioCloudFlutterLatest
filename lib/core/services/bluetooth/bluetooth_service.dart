import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';

import '../app_logger.dart';
import '../ecg/ecg_data.dart';
import 'ble_transport.dart';
import 'bt_frame_parser.dart';
import 'bt_protocol.dart';
import 'classic_spp_transport.dart';
import 'ecg_transport.dart';

enum BtConnectionState { disconnected, connecting, connected }

/// Transport-agnostic connection manager: picks classic SPP or BLE per
/// device, and drives the same framing/ACK logic as the original
/// `AppDeviceConnectedThread` regardless of which pipe the bytes came
/// through. Registered as a GetX service so every module (device scan,
/// home, live ECG) shares one connection.
class BluetoothService extends GetxService {
  final ClassicSppTransport classicSpp = ClassicSppTransport();
  final BleTransport ble = BleTransport();
  EcgTransport? _active;

  final BtFrameParser frameParser = BtFrameParser();
  StreamSubscription<List<int>>? _inputSub;

  int _packetCount = 0;
  int dataByteCount = BtProtocol.dataBytesV1;

  final Rx<BtConnectionState> state = BtConnectionState.disconnected.obs;
  final RxString connectedDeviceName = ''.obs;
  String connectedDeviceId = '';

  BluetoothService() {
    frameParser.onPacket.listen((packet) => _maybeSendAck(packet.isValid));
    // A v2 device announces itself with this marker somewhere in its
    // stream; a v1 device never sends it. Matches `AppDeviceConnectedThread
    // .read()`'s hardcoded `deviceVersion=2` on seeing 0x20 — the marker's
    // mere presence means v2, there's no separate version byte to parse.
    frameParser.onVersionMarker.listen((_) {
      EcgData.instance.hwVersion = 2;
      dataByteCount = BtProtocol.dataBytesV2;
      frameParser.dataByteCount = BtProtocol.dataBytesV2;
    });
  }

  /// Android shows both paired classic-SPP devices and BLE scan results;
  /// iOS (no classic-SPP API) only ever sees BLE.
  Stream<EcgDevice> scan() {
    if (Platform.isIOS) return ble.scan();
    return StreamGroupMerge([classicSpp.scan(), ble.scan()]).stream;
  }

  Future<List<EcgDevice>> pairedDevices() async {
    if (Platform.isIOS) return [];
    return classicSpp.pairedDevices();
  }

  Future<void> stopScan() async {
    await classicSpp.stopScan();
    await ble.stopScan();
  }

  Future<void> connect(EcgDevice device) async {
    state.value = BtConnectionState.connecting;
    try {
      _active = device.transport == TransportType.ble ? ble : classicSpp;
      await _active!.connect(device);
      connectedDeviceName.value = device.name;
      connectedDeviceId = device.id;
      _packetCount = 0;
      // Reset to v1 defaults on every fresh connection — a previous
      // session may have detected a v2 device, and this one might not be.
      EcgData.instance.hwVersion = 1;
      dataByteCount = BtProtocol.dataBytesV1;
      frameParser.reset();
      frameParser.dataByteCount = dataByteCount;
      _inputSub = _active!.input.listen(
        (bytes) => frameParser.addBytes(bytes),
        onDone: () => state.value = BtConnectionState.disconnected,
        onError: (Object e, StackTrace st) {
          AppLogger.e('Bluetooth input stream error for ${device.name}', e, st);
          state.value = BtConnectionState.disconnected;
        },
      );
      state.value = BtConnectionState.connected;
      unawaited(checkHwVersion());
    } catch (e, st) {
      AppLogger.e('Failed to connect to ${device.name} (${device.transport})', e, st);
      state.value = BtConnectionState.disconnected;
      rethrow;
    }
  }

  /// Port of `MainActivity.checkHwVersion()`: probes the device right
  /// after connecting so [BtFrameParser.onVersionMarker] (listened to in
  /// the constructor) has a chance to fire and switch to v2 framing before
  /// any real acquisition starts. If nothing arrives within the same
  /// ~2-second window the original waits, the v1 defaults set in
  /// [connect] stand.
  Future<void> checkHwVersion() async {
    _write([BtProtocol.cmdVersionCheckA]);
    _write([BtProtocol.cmdStop]);
    _write([BtProtocol.cmdVersionCheckB]);
    await Future.delayed(const Duration(seconds: 2));
  }

  /// Port of `NewEcgActivity.setGain()`'s device-side half — tells the
  /// device which hardware gain to use. [actualGain] is the "actual gain"
  /// value (3/6/12 on the current BARC-restricted spinner), not the
  /// display label.
  void sendGain(int actualGain) {
    final cmd = BtProtocol.gainCommands[actualGain];
    if (cmd == null) {
      AppLogger.w('No gain command mapped for actualGain=$actualGain');
      return;
    }
    _write([cmd]);
  }

  Future<void> disconnect() async {
    await _inputSub?.cancel();
    await _active?.disconnect();
    connectedDeviceName.value = '';
    connectedDeviceId = '';
    state.value = BtConnectionState.disconnected;
  }

  void _maybeSendAck(bool ok) {
    _packetCount++;
    if (dataByteCount == BtProtocol.dataBytesV1 || _packetCount % 500 == 0) {
      _write([ok ? BtProtocol.cmdAck : BtProtocol.cmdErr]);
    }
  }

  void _write(List<int> bytes) => _active?.write(bytes);

  void sendStart() => _write([BtProtocol.cmdStart]);
  void sendTestStart() => _write([BtProtocol.cmdTestStart]);
  void sendStop() => _write([BtProtocol.cmdStop]);

  @override
  void onClose() {
    _inputSub?.cancel();
    frameParser.dispose();
    super.onClose();
  }
}

/// Minimal stream-merge helper (avoids pulling in `package:async` just for
/// `StreamGroup`).
class StreamGroupMerge<T> {
  StreamGroupMerge(this._sources);
  final List<Stream<T>> _sources;

  Stream<T> get stream {
    final controller = StreamController<T>();
    var remaining = _sources.length;
    final subs = <StreamSubscription<T>>[];
    for (final s in _sources) {
      subs.add(s.listen(
        controller.add,
        onError: controller.addError,
        onDone: () {
          remaining--;
          if (remaining == 0) controller.close();
        },
      ));
    }
    controller.onCancel = () async {
      for (final sub in subs) {
        await sub.cancel();
      }
    };
    return controller.stream;
  }
}
