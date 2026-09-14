import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'bt_protocol.dart';
import 'ecg_transport.dart';

/// BLE (GATT) transport — the iOS connection path, and an Android
/// alternative, for ECG devices whose firmware also exposes a BLE
/// service. Built on `flutter_reactive_ble`.
///
/// IMPORTANT: [BtProtocol.bleServiceUuid]/[bleRxCharacteristicUuid]/
/// [bleTxCharacteristicUuid] are placeholders — this codebase has no
/// existing BLE implementation to read the real UUIDs from (only classic
/// SPP exists today). Confirm the device's actual GATT profile with the
/// firmware team and update those constants before relying on this for a
/// real device; until then, `connect()`/`write()` here will not talk to
/// real hardware.
class BleTransport implements EcgTransport {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription<ConnectionStateUpdate>? _connectionSub;
  StreamSubscription<List<int>>? _notifySub;
  String? _deviceId;
  DeviceConnectionState _state = DeviceConnectionState.disconnected;

  QualifiedCharacteristic get _rxChar => QualifiedCharacteristic(
        serviceId: Uuid.parse(BtProtocol.bleServiceUuid),
        characteristicId: Uuid.parse(BtProtocol.bleRxCharacteristicUuid),
        deviceId: _deviceId!,
      );

  QualifiedCharacteristic get _txChar => QualifiedCharacteristic(
        serviceId: Uuid.parse(BtProtocol.bleServiceUuid),
        characteristicId: Uuid.parse(BtProtocol.bleTxCharacteristicUuid),
        deviceId: _deviceId!,
      );

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get isConnected => _state == DeviceConnectionState.connected;

  @override
  Stream<EcgDevice> scan() {
    final controller = StreamController<EcgDevice>();
    final sub = _ble.scanForDevices(withServices: []).listen(
      (device) {
        if (device.name.startsWith(BtProtocol.deviceNamePrefix)) {
          controller.add(EcgDevice(id: device.id, name: device.name, isBonded: false, transport: TransportType.ble));
        }
      },
      onError: controller.addError,
    );
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(EcgDevice device) async {
    _deviceId = device.id;
    final completer = Completer<void>();
    _connectionSub = _ble.connectToDevice(id: device.id).listen((update) {
      _state = update.connectionState;
      if (update.connectionState == DeviceConnectionState.connected && !completer.isCompleted) {
        completer.complete();
      }
      if (update.connectionState == DeviceConnectionState.disconnected && !completer.isCompleted) {
        completer.completeError(StateError('Failed to connect to ${device.name}'));
      }
    }, onError: (e) {
      if (!completer.isCompleted) completer.completeError(e);
    });
    await completer.future;
  }

  @override
  Future<void> disconnect() async {
    await _notifySub?.cancel();
    await _connectionSub?.cancel();
    _state = DeviceConnectionState.disconnected;
  }

  @override
  Stream<List<int>> get input {
    if (_deviceId == null) return const Stream.empty();
    return _ble.subscribeToCharacteristic(_rxChar);
  }

  @override
  Future<void> write(List<int> bytes) async {
    if (_deviceId == null) return;
    await _ble.writeCharacteristicWithoutResponse(_txChar, value: bytes);
  }
}
