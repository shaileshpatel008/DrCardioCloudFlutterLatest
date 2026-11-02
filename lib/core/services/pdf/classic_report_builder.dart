import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../data/models/ecg_record_model.dart';
import '../ecg/ecg_data.dart';
import '../storage_service.dart';
import 'pdf_report_shared.dart';

/// "Classic" — the pink ECG-paper grid and blue section labels hospitals
/// already know from the original app's report (`PdfGenerator`'s
/// `draw4x3Graphs()`/`drawPatientInfo()`), kept visually familiar on
/// purpose, but with a refreshed header: a proper letterhead, aligned
/// patient-info fields, real comments text instead of an empty label, the
/// 8 ECG parameters in a readable 2-column grid, and a clear signature box
/// — the specific things the client asked to have "managed at our end"
/// even in the format meant to look like the familiar one.
class ClassicReportBuilder {
  ClassicReportBuilder._();

  static final _blue = PdfColor.fromHex('#2C3FB0');
  static final _blueFaint = PdfColor.fromHex('#B9C2E8');

  /// A4 landscape (841.89pt) minus 28pt margins each side.
  static const _contentWidth = 785.89;

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
            _buildLetterhead(storage, record),
            pw.SizedBox(height: 8),
            _buildInfoBox(record, signatureImage),
            pw.SizedBox(height: 8),
            ..._buildReportBody(record, storage, reportTypes[i]),
            pw.SizedBox(height: 8),
            _buildFooter(record, storage, reportTypes[i]),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildLetterhead(StorageService storage, EcgRecordModel record) {
    final doctorLine = [storage.doctorName, storage.doctorContactNo, storage.doctorAddress].where((s) => s.isNotEmpty).join('   |   ');
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(width: 30, height: 30, decoration: pw.BoxDecoration(color: _blue, shape: pw.BoxShape.circle)),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Dr. Cardio', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: _blue)),
                  pw.Text(
                    doctorLine.isEmpty ? (storage.clinicName.isEmpty ? 'ECG in your pocket' : storage.clinicName) : doctorLine,
                    style: pw.TextStyle(fontSize: 8, color: PdfReportShared.mutedColor),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('12-Lead ECG Report', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfReportShared.inkColor)),
                pw.Text('Acquired: ${PdfReportShared.formatDate(record.dateTime)}', style: pw.TextStyle(fontSize: 8, color: PdfReportShared.mutedColor)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 7),
        pw.Container(height: 2, color: _blue),
      ],
    );
  }

  static pw.Widget _buildInfoBox(EcgRecordModel record, pw.MemoryImage? signatureImage) {
    final medications = record.patient.medications.trim();
    final comments = record.patient.comments.trim();
    final params = PdfReportShared.analysisItems(record);

    pw.Widget cell(String title, pw.Widget content, {bool last = false}) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: pw.BoxDecoration(border: last ? null : pw.Border(right: pw.BorderSide(color: _blueFaint, width: 0.8))),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _blue)),
                pw.SizedBox(height: 3),
                content,
              ],
            ),
          ),
        );

    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _blue, width: 0.8), borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
            cell(
              'PATIENT INFO',
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Name : ${record.patient.name.isEmpty ? '-' : record.patient.name}', style: pw.TextStyle(fontSize: 7.8, color: PdfReportShared.inkColor)),
                  pw.Text(
                    'Age / Sex : ${record.patient.age.isEmpty ? '-' : record.patient.age} / ${record.patient.sex.isEmpty ? '-' : record.patient.sex}',
                    style: pw.TextStyle(fontSize: 7.8, color: PdfReportShared.inkColor),
                  ),
                  pw.Text('ID : ${record.patient.patientId.isEmpty ? '-' : record.patient.patientId}', style: pw.TextStyle(fontSize: 7.8, color: PdfReportShared.inkColor)),
                  pw.Text('Device : ${record.deviceName.isEmpty ? '-' : record.deviceName}', style: pw.TextStyle(fontSize: 7.8, color: PdfReportShared.inkColor)),
                ],
              ),
            ),
            cell(
              'COMMENTS',
              comments.isEmpty && medications.isEmpty
                  ? pw.Text('-', style: pw.TextStyle(fontSize: 7.8, color: PdfReportShared.mutedColor))
                  : pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (comments.isNotEmpty) pw.Text(comments, style: pw.TextStyle(fontSize: 7.8, color: PdfReportShared.inkColor)),
                        if (medications.isNotEmpty) ...[
                          if (comments.isNotEmpty) pw.SizedBox(height: 4),
                          pw.Text('Medications: $medications', style: pw.TextStyle(fontSize: 7.3, color: PdfReportShared.mutedColor)),
                        ],
                      ],
                    ),
            ),
            cell(
              'ECG PARAMETERS',
              params.isEmpty
                  ? pw.Text('-', style: pw.TextStyle(fontSize: 7.8, color: PdfReportShared.mutedColor))
                  : pw.Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: params
                          .map((e) => pw.SizedBox(
                                width: 72,
                                child: pw.Text('${e.key}: ${e.value}', style: pw.TextStyle(fontSize: 7.6, color: PdfReportShared.inkColor)),
                              ))
                          .toList(),
                    ),
            ),
            cell(
              'SIGNATURE',
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.SizedBox(
                    height: 20,
                    child: signatureImage != null
                        ? pw.Image(signatureImage, fit: pw.BoxFit.contain)
                        : pw.Container(),
                  ),
                  pw.Container(width: 72, height: 0.8, color: _blueFaint, margin: const pw.EdgeInsets.only(top: 2)),
                  pw.Text("Doctor's Signature", style: pw.TextStyle(fontSize: 6.5, color: PdfReportShared.mutedColor)),
                ],
              ),
              last: true,
            ),
          ],
        ),
      );
  }

  static List<pw.Widget> _buildReportBody(EcgRecordModel record, StorageService storage, String reportType) {
    final simultaneous = reportType.startsWith('Simultaneous');
    final (columns, rowsPerColumn) = PdfReportShared.gridShape(reportType);
    final cellHeight = rowsPerColumn > 6 ? 34.0 : (rowsPerColumn > 4 ? 42.0 : 56.0);
    final gridHeight = cellHeight * rowsPerColumn;

    return [
      pw.SizedBox(
        width: _contentWidth,
        height: gridHeight,
        child: pw.Stack(
          children: [
            pw.Positioned.fill(child: PdfReportShared.ecgPaperBackground(width: _contentWidth, height: gridHeight)),
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(color: _blue, width: 0.8)),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: List.generate(columns, (col) {
                  return pw.Expanded(
                    child: pw.Column(
                      children: List.generate(rowsPerColumn, (row) {
                        final index = PdfReportShared.leadIndexForCell(col, row, rowsPerColumn);
                        final leadName = PdfReportShared.leadNameAt(index);
                        final full = PdfReportShared.leadSamplesAt(record, index);
                        final samples = simultaneous ? full : PdfReportShared.sequentialSlice(full, columns, col);
                        return pw.Expanded(
                          child: pw.Container(
                            decoration: pw.BoxDecoration(
                              border: pw.Border(right: pw.BorderSide(color: _blueFaint, width: 0.5), bottom: pw.BorderSide(color: _blueFaint, width: 0.5)),
                            ),
                            child: pw.Stack(children: [
                              if (row == 0) pw.Positioned(top: 3, left: 2, child: _calibrationMark(cellHeight - 10)),
                              pw.Positioned(
                                top: 3,
                                left: row == 0 ? 17 : 4,
                                child: pw.Text(leadName, style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold, color: _blue)),
                              ),
                              pw.Center(child: PdfReportShared.tracePainter(samples, width: _contentWidth / columns, height: cellHeight - 4, color: PdfReportShared.inkColor, strokeWidth: 0.7)),
                            ]),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
      if (reportType.contains('4x3')) ...[
        pw.SizedBox(height: 4),
        _buildRhythmStrip(record, storage.longLead),
      ],
    ];
  }

  static pw.Widget _calibrationMark(double height) {
    return pw.CustomPaint(
      size: PdfPoint(12, height),
      painter: (context, size) {
        context.setStrokeColor(PdfReportShared.inkColor);
        context.setLineWidth(0.8);
        context.moveTo(1, size.y);
        context.lineTo(1, 2);
        context.lineTo(10, 2);
        context.lineTo(10, size.y);
        context.strokePath();
      },
    );
  }

  static pw.Widget _buildRhythmStrip(EcgRecordModel record, String longLead) {
    final index = _longLeadIndex(longLead);
    final samples = PdfReportShared.leadSamplesAt(record, index);
    const height = 58.0;
    return pw.SizedBox(
      width: _contentWidth,
      height: height,
      child: pw.Stack(
        children: [
          pw.Positioned.fill(child: PdfReportShared.ecgPaperBackground(width: _contentWidth, height: height)),
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(color: _blue, width: 0.8)),
            child: pw.Stack(children: [
              pw.Positioned(top: 4, left: 4, child: _calibrationMark(height - 14)),
              pw.Positioned(top: 4, left: 19, child: pw.Text(longLead, style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold, color: _blue))),
              pw.Center(child: PdfReportShared.tracePainter(samples, width: _contentWidth, height: height - 4, color: PdfReportShared.inkColor, strokeWidth: 0.7)),
            ]),
          ),
        ],
      ),
    );
  }

  static int _longLeadIndex(String longLead) {
    final index = EcgData.leadName.indexOf(longLead);
    return index == -1 ? 1 : index;
  }

  static pw.Widget _buildFooter(EcgRecordModel record, StorageService storage, String reportType) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Text(
            'X = ${storage.xAxisScale}mm/s  Y = 10mm/mV  ${record.filter} Filter',
            style: pw.TextStyle(fontSize: 7.5, color: PdfReportShared.inkColor),
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            children: [
              pw.Text('To be Finally Confirmed by the doctor', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7.5, color: PdfReportShared.inkColor)),
              pw.Text('Software calculated values. To be verified manually', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 6.5, color: PdfReportShared.mutedColor)),
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Text(reportType, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, color: PdfReportShared.inkColor)),
        ),
      ],
    );
  }
}
