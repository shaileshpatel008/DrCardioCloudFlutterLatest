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
        title: Obx(
          () => Text(
            controller.fileName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
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

        return PdfViewPinch(
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
        );
      }),
    );
  }
}
