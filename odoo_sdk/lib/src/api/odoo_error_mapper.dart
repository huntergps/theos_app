import 'package:dio/dio.dart';

import '../utils/security_utils.dart';
import 'odoo_exception.dart';

/// Converts Odoo JSON-2 and transport failures into the public typed hierarchy.
abstract final class OdooErrorMapper {
  static OdooException fromDio(
    DioException error, {
    String? model,
    String? method,
  }) {
    // Dio 5.10 added transformTimeout. Compare by name so this package keeps
    // compiling with the declared Dio >=5.4 range.
    if (error.type.name == 'transformTimeout') {
      return const OdooTimeoutException();
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const OdooTimeoutException();
      case DioExceptionType.connectionError:
        return OdooConnectionException(
          _sanitizeMessage(error.message, fallback: 'No server connection'),
        );
      case DioExceptionType.cancel:
        return const OdooRequestCancelledException();
      case DioExceptionType.badResponse:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
      default:
        break;
    }

    final response = error.response;
    if (response != null) {
      return fromResponse(
        response.data,
        statusCode: response.statusCode ?? 0,
        model: model,
        method: method,
      );
    }

    return OdooConnectionException(
      _sanitizeMessage(error.message, fallback: 'No server connection'),
    );
  }

  static OdooException fromResponse(
    dynamic payload, {
    int statusCode = 0,
    String? model,
    String? method,
  }) {
    final parsed = OdooException.fromResponse(
      payload,
      statusCode: statusCode,
      model: model,
      method: method,
    );
    final message = _sanitizeMessage(parsed.message);
    final errorData = _sanitizeMap(parsed.data);
    final methodData = _methodData(errorData);
    final signature = [
      message,
      parsed.technicalDetails,
      errorData?['name'],
      methodData?['name'],
      methodData?['exception_type'],
    ].whereType<Object>().join(' ').toLowerCase();

    if (_isExpiredSession(statusCode, signature)) {
      return OdooSessionExpiredException(
        message,
        statusCode > 0 ? statusCode : 403,
      );
    }
    if (statusCode == 401) {
      return OdooAuthenticationException(message);
    }
    if (statusCode == 403 || _containsType(signature, 'accesserror')) {
      return OdooAccessDeniedException(message);
    }

    final missingField = _missingField(signature);
    if (missingField != null) {
      return OdooFieldNotFoundException(
        targetModel: model ?? 'unknown.model',
        fieldName: missingField,
        method: method,
        message: message,
        statusCode: statusCode > 0 ? statusCode : 422,
      );
    }

    if (_isMissingMethod(statusCode, signature)) {
      return OdooMethodNotFoundException(
        targetModel: model ?? 'unknown.model',
        methodName: method ?? _missingMethod(signature) ?? 'unknown_method',
        message: message,
        statusCode: statusCode > 0 ? statusCode : 404,
      );
    }

    if (statusCode == 422 ||
        _containsType(signature, 'validationerror') ||
        _containsType(signature, 'usererror')) {
      return OdooValidationException(
        message,
        methodData ?? errorData,
        statusCode > 0 ? statusCode : 422,
      );
    }
    if (statusCode == 400) {
      return OdooBadRequestException(message, errorData);
    }
    if (statusCode == 404) {
      return OdooNotFoundException(message);
    }
    if (statusCode >= 500) {
      return OdooServerException(message, errorData, statusCode);
    }

    return OdooException(
      message: message,
      statusCode: statusCode,
      model: model,
      method: method,
      data: errorData,
      technicalDetails: parsed.technicalDetails == null
          ? null
          : ErrorSanitizer.sanitize(parsed.technicalDetails!),
    );
  }

  static bool _isExpiredSession(int statusCode, String signature) {
    if (signature.contains('sessionexpiredexception') ||
        signature.contains('checkidentityexception')) {
      return true;
    }
    if (statusCode != 401 && statusCode != 403) return false;
    return signature.contains('session expired') ||
        signature.contains('expired session') ||
        signature.contains('session is not valid') ||
        signature.contains('invalid session');
  }

  static bool _isMissingMethod(int statusCode, String signature) {
    final mentionsMethod =
        signature.contains('method') || signature.contains('attributeerror');
    final unavailable =
        signature.contains('does not exist') ||
        signature.contains('not found') ||
        signature.contains('has no attribute') ||
        signature.contains('unknown method');
    return mentionsMethod &&
        unavailable &&
        (statusCode == 404 || statusCode == 422);
  }

  static String? _missingField(String signature) {
    final match = RegExp(
      r'''(?:invalid|unknown)\s+field\s+['"]?([^'"\s]+)''',
      caseSensitive: false,
    ).firstMatch(signature);
    if (match != null) return _fieldLeaf(match.group(1));

    final absent = RegExp(
      r'''field\s+['"]?([^'"\s]+)['"]?\s+does not exist''',
      caseSensitive: false,
    ).firstMatch(signature);
    return _fieldLeaf(absent?.group(1));
  }

  static String? _fieldLeaf(String? qualifiedField) {
    if (qualifiedField == null) return null;
    return qualifiedField.split('.').last;
  }

  static String? _missingMethod(String signature) {
    return RegExp(
      r'''method\s+['"]?([^'"\s]+)''',
      caseSensitive: false,
    ).firstMatch(signature)?.group(1);
  }

  static bool _containsType(String signature, String type) {
    return signature.replaceAll('_', '').contains(type);
  }

  static Map<String, dynamic>? _methodData(Map<String, dynamic>? errorData) {
    final value = errorData?['data'];
    return value is Map<String, dynamic> ? value : null;
  }

  static String _sanitizeMessage(
    String? value, {
    String fallback = 'Odoo error',
  }) {
    return ErrorSanitizer.sanitize(
      value?.trim().isNotEmpty == true ? value! : fallback,
    );
  }

  static Map<String, dynamic>? _sanitizeMap(Map<String, dynamic>? value) {
    if (value == null) return null;
    return value.map((key, item) => MapEntry(key, _sanitizeValue(key, item)));
  }

  static dynamic _sanitizeValue(String key, dynamic value) {
    final normalizedKey = key.toLowerCase().replaceAll('-', '_');
    const sensitiveFragments = {
      'api_key',
      'apikey',
      'authorization',
      'cookie',
      'credential',
      'password',
      'private_key',
      'secret',
      'session_id',
      'token',
    };
    if (sensitiveFragments.any(normalizedKey.contains)) {
      return ErrorSanitizer.redactedPlaceholder;
    }
    if (value is String) return ErrorSanitizer.sanitize(value);
    if (value is Map) {
      return value.map<String, dynamic>(
        (nestedKey, nestedValue) => MapEntry(
          nestedKey.toString(),
          _sanitizeValue(nestedKey.toString(), nestedValue),
        ),
      );
    }
    if (value is List) {
      return value.map((item) => _sanitizeValue(key, item)).toList();
    }
    return value;
  }
}
