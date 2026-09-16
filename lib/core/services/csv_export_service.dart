import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/models/ecg_record_model.dart';
import 'dr_cardio_storage.dart';
import 'ecg/ecg_data.dart';
import 'record_file_naming.dart';

/// Writes the same per-lead sample columns the original app's CSV export
/// (`settings.csv`) produced, for the `csv_file` part of `api/upload-pdf`.
class CsvExportService {
  CsvExportService._();

  static String _leadRows(EcgRecordModel record) {
    final buffer = StringBuffer();
    buffer.writeln(EcgData.leadName.join(','));
    final maxLen = record.leadData.fold<int>(0, (m, lead) => lead.length > m ? lead.length : m);
    for (var i = 0; i < maxLen; i++) {
      final row = record.leadData.map((lead) => i < lead.length ? lead[i].toStringAsFixed(4) : '').join(',');
      buffer.writeln(row);
    }
    return buffer.toString();
  }

  static Future<File> generate(EcgRecordModel record) async {
    final dir = await DrCardioStorage.csvDir();
    final file = File(p.join(dir.path, '${RecordFileNaming.stem(record)}.csv'));
    await file.writeAsString(_leadRows(record));
    return file;
  }

  /// Port of `mFile.saveCsvFileWithFilter()`: the same per-lead sample
  /// data, prefixed with a metadata header — written to the "Filtered
  /// Data" folder alongside the plain `csv` export. Not part of the
  /// server upload (the original never uploads this file either); it's a
  /// local-only export for anyone pulling files off the device directly.
  static Future<File> generateFiltered(EcgRecordModel record) async {
    final sampleCount = record.leadData.fold<int>(0, (m, lead) => lead.length > m ? lead.length : m);
    final header = StringBuffer()
      ..writeln('Filter,${record.filter}')
      ..writeln('Device Name,${record.deviceName}')
      ..writeln('Date Time,${record.dateTime.toIso8601String()}')
      ..writeln('Raw Data Count,$sampleCount')
      ..writeln('Gain,${record.gain}')
      ..writeln('Patient Name,${record.patient.name}')
      ..writeln('Patient ID,${record.patient.patientId}')
      ..writeln();

    final dir = await DrCardioStorage.filteredDataDir();
    final file = File(p.join(dir.path, '${RecordFileNaming.stem(record)}.csv'));
    await file.writeAsString(header.toString() + _leadRows(record));
    return file;
  }
}
