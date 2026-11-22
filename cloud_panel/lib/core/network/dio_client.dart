import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../services/storage_service.dart';
import 'api_exception.dart';

/// Single Dio instance for the panel API: base URL, JSON headers, bearer
/// token, and one place that reacts to an expired session (401).
class DioClient {
  DioClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 3),
        sendTimeout: const Duration(minutes: 2),
        headers: {'Accept': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = StorageService.instance.token;
          if (token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          final isLogin = error.requestOptions.path.endsWith(ApiConstants.login);
          if (error.response?.statusCode == 401 && !isLogin) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: false, logPrint: (o) => debugPrint('[api] $o')));
    }
  }

  static final DioClient instance = DioClient._internal();
  late final Dio _dio;

  /// Set by AuthService: clears the session and returns to sign-in.
  void Function()? onUnauthorized;

  Dio get dio => _dio;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _run(() => _dio.get(path, queryParameters: _clean(query)));

  Future<Map<String, dynamic>> post(String path, {Object? data, Map<String, dynamic>? query}) =>
      _run(() => _dio.post(path, data: data, queryParameters: _clean(query)));

  Future<Map<String, dynamic>> put(String path, {Object? data}) => _run(() => _dio.put(path, data: data));

  Future<Map<String, dynamic>> delete(String path) => _run(() => _dio.delete(path));

  /// Binary download (zip / csv). Returns bytes plus the server's filename.
  Future<({Uint8List bytes, String? fileName})> download(String path, {Object? data}) async {
    try {
      final res = await _dio.post<List<int>>(
        path,
        data: data,
        options: Options(responseType: ResponseType.bytes, headers: {'Accept': '*/*'}),
      );
      final disposition = res.headers.value('content-disposition');
      String? fileName;
      if (disposition != null) {
        final match = RegExp(r'filename\*?=(?:UTF-8\x27\x27)?"?([^";]+)"?').firstMatch(disposition);
        fileName = match?.group(1);
      }
      return (bytes: Uint8List.fromList(res.data ?? const []), fileName: fileName);
    } on DioException catch (e) {
      // Error bodies arrive as bytes too; decode them for a readable message.
      final raw = e.response?.data;
      if (raw is List<int>) {
        String? message;
        try {
          final body = jsonDecode(utf8.decode(raw));
          if (body is Map && body['message'] != null) message = body['message'].toString();
        } catch (_) {}
        if (message != null) {
          throw ApiException(message, statusCode: e.response?.statusCode);
        }
      }
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> _run(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'status': 'success', 'data': data};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final out = <String, dynamic>{};
    query.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.trim().isEmpty) return;
      out[k] = v;
    });
    return out;
  }
}
