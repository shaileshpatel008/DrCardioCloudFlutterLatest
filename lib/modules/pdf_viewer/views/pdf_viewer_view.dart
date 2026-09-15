import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdfx/pdfx.dart';

import '../controllers/pdf_viewer_controller.dart';

const _kBg = Color(0xFF2B2A28);
const _kAppBarBg = Color(0xFF201F1E);

class PdfViewerView extends GetView<PdfViewerController> {
  const PdfViewerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kAppBarBg,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        // Plain Text, not Obx: fileName is a one-time getter derived from
        // Get.arguments in onInit, never reassigned — wrapping it in Obx
        // (as the previous version of this screen did) gives GetX's Obx
        // zero observables to track, which it treats as a hard error
        // ("improper use of a GetX"), not a no-op. Flutter's default error
        // widget for that failure is exactly the solid red block reported
        // here — it was never a rendering/theme glitch.
        title: Text(
          controller.fileName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        actions: [
          Obx(() {
            final pdf = controller.pdfController.value;
            if (pdf == null) return const SizedBox.shrink();
            return PdfPageNumber(
              controller: pdf,
              builder: (_, __, page, pagesCount) {
                if (pagesCount == null || pagesCount <= 1) return const SizedBox.shrink();
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text('$page / $pagesCount', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                  ),
                );
              },
            );
          }),
          IconButton(icon: const Icon(Icons.ios_share), tooltip: 'Share', onPressed: controller.share),
          IconButton(icon: const Icon(Icons.print_outlined), tooltip: 'Print', onPressed: controller.print),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        final err = controller.error.value;
        if (err != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 42),
                  const SizedBox(height: 14),
                  Text(err, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 18),
                  OutlinedButton(
                    onPressed: controller.retry,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return _DoubleTapToZoom(
          controller: controller.pdfController.value!,
          child: PdfViewPinch(
            controller: controller.pdfController.value!,
            padding: 16,
            minScale: 1,
            maxScale: 5,
            // Left at pdfx's default (a near-white page with a soft drop
            // shadow) — that's what actually makes a single page read as a
            // centered, floating "card" against the dark scaffold behind it.
            builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
              options: const DefaultBuilderOptions(),
              documentLoaderBuilder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              pageLoaderBuilder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorBuilder: (_, error) => Center(
                child: Text('$error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Adds double-tap-to-zoom on top of [PdfViewPinch]'s pinch/pan, matching
/// the original Android app's `PDFView.enableDoubletap(true)` (pinch alone
/// was never the only zoom gesture there). `PdfControllerPinch` IS the
/// `TransformationController` `PdfViewPinch` renders from, so driving it
/// externally — animated, so it doesn't just snap — moves the same view
/// pinch would. A double-tap and a pinch/pan use distinct gesture
/// recognizers, so both coexist on the same child without either stealing
/// the other's gestures.
class _DoubleTapToZoom extends StatefulWidget {
  const _DoubleTapToZoom({required this.controller, required this.child});
  final PdfControllerPinch controller;
  final Widget child;

  @override
  State<_DoubleTapToZoom> createState() => _DoubleTapToZoomState();
}

class _DoubleTapToZoomState extends State<_DoubleTapToZoom> with SingleTickerProviderStateMixin {
  static const _zoomScale = 2.5;

  late final AnimationController _animController;
  Animation<Matrix4>? _zoomAnimation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))
      ..addListener(() {
        final anim = _zoomAnimation;
        if (anim != null) widget.controller.value = anim.value;
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final begin = widget.controller.value;
    final Matrix4 end;
    if (begin.getMaxScaleOnAxis() > 1.05) {
      // Already zoomed in — double-tap zooms back out.
      end = Matrix4.identity();
    } else {
      // Zoom in centered on exactly where the user double-tapped.
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      end = Matrix4.identity()
        ..translate(-position.dx * (_zoomScale - 1), -position.dy * (_zoomScale - 1))
        ..scale(_zoomScale);
    }
    _zoomAnimation = Matrix4Tween(begin: begin, end: end).animate(
      CurveTween(curve: Curves.easeOut).animate(_animController),
    );
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: widget.child,
    );
  }
}
