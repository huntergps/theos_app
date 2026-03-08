/// Base exception class for the application.
///
/// Use [AppException] subclasses to throw typed exceptions that can be
/// caught and converted to [Failure] objects for the domain layer.
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalException;

  const AppException({
    required this.message,
    this.code,
    this.originalException,
  });

  @override
  String toString() => 'AppException($code): $message';
}

/// Server-side exceptions (API errors).
class ServerException extends AppException {
  final int? statusCode;

  const ServerException({
    required super.message,
    super.code,
    super.originalException,
    this.statusCode,
  });

  factory ServerException.fromResponse(int statusCode, String body) {
    return ServerException(
      message: body,
      statusCode: statusCode,
      code: 'HTTP_$statusCode',
    );
  }
}

/// Network exceptions.
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'No network connection',
    super.code = 'NETWORK_ERROR',
    super.originalException,
  });
}

/// Cache/database exceptions.
class CacheException extends AppException {
  const CacheException({
    required super.message,
    super.code = 'CACHE_ERROR',
    super.originalException,
  });
}

/// Authentication exceptions.
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code = 'AUTH_ERROR',
    super.originalException,
  });

  factory AuthException.invalidCredentials() => const AuthException(
    message: 'Invalid credentials',
    code: 'INVALID_CREDENTIALS',
  );

  factory AuthException.sessionExpired() => const AuthException(
    message: 'Session expired',
    code: 'SESSION_EXPIRED',
  );
}

/// Validation exceptions.
class AppValidationException extends AppException {
  final Map<String, List<String>>? fieldErrors;

  const AppValidationException({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    super.originalException,
    this.fieldErrors,
  });
}

/// Not found exceptions.
class NotFoundException extends AppException {
  final String? entityType;
  final dynamic entityId;

  const NotFoundException({
    required super.message,
    super.code = 'NOT_FOUND',
    super.originalException,
    this.entityType,
    this.entityId,
  });

  factory NotFoundException.entity(String type, dynamic id) =>
      NotFoundException(
        message: '$type with ID $id not found',
        entityType: type,
        entityId: id,
      );
}

/// Sync exceptions for offline-first operations.
class SyncException extends AppException {
  final int? retryCount;

  const SyncException({
    required super.message,
    super.code = 'SYNC_ERROR',
    super.originalException,
    this.retryCount,
  });
}
