/// Odoo Model Manager Exception Hierarchy
///
/// Provides specific exception types for model manager operations.
/// These extend the core OdooException from odoo_exception.dart.
library;

import '../api/odoo_exception.dart';

/// Base exception for model manager operations.
class OdooModelException extends OdooException {
  OdooModelException(
    String message, {
    String? code,
    String? details,
  }) : super(
          message: message,
          technicalDetails: details,
          data: code != null ? {'code': code} : null,
        );
}

/// Exception thrown when a manager is accessed before initialization.
class OdooManagerNotInitializedException extends OdooModelException {
  /// The type name of the uninitialized manager.
  final String managerType;

  OdooManagerNotInitializedException(this.managerType)
      : super(
          'Manager $managerType not initialized. '
          'Call initialize() before using the manager.',
          code: 'MANAGER_NOT_INITIALIZED',
        );
}

/// Exception thrown when a batch operation fails.
class OdooBatchOperationException extends OdooModelException {
  /// IDs that failed during the batch operation.
  final List<int> failedIds;

  /// The operation that failed (create, update, delete).
  final String operation;

  OdooBatchOperationException(
    this.failedIds,
    this.operation, {
    String? details,
  }) : super(
          'Batch $operation failed for ${failedIds.length} record(s)',
          code: 'BATCH_OPERATION_FAILED',
          details: details,
        );
}

/// Exception thrown for cache-related errors.
class OdooCacheException extends OdooModelException {
  OdooCacheException(
    String message, {
    String code = 'CACHE_ERROR',
    String? details,
  }) : super(message, code: code, details: details);

  /// Creates exception for cache capacity exceeded.
  factory OdooCacheException.capacityExceeded(int maxSize) {
    return OdooCacheException(
      'Cache capacity exceeded (max: $maxSize)',
      code: 'CACHE_CAPACITY_EXCEEDED',
    );
  }

  /// Creates exception for invalid cache configuration.
  factory OdooCacheException.invalidConfig(String reason) {
    return OdooCacheException(
      'Invalid cache configuration: $reason',
      code: 'CACHE_INVALID_CONFIG',
    );
  }
}

/// Exception thrown when sync operations fail.
class OdooSyncException extends OdooModelException {
  /// The model being synced when the error occurred.
  final String? syncModel;

  /// The phase of sync that failed.
  final String? phase;

  OdooSyncException(
    String message, {
    this.syncModel,
    this.phase,
    String code = 'SYNC_ERROR',
    String? details,
  }) : super(message, code: code, details: details);

  /// Creates exception for sync already in progress.
  factory OdooSyncException.alreadyInProgress(String model) {
    return OdooSyncException(
      'Sync already in progress for $model',
      syncModel: model,
      code: 'SYNC_ALREADY_IN_PROGRESS',
    );
  }

  /// Creates exception for sync cancelled.
  factory OdooSyncException.cancelled(String model) {
    return OdooSyncException(
      'Sync cancelled for $model',
      syncModel: model,
      code: 'SYNC_CANCELLED',
    );
  }
}

/// Exception thrown for record-level validation errors.
///
/// This complements [ValidationException] from odoo_record.dart with
/// additional context for manager operations.
class OdooRecordValidationException extends OdooModelException {
  /// The record ID that failed validation.
  final int? recordId;

  /// Field-level validation errors.
  final Map<String, String> fieldErrors;

  OdooRecordValidationException(
    this.fieldErrors, {
    this.recordId,
    String? details,
  }) : super(
          'Validation failed: ${fieldErrors.values.join(', ')}',
          code: 'RECORD_VALIDATION_FAILED',
          details: details,
        );
}

/// Exception thrown when a record cannot be found.
class OdooRecordNotFoundLocalException extends OdooModelException {
  /// The ID of the record that was not found.
  final int recordId;

  /// The model name.
  final String recordModel;

  OdooRecordNotFoundLocalException(this.recordId, this.recordModel)
      : super(
          'Record with ID $recordId not found in local database for $recordModel',
          code: 'RECORD_NOT_FOUND_LOCAL',
        );
}
