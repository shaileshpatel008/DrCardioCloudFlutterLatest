import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../demo/demo_documents.dart';
import '../../utils/link_opener.dart';
import '../ui_kit.dart';
import 'pdf_frame_io.dart' if (dart.library.js_interop) 'pdf_frame_web.dart' as frame;

/// Inline PDF preview: on the web the browser's own PDF viewer is embedded;
/// on Android / iOS a card opens the file in the system viewer.
class PdfPreview extends StatelessWidget {
  const PdfPreview({super.key, required this.url, this.height = 560, this.title = 'ECG recording'});

  final String? url;
  final double height;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
        child: Text('This document is not available yet.', style: AppTextStyles.muted),
      );
    }
    if (DemoDocuments.handles(url)) return DemoDocuments.inline(url!, height: height);
    if (frame.supportsInlinePdf) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(height: height, child: frame.buildPdfFrame(url!)),
      );
    }
    return InkWell(
      onTap: () => LinkOpener.open(url),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6F4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF6D5CF)),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTextStyles.body(weight: FontWeight.w700)),
              Text('Tap to open in your PDF viewer', style: AppTextStyles.caption),
            ]),
          ),
          const IconAction(icon: Icons.open_in_new_rounded, tooltip: 'Open', onPressed: null),
        ]),
      ),
    );
  }
}
