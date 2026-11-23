import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../utils/formatters.dart';
import '../utils/html_text.dart';
import '../widgets/app_toast.dart';
import 'demo_ecg_wave.dart';
import 'demo_store.dart';

/// Demo-build stand-ins for the ECG and report PDFs (links "demo://ecg/12",
/// "demo://report/12"): drawn on the device from the record's data.
class DemoDocuments {
  DemoDocuments._();

  static bool handles(String? url) => url != null && url.startsWith('demo://');

  static (String, Map<String, dynamic>?) _parse(String url) {
    final parts = url.substring('demo://'.length).split('/');
    final id = parts.length > 1 ? int.tryParse(parts[1]) : null;
    return (parts.first, id == null ? null : DemoStore.instance.records[id]);
  }

  /// Opens the document full screen (pinch to zoom on the ECG).
  static void open(String url) {
    final (kind, record) = _parse(url);
    if (kind == 'csv') {
      AppToast.info('In the demo, CSV files come from Download ECG → Export CSV.');
      return;
    }
    if (record == null) {
      AppToast.error('This file is not available.');
      return;
    }
    Get.to<void>(
      () => _DocumentPage(kind: kind, record: record),
      transition: Transition.downToUp,
    );
  }

  /// Inline preview used where the app embeds a PDF.
  static Widget inline(String url, {double height = 560}) {
    final (kind, record) = _parse(url);
    if (record == null) return const SizedBox.shrink();
    // The ECG sheet keeps its print proportions; the report scrolls inside [height].
    return LayoutBuilder(
      builder: (context, box) {
        final h = kind == 'report' || !box.maxWidth.isFinite ? height : (box.maxWidth * 672 / 1040).clamp(160.0, height);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: h,
            child: Stack(
              children: [
                Positioned.fill(
                  child: kind == 'report'
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.all(2),
                          child: DemoReportPage(record: record),
                        )
                      : Container(
                          color: Colors.white,
                          alignment: Alignment.center,
                          child: FittedBox(
                            child: SizedBox(width: 1040, height: 672, child: DemoEcgSheet(record: record)),
                          ),
                        ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Material(
                    color: AppColors.ink.withValues(alpha: .78),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => open(url),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_full_rounded, size: 15, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Full screen',
                              style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DocumentPage extends StatefulWidget {
  const _DocumentPage({required this.kind, required this.record});
  final String kind;
  final Map<String, dynamic> record;

  @override
  State<_DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends State<_DocumentPage> {
  // On phones the 12-lead sheet is shown in landscape, like a print-out.
  bool get _rotate => !kIsWeb && widget.kind == 'ecg' && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (_rotate) SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }

  @override
  void dispose() {
    if (_rotate) SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final record = widget.record;
    final patient = '${(record['patient'] as Map?)?['name'] ?? record['file_name']}';
    return Scaffold(
      backgroundColor: const Color(0xFF2A2D34),
      appBar: AppBar(
        backgroundColor: AppColors.sidebar,
        foregroundColor: Colors.white,
        title: Text(
          kind == 'report' ? 'Report · $patient' : 'ECG · $patient',
          style: AppTextStyles.body(size: 16, weight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: kind == 'report'
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    children: [
                      DemoReportPage(record: record),
                      const SizedBox(height: 14),
                      Container(
                        color: Colors.white,
                        child: AspectRatio(
                          aspectRatio: 1040 / 672,
                          child: DemoEcgSheet(record: record),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : InteractiveViewer(
              maxScale: 6,
              child: Center(
                child: FittedBox(
                  child: Container(
                    color: Colors.white,
                    width: 1040,
                    height: 672,
                    child: DemoEcgSheet(record: record),
                  ),
                ),
              ),
            ),
    );
  }
}

/// A 12-lead ECG print-out: 3×4 leads plus a lead II rhythm strip on
/// 1 mm / 5 mm grid paper, 25 mm/s and 10 mm/mV.
class DemoEcgSheet extends StatelessWidget {
  const DemoEcgSheet({super.key, required this.record});
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _EcgPainter(record), size: Size.infinite),
  );
}

class _EcgPainter extends CustomPainter {
  _EcgPainter(this.record) : wave = EcgWave.forRecord(record);
  final Map<String, dynamic> record;
  final EcgWave wave;

  static const _sheetW = 260.0; // mm
  static const _gridTop = 20.0;
  static const _gridH = 132.0;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / _sheetW; // px per mm
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    // Header
    final patient = (record['patient'] as Map?) ?? const {};
    final created = DateTime.tryParse('${record['created_at']}')?.toLocal();
    _text(canvas, 'Dr. Cardio  ·  12-lead ECG', Offset(5 * k, 3 * k), 4.2 * k, AppColors.brand, FontWeight.w800);
    _text(
      canvas,
      '${patient['name'] ?? '—'}   ·   ${patient['age'] ?? '—'} y / ${patient['gender'] ?? '—'}   ·   ID ${patient['id'] ?? '—'}   ·   HR ${wave.hr.round()} bpm',
      Offset(5 * k, 9.5 * k),
      3.1 * k,
      AppColors.ink,
      FontWeight.w600,
    );
    _text(
      canvas,
      '${record['hospital_name'] ?? ''}   ·   ${record['instrument_id'] ?? ''}   ·   ${created == null ? '' : Fmt.dateTime(created)}',
      Offset(5 * k, 14.2 * k),
      2.8 * k,
      AppColors.muted,
      FontWeight.w400,
    );
    _text(canvas, 'SAMPLE · DEMO', Offset(225 * k, 4 * k), 2.6 * k, AppColors.faint, FontWeight.w700);

    // Grid paper
    final gridRect = Rect.fromLTWH(5 * k, _gridTop * k, 250 * k, _gridH * k);
    canvas.drawRect(gridRect, Paint()..color = const Color(0xFFFFF7F6));
    final minor = Paint()
      ..color = const Color(0xFFF9D9D4)
      ..strokeWidth = .5;
    final major = Paint()
      ..color = const Color(0xFFF0A79C)
      ..strokeWidth = 1;
    for (var mm = 0; mm <= 250; mm++) {
      final x = gridRect.left + mm * k;
      canvas.drawLine(Offset(x, gridRect.top), Offset(x, gridRect.bottom), mm % 5 == 0 ? major : minor);
    }
    for (var mm = 0; mm <= _gridH; mm++) {
      final y = gridRect.top + mm * k;
      canvas.drawLine(Offset(gridRect.left, y), Offset(gridRect.right, y), mm % 5 == 0 ? major : minor);
    }

    // Traces
    final pen = Paint()
      ..color = const Color(0xFF14161C)
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    void trace(String lead, double x0mm, double baseMm, double seconds, double tStart) {
      final path = Path();
      final n = (seconds * 200).round();
      for (var i = 0; i <= n; i++) {
        final t = tStart + i / 200;
        final x = (x0mm + (i / 200) * 25) * k;
        final y = (baseMm - wave.value(lead, t) * 10) * k;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, pen);
    }

    for (var row = 0; row < 3; row++) {
      final base = _gridTop + 20 + row * 30.0;
      for (var col = 0; col < 4; col++) {
        final lead = EcgWave.layout[row][col];
        final x0 = 5 + col * 62.5;
        trace(lead, x0, base, 2.5, col * 2.5);
        _text(canvas, lead, Offset((x0 + 1.5) * k, (base - 13) * k), 3 * k, AppColors.ink, FontWeight.w700);
        if (col > 0) {
          canvas.drawLine(Offset(x0 * k, (base - 4) * k), Offset(x0 * k, (base + 4) * k), pen);
        }
      }
    }
    final rhythmBase = _gridTop + 20 + 3 * 30.0 + 6;
    trace('II', 5, rhythmBase, 10, 0);
    _text(canvas, 'II', Offset(6.5 * k, (rhythmBase - 13) * k), 3 * k, AppColors.ink, FontWeight.w700);

    _text(canvas, '25 mm/s   ·   10 mm/mV   ·   0.05–150 Hz', Offset(5 * k, (_gridTop + _gridH + 3) * k), 2.6 * k, AppColors.subtle, FontWeight.w500);
  }

  void _text(Canvas canvas, String s, Offset at, double size, Color color, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: color, fontWeight: weight, fontFamily: 'Inter'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _EcgPainter old) => old.record != record;
}

/// The cardiologist's report as the hospital receives it.
class DemoReportPage extends StatelessWidget {
  const DemoReportPage({super.key, required this.record});
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final patient = (r['patient'] as Map?) ?? const {};
    final m = (r['measurements'] as Map?) ?? const {};
    final abnormal = r['ecg_status'] == 'abnormal';
    final created = DateTime.tryParse('${r['created_at']}')?.toLocal();
    final reported = DateTime.tryParse('${r['reported_at']}')?.toLocal();
    final advice = HtmlText.toPlain('${r['cardiologist_report'] ?? ''}');
    final cardioProfile = (DemoStore.instance.roles['cardio']?['user'] as Map?);
    final footer = cardioProfile != null && cardioProfile['id'] == r['cardiologist_id']
        ? '${(cardioProfile['cardiologist'] as Map?)?['footer'] ?? 'Consultant Cardiologist'}'
        : 'Consultant Cardiologist';

    Widget field(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.body(size: 10.5, weight: FontWeight.w700, color: AppColors.faint).copyWith(letterSpacing: .8),
        ),
        const SizedBox(height: 3),
        Text(value, style: AppTextStyles.body(size: 14, weight: FontWeight.w600)),
      ],
    );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r['hospital_name'] ?? ''}', style: AppTextStyles.display(20)),
                    const SizedBox(height: 2),
                    Text('${r['doctor_name'] ?? ''}  ·  ${r['address'] ?? ''}', style: AppTextStyles.caption),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'ECG REPORT',
                    style: AppTextStyles.body(size: 12, weight: FontWeight.w800, color: AppColors.brand).copyWith(letterSpacing: 1.6),
                  ),
                  const SizedBox(height: 2),
                  Text(Fmt.dateTime(reported ?? created), style: AppTextStyles.caption),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 2, color: AppColors.brand),
          const SizedBox(height: 16),
          Wrap(
            spacing: 28,
            runSpacing: 14,
            children: [
              field('Patient', '${patient['name'] ?? '—'}'),
              field('Age / Gender', '${patient['age'] ?? '—'} / ${patient['gender'] ?? '—'}'),
              field('Patient ID', '${patient['id'] ?? '—'}'),
              field('Recorded', Fmt.dateTime(created)),
              field('Technician', '${r['staff_name'] ?? '—'}'),
              field('Device', '${r['instrument_id'] ?? '—'}'),
            ],
          ),
          const SizedBox(height: 20),
          if (r['status'] != 'reported')
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.requestedBg, borderRadius: BorderRadius.circular(10)),
              child: Text('The cardiologist has not published this report yet.', style: AppTextStyles.body(color: AppColors.requestedText)),
            )
          else ...[
            Row(
              children: [
                Text('Impression', style: AppTextStyles.h3),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: abnormal ? AppColors.dangerBg : AppColors.reportedBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    abnormal ? 'Abnormal ECG' : 'Normal ECG',
                    style: AppTextStyles.body(size: 12.5, weight: FontWeight.w700, color: abnormal ? AppColors.dangerText : AppColors.reportedText),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Wrap(
                children: [
                  for (final (label, key, unit) in const [
                    ('HR', 'hr', 'bpm'),
                    ('R (II)', 'r', 'mV'),
                    ('RR', 'rr', 'ms'),
                    ('PR', 'pr', 'ms'),
                    ('QRS', 'qrs', 'ms'),
                    ('QT', 'qt', 'ms'),
                    ('QTc', 'qtc', 'ms'),
                    ('QT/QTc', 'qt_by_qtc', ''),
                  ])
                    SizedBox(
                      width: 98,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: AppTextStyles.caption),
                            const SizedBox(height: 2),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${m[key] ?? '—'}',
                                    style: AppTextStyles.body(size: 16, weight: FontWeight.w700),
                                  ),
                                  if (unit.isNotEmpty && m[key] != null) TextSpan(text: ' $unit', style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('Interpretation & advice', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text(advice.isEmpty ? '—' : advice, style: AppTextStyles.body(size: 14.5, height: 1.6, color: AppColors.body)),
            const SizedBox(height: 26),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(r['tat_minutes'] == null ? '' : 'Turnaround: ${Fmt.minutes((r['tat_minutes'] as num).toInt())}', style: AppTextStyles.caption),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${r['cardiologist_name'] ?? ''}',
                      style: AppTextStyles.display(17, color: AppColors.ink2).copyWith(fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
                    ),
                    Container(width: 190, height: 1, color: AppColors.line, margin: const EdgeInsets.symmetric(vertical: 6)),
                    Text(footer, style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Text('Generated by Dr. Cardio ECG Cloud  ·  sample data for demonstration', style: AppTextStyles.body(size: 11, color: AppColors.faint)),
        ],
      ),
    );
  }
}
