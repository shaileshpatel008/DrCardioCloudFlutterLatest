import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';

import '../app_logger.dart';
import '../ecg/ecg_data.dart';
import '../storage_service.dart';
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
  StreamSubscription<void>? _disconnectSub;

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

  /// Upper bound on a single connection attempt. Without this, a native
  /// socket/GATT call that never resolves (observed when the OS/peripheral
  /// already considers the device connected from a previous attempt this
  /// app lost track of — e.g. after a hot-restart or a killed process)
  /// leaves [state] stuck at `connecting` forever: the `catch` block below
  /// that resets it to `disconnected` never runs because nothing ever
  /// throws or completes. That, in turn, permanently blocks
  /// [autoReconnectIfNeeded] (which only acts when `disconnected`) and
  /// makes `HomeController.startNewEcg()` show its "trying to connect…"
  /// toast forever with no way to recover short of killing the app.
  static const _connectTimeout = Duration(seconds: 20);

  Future<void> connect(EcgDevice device) async {
    state.value = BtConnectionState.connecting;
    try {
      _active = device.transport == TransportType.ble ? ble : classicSpp;
      await _active!.connect(device).timeout(
            _connectTimeout,
            onTimeout: () => throw TimeoutException('Connecting to ${device.name} timed out'),
          );
      connectedDeviceName.value = device.name;
      connectedDeviceId = device.id;
      _packetCount = 0;
      // Reset to v1 defaults on every fresh connection — a previous
      // session may have detected a v2 device, and this one might not be.
      EcgData.instance.hwVersion = 1;
      dataByteCount = BtProtocol.dataBytesV1;
      frameParser.reset();
      frameParser.dataByteCount = dataByteCount;
      final isBle = device.transport == TransportType.ble;
      _inputSub = _active!.input.listen(
        // BLE notifications arrive as discrete, already-framed packets (and
        // often batch several samples ahead of one trailing EOR); classic
        // SPP is a continuous byte stream fed one byte at a time instead.
        (bytes) => isBle ? frameParser.addBlePacket(bytes) : frameParser.addBytes(bytes),
        onDone: () => state.value = BtConnectionState.disconnected,
        onError: (Object e, StackTrace st) {
          AppLogger.e('Bluetooth input stream error for ${device.name}', e, st);
          state.value = BtConnectionState.disconnected;
        },
      );
      // Belt-and-braces alongside the above: a BLE notification stream can
      // simply stop emitting on a mid-session disconnect without ever
      // calling `onDone`/`onError` (its notification subscription and its
      // connection-state tracking are two separate things under the hood),
      // which would otherwise leave `state` stuck reporting `connected`
      // long after the device is actually gone — see `EcgTransport
      // .onDisconnected`'s doc comment.
      await _disconnectSub?.cancel();
      _disconnectSub = _active!.onDisconnected.listen((_) {
        state.value = BtConnectionState.disconnected;
      });
      state.value = BtConnectionState.connected;
      unawaited(checkHwVersion());
    } catch (e, st) {
      AppLogger.e('Failed to connect to ${device.name} (${device.transport})', e, st);
      state.value = BtConnectionState.disconnected;
      rethrow;
    }
  }

  /// Port of `MainActivity.checkLastConnectedDevice()`/`tryConnectTo()`:
  /// silently reconnects to whichever device was last successfully
  /// connected, directly by its stored address — not via a fresh scan,
  /// since a device already connected (as this one may still be at the
  /// OS/GATT level even after this app's process was killed and
  /// restarted) stops advertising and would never show up in one. Called
  /// once per app session from `HomeController.onInit()`; failures are
  /// swallowed since this is a best-effort background attempt, not a
  /// user-initiated action that deserves an error dialog — the device
  /// card just goes on showing "not connected", same as if this were
  /// never attempted.
  Future<void> autoReconnectIfNeeded() async {
    if (state.value != BtConnectionState.disconnected) return;
    final storage = StorageService.instance;
    final address = storage.savedDeviceAddress;
    if (address.isEmpty) return;

    final device = EcgDevice(
      id: address,
      name: storage.savedDeviceName,
      isBonded: false,
      transport: storage.savedDeviceTransport == TransportType.classicSpp.name ? TransportType.classicSpp : TransportType.ble,
    );
    try {
      await connect(device);
    } catch (e, st) {
      AppLogger.w('Auto-reconnect to ${device.name} ($address) failed', e, st);
    }
  }

  /// Port of `MainActivity.checkHwVersion()`: probes the device right
  /// after connecting so [BtFrameParser.onVersionMarker] (listened to in
  /// the constructor) has a chance to fire and switch to v2 framing before
  /// any real acquisition starts. If nothing arrives within the same
  /// ~2-second window the original waits, the v1 defaults set in
  /// [connect] stand.
  Future<void> checkHwVersion() async {
    unawaited(_write([BtProtocol.cmdVersionCheckA]));
    unawaited(_write([BtProtocol.cmdStop]));
    unawaited(_write([BtProtocol.cmdVersionCheckB]));
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
    unawaited(_write([cmd]));
  }

  Future<void> disconnect() async {
    await _inputSub?.cancel();
    await _disconnectSub?.cancel();
    await _active?.disconnect();
    connectedDeviceName.value = '';
    connectedDeviceId = '';
    state.value = BtConnectionState.disconnected;
  }

  void _maybeSendAck(bool ok) {
    _packetCount++;
    // BLE always ACKs every packet — ported as-is from `NewEcgActivity`'s
    // explicit note that throttling BLE ACKs the same way classic SPP does
    // (every packet for v1, every 500th for v2) was tried and didn't help,
    // and risks stalling firmware that waits for an ACK before continuing.
    final isBle = _active?.type == TransportType.ble;
    if (isBle || dataByteCount == BtProtocol.dataBytesV1 || _packetCount % 500 == 0) {
      unawaited(_write([ok ? BtProtocol.cmdAck : BtProtocol.cmdErr]));
    }
  }

  /// Was fire-and-forget (`_active?.write(bytes)` with the returned Future
  /// discarded) — any failure from the transport (a dead classic-SPP
  /// socket, a BLE characteristic write rejected because the GATT
  /// connection had actually dropped) became an unhandled Future error
  /// nobody ever saw, and the caller had no way to tell a write actually
  /// reached the device from one that silently vanished. [sendStart]/
  /// [sendTestStart] need that distinction to warn the user instead of
  /// leaving the UI showing "recording" while nothing is happening.
  Future<bool> _write(List<int> bytes) async {
    try {
      await _active?.write(bytes);
      return true;
    } catch (e, st) {
      AppLogger.e('Bluetooth write failed (transport=${_active?.type})', e, st);
      return false;
    }
  }

  Future<bool> sendStart() => _write([BtProtocol.cmdStart]);
  Future<bool> sendTestStart() => _write([BtProtocol.cmdTestStart]);
  void sendStop() => unawaited(_write([BtProtocol.cmdStop]));

  @override
  void onClose() {
    _inputSub?.cancel();
    _disconnectSub?.cancel();
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
