import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/models/ecg_record_model.dart';
import 'ecg/ecg_data.dart';

/// Writes the same per-lead sample columns the original app's CSV export
/// (`settings.csv`) produced, for the `csv_file` part of `api/upload-pdf`.
class CsvExportService {
  CsvExportService._();

  static Future<File> generate(EcgRecordModel record) async {
    final buffer = StringBuffer();
    buffer.writeln(EcgData.leadName.join(','));

    final maxLen = record.leadData.fold<int>(0, (m, lead) => lead.length > m ? lead.length : m);
    for (var i = 0; i < maxLen; i++) {
      final row = record.leadData.map((lead) => i < lead.length ? lead[i].toStringAsFixed(4) : '').join(',');
      buffer.writeln(row);
    }

    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory(p.join(dir.path, 'ecg_reports'));
    if (!await reportsDir.exists()) await reportsDir.create(recursive: true);
    final file = File(p.join(reportsDir.path, '${record.id}.csv'));
    await file.writeAsString(buffer.toString());
    return file;
  }
}
