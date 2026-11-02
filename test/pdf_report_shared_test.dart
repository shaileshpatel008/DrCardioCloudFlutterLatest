import 'package:drcardio_flutter/core/services/pdf/pdf_report_shared.dart';
import 'package:drcardio_flutter/data/models/ecg_record_model.dart';
import 'package:drcardio_flutter/data/models/patient_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PdfReportShared (shared by all 4 report formats)', () {
    test('gridShape matches the report-type name', () {
      expect(PdfReportShared.gridShape('Simultaneous 4x3'), (4, 3));
      expect(PdfReportShared.gridShape('Sequential 4x3'), (4, 3));
      expect(PdfReportShared.gridShape('Simultaneous 6x2'), (2, 6));
      expect(PdfReportShared.gridShape('Sequential 6x2'), (2, 6));
      expect(PdfReportShared.gridShape('12x1'), (1, 12));
    });

    test('leadIndexForCell is column-major: column 0 gets indices 0..rows-1', () {
      const rowsPerColumn = 3;
      expect(PdfReportShared.leadIndexForCell(0, 0, rowsPerColumn), 0);
      expect(PdfReportShared.leadIndexForCell(0, 1, rowsPerColumn), 1);
      expect(PdfReportShared.leadIndexForCell(0, 2, rowsPerColumn), 2);
      expect(PdfReportShared.leadIndexForCell(1, 0, rowsPerColumn), 3);
      expect(PdfReportShared.leadIndexForCell(3, 2, rowsPerColumn), 11);
    });

    test('every format\'s 4x3 grid groups the same way: I/II/III, aVR/aVL/aVF, V1/V2/V3, V4/V5/V6', () {
      const rowsPerColumn = 3;
      List<String> column(int col) => List.generate(rowsPerColumn, (row) => PdfReportShared.leadNameAt(PdfReportShared.leadIndexForCell(col, row, rowsPerColumn)));
      expect(column(0), ['I', 'II', 'III']);
      expect(column(1), ['aVR', 'aVL', 'aVF']);
      expect(column(2), ['V1', 'V2', 'V3']);
      expect(column(3), ['V4', 'V5', 'V6']);
    });

    test('leadSamplesAt returns the exact list at that index, empty past the end', () {
      final data = [
        [1.0, 2.0],
        [3.0, 4.0],
      ];
      final record = _record(data);
      expect(PdfReportShared.leadSamplesAt(record, 0), [1.0, 2.0]);
      expect(PdfReportShared.leadSamplesAt(record, 1), [3.0, 4.0]);
      expect(PdfReportShared.leadSamplesAt(record, 5), isEmpty);
    });

    test('sequentialSlice splits into equal contiguous chunks per column', () {
      final samples = List<double>.generate(12, (i) => i.toDouble());
      expect(PdfReportShared.sequentialSlice(samples, 4, 0), [0, 1, 2]);
      expect(PdfReportShared.sequentialSlice(samples, 4, 1), [3, 4, 5]);
      expect(PdfReportShared.sequentialSlice(samples, 4, 3), [9, 10, 11]);
      // A single column (or empty samples) returns the whole list untouched.
      expect(PdfReportShared.sequentialSlice(samples, 1, 0), samples);
    });
  });
}

EcgRecordModel _record(List<List<double>> leadData) => EcgRecordModel(
      id: 'test',
      dateTime: DateTime(2026),
      patient: PatientModel(patientId: '', name: '', age: '', sex: ''),
      deviceName: '',
      filter: '0 to 40 Hz',
      gain: '1',
      leadData: leadData,
    );
