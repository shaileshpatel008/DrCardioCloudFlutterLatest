import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../models/ecg_record_model.dart';
import 'auth_remote_datasource.dart';

class EcgRemoteDataSource {
  final Dio _dio = DioClient.instance.dio;

  /// POST api/upload-pdf (multipart) — same field names as
  /// `MainActivity.uploadPDF()`'s `VolleyMultipartRequest`: device_id,
  /// latitude, longitude, device_info, patient_info, address, hr, r, rr,
  /// pr, qrs, qt, qtc, qt_by_qtc, have_to_assign_cardiologist, plus the
  /// `document_path` (PDF) and `csv_file` (CSV) file parts. Auth header is
  /// attached automatically by [DioClient]'s interceptor.
  Future<void> uploadReport({
    required EcgRecordModel record,
    required bool autoAssignCardiologist,
  }) async {
    if (record.pdfPath == null || record.csvPath == null) {
      throw StateError('Record ${record.id} has no generated PDF/CSV to upload.');
    }

    final formData = FormData.fromMap({
      'device_id': record.deviceId,
      'latitude': record.latitude,
      'longitude': record.longitude,
      'device_info': jsonEncode({'platform': Platform.operatingSystem}),
      'patient_info': jsonEncode(record.patient.toJson()),
      'address': record.address,
      'hr': record.hr,
      'r': record.r,
      'rr': record.rr,
      'pr': record.pr,
      'qrs': record.qrs,
      'qt': record.qt,
      'qtc': record.qtc,
      'qt_by_qtc': record.qtByQtc,
      'have_to_assign_cardiologist': autoAssignCardiologist ? 'true' : 'false',
      'document_path': await MultipartFile.fromFile(record.pdfPath!, filename: '${record.id}.pdf'),
      'csv_file': await MultipartFile.fromFile(record.csvPath!, filename: '${record.id}.csv'),
    });

    final response = await _dio.post(ApiConstants.uploadPdf, data: formData);
    final body = response.data is String ? jsonDecode(response.data as String) : response.data;
    if ((body['status'] as String?)?.toLowerCase() != 'success') {
      throw ApiStatusException(body['error_data']?.toString() ?? 'Upload failed');
    }
  }

  /// GET api/auth-device?device_id= — re-validates a paired device
  /// against the signed-in account.
  Future<bool> authDevice(String deviceId) async {
    final response = await _dio.get(ApiConstants.authDevice, queryParameters: {'device_id': deviceId});
    final body = response.data is String ? jsonDecode(response.data as String) : response.data;
    return (body['status'] as String?)?.toLowerCase() == 'success';
  }
}
