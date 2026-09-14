import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../models/user_model.dart';

/// Thrown for a well-formed `{"status":"error", "error_data": "..."}`
/// response — mirrors how `SignInActivity` reads `error_data` for its
/// toast on a failed login.
class ApiStatusException implements Exception {
  ApiStatusException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthRemoteDataSource {
  final Dio _dio = DioClient.instance.dio;

  /// POST api/login — same form fields as `SignInActivity`'s Volley
  /// request: email, password, device_info (JSON string), device_type,
  /// device_token (FCM token; empty string here — push notifications are
  /// out of scope for this port, see README).
  Future<UserModel> login({
    required String email,
    required String password,
    String deviceToken = '',
  }) async {
    final deviceInfo = await _buildDeviceInfo();
    final response = await _dio.post(
      ApiConstants.login,
      data: FormData.fromMap({
        'email': email,
        'password': password,
        'device_info': jsonEncode(deviceInfo),
        'device_type': Platform.isIOS ? 'ios' : 'android',
        'device_token': deviceToken,
      }),
    );

    final body = response.data is String ? jsonDecode(response.data as String) : response.data;
    if ((body['status'] as String?)?.toLowerCase() == 'success') {
      return UserModel.fromJson(body['success_data'] as Map<String, dynamic>);
    }
    throw ApiStatusException(body['error_data']?.toString() ?? 'Login failed');
  }

  /// GET api/get-token?user_id= — refreshes the bearer token and returns
  /// the account's report-limit quota.
  Future<UserModel> refreshToken(int userId) async {
    final response = await _dio.get(ApiConstants.getToken, queryParameters: {'user_id': userId});
    final body = response.data is String ? jsonDecode(response.data as String) : response.data;
    if ((body['status'] as String?)?.toLowerCase() == 'success') {
      return UserModel.fromJson(body['success_data'] as Map<String, dynamic>);
    }
    throw ApiStatusException(body['error_data']?.toString() ?? 'Token refresh failed');
  }

  Future<Map<String, dynamic>> _buildDeviceInfo() async {
    final info = await PackageInfo.fromPlatform();
    return {
      'Platform': Platform.operatingSystem,
      'OS Version': Platform.operatingSystemVersion,
      'App Version': info.version,
    };
  }
}
