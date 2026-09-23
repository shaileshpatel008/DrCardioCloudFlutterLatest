/// A discovered/connectable ECG device, transport-agnostic.
class EcgDevice {
  EcgDevice({required this.id, required this.name, required this.isBonded, required this.transport});
  final String id; // MAC address (classic) or peripheral id (BLE)
  final String name;
  final bool isBonded;
  final TransportType transport;
}

enum TransportType { classicSpp, ble }

/// Common surface both the classic-SPP (Android RFCOMM) and BLE transports
/// implement, so [BluetoothService]/[EcgEngine] don't need to know which
/// one is in use — same protocol bytes, same framing, different pipe.
abstract class EcgTransport {
  TransportType get type;

  Stream<EcgDevice> scan();
  Future<void> stopScan();

  Future<void> connect(EcgDevice device);
  Future<void> disconnect();

  /// Fires once when the transport detects the device has dropped the
  /// connection on its own (out of range, powered off, OS-level GATT
  /// drop) — as opposed to this app calling [disconnect] itself. Needed
  /// because [input] completing/erroring isn't a reliable enough signal on
  /// every platform/plugin combination: a BLE characteristic-notification
  /// stream can simply stop emitting on a mid-session disconnect without
  /// ever calling its stream's `onDone`/`onError`, which would otherwise
  /// leave [BluetoothService.state] stuck reporting `connected` forever.
  Stream<void> get onDisconnected;

  /// Raw incoming bytes from the device.
  Stream<List<int>> get input;

  /// Send raw bytes to the device (command bytes, ACK/ERR).
  Future<void> write(List<int> bytes);

  bool get isConnected;
}
