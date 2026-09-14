/// Wire protocol constants, ported from `appbluetoothmodule`'s
/// `AppBluetoothHelper` fields and `app/src/main/res/values/DeviceCommands.xml`
/// (identical in both the SDK repo and this production repo).
///
/// The ECG device speaks a simple framed protocol over classic Bluetooth
/// SPP (RFCOMM): a start-of-record marker, optional status bytes, a fixed
/// number of data bytes, then an end-of-record marker.
class BtProtocol {
  BtProtocol._();

  /// RFCOMM service UUID the Android app connects with (standard SPP UUID).
  static const String sppUuid = '00001101-0000-1000-8000-00805F9B34FB';

  /// Only devices whose advertised name starts with this prefix are shown
  /// (`R.string.bt_prefix` in `appbluetoothmodule/.../defaultSettings.xml`).
  static const String deviceNamePrefix = 'Dr.Cardio/';

  static const int sorA = 0xAA;
  static const int sorB = 0xBB;
  static const int eor = 0x0A;
  static const int statusBytes = 3;
  static const int dataBytesV1 = 16;
  static const int dataBytesV2 = 24;
  static const int versionMarker = 0x20;

  static const int cmdStart = 0x41;
  static const int cmdStop = 0x53;
  static const int cmdTestStart = 0x54;
  static const int cmdAck = 0x79;
  static const int cmdErr = 0x78;

  /// BLE (iOS + Android alternate transport) service/characteristic UUIDs.
  /// PLACEHOLDER — the device's real BLE GATT profile wasn't available to
  /// read in this session; ask the firmware/hardware team for the actual
  /// service UUID and Rx/Tx characteristic UUIDs and replace these before
  /// shipping an iOS build. Framing (SOR/EOR/ACK bytes) is expected to be
  /// identical to the SPP transport, just carried over BLE notify/write
  /// instead of an RFCOMM byte stream.
  static const String bleServiceUuid = '0000FFE0-0000-1000-8000-00805F9B34FB';
  static const String bleRxCharacteristicUuid = '0000FFE1-0000-1000-8000-00805F9B34FB';
  static const String bleTxCharacteristicUuid = '0000FFE2-0000-1000-8000-00805F9B34FB';
}
