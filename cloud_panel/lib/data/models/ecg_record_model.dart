import '../../core/utils/json_utils.dart';

/// Report workflow status of an ECG (pdfs.status).
enum ReportStatus { pending, requested, reported, noCredit }

ReportStatus reportStatusFrom(String? v) => switch (v) {
      'requested' => ReportStatus.requested,
      'reported' => ReportStatus.reported,
      'no_credit' => ReportStatus.noCredit,
      _ => ReportStatus.pending,
    };

extension ReportStatusX on ReportStatus {
  String get apiValue => switch (this) {
        ReportStatus.pending => 'pending',
        ReportStatus.requested => 'requested',
        ReportStatus.reported => 'reported',
        ReportStatus.noCredit => 'no_credit',
      };

  String get label => switch (this) {
        ReportStatus.pending => 'Pending',
        ReportStatus.requested => 'Requested',
        ReportStatus.reported => 'Reported',
        ReportStatus.noCredit => 'No credit',
      };
}

class EcgMeasurements {
  const EcgMeasurements({this.hr, this.r, this.rr, this.pr, this.qrs, this.qt, this.qtc, this.qtByQtc});

  final String? hr, r, rr, pr, qrs, qt, qtc, qtByQtc;

  bool get isEmpty => [hr, r, rr, pr, qrs, qt, qtc, qtByQtc].every((v) => v == null || v.isEmpty);

  factory EcgMeasurements.fromJson(Map<String, dynamic> j) => EcgMeasurements(
        hr: asString(j['hr']),
        r: asString(j['r']),
        rr: asString(j['rr']),
        pr: asString(j['pr']),
        qrs: asString(j['qrs']),
        qt: asString(j['qt']),
        qtc: asString(j['qtc']),
        qtByQtc: asString(j['qt_by_qtc']),
      );
}

class EcgActions {
  const EcgActions({
    this.viewReport = false,
    this.delete = false,
    this.reassign = false,
    this.assign = false,
    this.diagnose = false,
    this.editReport = false,
  });

  final bool viewReport, delete, reassign, assign, diagnose, editReport;

  factory EcgActions.fromJson(Map<String, dynamic> j) => EcgActions(
        viewReport: asBool(j['view_report']),
        delete: asBool(j['delete']),
        reassign: asBool(j['reassign']),
        assign: asBool(j['assign']),
        diagnose: asBool(j['diagnose']),
        editReport: asBool(j['edit_report']),
      );
}

class PatientInfo {
  const PatientInfo({this.name, this.age, this.gender, this.id});
  final String? name, age, gender, id;

  bool get isEmpty => [name, age, gender, id].every((v) => v == null);

  factory PatientInfo.fromJson(Map<String, dynamic> j) => PatientInfo(
        name: asString(j['name']),
        age: asString(j['age']),
        gender: asString(j['gender']),
        id: asString(j['id']),
      );
}

class EcgRecord {
  EcgRecord({
    required this.id,
    required this.fileName,
    required this.status,
    required this.statusLabel,
    required this.actions,
    required this.measurements,
    this.ecgPdfUrl,
    this.reportPdfUrl,
    this.cardiologistReportPdfUrl,
    this.csvUrl,
    this.staffName,
    this.hospitalName,
    this.doctorName,
    this.clientId,
    this.clientUserId,
    this.instrumentId,
    this.cardiologistId,
    this.cardiologistName,
    this.isReassigned = false,
    this.ecgStatus,
    this.tatMinutes,
    this.address,
    this.latitude,
    this.longitude,
    this.patient,
    this.deviceModel,
    this.requestedAt,
    this.reportedAt,
    this.createdAt,
    this.updatedAt,
    this.cardiologistReport,
  });

  final int id;
  final String fileName;
  final String? ecgPdfUrl;
  final String? reportPdfUrl;
  final String? cardiologistReportPdfUrl;
  final String? csvUrl;
  final String? staffName;
  final String? hospitalName;
  final String? doctorName;
  final int? clientId;
  final int? clientUserId;
  final String? instrumentId;
  final int? cardiologistId;
  final String? cardiologistName;
  final bool isReassigned;
  final ReportStatus status;
  final String statusLabel;
  final String? ecgStatus;
  final int? tatMinutes;
  final String? address;
  final String? latitude;
  final String? longitude;
  final PatientInfo? patient;
  final String? deviceModel;
  final DateTime? requestedAt;
  final DateTime? reportedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final EcgActions actions;
  final EcgMeasurements measurements;
  final String? cardiologistReport;

  bool get isAbnormal => ecgStatus == 'abnormal';
  bool get isNormal => ecgStatus == 'normal';

  /// Patient name if the device sent one, otherwise derived from the file
  /// name the app uploads ("Ramesh_K_2026-11-22_14-11-20.pdf").
  String get displayName {
    final n = patient?.name;
    if (n != null && n.isNotEmpty) return n;
    final base = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final match = RegExp(r'^(.*?)_\d{4}-\d{2}-\d{2}').firstMatch(base);
    final raw = (match?.group(1) ?? base).replaceAll('_', ' ').trim();
    return raw.isEmpty ? 'ECG #$id' : raw;
  }

  bool get hasLocation =>
      latitude != null && longitude != null && latitude != '0.0' && longitude != '0.0' && latitude != '0';

  factory EcgRecord.fromJson(Map<String, dynamic> j) {
    final deviceInfo = j['device_info'];
    String? model;
    if (deviceInfo is Map) {
      model = asString(deviceInfo['FullDeviceInfo']) ?? asString(deviceInfo['Model']) ?? asString(deviceInfo['platform']);
    }
    final patient = j['patient'];
    return EcgRecord(
      id: asIntOr(j['id']),
      fileName: asStringOr(j['file_name'], 'ECG'),
      ecgPdfUrl: asString(j['ecg_pdf_url']),
      reportPdfUrl: asString(j['report_pdf_url']),
      cardiologistReportPdfUrl: asString(j['cardiologist_report_pdf_url']),
      csvUrl: asString(j['csv_url']),
      staffName: asString(j['staff_name']),
      hospitalName: asString(j['hospital_name']),
      doctorName: asString(j['doctor_name']),
      clientId: asInt(j['client_id']),
      clientUserId: asInt(j['client_user_id']),
      instrumentId: asString(j['instrument_id']),
      cardiologistId: asInt(j['cardiologist_id']),
      cardiologistName: asString(j['cardiologist_name']),
      isReassigned: asBool(j['is_reassigned']),
      status: reportStatusFrom(asString(j['status'])),
      statusLabel: asStringOr(j['status_label'], 'Pending'),
      ecgStatus: asString(j['ecg_status']),
      tatMinutes: asInt(j['tat_minutes']),
      address: asString(j['address']),
      latitude: asString(j['latitude']),
      longitude: asString(j['longitude']),
      patient: patient is Map ? PatientInfo.fromJson(asMap(patient)) : null,
      deviceModel: model,
      requestedAt: asDate(j['requested_at']),
      reportedAt: asDate(j['reported_at']),
      createdAt: asDate(j['created_at']),
      updatedAt: asDate(j['updated_at']),
      actions: EcgActions.fromJson(asMap(j['actions'])),
      measurements: EcgMeasurements.fromJson(asMap(j['measurements'])),
      cardiologistReport: asString(j['cardiologist_report']),
    );
  }
}

class EcgSummary {
  const EcgSummary({this.all = 0, this.pending = 0, this.requested = 0, this.reported = 0, this.noCredit = 0});
  final int all, pending, requested, reported, noCredit;

  int forStatus(ReportStatus? s) => switch (s) {
        null => all,
        ReportStatus.pending => pending,
        ReportStatus.requested => requested,
        ReportStatus.reported => reported,
        ReportStatus.noCredit => noCredit,
      };

  factory EcgSummary.fromJson(Map<String, dynamic> j) {
    final s = asMap(j['by_status']);
    return EcgSummary(
      all: asIntOr(j['all']),
      pending: asIntOr(s['pending']),
      requested: asIntOr(s['requested']),
      reported: asIntOr(s['reported']),
      noCredit: asIntOr(s['no_credit']),
    );
  }
}

class ReportTemplate {
  const ReportTemplate(this.id, this.title, this.body);
  final int id;
  final String title;
  final String body;

  factory ReportTemplate.fromJson(Map<String, dynamic> j) =>
      ReportTemplate(asIntOr(j['id']), asStringOr(j['title'], 'Template'), asStringOr(j['body']));
}
