import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/ecg_record_model.dart';
import '../constants/app_assets.dart';
import 'dr_cardio_storage.dart';
import 'pdf/classic_report_builder.dart';
// Play Store release: the other 3 formats are unused while generation is
// forced to Classic below — uncomment these along with the dispatch switch
// to restore them.
// import 'pdf/modern_clean_report_builder.dart';
// import 'pdf/modern_compact_report_builder.dart';
// import 'pdf/modern_dashboard_report_builder.dart';
import 'pdf/pdf_report_shared.dart';
// import 'pdf/report_format.dart';
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

    // Play Store release: format picker is hidden (see settings_view.dart)
    // and every report is forced to Classic for now, regardless of any
    // stored preference. Restore the dynamic dispatch below (and re-enable
    // the picker) once the other formats are ready.
    // final format = ReportFormat.fromStorageKey(storage.reportFormat);

    // Read once up front (the only async step) rather than per report-type
    // page — every builder's `_build*` methods stay synchronous. Port of
    // `PdfGenerator`'s non-empty-string-checked `patient_photo`/
    // `patient_signature_photo` draws: null here (empty path, or the file
    // no longer exists) means the page reserves no space for it at all,
    // not an empty box.
    final photoImage = await PdfReportShared.loadImage(record.patient.photoPath);
    final signatureImage = await PdfReportShared.loadImage(record.patient.signaturePath);
    final logoImage = pw.MemoryImage((await rootBundle.load(AppAssets.logoFull)).buffer.asUint8List());

    // Play Store release: always Classic. Restore this dynamic dispatch
    // (and the `format` line above) when the other formats are ready:
    // switch (format) {
    //   case ReportFormat.classic:
    //     ClassicReportBuilder.addPages(doc, record, storage, reportTypes, photoImage, signatureImage, logoImage);
    //   case ReportFormat.modernClean:
    //     ModernCleanReportBuilder.addPages(doc, record, storage, reportTypes, photoImage, signatureImage);
    //   case ReportFormat.modernCompact:
    //     ModernCompactReportBuilder.addPages(doc, record, storage, reportTypes, photoImage, signatureImage);
    //   case ReportFormat.modernDashboard:
    //     ModernDashboardReportBuilder.addPages(doc, record, storage, reportTypes, photoImage, signatureImage);
    // }
    ClassicReportBuilder.addPages(doc, record, storage, reportTypes, photoImage, signatureImage, logoImage);

    final dir = await DrCardioStorage.reportsDir();
    final file = File(p.join(dir.path, '${RecordFileNaming.stem(record)}.pdf'));
    await file.writeAsBytes(await doc.save());
    return file;
  }
}
