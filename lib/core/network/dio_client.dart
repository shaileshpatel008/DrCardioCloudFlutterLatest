import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../services/storage_service.dart';
import 'api_log_interceptor.dart';

/// Thin Dio wrapper: base URL + bearer-token header (mirrors
/// `VolleyMultipartRequest.getHeaders()`'s `Authorization: Bearer <token>`).
class DioClient {
  DioClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(minutes: 5), // PDF/CSV multipart uploads
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
      ),
    );
    // Logs every call's URL, request and response into AppLogger's
    // persisted, shareable log file (see ApiLogInterceptor) — added last so
    // it sees the Authorization header the interceptor above just attached.
    _dio.interceptors.add(ApiLogInterceptor());
  }

  static final DioClient instance = DioClient._internal();
  late final Dio _dio;

  Dio get dio => _dio;
}
