import 'patient_model.dart';

enum SyncStatus { synced, pending, failed, offline }

/// Mirrors `ECGDataModel` (the original's per-recording record) plus the
/// upload payload fields `MainActivity.uploadPDF()` sends to
/// `api/upload-pdf` (hr, r, rr, pr, qrs, qt, qtc, qt_by_qtc, device_id,
/// lat/long, device_info, patient_info, address).
class EcgRecordModel {
  EcgRecordModel({
    required this.id,
    required this.dateTime,
    required this.patient,
    required this.deviceName,
    required this.filter,
    required this.gain,
    required this.leadData,
    this.pdfPath,
    this.csvPath,
    this.datPath,
    this.deviceId = '',
    this.latitude = '',
    this.longitude = '',
    this.address = '',
    this.hr = '',
    this.r = '',
    this.rr = '',
    this.pr = '',
    this.qrs = '',
    this.qt = '',
    this.qtc = '',
    this.qtByQtc = '',
    this.syncStatus = SyncStatus.pending,
  });

  final String id;
  final DateTime dateTime;
  final PatientModel patient;
  final String deviceName;
  final String filter;
  final String gain;

  /// Down-sampled, filtered samples per lead (I, II, III, aVR, aVL, aVF,
  /// V1-V6), same order as `EcgData.leadName`.
  final List<List<double>> leadData;

  final String? pdfPath;
  final String? csvPath;

  /// Raw waveform export path — see `DatFileService`. Nullable because
  /// records saved before this field existed have none.
  final String? datPath;

  final String deviceId;
  final String latitude;
  final String longitude;
  final String address;
  final String hr;
  final String r;
  final String rr;
  final String pr;
  final String qrs;
  final String qt;
  final String qtc;
  final String qtByQtc;

  SyncStatus syncStatus;

  EcgRecordModel copyWith({SyncStatus? syncStatus, String? pdfPath, String? csvPath, String? datPath}) {
    return EcgRecordModel(
      id: id,
      dateTime: dateTime,
      patient: patient,
      deviceName: deviceName,
      filter: filter,
      gain: gain,
      leadData: leadData,
      pdfPath: pdfPath ?? this.pdfPath,
      csvPath: csvPath ?? this.csvPath,
      datPath: datPath ?? this.datPath,
      deviceId: deviceId,
      latitude: latitude,
      longitude: longitude,
      address: address,
      hr: hr,
      r: r,
      rr: rr,
      pr: pr,
      qrs: qrs,
      qt: qt,
      qtc: qtc,
      qtByQtc: qtByQtc,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
