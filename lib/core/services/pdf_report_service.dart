import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/ecg_record_model.dart';
import 'dr_cardio_storage.dart';
import 'pdf/classic_report_builder.dart';
import 'pdf/modern_clean_report_builder.dart';
import 'pdf/modern_compact_report_builder.dart';
import 'pdf/modern_dashboard_report_builder.dart';
import 'pdf/pdf_report_shared.dart';
import 'pdf/report_format.dart';
import 'record_file_naming.dart';
import 'storage_service.dart';

/// Builds the PDF report and dispatches to one of 4 selectable layouts
/// (Settings' "Report Format" picker, [StorageService.reportFormat]) —
/// each builder owns its own full page layout (Classic recreates the old
/// app's familiar pink ECG-paper grid with a refreshed header; Modern
/// Clean is this app's own from-scratch redesign that replaced
/// `SupportClass.PdfGenerator`'s manual `Canvas`/`Paint` drawing; Modern
/// Compact and Modern Dashboard are new alternatives) but all of them
/// share the same lead-indexing math and trace painter in
/// [PdfReportShared], so a lead's data and its printed label can never
/// drift apart regardless of which format is selected.
class PdfReportService {
  PdfReportService._();

  static Future<File> generate(EcgRecordModel record) async {
    final storage = StorageService.instance;
    final doc = pw.Document();
    final reportTypes = storage.reportTypes.isEmpty ? const ['Simultaneous 4x3'] : storage.reportTypes;
    final format = ReportFormat.fromStorageKey(storage.reportFormat);

    // Read once up front (the only async step) rather than per report-type
    // page — every builder's `_build*` methods stay synchronous. Port of
    // `PdfGenerator`'s non-empty-string-checked `patient_photo`/
    // `patient_signature_photo` draws: null here (empty path, or the file
    // no longer exists) means the page reserves no space for it at all,
    // not an empty box.
    final photoImage = await PdfReportShared.loadImage(record.patient.photoPath);
    final signatureImage = await PdfReportShared.loadImage(record.patient.signaturePath);

    switch (format) {
      case ReportFormat.classic:
        ClassicReportBuilder.addPages(doc, record, storage, reportTypes, photoImage, signatureImage);
      case ReportFormat.modernClean:
        ModernCleanReportBuilder.addPages(doc, record, storage, reportTypes, photoImage, signatureImage);
      case ReportFormat.modernCompact:
        ModernCompactReportBuilder.addPages(doc, record, storage, reportTypes, photoImage, signatureImage);
      case ReportFormat.modernDashboard:
        ModernDashboardReportBuilder.addPages(doc, record, storage, reportTypes, photoImage, signatureImage);
    }

    final dir = await DrCardioStorage.reportsDir();
    final file = File(p.join(dir.path, '${RecordFileNaming.stem(record)}.pdf'));
    await file.writeAsBytes(await doc.save());
    return file;
  }
}
