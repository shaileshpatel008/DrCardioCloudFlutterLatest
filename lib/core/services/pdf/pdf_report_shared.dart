import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../data/models/ecg_record_model.dart';
import '../ecg/ecg_data.dart';

/// Pieces every [ReportFormat] builder shares: brand colors, the lead-trace
/// painter, the column-major lead/cell index math, and small data-shaping
/// helpers (ECG params list, sequential-report slicing, image loading).
/// Kept separate from any one format so none of them have to duplicate —
/// or risk drifting from — the lead-indexing logic that
/// `test/widget_test.dart`'s "is lead N plotted as lead N" tests pin down.
class PdfReportShared {
  PdfReportShared._();

  static final brandColor = PdfColor.fromHex('#C53827');
  static final inkColor = PdfColor.fromHex('#201F1E');
  static final mutedColor = PdfColor.fromHex('#6B6B6B');
  static final borderColor = PdfColor.fromHex('#E5E5E5');

  /// Grid shape for a report type name ("NxM"): 6x2 -> 2 columns of 6,
  /// 12x1 -> 1 column of 12, else (4x3) -> 4 columns of 3. See
  /// `PdfReportService._buildLeadGrid`'s original note on why this is
  /// column-major (one clinical lead group per column) and why 4x3 is the
  /// only shape that also gets a rhythm strip.
  static (int columns, int rowsPerColumn) gridShape(String reportType) {
    if (reportType.contains('6x2')) return (2, 6);
    if (reportType == '12x1') return (1, 12);
    return (4, 3);
  }

  /// The lead index for grid cell (col, row) — column-major, matching the
  /// old app's `draw4x3Graphs()` (`col = floor(ch/rows), row = ch % rows`
  /// inverted). Every builder MUST go through this (not its own ad-hoc
  /// formula) so a lead's label and its data always come from the same
  /// index — see the regression tests in test/widget_test.dart.
  static int leadIndexForCell(int col, int row, int rowsPerColumn) => col * rowsPerColumn + row;

  static String leadNameAt(int index) => index < EcgData.leadName.length ? EcgData.leadName[index] : '';

  static List<double> leadSamplesAt(EcgRecordModel record, int index) =>
      index < record.leadData.length ? record.leadData[index] : const <double>[];

  /// Splits [samples] into [columns] equal contiguous chunks and returns
  /// the one for [columnIndex] — a "Sequential" report's per-column
  /// window, approximated as dividing the recording into as many time
  /// segments as there are columns.
  static List<double> sequentialSlice(List<double> samples, int columns, int columnIndex) {
    if (samples.isEmpty || columns <= 1) return samples;
    final chunk = samples.length ~/ columns;
    if (chunk == 0) return samples;
    final start = columnIndex * chunk;
    final end = columnIndex == columns - 1 ? samples.length : start + chunk;
    return samples.sublist(start, end);
  }

  /// The 8 HR/R(II)/RR/PR/QRS/QT/QTc/QT-QTc figures `EcgAnalysisService`
  /// computes at save time, as label/value pairs — empty when
  /// [EcgRecordModel.hr] is empty (a recording under ~13s, or one saved
  /// before this measurement existed).
  static List<MapEntry<String, String>> analysisItems(EcgRecordModel record) {
    if (record.hr.isEmpty) return const [];
    return [
      MapEntry('HR', '${record.hr}/min'),
      MapEntry('R(II)', '${record.r}mV'),
      MapEntry('RR', '${record.rr}ms'),
      MapEntry('PR', '${record.pr}ms'),
      MapEntry('QRS', '${record.qrs}ms'),
      MapEntry('QT', '${record.qt}ms'),
      MapEntry('QTc', '${record.qtc}ms'),
      MapEntry('QT/QTc', record.qtByQtc),
    ];
  }

  /// Empty path, missing file, or an unreadable one all resolve to null —
  /// the caller treats null as "nothing to draw", not a placeholder.
  static Future<pw.MemoryImage?> loadImage(String path) async {
    if (path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  static String formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Draws one lead's trace into a [width]x[height] box, scaled against the
  /// device's real calibration constant (`EcgData.valPerMv`) the same way
  /// the live monitor view does — see `EcgLeadChart`'s own painter for the
  /// full rationale (this was previously a made-up constant unrelated to
  /// calibration, which over/under-scaled the trace).
  static pw.Widget tracePainter(
    List<double> samples, {
    required double width,
    required double height,
    PdfColor? color,
    double strokeWidth = 0.6,
  }) {
    final traceColor = color ?? inkColor;
    return pw.CustomPaint(
      size: PdfPoint(width, height),
      painter: (context, size) {
        if (samples.isEmpty) return;
        final midY = size.y / 2;
        final window = samples.length > 300 ? samples.sublist(samples.length - 300) : samples;
        final xScale = size.x / window.length;
        final scaleY = (size.y / 2) / (1.5 * EcgData.instance.valPerMv);
        double y(double v) => (midY - v * scaleY).clamp(0.0, size.y);
        context.setStrokeColor(traceColor);
        context.setLineWidth(strokeWidth);
        context.moveTo(0, y(window[0]));
        for (var i = 1; i < window.length; i++) {
          context.lineTo(i * xScale, y(window[i]));
        }
        context.strokePath();
      },
    );
  }

  /// Classic ECG graph paper: fine lines every 1mm-equivalent box, a
  /// heavier line every 5 boxes — the pink/blue pattern the old app's
  /// reports (and real ECG paper) use, drawn once behind a whole grid
  /// area rather than per cell so the lines stay continuous across cells.
  static pw.Widget ecgPaperBackground({required double width, required double height, double boxSize = 6}) {
    final fine = PdfColor.fromHex('#E79DBB');
    final heavy = PdfColor.fromHex('#5867D8');
    return pw.CustomPaint(
      size: PdfPoint(width, height),
      painter: (context, size) {
        context.setFillColor(PdfColor.fromHex('#FDEFF4'));
        context.drawRect(0, 0, size.x, size.y);
        context.fillPath();
        var i = 0;
        for (double x = 0; x <= size.x; x += boxSize, i++) {
          context.setStrokeColor(i % 5 == 0 ? heavy : fine);
          context.setLineWidth(i % 5 == 0 ? 0.6 : 0.25);
          context.moveTo(x, 0);
          context.lineTo(x, size.y);
          context.strokePath();
        }
        i = 0;
        for (double y = 0; y <= size.y; y += boxSize, i++) {
          context.setStrokeColor(i % 5 == 0 ? heavy : fine);
          context.setLineWidth(i % 5 == 0 ? 0.6 : 0.25);
          context.moveTo(0, y);
          context.lineTo(size.x, y);
          context.strokePath();
        }
      },
    );
  }
}
