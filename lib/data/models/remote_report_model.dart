/// One entry from `GET api/ecg-list`'s `success_data` array — the
/// server's own record of a report, independent of whatever this device
/// has locally. Fields match `ReportActivity.callGetReportsECGsListApi()`
/// exactly; there is no patient/lead data in this payload; opening one
/// downloads the PDF from [documentPath].
class RemoteReportModel {
  RemoteReportModel({
    required this.ecgRecordId,
    required this.documentName,
    required this.documentPath,
    required this.status,
    required this.assignedToCardiologist,
  });

  final String ecgRecordId;
  final String documentName;
  final String documentPath;
  final String status;
  final bool assignedToCardiologist;

  bool get isReported => status.toLowerCase().contains('reported');

  factory RemoteReportModel.fromJson(Map<String, dynamic> json) => RemoteReportModel(
        ecgRecordId: json['ecg_record_id']?.toString() ?? '',
        documentName: json['document_name']?.toString() ?? '',
        documentPath: json['document_path']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        assignedToCardiologist: (json['has_assigned_to_cardiologist']?.toString().toLowerCase()) == 'true',
      );
}
