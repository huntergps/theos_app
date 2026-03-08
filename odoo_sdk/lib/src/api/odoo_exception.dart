/// Odoo-specific exceptions for error handling.
///
/// These exceptions provide detailed information about errors
/// that occur when communicating with Odoo servers.
library;

import '../errors/failures.dart';
import '../utils/security_utils.dart';

// ============================================================================
// BASE EXCEPTION
// ============================================================================

/// Base exception for all Odoo-related errors.
///
/// Used for global error handling across all Odoo operations.
/// Contains the error message from Odoo which can be displayed to users.
class OdooException implements Exception {
  /// The user-friendly error message from Odoo
  final String message;

  /// HTTP status code if available (0 if not applicable)
  final int statusCode;

  /// The model where the error occurred
  final String? model;

  /// The method that was called
  final String? method;

  /// Additional error data from the server
  final Map<String, dynamic>? data;

  /// Technical error details (for debugging)
  final String? technicalDetails;

  const OdooException({
    required this.message,
    this.statusCode = 0,
    this.model,
    this.method,
    this.data,
    this.technicalDetails,
  });

  /// Alternate constructor for quick creation
  const OdooException.simple(int statusCode, String message, [Map<String, dynamic>? data])
      : this(message: message, statusCode: statusCode, data: data);

  @override
  String toString() {
    final buffer = StringBuffer('OdooException: $message');
    if (statusCode > 0) buffer.write(' (HTTP $statusCode)');
    if (model != null && method != null) buffer.write(' [$model.$method]');
    if (data != null) buffer.write('\nData: ${_sanitizeData(data!)}');
    return buffer.toString();
  }

  /// Sanitize exception data to prevent credential leaks in logs/stack traces.
  static String _sanitizeData(Map<String, dynamic> data) {
    return CredentialMasker.maskMap(data);
  }

  /// Create from Odoo error response data
  ///
  /// Odoo JSON2 API returns errors in format:
  /// {"error": {"code": 422, "message": "..."}} or
  /// {"message": "..."} or
  /// {"description": "..."} or just a string
  factory OdooException.fromResponse(
    dynamic data, {
    int? statusCode,
    String? model,
    String? method,
  }) {
    String message = 'Unknown Odoo error';
    String? technicalDetails;
    Map<String, dynamic>? errorData;

    if (data == null) {
      return OdooException(
        message: message,
        statusCode: statusCode ?? 0,
        model: model,
        method: method,
      );
    }

    // Handle different error formats from Odoo
    if (data is String) {
      message = data;
    } else if (data is Map) {
      // Check for nested error structure
      final errorObj = data['error'] ?? data;

      if (errorObj is Map) {
        errorData = Map<String, dynamic>.from(errorObj);

        // Try different message fields
        message = errorObj['message']?.toString() ??
            errorObj['description']?.toString() ??
            errorObj['data']?['message']?.toString() ??
            errorObj['name']?.toString() ??
            message;

        // Capture technical details if available
        if (errorObj['data'] is Map) {
          final dataMap = errorObj['data'] as Map;
          technicalDetails = dataMap['debug']?.toString() ??
              dataMap['exception_type']?.toString();
        }
      } else if (errorObj is String) {
        message = errorObj;
      }
    }

    return OdooException(
      message: message,
      statusCode: statusCode ?? 0,
      model: model,
      method: method,
      data: errorData,
      technicalDetails: technicalDetails,
    );
  }
}

// ============================================================================
// HTTP STATUS EXCEPTIONS
// ============================================================================

/// Exception for HTTP 400 Bad Request errors.
///
/// Indicates malformed request syntax or invalid parameters.
class OdooBadRequestException extends OdooException {
  const OdooBadRequestException(String message, [Map<String, dynamic>? data])
      : super(message: message, statusCode: 400, data: data);
}

/// Exception for HTTP 401 Unauthorized errors.
///
/// Indicates invalid or missing authentication credentials.
class OdooAuthenticationException extends OdooException {
  const OdooAuthenticationException(String message)
      : super(message: message, statusCode: 401);
}

/// Exception for HTTP 403 Forbidden errors.
///
/// Indicates the user lacks permission for the requested operation.
class OdooAccessDeniedException extends OdooException {
  const OdooAccessDeniedException(String message)
      : super(message: message, statusCode: 403);
}

/// Exception for HTTP 404 Not Found errors.
///
/// Indicates the requested resource (model, record, method) doesn't exist.
class OdooNotFoundException extends OdooException {
  const OdooNotFoundException(String message)
      : super(message: message, statusCode: 404);
}

/// Exception for HTTP 500 Server errors.
///
/// Indicates an unhandled error on the Odoo server.
class OdooServerException extends OdooException {
  const OdooServerException(String message, [Map<String, dynamic>? data])
      : super(message: message, statusCode: 500, data: data);
}

// ============================================================================
// VALIDATION EXCEPTIONS
// ============================================================================

/// Exception for validation errors (HTTP 500 with validation_error type).
///
/// Indicates the data provided failed server-side validation.
class OdooValidationException extends OdooException {
  /// Field-specific validation errors.
  final Map<String, List<String>>? fieldErrors;

  OdooValidationException(String message, [Map<String, dynamic>? data])
      : fieldErrors = _extractFieldErrors(data),
        super(message: message, statusCode: 400, data: data);

  static Map<String, List<String>>? _extractFieldErrors(
      Map<String, dynamic>? data) {
    if (data == null) return null;
    final errors = data['field_errors'];
    if (errors is! Map) return null;

    return errors.map((key, value) {
      final messages = value is List
          ? value.map((e) => e.toString()).toList()
          : [value.toString()];
      return MapEntry(key.toString(), messages);
    });
  }
}

// ============================================================================
// NETWORK EXCEPTIONS
// ============================================================================

/// Exception for connection timeout.
class OdooTimeoutException extends OdooException {
  const OdooTimeoutException([String message = 'Connection timeout'])
      : super(message: message, statusCode: 0);
}

/// Exception for network connection failures.
class OdooConnectionException extends OdooException {
  const OdooConnectionException([String message = 'No server connection'])
      : super(message: message, statusCode: 0);
}

// ============================================================================
// OFFLINE-FIRST EXCEPTIONS
// ============================================================================

/// Exception for record not found in local database.
class OdooRecordNotFoundException extends OdooException {
  final String recordModel;
  final int recordId;

  OdooRecordNotFoundException(this.recordModel, this.recordId)
      : super(
          message: 'Record $recordModel($recordId) not found locally',
          statusCode: 404,
          model: recordModel,
        );
}

/// Exception for duplicate UUID conflict.
class OdooDuplicateUuidException extends OdooException {
  final String uuid;
  final String conflictModel;

  OdooDuplicateUuidException(this.conflictModel, this.uuid)
      : super(
          message: 'Duplicate UUID $uuid for model $conflictModel',
          statusCode: 409,
          model: conflictModel,
        );
}

/// Exception for sync conflicts.
class OdooSyncConflictException extends OdooException {
  final String conflictModel;
  final int conflictRecordId;
  final DateTime localWriteDate;
  final DateTime serverWriteDate;

  OdooSyncConflictException({
    required this.conflictModel,
    required this.conflictRecordId,
    required this.localWriteDate,
    required this.serverWriteDate,
  }) : super(
          message: 'Sync conflict: $conflictModel($conflictRecordId) '
              'modified locally ($localWriteDate) and on server ($serverWriteDate)',
          statusCode: 409,
          model: conflictModel,
        );
}

/// Exception for offline operation failures.
class OdooOfflineException extends OdooException {
  const OdooOfflineException([String message = 'Operation requires connection'])
      : super(message: message, statusCode: 0);
}

/// Exception for queue processing failures.
class OdooQueueException extends OdooException {
  final int operationId;
  final int retryCount;

  OdooQueueException(this.operationId, this.retryCount, String message)
      : super(message: message, statusCode: 0);
}

// ============================================================================
// BRIDGE: OdooException → Failure
// ============================================================================

/// Extension to convert any OdooException to the appropriate Failure type.
///
/// This bridges the Odoo API exception hierarchy with the Clean Architecture
/// Failure hierarchy, enabling a single error-handling path:
///
/// ```dart
/// try {
///   await client.searchRead(...);
/// } on OdooException catch (e) {
///   return Err(e.toFailure());
/// }
/// ```
extension OdooExceptionToFailure on OdooException {
  Failure toFailure() {
    return switch (this) {
      OdooAuthenticationException() ||
      OdooAccessDeniedException() =>
        AuthFailure(message: message, originalError: this),
      OdooNotFoundException() || OdooRecordNotFoundException() =>
        NotFoundFailure(message: message, originalError: this),
      OdooValidationException(:final fieldErrors) =>
        ValidationFailure(
          message: message,
          fieldErrors: fieldErrors,
          originalError: this,
        ),
      OdooTimeoutException() || OdooConnectionException() =>
        NetworkFailure(message: message, originalError: this),
      OdooOfflineException() =>
        OfflineFailure(message: message, originalError: this),
      OdooSyncConflictException() =>
        SyncFailure(message: message, originalError: this),
      OdooQueueException(:final retryCount) =>
        SyncFailure(
          message: message,
          retryCount: retryCount,
          originalError: this,
        ),
      _ => ServerFailure(
          message: message,
          statusCode: statusCode > 0 ? statusCode : null,
          originalError: this,
        ),
    };
  }
}
