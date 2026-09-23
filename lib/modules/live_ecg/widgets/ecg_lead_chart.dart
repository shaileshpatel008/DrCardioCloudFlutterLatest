import 'package:flutter/material.dart';

import '../../../core/services/ecg/ecg_data.dart';
import '../../../theme/app_colors.dart';

/// Renders one ECG lead's rolling waveform on a black/yellow monitor panel
/// — replaces the original's per-lead MPAndroidChart `LineChart`
/// (`ecgData.chart[ch]`, `Color.BLACK` background / `Color.YELLOW` trace).
/// Shows only the most recent [visibleSamples] points, matching the
/// original's `setVisibleXRange`/`moveViewToX` scrolling window.
class EcgLeadChart extends StatelessWidget {
  const EcgLeadChart({super.key, required this.leadIndex, required this.visibleSamples, this.height, this.showLabel = true});

  final int leadIndex;
  final int visibleSamples;

  /// Fixed height (used for the small grid layout); leave null to fill
  /// whatever height the parent already constrains, e.g. an [Expanded]
  /// row in a full-height single-column stack.
  final double? height;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final samples = EcgData.instance.chartData[leadIndex];
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(color: AppColors.monitorBg, borderRadius: BorderRadius.circular(10)),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _EcgPainter(samples: samples, visibleSamples: visibleSamples))),
          if (showLabel)
            Positioned(
              top: 5,
              left: 7,
              child: Text(
                EcgData.leadName[leadIndex],
                style: const TextStyle(
                  color: AppColors.monitorTrace,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EcgPainter extends CustomPainter {
  _EcgPainter({required this.samples, required this.visibleSamples});
  final List<double> samples;
  final int visibleSamples;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.monitorGrid
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

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
    final scaleY = size.height / 5;
    for (var i = 0; i < window.length; i++) {
      final x = i * dx;
      final y = (midY - window[i] * scaleY).clamp(0.0, size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, tracePaint);
  }

  @override
  bool shouldRepaint(covariant _EcgPainter oldDelegate) => true;
}
