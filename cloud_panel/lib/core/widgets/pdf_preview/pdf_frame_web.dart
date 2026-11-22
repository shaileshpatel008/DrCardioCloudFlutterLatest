import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

const bool supportsInlinePdf = true;

final Set<String> _registered = {};

/// Embeds the browser's PDF viewer for [url] (an <iframe> platform view).
Widget buildPdfFrame(String url) {
  final viewType = 'pdf-frame-${url.hashCode}';
  if (_registered.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      return web.HTMLIFrameElement()
        ..src = url
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.background = '#FFF6F4';
    });
  }
  return HtmlElementView(viewType: viewType);
}
