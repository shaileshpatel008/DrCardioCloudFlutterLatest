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

  /// Raw incoming bytes from the device.
  Stream<List<int>> get input;

  /// Send raw bytes to the device (command bytes, ACK/ERR).
  Future<void> write(List<int> bytes);

  bool get isConnected;
}
