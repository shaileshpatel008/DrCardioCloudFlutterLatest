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

  /// `MainActivity.checkHwVersion()`'s probe sequence — written as
  /// [cmdVersionCheckA], [cmdStop], [cmdVersionCheckB] right after
  /// connecting. A v2 device replies somewhere in its stream with
  /// [versionMarker] (0x20); a v1 device never sends it, so hwVersion
  /// stays 1 after a short timeout.
  static const int cmdVersionCheckA = 0x23;
  static const int cmdVersionCheckB = 0x56;

  /// `NewEcgActivity.setGain()`'s hardware gain command, keyed by the
  /// "actual gain" value (not the display label) — e.g. actualGain 6 sends
  /// 0x46. Only 3/6/12 are reachable from the current (BARC-restricted)
  /// gain spinner, but all seven from `DeviceCommands.xml` are kept here
  /// for fidelity to the device's real command set.
  static const Map<int, int> gainCommands = {
    1: 0x42,
    2: 0x43,
    3: 0x44,
    4: 0x45,
    6: 0x46,
    8: 0x47,
    12: 0x48,
  };

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
