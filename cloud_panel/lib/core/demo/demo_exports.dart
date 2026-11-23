import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../utils/html_text.dart';
import 'demo_ecg_wave.dart';

/// Builds the files the demo's "Download ECG" and "Export ECG counts" return:
/// a real zip of one-page ECG PDFs (or CSV sample files), and a counts CSV.
class DemoExports {
  DemoExports._();

  static String _base(Map<String, dynamic> r) => '${r['file_name']}'.replaceAll(RegExp(r'\.pdf$'), '');

  static Uint8List pdfZip(List<Map<String, dynamic>> records) => _zip({for (final r in records) '${_base(r)}.pdf': _ecgPdf(r)});

  static Uint8List csvZip(List<Map<String, dynamic>> records) =>
      _zip({for (final r in records.take(25)) 'csv_files/${_base(r)}.csv': Uint8List.fromList(utf8.encode(_samplesCsv(r)))});

  static String countsCsv(List<Map<String, dynamic>> reported) {
    final by = <String, List<int>>{};
    for (final r in reported) {
      final row = by.putIfAbsent('${r['hospital_name']}', () => [0, 0, 0]);
      row[0]++;
      if (r['ecg_status'] == 'normal') row[1]++;
      if (r['ecg_status'] == 'abnormal') row[2]++;
    }
    final b = StringBuffer('Hospital,Reported ECGs,Normal,Abnormal\n');
    final total = [0, 0, 0];
    for (final e in by.entries) {
      b.writeln('"${e.key}",${e.value.join(',')}');
      for (var i = 0; i < 3; i++) {
        total[i] += e.value[i];
      }
    }
    b.writeln('Total,${total.join(',')}');
    return b.toString();
  }

  // ------------------------------------------------------------------ CSV

  static String _samplesCsv(Map<String, dynamic> r) {
    final wave = EcgWave.forRecord(r);
    final b = StringBuffer('time_s,${EcgWave.leads.join(',')}\n');
    for (var i = 0; i < 500; i++) {
      final t = i / 200;
      b.writeln('${t.toStringAsFixed(3)},${EcgWave.leads.map((l) => wave.value(l, t).toStringAsFixed(3)).join(',')}');
    }
    return b.toString();
  }

  // ------------------------------------------------------------------ PDF

  static String _esc(String s) => s.replaceAll('\\', '\\\\').replaceAll('(', '\\(').replaceAll(')', '\\)').replaceAll(RegExp(r'[^\x20-\x7E]'), '-');

  /// One A4 landscape page: header, 12-lead grid and the report summary.
  static Uint8List _ecgPdf(Map<String, dynamic> r) {
    const mm = 72 / 25.4;
    final wave = EcgWave.forRecord(r);
    final c = StringBuffer();
    final patient = (r['patient'] as Map?) ?? const {};
    final created = DateTime.tryParse('${r['created_at']}')?.toLocal();

    void text(double x, double y, double size, String s, {bool bold = false}) =>
        c.writeln('BT /${bold ? 'F2' : 'F1'} $size Tf ${x.toStringAsFixed(1)} ${y.toStringAsFixed(1)} Td (${_esc(s)}) Tj ET');

    // Header
    c.writeln('0.773 0.220 0.153 rg');
    text(28, 560, 16, 'Dr. Cardio  |  12-lead ECG', bold: true);
    c.writeln('0.1 0.1 0.12 rg');
    text(28, 542, 10, 'Patient: ${patient['name'] ?? '-'}   Age: ${patient['age'] ?? '-'}   Gender: ${patient['gender'] ?? '-'}   ID: ${patient['id'] ?? '-'}');
    text(
      28,
      528,
      10,
      '${r['hospital_name'] ?? ''}   Device: ${r['instrument_id'] ?? ''}   Recorded: ${created == null ? '-' : DateFormat('d MMM yyyy, hh:mm a').format(created)}   HR: ${wave.hr.round()} bpm',
    );
    text(600, 560, 8, 'SAMPLE DATA - DEMO BUILD');

    // Paper grid (5 mm squares) inside the trace area.
    const left = 28.0, bottom = 70.0, width = 250 * mm, height = 150 * mm;
    c.writeln('0.98 0.82 0.80 RG 0.4 w');
    for (var x = 0.0; x <= width + 0.1; x += 5 * mm) {
      c.writeln('${(left + x).toStringAsFixed(2)} $bottom m ${(left + x).toStringAsFixed(2)} ${(bottom + height).toStringAsFixed(2)} l S');
    }
    for (var y = 0.0; y <= height + 0.1; y += 5 * mm) {
      c.writeln('$left ${(bottom + y).toStringAsFixed(2)} m ${(left + width).toStringAsFixed(2)} ${(bottom + y).toStringAsFixed(2)} l S');
    }

    // Traces: 25 mm/s, 10 mm/mV; 3 rows of 4 leads (2.5 s each) + rhythm strip.
    c.writeln('0.08 0.09 0.12 RG 0.7 w');
    void trace(String lead, double x0, double yBase, double seconds, double tStart) {
      final n = (seconds * 200).round();
      for (var i = 0; i <= n; i++) {
        final t = tStart + i / 200;
        final x = x0 + (i / 200) * 25 * mm;
        final y = yBase + wave.value(lead, t) * 10 * mm;
        c.write('${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} ${i == 0 ? 'm' : 'l'} ');
      }
      c.writeln('S');
    }

    for (var row = 0; row < 3; row++) {
      final yBase = bottom + height - (row + 1) * 32 * mm;
      for (var col = 0; col < 4; col++) {
        final lead = EcgWave.layout[row][col];
        final x0 = left + col * 62.5 * mm;
        trace(lead, x0, yBase, 2.5, col * 2.5);
        c.writeln('0.08 0.09 0.12 rg');
        text(x0 + 3, yBase + 12 * mm, 8, lead, bold: true);
      }
    }
    trace('II', left, bottom + 14 * mm, 10, 0);
    text(left + 3, bottom + 26 * mm, 8, 'II', bold: true);

    // Report summary
    c.writeln('0.1 0.1 0.12 rg');
    text(28, 52, 8, '25 mm/s   10 mm/mV   0.05-150 Hz');
    if (r['status'] == 'reported') {
      final m = (r['measurements'] as Map?) ?? const {};
      text(
        28,
        38,
        9,
        '${'${r['ecg_status'] ?? ''}'.toUpperCase()}  |  HR ${m['hr'] ?? '-'}  PR ${m['pr'] ?? '-'}  QRS ${m['qrs'] ?? '-'}  QT ${m['qt'] ?? '-'}  QTc ${m['qtc'] ?? '-'}  |  ${r['cardiologist_name'] ?? ''}',
        bold: true,
      );
      text(28, 24, 9, HtmlText.toPlain('${r['cardiologist_report'] ?? ''}').replaceAll('\n', '  '));
    } else {
      text(28, 30, 9, 'Status: ${r['status_label'] ?? r['status']}  -  awaiting cardiologist report');
    }

    final content = utf8.encode(c.toString());
    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 842 595] /Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >>',
      '__STREAM__',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>',
    ];
    final out = BytesBuilder();
    out.add(latin1.encode('%PDF-1.4\n'));
    final offsets = <int>[];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(out.length);
      out.add(latin1.encode('${i + 1} 0 obj\n'));
      if (objects[i] == '__STREAM__') {
        out.add(latin1.encode('<< /Length ${content.length} >>\nstream\n'));
        out.add(content);
        out.add(latin1.encode('\nendstream\n'));
      } else {
        out.add(latin1.encode('${objects[i]}\n'));
      }
      out.add(latin1.encode('endobj\n'));
    }
    final xref = out.length;
    final x = StringBuffer('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
    for (final o in offsets) {
      x.write('${o.toString().padLeft(10, '0')} 00000 n \n');
    }
    x.write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
    out.add(latin1.encode(x.toString()));
    return out.toBytes();
  }

  // ------------------------------------------------------------------ ZIP (stored)

  static final List<int> _crcTable = List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });

  static int _crc32(List<int> data) {
    var c = 0xFFFFFFFF;
    for (final b in data) {
      c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
    }
    return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  static Uint8List _zip(Map<String, Uint8List> files) {
    final out = BytesBuilder();
    final central = BytesBuilder();
    final now = DateTime.now();
    final dosTime = (now.hour << 11) | (now.minute << 5) | (now.second ~/ 2);
    final dosDate = ((now.year - 1980) << 9) | (now.month << 5) | now.day;

    Uint8List header(int sig, List<(int, int)> fields) {
      final size = 4 + fields.fold<int>(0, (s, f) => s + f.$2);
      final b = ByteData(size)..setUint32(0, sig, Endian.little);
      var o = 4;
      for (final (v, w) in fields) {
        if (w == 2) {
          b.setUint16(o, v, Endian.little);
        } else {
          b.setUint32(o, v, Endian.little);
        }
        o += w;
      }
      return b.buffer.asUint8List();
    }

    files.forEach((name, data) {
      final nameBytes = utf8.encode(name);
      final crc = _crc32(data);
      final offset = out.length;
      out.add(
        header(0x04034b50, [(20, 2), (0, 2), (0, 2), (dosTime, 2), (dosDate, 2), (crc, 4), (data.length, 4), (data.length, 4), (nameBytes.length, 2), (0, 2)]),
      );
      out.add(nameBytes);
      out.add(data);
      central.add(
        header(0x02014b50, [
          (20, 2),
          (20, 2),
          (0, 2),
          (0, 2),
          (dosTime, 2),
          (dosDate, 2),
          (crc, 4),
          (data.length, 4),
          (data.length, 4),
          (nameBytes.length, 2),
          (0, 2),
          (0, 2),
          (0, 2),
          (0, 2),
          (0, 4),
          (offset, 4),
        ]),
      );
      central.add(nameBytes);
    });
    final cdOffset = out.length;
    final cd = central.toBytes();
    out.add(cd);
    out.add(header(0x06054b50, [(0, 2), (0, 2), (files.length, 2), (files.length, 2), (cd.length, 4), (cdOffset, 4), (0, 2)]));
    return out.toBytes();
  }
}
