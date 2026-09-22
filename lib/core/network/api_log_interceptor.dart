import 'dart:convert';

import 'package:dio/dio.dart';

import '../services/app_logger.dart';

/// Logs every API call's URL, request and response through [AppLogger]
/// instead of just the console — the app previously only logged API traffic
/// via `pretty_dio_logger`, which prints to the console and nothing else, so
/// a tester hitting an API error had no way to hand back what actually went
/// over the wire. Routing through [AppLogger] means it lands in the same
/// `app.log` file "Share Debug Logs" (Settings → Diagnostics) already sends,
/// so a failing report upload or login can be diagnosed from that file
/// alone.
///
/// A password or bearer token in that shared file would be a real leak, so
/// both are redacted before anything is written — unlike the original
/// Android app's Volley requests, which were never logged at all and so
/// never had to worry about it.
class ApiLogInterceptor extends Interceptor {
  static const _redactedFields = {'password'};
  static const _maxBodyChars = 3000;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final headers = Map<String, dynamic>.from(options.headers);
    if (headers.containsKey('Authorization')) headers['Authorization'] = 'Bearer ***';
    final body = _describeRequestBody(options.data);
    AppLogger.i(
      '→ API ${options.method} ${options.uri}'
      '\n  headers: $headers'
      '${body != null ? '\n  body: $body' : ''}',
    );
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    AppLogger.i(
      '← API ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}'
      '\n  body: ${_truncate(_stringify(response.data))}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final req = err.requestOptions;
    final response = err.response;
    AppLogger.e(
      '✕ API ${req.method} ${req.uri} failed — ${err.type}'
      '${response != null ? '\n  status: ${response.statusCode}\n  body: ${_truncate(_stringify(response.data))}' : ''}',
      err.message,
    );
    handler.next(err);
  }

  /// [FormData] (every POST in this app) logs its plain fields and, for
  /// each attached file, only its filename/size — never the file's bytes,
  /// which would otherwise dump a whole PDF/CSV upload into the log file.
  static String? _describeRequestBody(Object? data) {
    if (data == null) return null;
    if (data is FormData) {
      final fields = data.fields.map((f) => '${f.key}=${_redact(f.key, f.value)}');
      final files = data.files.map((f) => '${f.key}=<file ${f.value.filename}, ${f.value.length}b>');
      return [...fields, ...files].join(', ');
    }
    if (data is Map) {
      final sanitized = <String, dynamic>{for (final e in data.entries) '${e.key}': _redact('${e.key}', e.value)};
      return _truncate(jsonEncode(sanitized));
    }
    return _truncate(data.toString());
  }

  static Object? _redact(String key, Object? value) => _redactedFields.contains(key) ? '***' : value;

  static String _stringify(Object? data) {
    if (data == null) return 'null';
    if (data is String) return data;
    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }

  static String _truncate(String s) => s.length > _maxBodyChars ? '${s.substring(0, _maxBodyChars)}… (truncated, ${s.length} chars total)' : s;
}
