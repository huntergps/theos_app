/// Base failure class for Clean Architecture error handling.
///
/// Use [Failure] subclasses to represent domain-level errors that can be
/// handled by the UI layer. This separates error handling from exceptions.
///
/// Example:
/// ```dart
/// Future<Result<User>> getUser(int id) async {
///   try {
///     final user = await api.fetchUser(id);
///     return Ok(user);
///   } on SocketException {
///     return Err(NetworkFailure());
///   }
/// }
/// ```
abstract class Failure {
  final String message;
  final String? code;
  final dynamic originalError;

  const Failure({required this.message, this.code, this.originalError});

  @override
  String toString() => 'Failure($code): $message';
}

/// Server-side failures (API errors, HTTP errors).
class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure({
    required super.message,
    super.code,
    super.originalError,
    this.statusCode,
  });

  factory ServerFailure.fromException(dynamic e) {
    return ServerFailure(message: e.toString(), originalError: e);
  }
}

/// Network-related failures (no connection, timeout).
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No network connection',
    super.code = 'NETWORK_ERROR',
    super.originalError,
  });
}

/// Cache/local database failures.
class CacheFailure extends Failure {
  const CacheFailure({
    required super.message,
    super.code = 'CACHE_ERROR',
    super.originalError,
  });
}

/// Authentication failures.
class AuthFailure extends Failure {
  const AuthFailure({
    required super.message,
    super.code = 'AUTH_ERROR',
    super.originalError,
  });

  factory AuthFailure.invalidCredentials() => const AuthFailure(
    message: 'Invalid credentials',
    code: 'INVALID_CREDENTIALS',
  );

  factory AuthFailure.sessionExpired() => const AuthFailure(
    message: 'Session expired',
    code: 'SESSION_EXPIRED',
  );

  factory AuthFailure.unauthorized() =>
      const AuthFailure(message: 'Unauthorized', code: 'UNAUTHORIZED');
}

/// Validation failures with optional field-level errors.
class ValidationFailure extends Failure {
  final Map<String, List<String>>? fieldErrors;

  const ValidationFailure({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    super.originalError,
    this.fieldErrors,
  });
}

/// Not found failures.
class NotFoundFailure extends Failure {
  final String? entityType;
  final dynamic entityId;

  const NotFoundFailure({
    required super.message,
    super.code = 'NOT_FOUND',
    super.originalError,
    this.entityType,
    this.entityId,
  });

  factory NotFoundFailure.entity(String type, dynamic id) => NotFoundFailure(
    message: '$type with ID $id not found',
    entityType: type,
    entityId: id,
  );
}

/// Sync failures for offline-first operations.
class SyncFailure extends Failure {
  final int? retryCount;
  final DateTime? lastAttempt;

  const SyncFailure({
    required super.message,
    super.code = 'SYNC_ERROR',
    super.originalError,
    this.retryCount,
    this.lastAttempt,
  });

  factory SyncFailure.maxRetriesExceeded(int maxRetries) => SyncFailure(
    message: 'Max retries exceeded ($maxRetries)',
    code: 'MAX_RETRIES_EXCEEDED',
    retryCount: maxRetries,
  );
}

/// Offline operation failures.
class OfflineFailure extends Failure {
  final bool isQueued;
  final int? queuePosition;

  const OfflineFailure({
    required super.message,
    super.code = 'OFFLINE_ERROR',
    super.originalError,
    this.isQueued = false,
    this.queuePosition,
  });

  factory OfflineFailure.noConnection() => const OfflineFailure(
    message: 'No connection. Operation will be processed when back online.',
    code: 'NO_CONNECTION',
    isQueued: true,
  );

  factory OfflineFailure.queueFull() => const OfflineFailure(
    message: 'Offline operation queue is full',
    code: 'QUEUE_FULL',
  );

  factory OfflineFailure.conflictDetected(String details) => OfflineFailure(
    message: 'Conflict detected: $details',
    code: 'CONFLICT_DETECTED',
  );
}
