import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../data/models/ecg_record_model.dart';
import 'dr_cardio_storage.dart';
import 'record_file_naming.dart';

/// Raw waveform export mirroring the original app's `.dat` file
/// (`mFile.saveDatFile()` / `readDatFile()`, written to
/// `Documents/Dr.cardio/Data/`) — a portable, on-disk copy of the full
/// per-lead sample data, independent of the app's SQLite store, so a
/// recording's raw signal survives even if the database were ever lost,
/// and so a file can be pulled off the device the same way the legacy
/// app's were (Android's Files app / iOS's Files app "On My iPhone").
///
/// This is NOT byte-for-byte compatible with the legacy Java format — that
/// one also packs hardware-specific fields (`hwVersion`, `dcShift`) this
/// rewrite never tracked in the first place. It's a from-scratch format
/// this app both writes and reads: a small UTF-8 text header (so the file
/// is self-describing) followed by raw big-endian float32 samples,
/// sample-major across all 12 leads.
class DatFileService {
  DatFileService._();

  static const _dataMarker = '---DATA---\n';

  static Future<File> generate(EcgRecordModel record) async {
    final dir = await DrCardioStorage.dataDir();
    final file = File(p.join(dir.path, '${RecordFileNaming.stem(record)}.dat'));

    final leadCount = record.leadData.length;
    final sampleCount = record.leadData.fold<int>(0, (m, lead) => lead.length > m ? lead.length : m);

    final header = StringBuffer()
      ..writeln('FORMAT_VERSION|drcardio-dart-1')
      ..writeln('DEVICE_NAME|${record.deviceName}')
      ..writeln('DATE_TIME|${record.dateTime.toIso8601String()}')
      ..writeln('LEAD_COUNT|$leadCount')
      ..writeln('SAMPLE_COUNT|$sampleCount')
      ..writeln('FILTER|${record.filter}')
      ..writeln('GAIN|${record.gain}')
      ..writeln('PATIENT_NAME|${record.patient.name}')
      ..writeln('PATIENT_ID|${record.patient.patientId}')
      ..writeln('PATIENT_AGE|${record.patient.age}')
      ..writeln('PATIENT_SEX|${record.patient.sex}')
      ..write(_dataMarker);

    final samples = ByteData(sampleCount * leadCount * 4);
    var offset = 0;
    for (var i = 0; i < sampleCount; i++) {
      for (var lead = 0; lead < leadCount; lead++) {
        final leadSamples = record.leadData[lead];
        samples.setFloat32(offset, i < leadSamples.length ? leadSamples[i] : 0.0, Endian.big);
        offset += 4;
      }
    }

    final bytes = BytesBuilder()
      ..add(utf8.encode(header.toString()))
      ..add(samples.buffer.asUint8List());

    await file.writeAsBytes(bytes.toBytes());
    return file;
  }

  /// Reads a `.dat` file back into per-lead sample arrays — the write/read
  /// counterpart, for a future "restore from raw export" flow. Load Data's
  /// list currently reads from the SQLite store (faster, and already has
  /// the full record); this is for portability/export, not the primary
  /// read path.
  static Future<List<List<double>>> readLeadData(File file) async {
    final bytes = await file.readAsBytes();
    final markerBytes = utf8.encode(_dataMarker);
    final markerIndex = _indexOfBytes(bytes, markerBytes);
    if (markerIndex == -1) {
      throw const FormatException('Not a valid Dr.Cardio .dat file');
    }

    final header = utf8.decode(bytes.sublist(0, markerIndex));
    final fields = <String, String>{};
    for (final line in header.split('\n')) {
      final sep = line.indexOf('|');
      if (sep == -1) continue;
      fields[line.substring(0, sep)] = line.substring(sep + 1);
    }
    final leadCount = int.parse(fields['LEAD_COUNT'] ?? '0');
    final sampleCount = int.parse(fields['SAMPLE_COUNT'] ?? '0');

    final dataStart = markerIndex + markerBytes.length;
    final data = ByteData.sublistView(bytes, dataStart);
    final leadData = List.generate(leadCount, (_) => List<double>.filled(sampleCount, 0));
    var offset = 0;
    for (var i = 0; i < sampleCount; i++) {
      for (var lead = 0; lead < leadCount; lead++) {
        leadData[lead][i] = data.getFloat32(offset, Endian.big);
        offset += 4;
      }
    }
    return leadData;
  }

  static int _indexOfBytes(List<int> haystack, List<int> needle) {
    for (var i = 0; i <= haystack.length - needle.length; i++) {
      var match = true;
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }
}
