import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'dr_cardio_storage.dart';

/// Patient photo/signature capture — port of `PatientData`'s `ImagePicker`
/// (photo, and signature-from-gallery) and `SilkySignaturePad` (drawn
/// signature) flows.
///
/// Unlike the original, which just kept whatever path the OS picker/camera
/// handed back (a real file the user could later delete or move from
/// outside the app, silently breaking report generation), every capture
/// here is immediately copied/written into this app's own sandboxed
/// storage — same folder-per-kind convention as `DrCardioStorage`'s
/// existing Data/Reports/csv folders — so it survives independently of
/// wherever it originally came from and works the same online or offline
/// (nothing here ever touches the network).
class PatientMediaService {
  PatientMediaService._();

  static final ImagePicker _picker = ImagePicker();

  /// Opens the camera or gallery (per [source]), downscales to a
  /// reasonable size for a small report thumbnail (matching the
  /// original's `maxResultSize(200, 200)`), and copies the result into
  /// [DrCardioStorage.photosDir]. Returns null if the user cancelled.
  static Future<String?> pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 480,
      maxHeight: 480,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return _copyInto(await DrCardioStorage.photosDir(), picked.path, prefix: 'photo');
  }

  /// "Select from Gallery" alternative to drawing — port of
  /// `PatientData`'s `rbFromGallery` signature mode.
  static Future<String?> pickSignatureFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 400,
      imageQuality: 90,
    );
    if (picked == null) return null;
    return _copyInto(await DrCardioStorage.signaturesDir(), picked.path, prefix: 'signature');
  }

  /// Writes a drawn signature's exported PNG bytes (from the `signature`
  /// package's `SignatureController.toPngBytes()`) into
  /// [DrCardioStorage.signaturesDir].
  static Future<String> saveDrawnSignature(Uint8List pngBytes) async {
    final dir = await DrCardioStorage.signaturesDir();
    final file = File(p.join(dir.path, 'signature_${DateTime.now().millisecondsSinceEpoch}.png'));
    await file.writeAsBytes(pngBytes);
    return file.path;
  }

  static Future<String> _copyInto(Directory dir, String sourcePath, {required String prefix}) async {
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final dest = File(p.join(dir.path, '${prefix}_${DateTime.now().millisecondsSinceEpoch}$ext'));
    await File(sourcePath).copy(dest.path);
    return dest.path;
  }
}
