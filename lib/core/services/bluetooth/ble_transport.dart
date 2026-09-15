import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'bt_protocol.dart';
import 'ecg_transport.dart';

/// BLE (GATT) transport, ported from the Android app's
/// `appbluetoothmodule/.../BleManager.java`. This is the ONLY transport
/// these ECG devices actually use — they are not classic-SPP/pairable
/// devices at all, which is why the classic path always failed pairing
/// for them. No bonding/pairing step exists anywhere in `BleManager`
/// (`connectGatt(..., TRANSPORT_LE)` connects directly), and this port
/// intentionally has none either.
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
    _connectionSub = _ble
        .connectToDevice(id: device.id, connectionTimeout: const Duration(seconds: 15))
        .listen((update) async {
      _state = update.connectionState;
      if (update.connectionState == DeviceConnectionState.connected) {
        // Best-effort tuning to match `BleManager.onConnectionStateChange()`
        // (CONNECTION_PRIORITY_HIGH + MTU 247 right after connecting).
        // Some OEM stacks/firmware reject or ignore these — that must never
        // fail the connection itself, hence the swallowed errors.
        try {
          await _ble.requestConnectionPriority(
            deviceId: device.id,
            priority: ConnectionPriority.highPerformance,
          );
        } catch (_) {
          // Non-fatal — device still works at the default connection interval.
        }
        try {
          await _ble.requestMtu(deviceId: device.id, mtu: 247);
        } catch (_) {
          // Non-fatal — falls back to the default (23-byte) MTU.
        }
        try {
          // `DeviceConnectionState.connected` fires as soon as the GATT
          // link is up — Android doesn't guarantee service discovery has
          // finished by then, so the very first characteristic read/write
          // right after connecting intermittently fails (a well-known
          // Android BLE timing gap, not device flakiness). Wait for the
          // real service to actually show up before declaring "connected",
          // retrying a few times since discovery can take a moment.
          await _waitForService(device.id);
          if (!completer.isCompleted) completer.complete();
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      }
      if (update.connectionState == DeviceConnectionState.disconnected && !completer.isCompleted) {
        completer.completeError(StateError('Failed to connect to ${device.name}'));
      }
    }, onError: (e) {
      if (!completer.isCompleted) completer.completeError(e);
    });
    await completer.future;
  }

  /// Polls [FlutterReactiveBle.getDiscoveredServices] until the ECG
  /// service actually appears, instead of assuming it's ready the instant
  /// the connection state flips to `connected`. Throws with the list of
  /// whatever services WERE found if it never shows up — far more useful
  /// for diagnosing a real UUID/firmware mismatch than the generic
  /// platform-channel error that write()/input would otherwise surface.
  Future<void> _waitForService(String deviceId) async {
    final target = Uuid.parse(BtProtocol.bleServiceUuid);
    const maxAttempts = 5;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      List<Service> services = const [];
      try {
        services = await _ble.getDiscoveredServices(deviceId);
      } catch (_) {
        // Discovery itself not finished yet — treated the same as "not
        // found this attempt" below, retried rather than failing outright.
      }
      if (services.any((s) => s.id == target)) return;
      if (attempt == maxAttempts) {
        final found = services.map((s) => s.id.toString()).join(', ');
        throw StateError(
          'ECG BLE service (${BtProtocol.bleServiceUuid}) never appeared after connecting. '
          'Services found: ${found.isEmpty ? '(none)' : found}',
        );
      }
      await Future.delayed(Duration(milliseconds: 300 * attempt));
    }
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
