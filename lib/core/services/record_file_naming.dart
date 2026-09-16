import '../../data/models/ecg_record_model.dart';

/// Builds the human-readable file name used for a recording's on-disk and
/// uploaded files — port of `NewEcgActivity`'s `appendFileName + "_" +
/// ecgData.date_time` construction (`NewEcgActivity.java:1001-1005`,
/// `mFile.saveDataCsvFile()`), so a saved/uploaded file reads e.g.
/// `Testoff_2026-09-14_15-57-55.44.pdf` — patient name + timestamp —
/// instead of an opaque numeric ID nobody can match back to a patient.
class RecordFileNaming {
  RecordFileNaming._();

  /// The shared name stem (no extension) for a record's .pdf/.csv/.dat
  /// files and its uploaded filename.
  static String stem(EcgRecordModel record) => '${_sanitize(record.patient.name)}_${_timestamp(record.dateTime)}';

  /// Port of `ecgData.date_time`'s exact format
  /// (`new SimpleDateFormat("yyyy-MM-dd_HH-mm-ss.SS").format(new Date())`,
  /// `NewEcgActivity.java:823`). Java's "SS" pattern for milliseconds
  /// truncates to the leading 2 digits (divides by 10) rather than
  /// rounding or taking the last 2 digits, hence `millisecond ~/ 10`.
  static String _timestamp(DateTime dt) {
    String pad2(int v) => v.toString().padLeft(2, '0');
    final date = '${dt.year.toString().padLeft(4, '0')}-${pad2(dt.month)}-${pad2(dt.day)}';
    final time = '${pad2(dt.hour)}-${pad2(dt.minute)}-${pad2(dt.second)}';
    final hundredths = pad2(dt.millisecond ~/ 10);
    return '${date}_$time.$hundredths';
  }

  /// Port of `NewEcgActivity.java:1001-1002`'s
  /// `patient_name.substring(0, 11)` + `replaceAll("[^a-zA-Z0-9]", "_")`.
  /// (The original's `.dat`/"Filtered Data" writers use a slightly
  /// different, unsanitized 20-or-11-char rule — this rewrite uses one
  /// sanitized stem everywhere instead, which avoids a patient name with a
  /// `/` or other path-breaking character corrupting a file path.)
  static String _sanitize(String patientName) {
    final truncated = patientName.length > 11 ? patientName.substring(0, 11) : patientName;
    final sanitized = truncated.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return sanitized.isEmpty ? 'Patient' : sanitized;
  }
}
