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
          _statusBuf.clear();
          _dataBuf.clear();
          _state = _ParserState.readingData;
        } else if (b == BtProtocol.versionMarker) {
          _versionMarkerController.add(null);
        }
        break;

      case _ParserState.readingStatus:
        _statusBuf.add(b);
        if (_statusBuf.length >= BtProtocol.statusBytes) {
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

  void reset() {
    _state = _ParserState.waitingForSor;
    _statusBuf.clear();
    _dataBuf.clear();
    _resyncCount = 0;
  }

  void dispose() {
    _packetController.close();
    _versionMarkerController.close();
  }
}
