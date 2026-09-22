import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves the on-device folders a saved recording's files live in —
/// `Documents/Dr.cardio/{Data,Reports,csv,Filtered Data}` — matching the
/// original app's `StartupActivity.checkCreateStorageFolders()`
/// (`Dr.cardio/Data` for `.dat`, `/Reports` for `.pdf`, `/csv` for
/// `.csv`, `/Filtered Data` for the filtered+metadata CSV).
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

  /// Must match `R.string.storage_folder` (`res/values/settings.xml`)
  /// exactly, lowercase "c" and all — this is the literal folder name the
  /// live, already-shipped app creates and that the existing user guide
  /// documents; `mFile.DIR_DR_CARDIO` ("Dr.Cardio", capital C) is unused
  /// dead code in the original and must NOT be used here.
  static const _root = 'Dr.cardio';

  static Future<Directory> _folder(String name) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _root, name));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Raw waveform `.dat` exports — `storage_sub_folders[0]`.
  static Future<Directory> dataDir() => _folder('Data');

  /// Generated `.pdf` reports — `storage_sub_folders[1]`.
  static Future<Directory> reportsDir() => _folder('Reports');

  /// Per-lead sample `.csv` exports — `storage_sub_folders[2]`.
  static Future<Directory> csvDir() => _folder('csv');

  /// Filtered/baseline-corrected `.csv` exports with a metadata header —
  /// `storage_sub_folders[3]`, port of `mFile.saveCsvFileWithFilter()`.
  static Future<Directory> filteredDataDir() => _folder('Filtered Data');

  /// Patient photos, copied here at capture time rather than referenced by
  /// their original OS gallery/camera path (the original app's approach,
  /// and fragile — deleting the source photo from the gallery would break
  /// report generation). Not part of the original's four folders since it
  /// never had this feature; same root, new sub-folder.
  static Future<Directory> photosDir() => _folder('Photos');

  /// Patient signatures (drawn or uploaded), same rationale as [photosDir].
  static Future<Directory> signaturesDir() => _folder('Signatures');
}
