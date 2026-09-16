import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves the on-device folders a saved recording's files live in —
/// `Documents/Dr.Cardio/{Data,Reports,csv}` — matching the original app's
/// `StartupActivity.checkCreateStorageFolders()` (`Dr.cardio/Data` for
/// `.dat`, `/Reports` for `.pdf`, `/csv` for `.csv`).
///
/// The original wrote to shared/external storage
/// (`getExternalStoragePublicDirectory`), which needed a runtime storage
/// permission on older Android and doesn't exist as a concept on iOS at
/// all. Modern Android (scoped storage, API 29+) no longer allows
/// unmediated writes to that public tree either, so this rewrite roots the
/// same folder names under the app's own sandboxed documents directory —
/// no permission prompt, identical code path on both platforms, and still
/// reachable from within the app (Load Data, Reports, PDF viewer) exactly
/// like before.
class DrCardioStorage {
  DrCardioStorage._();

  static const _root = 'Dr.Cardio';

  static Future<Directory> _folder(String name) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _root, name));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Raw waveform `.dat` exports.
  static Future<Directory> dataDir() => _folder('Data');

  /// Generated `.pdf` reports.
  static Future<Directory> reportsDir() => _folder('Reports');

  /// Per-lead sample `.csv` exports.
  static Future<Directory> csvDir() => _folder('csv');
}
