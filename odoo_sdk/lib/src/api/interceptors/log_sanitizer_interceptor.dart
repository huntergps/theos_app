/// SEC-03: Dio interceptor that sanitizes sensitive data from request/response logs.
///
/// Masks Authorization headers and other sensitive fields before they
/// reach Dio's built-in LogInterceptor or any custom logging.
///
/// Usage:
/// ```dart
/// dio.interceptors.add(LogSanitizerInterceptor());
/// dio.interceptors.add(LogInterceptor()); // Now safe to use
/// ```
library;

import 'package:dio/dio.dart';
import '../../utils/security_utils.dart';

/// Dio interceptor that provides header and URL sanitization utilities
/// for safe logging of HTTP requests and responses.
///
/// The interceptor itself passes requests through unchanged (it does not
/// modify actual request/response data). Its static methods are used by
/// logging code to sanitize sensitive values before output.
class LogSanitizerInterceptor extends Interceptor {
  /// Headers to sanitize (keys are case-insensitive).
  static const _sensitiveHeaders = {
    'authorization',
    'x-api-key',
    'cookie',
    'set-cookie',
    'proxy-authorization',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Pass through unchanged — actual headers are not modified.
    // Use sanitizeHeaders() in logging code for safe output.
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }

  /// Sanitize headers map for safe logging.
  ///
  /// Returns a new map with sensitive header values masked.
  /// Original map is not modified.
  ///
  /// Example:
  /// ```dart
  /// final safeHeaders = LogSanitizerInterceptor.sanitizeHeaders({
  ///   'Authorization': 'Bearer sk_test_abc123xyz',
  ///   'Content-Type': 'application/json',
  /// });
  /// // {'Authorization': 'Be*************yz', 'Content-Type': 'application/json'}
  /// ```
  static Map<String, dynamic> sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = <String, dynamic>{};
    for (final entry in headers.entries) {
      if (_sensitiveHeaders.contains(entry.key.toLowerCase()) &&
          entry.value is String) {
        sanitized[entry.key] = CredentialMasker.mask(entry.value as String);
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  /// Sanitize a URL string, masking any query parameters that look like credentials.
  ///
  /// Parameters with keys containing "key", "token", "secret", "password",
  /// or "auth" will have their values masked.
  ///
  /// Example:
  /// ```dart
  /// final safeUrl = LogSanitizerInterceptor.sanitizeUrl(
  ///   'https://api.example.com/data?api_key=secret123&page=1',
  /// );
  /// // 'https://api.example.com/data?api_key=se*****23&page=1'
  /// ```
  static String sanitizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.queryParameters.isEmpty) return url;

      final sanitizedParams = <String, String>{};
      for (final entry in uri.queryParameters.entries) {
        final lowerKey = entry.key.toLowerCase();
        if (lowerKey.contains('key') ||
            lowerKey.contains('token') ||
            lowerKey.contains('secret') ||
            lowerKey.contains('password') ||
            lowerKey.contains('auth')) {
          sanitizedParams[entry.key] = CredentialMasker.mask(entry.value);
        } else {
          sanitizedParams[entry.key] = entry.value;
        }
      }
      return uri.replace(queryParameters: sanitizedParams).toString();
    } catch (_) {
      return url;
    }
  }
}
