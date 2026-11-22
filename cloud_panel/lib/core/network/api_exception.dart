import 'package:dio/dio.dart';

/// A failed API call, already turned into something a person can read.
/// [fieldErrors] carries Laravel's 422 `errors` map so forms can show the
/// message under the matching field.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidation => statusCode == 422;

  String? errorFor(String field) => fieldErrors[field];

  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    if (response == null) {
      final offline = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout;
      return ApiException(
        offline
            ? 'Can\'t reach the server. Please check your internet connection and try again.'
            : 'Something went wrong. Please try again.',
      );
    }

    final code = response.statusCode;
    final data = response.data;
    final fields = <String, String>{};
    String? message;

    if (data is Map) {
      message = data['message']?.toString();
      final errors = data['errors'];
      if (errors is Map) {
        errors.forEach((key, value) {
          if (value is List && value.isNotEmpty) {
            fields[key.toString()] = value.first.toString();
          } else if (value != null) {
            fields[key.toString()] = value.toString();
          }
        });
      }
    }

    message ??= switch (code) {
      401 => 'Your session has expired. Please sign in again.',
      403 => 'You do not have access to this section.',
      404 => 'We couldn\'t find that record.',
      429 => 'Too many attempts. Please wait a moment and try again.',
      int c when c >= 500 => 'The server had a problem. Please try again in a moment.',
      _ => 'Something went wrong. Please try again.',
    };
    if (code == 401 && message == 'Unauthenticated.') {
      message = 'Your session has expired. Please sign in again.';
    }

    return ApiException(message, statusCode: code, fieldErrors: fields);
  }

  @override
  String toString() => message;
}
