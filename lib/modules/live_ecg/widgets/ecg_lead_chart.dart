import 'package:flutter/material.dart';

import '../../../core/services/ecg/ecg_data.dart';
import '../../../theme/app_colors.dart';

/// Renders one ECG lead's rolling waveform on a black/yellow monitor panel
/// — replaces the original's per-lead MPAndroidChart `LineChart`
/// (`ecgData.chart[ch]`, `Color.BLACK` background / `Color.YELLOW` trace).
/// Shows only the most recent [visibleSamples] points, matching the
/// original's `setVisibleXRange`/`moveViewToX` scrolling window.
class EcgLeadChart extends StatelessWidget {
  const EcgLeadChart({
    super.key,
    required this.leadIndex,
    required this.visibleSamples,
    this.height,
    this.showLabel = true,
    this.isOff = false,
  });

  final int leadIndex;
  final int visibleSamples;

  /// Fixed height (used for the small grid layout); leave null to fill
  /// whatever height the parent already constrains, e.g. an [Expanded]
  /// row in a full-height single-column stack.
  final double? height;
  final bool showLabel;

  /// True when `EcgData.isLeadOff` says this lead's electrode(s) are
  /// currently disconnected. A floating ADC input rails to its limits, so
  /// its raw samples are noise that could be mistaken for a real (and
  /// alarming) rhythm in a medical app — the trace is suppressed and
  /// replaced with a plain "LEAD OFF" state instead of being drawn.
  final bool isOff;

  @override
  Widget build(BuildContext context) {
    final samples = EcgData.instance.chartData[leadIndex];
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(color: AppColors.monitorBg, borderRadius: BorderRadius.circular(10)),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _EcgPainter(samples: samples, visibleSamples: visibleSamples, isOff: isOff))),
          if (showLabel)
            Positioned(
              top: 5,
              left: 7,
              child: Text(
                EcgData.leadName[leadIndex],
                style: TextStyle(
                  color: isOff ? AppColors.brandRed : AppColors.monitorTrace,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (isOff)
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sensors_off, color: AppColors.brandRed.withValues(alpha: 0.85), size: 13),
                  const SizedBox(width: 5),
                  Text('LEAD OFF',
                      style: TextStyle(
                          color: AppColors.brandRed.withValues(alpha: 0.85), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EcgPainter extends CustomPainter {
  _EcgPainter({required this.samples, required this.visibleSamples, this.isOff = false});
  final List<double> samples;
  final int visibleSamples;
  final bool isOff;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.monitorGrid
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // A disconnected electrode's input floats and rails the ADC — plotting
    // it would paint a wall of spikes that looks like a real (and
    // alarming) arrhythmia. Leave the panel blank but gridded; the "LEAD
    // OFF" overlay built in EcgLeadChart communicates the actual state.
    if (isOff) return;

    if (samples.isEmpty) return;
    final start = samples.length > visibleSamples ? samples.length - visibleSamples : 0;
    final window = samples.sublist(start);
    if (window.length < 2) return;

    final tracePaint = Paint()
      ..color = AppColors.monitorTrace
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final path = Path();
    final dx = size.width / visibleSamples;
    final midY = size.height / 2;
    // Port of `NewEcgActivity.modifyLineChartsUI()`'s fixed Y-axis window
    // (`leftAxis.setAxisMaximum/Minimum(±1.5 * settings.val_per_mv)`) —
    // the plotted samples are in the same raw-ADC-count unit system as
    // `val_per_mv` (both derive from `graph_scale * hpf_val` with no mV
    // conversion in between), so half the panel height has to map to
    // exactly `1.5 * valPerMv` of that same unit to match. The previous
    // `size.height / 5` was a made-up constant with no relation to that
    // calibration constant at all — for hwVersion 1 (valPerMv ~54.6) a
    // normal QRS complex is tens of units tall, more than 10x what that
    // constant assumed fit on screen, so nearly every beat saturated.
    final scaleY = (size.height / 2) / (1.5 * EcgData.instance.valPerMv);
    for (var i = 0; i < window.length; i++) {
      final x = i * dx;
      final y = midY - window[i] * scaleY;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    // A real excursion past the calibrated window (big enough to be
    // clinically real, e.g. hypertrophy) should still happen sometimes —
    // MPAndroidChart's own renderer just crops it at the plot area
    // instead of flattening it, so the trace visibly runs off the top/
    // bottom edge rather than growing the ugly flat-topped "squares" a
    // clamped coordinate produces whenever two consecutive samples both
    // saturate.
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(path, tracePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EcgPainter oldDelegate) => true;
}
