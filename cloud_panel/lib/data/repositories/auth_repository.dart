import 'package:flutter/foundation.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/user_model.dart';

class AuthRepository {
  final _api = DioClient.instance;

  /// Returns the bearer token and the signed-in user.
  Future<({String token, UserModel user})> login(String email, String password) async {
    final res = await _api.post(ApiConstants.login, data: {
      'email': email.trim(),
      'password': password,
      'device_name': kIsWeb ? 'web' : defaultTargetPlatform.name,
    });
    final data = asMap(res['data']);
    return (token: asStringOr(data['token']), user: UserModel.fromJson(asMap(data['user'])));
  }

  Future<UserModel> me() async {
    final res = await _api.get(ApiConstants.me);
    return UserModel.fromJson(asMap(res['data']));
  }

  Future<void> logout() async {
    await _api.post(ApiConstants.logout);
  }

  Future<String> forgotPassword(String email) async {
    final res = await _api.post(ApiConstants.forgotPassword, data: {'email': email.trim()});
    return asStringOr(res['message'], 'We have emailed your password reset link.');
  }
}
