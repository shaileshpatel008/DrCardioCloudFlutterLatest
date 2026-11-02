import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../data/models/ecg_record_model.dart';
import '../ecg/ecg_data.dart';
import '../storage_service.dart';
import 'pdf_report_shared.dart';

/// "Modern Dashboard" — a patient card and big stat tiles (HR, QRS, QT/QTc,
/// PR) up top, a light-grey, border-free 12-lead grid, and a dedicated
/// "Interpretation" box for the reviewing cardiologist's own notes.
class ModernDashboardReportBuilder {
  ModernDashboardReportBuilder._();

  static final _tileBg = PdfColor.fromHex('#F7F7F7');
  static final _tintBg = PdfColor.fromHex('#FBEAE7');
  static final _tintInk = PdfColor.fromHex('#9E2A1B');
  static final _cellBg = PdfColor.fromHex('#F7F8FA');
  static final _muted2 = PdfColor.fromHex('#9A928E');

  static const _pageWidth = 785.89;
  static const _pageHeight = 539.28;

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
    final simultaneous = reportType.startsWith('Simultaneous');
    final (columns, rowsPerColumn) = PdfReportShared.gridShape(reportType);
    final params = PdfReportShared.analysisItems(record);

    return pw.SizedBox(
      width: _pageWidth,
      height: _pageHeight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildTopRow(record, params),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('12-Lead ECG', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfReportShared.inkColor)),
              pw.Row(children: [
                pw.Text('X = ${storage.xAxisScale}mm/s  Y = 10mm/mV  ${record.filter}  ', style: pw.TextStyle(fontSize: 7.5, color: PdfReportShared.mutedColor)),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: pw.BoxDecoration(color: PdfReportShared.brandColor, borderRadius: pw.BorderRadius.circular(10)),
                  child: pw.Text(reportType.toUpperCase(), style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                ),
              ]),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Expanded(child: _buildGrid(record, columns: columns, rowsPerColumn: rowsPerColumn, simultaneous: simultaneous)),
          if (reportType.contains('4x3')) ...[
            pw.SizedBox(height: 5),
            _buildRhythmStrip(record, storage.longLead),
          ],
          pw.SizedBox(height: 6),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(child: _buildInterpretationBox()),
              pw.SizedBox(width: 10),
              _buildSignatureBox(signatureImage),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Software calculated values. To be finally confirmed and verified by the doctor.',
            style: pw.TextStyle(fontSize: 6.5, color: _muted2),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static String _paramValue(List<MapEntry<String, String>> params, String key) {
    final matches = params.where((e) => e.key == key);
    return matches.isEmpty ? '-' : matches.first.value;
  }

  static pw.Widget _buildTopRow(EcgRecordModel record, List<MapEntry<String, String>> params) {
    final hr = _paramValue(params, 'HR').replaceAll('/min', '');
    final qt = _paramValue(params, 'QT');
    final qtc = _paramValue(params, 'QTc');

    final tileData = <MapEntry<String, String>>[
      MapEntry('QRS DURATION', _paramValue(params, 'QRS')),
      MapEntry('QT / QTc', '$qt/$qtc'),
      MapEntry('PR INTERVAL', _paramValue(params, 'PR')),
    ];

    return pw.Row(
      children: [
        pw.Expanded(
          flex: 11,
          child: pw.Container(
            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F6F4F1'), borderRadius: pw.BorderRadius.circular(10)),
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 32,
                  height: 32,
                  decoration: pw.BoxDecoration(color: PdfReportShared.brandColor, shape: pw.BoxShape.circle),
                  child: pw.Center(child: pw.Text(_initials(record.patient.name), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                ),
                pw.SizedBox(width: 9),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(record.patient.name.isEmpty ? '-' : record.patient.name, style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: PdfReportShared.inkColor)),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        '${record.patient.age.isEmpty ? '-' : record.patient.age} / ${record.patient.sex.isEmpty ? '-' : record.patient.sex}  ·  ID ${record.patient.patientId.isEmpty ? '-' : record.patient.patientId}  ·  ${record.deviceName.isEmpty ? '-' : record.deviceName}',
                        style: pw.TextStyle(fontSize: 7.5, color: PdfReportShared.mutedColor),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Acquired', style: pw.TextStyle(fontSize: 6.5, color: PdfReportShared.mutedColor)),
                    pw.Text(PdfReportShared.formatDate(record.dateTime), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfReportShared.inkColor)),
                  ],
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          flex: 14,
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  decoration: pw.BoxDecoration(color: _tintBg, borderRadius: pw.BorderRadius.circular(9)),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(hr, style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: _tintInk)),
                      pw.Text('HEART RATE (bpm)', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfReportShared.brandColor)),
                    ],
                  ),
                ),
              ),
              for (final t in tileData) ...[
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Container(
                    decoration: pw.BoxDecoration(color: _tileBg, borderRadius: pw.BorderRadius.circular(9)),
                    padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(t.value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfReportShared.inkColor)),
                        pw.Text(t.key, style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfReportShared.mutedColor)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
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
            margin: const pw.EdgeInsets.all(2.5),
            decoration: pw.BoxDecoration(color: _cellBg, borderRadius: pw.BorderRadius.circular(5)),
            child: pw.Stack(children: [
              pw.Positioned(top: 3, left: 5, child: pw.Text(leadName, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfReportShared.inkColor))),
              pw.Center(child: PdfReportShared.tracePainter(samples, width: (_pageWidth - 8 * columns) / columns, height: 34, color: PdfColor.fromHex('#2B2A29'), strokeWidth: 0.7)),
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
      height: 42,
      decoration: pw.BoxDecoration(color: _cellBg, borderRadius: pw.BorderRadius.circular(5)),
      child: pw.Stack(children: [
        pw.Positioned(
          top: 3,
          left: 5,
          child: pw.Text('$longLead  ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfReportShared.inkColor)),
        ),
        pw.Positioned(top: 3, left: 20, child: pw.Text('Rhythm Strip', style: pw.TextStyle(fontSize: 7, color: PdfReportShared.mutedColor))),
        pw.Center(child: PdfReportShared.tracePainter(samples, width: _pageWidth - 10, height: 34, color: PdfColor.fromHex('#2B2A29'), strokeWidth: 0.7)),
      ]),
    );
  }

  static pw.Widget _buildInterpretationBox() {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColor.fromHex('#D8D4D0'), width: 0.7), borderRadius: pw.BorderRadius.circular(8)),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('INTERPRETATION', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: _muted2)),
          pw.SizedBox(height: 3),
          pw.Text('To be completed by the reviewing cardiologist.', style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic, color: PdfColor.fromHex('#B3B3B3'))),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatureBox(pw.MemoryImage? signatureImage) {
    return pw.Container(
      width: 160,
      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F6F4F1'), borderRadius: pw.BorderRadius.circular(8)),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.SizedBox(height: 18, child: signatureImage != null ? pw.Image(signatureImage, fit: pw.BoxFit.contain) : pw.Container()),
          pw.Container(width: 100, height: 0.8, color: PdfReportShared.borderColor, margin: const pw.EdgeInsets.only(top: 2, bottom: 2)),
          pw.Text('Dr. · Cardiologist', style: pw.TextStyle(fontSize: 6.5, color: PdfReportShared.mutedColor)),
        ],
      ),
    );
  }
}
