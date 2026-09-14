import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import 'bt_protocol.dart';
import 'ecg_transport.dart';

/// Android-only classic Bluetooth SPP (RFCOMM) transport — port of
/// `AppBluetoothHelper` + `AppBluetoothConnectionThread` +
/// `AppDeviceConnectedThread`, rebuilt on `flutter_bluetooth_serial`
/// instead of raw `BluetoothSocket`/`Thread`. This is the app's existing,
/// working connection mode on Android and stays the default there.
///
/// Classic SPP has no public iOS API at all (Apple doesn't expose it to
/// third-party apps), so this transport is never used on iOS —
/// [BleTransport] covers that platform.
class ClassicSppTransport implements EcgTransport {
  final FlutterBluetoothSerial _bt = FlutterBluetoothSerial.instance;
  BluetoothConnection? _connection;

  @override
  TransportType get type => TransportType.classicSpp;

  @override
  bool get isConnected => _connection?.isConnected ?? false;

  Future<List<EcgDevice>> pairedDevices() async {
    final bonded = await _bt.getBondedDevices();
    return bonded
        .where((d) => (d.name ?? '').startsWith(BtProtocol.deviceNamePrefix))
        .map((d) => EcgDevice(id: d.address, name: d.name ?? '', isBonded: true, transport: TransportType.classicSpp))
        .toList();
  }

  @override
  Stream<EcgDevice> scan() {
    final controller = StreamController<EcgDevice>();
    final sub = _bt.startDiscovery().listen(
      (result) {
        final name = result.device.name;
        if (name != null && name.startsWith(BtProtocol.deviceNamePrefix)) {
          controller.add(EcgDevice(
            id: result.device.address,
            name: name,
            isBonded: result.device.isBonded,
            transport: TransportType.classicSpp,
          ));
        }
      },
      onDone: () => controller.close(),
      onError: controller.addError,
    );
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  @override
  Future<void> stopScan() => _bt.cancelDiscovery();

  /// Port of `AppBluetoothConnectionThread.run()`'s bonding handling: on
  /// Android, `createRfcommSocketToServiceRecord().connect()` to an
  /// *unbonded* device frequently fails outright (no automatic OS pairing
  /// prompt) rather than pairing on the fly, so the original app checks
  /// bond state first and explicitly runs the pairing flow
  /// (`device.createBond()` + wait for `ACTION_BOND_STATE_CHANGED` ==
  /// `BOND_BONDED`, then retries the connection) before ever opening the
  /// socket. `bondDeviceAtAddress` is this plugin's equivalent of that
  /// bond-then-retry dance in one awaitable call.
  @override
  Future<void> connect(EcgDevice device) async {
    await stopScan();
    final bondState = await _bt.getBondStateForAddress(device.id);
    if (bondState != BluetoothBondState.bonded) {
      final bonded = await _bt.bondDeviceAtAddress(device.id);
      if (bonded != true) {
        throw StateError('Pairing with ${device.name} failed or was cancelled.');
      }
    }
    _connection = await BluetoothConnection.toAddress(device.id);
  }

  @override
  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
  }

  @override
  Stream<List<int>> get input => _connection?.input ?? const Stream.empty();

  @override
  Future<void> write(List<int> bytes) async {
    _connection?.output.add(Uint8List.fromList(bytes));
  }

  Future<bool> isBluetoothEnabled() async => await _bt.isEnabled ?? false;
  Future<void> requestEnable() => _bt.requestEnable();
}
