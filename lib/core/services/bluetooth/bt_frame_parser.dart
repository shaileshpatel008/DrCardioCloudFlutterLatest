import 'dart:async';

import 'bt_protocol.dart';

/// One complete data frame from the device: either a valid packet
/// ([isValid] true) or a framing mismatch (still emitted so the caller can
/// ACK/ERR the device and keep it streaming).
class EcgFramePacket {
  EcgFramePacket({required this.isValid, required this.statusBytes, required this.dataBytes});
  final bool isValid;
  final List<int> statusBytes;
  final List<int> dataBytes;
}

enum _ParserState { waitingForSor, readingStatus, readingData, waitingForEor, resync }

/// Byte-at-a-time re-implementation of the framing state machine in
/// `AppDeviceConnectedThread.read()`. Feeding it raw bytes as they arrive
/// (from either the classic-SPP socket or a BLE notify stream — both feed
/// the same parser) reproduces the original's blocking-read behaviour
/// without needing a dedicated reader thread.
class BtFrameParser {
  BtFrameParser({this.dataByteCount = BtProtocol.dataBytesV1});

  int dataByteCount;

  _ParserState _state = _ParserState.waitingForSor;
  final List<int> _statusBuf = [];
  final List<int> _dataBuf = [];
  int _resyncCount = 0;

  /// SOR_B packets carry no status bytes of their own — the device only
  /// resends lead-off status on the (less frequent) SOR_A packets — so both
  /// the classic-SPP byte-at-a-time path ([addByte]) and the BLE path
  /// ([addBlePacket]) carry forward the last SOR_A's status bytes for every
  /// SOR_B packet in between, the same way `NewEcgActivity.lastStatusBytes`
  /// does. Without this, a SOR_B packet's [EcgFramePacket.statusBytes] would
  /// be empty, `EcgEngine` would never update `EcgData.leadStatus` for it,
  /// and — since most streamed samples arrive as SOR_B — the lead-off
  /// warning banner would only ever reflect whatever the very first SOR_A
  /// packet said, frozen from then on, rather than the device's current
  /// lead-off state.
  List<int> _lastStatusBytes = List.filled(BtProtocol.statusBytes, 0);

  final StreamController<EcgFramePacket> _packetController = StreamController<EcgFramePacket>.broadcast();
  final StreamController<void> _versionMarkerController = StreamController<void>.broadcast();

  Stream<EcgFramePacket> get onPacket => _packetController.stream;
  Stream<void> get onVersionMarker => _versionMarkerController.stream;

  void addBytes(Iterable<int> bytes) {
    for (final b in bytes) {
      addByte(b);
    }
  }

  void addByte(int byte) {
    final b = byte & 0xff;
    switch (_state) {
      case _ParserState.waitingForSor:
        if (b == BtProtocol.sorA) {
          _statusBuf.clear();
          _dataBuf.clear();
          _state = _ParserState.readingStatus;
        } else if (b == BtProtocol.sorB) {
          _statusBuf
            ..clear()
            ..addAll(_lastStatusBytes);
          _dataBuf.clear();
          _state = _ParserState.readingData;
        } else if (b == BtProtocol.versionMarker) {
          _versionMarkerController.add(null);
        }
        break;

      case _ParserState.readingStatus:
        _statusBuf.add(b);
        if (_statusBuf.length >= BtProtocol.statusBytes) {
          _lastStatusBytes = List.unmodifiable(_statusBuf);
          _state = _ParserState.readingData;
        }
        break;

      case _ParserState.readingData:
        _dataBuf.add(b);
        if (_dataBuf.length >= dataByteCount) {
          _state = _ParserState.waitingForEor;
        }
        break;

      case _ParserState.waitingForEor:
        if (b == BtProtocol.eor) {
          _packetController.add(EcgFramePacket(
            isValid: true,
            statusBytes: List.unmodifiable(_statusBuf),
            dataBytes: List.unmodifiable(_dataBuf),
          ));
          _state = _ParserState.waitingForSor;
        } else {
          _packetController.add(EcgFramePacket(
            isValid: false,
            statusBytes: List.unmodifiable(_statusBuf),
            dataBytes: List.unmodifiable(_dataBuf),
          ));
          _resyncCount = 0;
          _state = _ParserState.resync;
        }
        break;

      case _ParserState.resync:
        _resyncCount++;
        if (b == BtProtocol.eor || _resyncCount >= dataByteCount) {
          _state = _ParserState.waitingForSor;
        }
        break;
    }
  }

  /// Parses one complete, atomically-delivered BLE GATT notification,
  /// ported from `NewEcgActivity.processBleData()`. Unlike [addBytes] (a
  /// continuous classic-SPP byte stream fed one byte at a time), a BLE
  /// notification already arrives as a discrete, complete frame — and
  /// since the firmware packs as many samples as fit in the negotiated
  /// MTU, it often carries several samples back-to-back ahead of a single
  /// trailing EOR rather than exactly one like classic SPP always does.
  void addBlePacket(List<int> data) {
    if (data.isEmpty) return;
    final packetType = data[0] & 0xff;

    if (packetType == BtProtocol.versionMarker) {
      _versionMarkerController.add(null);
      return;
    }

    final int headerLen;
    if (packetType == BtProtocol.sorA) {
      headerLen = 1 + BtProtocol.statusBytes;
    } else if (packetType == BtProtocol.sorB) {
      headerLen = 1;
    } else {
      return; // Unknown packet type — discarded, same as the Android port.
    }

    const trailerLen = 1;
    if (data.length < headerLen + dataByteCount + trailerLen) {
      return; // Too short to hold even one whole sample — discarded.
    }

    final List<int> statusBytes;
    if (packetType == BtProtocol.sorA) {
      statusBytes = List.unmodifiable(data.sublist(1, 1 + BtProtocol.statusBytes));
      _lastStatusBytes = statusBytes;
    } else {
      statusBytes = _lastStatusBytes;
    }

    final sampleCount = (data.length - headerLen - trailerLen) ~/ dataByteCount;
    final payloadLen = sampleCount * dataByteCount;
    final eor = data[data.length - 1] & 0xff;

    _packetController.add(EcgFramePacket(
      isValid: eor == BtProtocol.eor,
      statusBytes: statusBytes,
      dataBytes: List.unmodifiable(data.sublist(headerLen, headerLen + payloadLen)),
    ));
  }

  void reset() {
    _state = _ParserState.waitingForSor;
    _statusBuf.clear();
    _dataBuf.clear();
    _resyncCount = 0;
    _lastStatusBytes = List.filled(BtProtocol.statusBytes, 0);
  }

  void dispose() {
    _packetController.close();
    _versionMarkerController.close();
  }
}
