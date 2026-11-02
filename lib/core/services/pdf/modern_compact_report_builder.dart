import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../data/models/ecg_record_model.dart';
import '../ecg/ecg_data.dart';
import '../storage_service.dart';
import 'pdf_report_shared.dart';

/// "Modern Compact" — a dark sidebar carrying patient info and the key
/// figures (HR as a big tile, QRS/QT/QTc/PR/RR/R(II) underneath, comments,
/// signature), with a dense 12-lead grid filling the rest of the page.
/// Denser and less paper-like than the other formats, aimed at clinics
/// that print a lot of these and want to spend less per page.
class ModernCompactReportBuilder {
  ModernCompactReportBuilder._();

  static final _dark = PdfColor.fromHex('#201F1E');
  static final _lightOnDark = PdfColor.fromHex('#D8D4D0');
  static final _mutedOnDark = PdfColor.fromHex('#9A928E');
  static final _faintOnDark = PdfColor.fromHex('#70686F');
  static final _tileTint = PdfColor.fromHex('#F08A7D');

  static const _pageWidth = 785.89;

  /// A4 landscape content height is 539.2756pt (595.2756 - 56pt margins);
  /// kept a touch under that exact value — using 539.28 here previously
  /// came out *just* above the real figure due to floating-point
  /// rounding, and MultiPage's exact-fit check rejected a page that was
  /// taller than available space by a few thousandths of a point.
  static const _pageHeight = 539.0;
  static const _sidebarWidth = 170.0;

  static void addPages(
    pw.Document doc,
    EcgRecordModel record,
    StorageService storage,
    List<String> reportTypes,
    pw.MemoryImage? photoImage,
    pw.MemoryImage? signatureImage,
  ) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          for (var i = 0; i < reportTypes.length; i++) ...[
            if (i > 0) pw.NewPage(),
            _buildPage(record, storage, reportTypes[i], signatureImage),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildPage(EcgRecordModel record, StorageService storage, String reportType, pw.MemoryImage? signatureImage) {
    return pw.SizedBox(
      width: _pageWidth,
      height: _pageHeight,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _buildSidebar(record, signatureImage),
          pw.SizedBox(width: 14),
          pw.Expanded(child: _buildMain(record, storage, reportType)),
        ],
      ),
    );
  }

  static pw.Widget _buildSidebar(EcgRecordModel record, pw.MemoryImage? signatureImage) {
    final params = PdfReportShared.analysisItems(record);
    final sideParams = params.where((e) => e.key != 'HR').toList();
    final hrMatches = params.where((e) => e.key == 'HR');
    final hr = hrMatches.isEmpty ? null : hrMatches.first.value.replaceAll('/min', '');
    final comments = record.patient.comments.trim();
    final medications = record.patient.medications.trim();

    return pw.Container(
      width: _sidebarWidth,
      color: _dark,
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Container(width: 7, height: 7, decoration: pw.BoxDecoration(color: PdfReportShared.brandColor, shape: pw.BoxShape.circle)),
            pw.SizedBox(width: 5),
            pw.Text('DR. CARDIO', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _lightOnDark)),
          ]),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.white, thickness: 0.4),
          pw.SizedBox(height: 10),
          pw.Text(record.patient.name.isEmpty ? '-' : record.patient.name, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          pw.SizedBox(height: 2),
          pw.Text(
            '${record.patient.age.isEmpty ? '-' : record.patient.age} / ${record.patient.sex.isEmpty ? '-' : record.patient.sex}  ·  ID ${record.patient.patientId.isEmpty ? '-' : record.patient.patientId}',
            style: pw.TextStyle(fontSize: 7.5, color: _mutedOnDark),
          ),
          pw.SizedBox(height: 5),
          pw.Text(record.deviceName.isEmpty ? '-' : record.deviceName, style: pw.TextStyle(fontSize: 7, color: _faintOnDark)),
          pw.Text(PdfReportShared.formatDate(record.dateTime), style: pw.TextStyle(fontSize: 7, color: _faintOnDark)),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.white, thickness: 0.4),
          pw.SizedBox(height: 10),
          if (hr != null) ...[
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              // #C53827 (brand red) at ~16% opacity flattened over the
              // sidebar's #201F1E background, precomputed to a literal hex
              // rather than relying on PdfColor.flatten() at paint time.
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#3A231F'), borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(hr, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _tileTint)),
                  pw.Text('BPM', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: _tileTint)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
          ],
          if (sideParams.isNotEmpty)
            pw.Wrap(
              spacing: 10,
              runSpacing: 6,
              children: sideParams
                  .map((e) => pw.SizedBox(
                        width: 65,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(e.key, style: pw.TextStyle(fontSize: 6, color: _faintOnDark)),
                            pw.Text(e.value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          if (comments.isNotEmpty || medications.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.white, thickness: 0.4),
            pw.SizedBox(height: 8),
            pw.Text('COMMENTS', style: pw.TextStyle(fontSize: 6, color: _mutedOnDark)),
            pw.SizedBox(height: 2),
            if (comments.isNotEmpty) pw.Text(comments, style: pw.TextStyle(fontSize: 7, color: _lightOnDark)),
            if (medications.isNotEmpty) pw.Text('Meds: $medications', style: pw.TextStyle(fontSize: 6.5, color: _faintOnDark)),
          ],
          pw.Spacer(),
          pw.Divider(color: PdfColors.white, thickness: 0.4),
          pw.SizedBox(height: 6),
          if (signatureImage != null) pw.SizedBox(height: 18, child: pw.Image(signatureImage, fit: pw.BoxFit.contain)),
        ],
      ),
    );
  }

  static pw.Widget _buildMain(EcgRecordModel record, StorageService storage, String reportType) {
    final simultaneous = reportType.startsWith('Simultaneous');
    final (columns, rowsPerColumn) = PdfReportShared.gridShape(reportType);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('12-Lead ECG  ·  $reportType', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _dark)),
            pw.Text('X = ${storage.xAxisScale}mm/s  Y = 10mm/mV  ${record.filter}', style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#9A928E'))),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Expanded(child: _buildGrid(record, columns: columns, rowsPerColumn: rowsPerColumn, simultaneous: simultaneous)),
        if (reportType.contains('4x3')) ...[
          pw.SizedBox(height: 4),
          _buildRhythmStrip(record, storage.longLead),
        ],
        pw.SizedBox(height: 4),
        pw.Text(
          'Software calculated values · to be verified and confirmed by the doctor',
          style: pw.TextStyle(fontSize: 6.5, color: PdfColor.fromHex('#9A928E')),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  static pw.Widget _buildGrid(EcgRecordModel record, {required int columns, required int rowsPerColumn, required bool simultaneous}) {
    final columnWidgets = <pw.Widget>[];
    for (var col = 0; col < columns; col++) {
      final cells = <pw.Widget>[];
      for (var row = 0; row < rowsPerColumn; row++) {
        final index = PdfReportShared.leadIndexForCell(col, row, rowsPerColumn);
        final leadName = PdfReportShared.leadNameAt(index);
        final full = PdfReportShared.leadSamplesAt(record, index);
        final samples = simultaneous ? full : PdfReportShared.sequentialSlice(full, columns, col);
        cells.add(pw.Expanded(
          child: pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: PdfReportShared.borderColor, width: 0.5), bottom: pw.BorderSide(color: PdfReportShared.borderColor, width: 0.5))),
            child: pw.Stack(children: [
              pw.Positioned(top: 2, left: 3, child: pw.Text(leadName, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _dark))),
              pw.Center(child: PdfReportShared.tracePainter(samples, width: (_pageWidth - _sidebarWidth - 14) / columns, height: 36, color: _dark, strokeWidth: 0.7)),
            ]),
          ),
        ));
      }
      columnWidgets.add(pw.Expanded(child: pw.Column(children: cells)));
    }
    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: columnWidgets);
  }

  static pw.Widget _buildRhythmStrip(EcgRecordModel record, String longLead) {
    final index = EcgData.leadName.indexOf(longLead);
    final leadIndex = index == -1 ? 1 : index;
    final samples = PdfReportShared.leadSamplesAt(record, leadIndex);
    return pw.Container(
      height: 46,
      decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _dark, width: 1.4))),
      padding: const pw.EdgeInsets.only(top: 3),
      child: pw.Stack(children: [
        pw.Positioned(top: 2, left: 0, child: pw.Text('$longLead  ·  Rhythm', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _dark))),
        pw.Center(child: PdfReportShared.tracePainter(samples, width: _pageWidth - _sidebarWidth - 14, height: 40, color: _dark, strokeWidth: 0.7)),
      ]),
    );
  }
}
