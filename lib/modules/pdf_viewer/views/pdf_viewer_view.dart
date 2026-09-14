import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';

import '../controllers/pdf_viewer_controller.dart';

class PdfViewerView extends GetView<PdfViewerController> {
  const PdfViewerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3A3A3A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF201F1E),
        foregroundColor: Colors.white,
        title: Obx(() => Text(controller.fileName, style: const TextStyle(fontSize: 14.5))),
        actions: [
          IconButton(icon: const Icon(Icons.ios_share), onPressed: controller.share),
          IconButton(icon: const Icon(Icons.print_outlined), onPressed: controller.print),
        ],
      ),
      body: Obx(() {
        final data = controller.bytes.value?.data;
        if (controller.isLoading.value || data == null) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        return PdfPreview(
          build: (format) async => data,
          canChangePageFormat: false,
          canChangeOrientation: false,
          allowSharing: false,
          allowPrinting: false,
          useActions: false,
        );
      }),
    );
  }
}
