import 'file_saver_io.dart' if (dart.library.js_interop) 'file_saver_web.dart' as impl;

/// Saves downloaded bytes the way each platform expects:
///  - web: a normal browser download
///  - Android / iOS: saved to the app's documents folder, then the share
///    sheet opens so the file can be saved to Files / Drive or sent on.
class FileSaver {
  FileSaver._();

  static Future<String?> save(List<int> bytes, String fileName, {String mimeType = 'application/octet-stream'}) =>
      impl.saveFile(bytes, fileName, mimeType);
}
