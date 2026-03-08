import 'package:dio/dio.dart';

import '../odoo_exception.dart';
import '../../utils/odoo_parsing_utils.dart';
import 'odoo_http_client.dart';

/// Odoo CRUD operations via JSON-2 API
///
/// Provides typed methods for:
/// - search_read: Query with domain filtering
/// - search_count: Count records
/// - read: Fetch by IDs
/// - write: Update records
/// - create: Create new records
/// - unlink: Delete records
/// - call: Generic method invocation
class OdooCrudApi {
  final OdooHttpClient _httpClient;

  OdooCrudApi({required OdooHttpClient httpClient}) : _httpClient = httpClient;

  /// Default context to include in all API calls (e.g., language).
  ///
  /// This is merged with any context provided in individual calls.
  /// The language is taken from `OdooClientConfig.defaultLanguage`.
  Map<String, dynamic> get _defaultContext => {
        'lang': _httpClient.config.defaultLanguage,
      };

  /// Generic Odoo method call
  ///
  /// For methods that operate on recordsets (like action_session_open), use 'ids' parameter.
  /// For methods with positional arguments, use 'args' parameter.
  /// The default context (with lang from config) is automatically added to all calls.
  ///
  /// Pass a [cancelToken] to allow cancelling long-running operations.
  ///
  /// Throws [OdooException] if:
  /// - HTTP error occurs (non-200 response)
  /// - Odoo returns an error in the response body
  ///
  /// Odoo 19 JSON2 API: parameters go directly in body, NOT wrapped in "kwargs"
  /// See: https://www.odoo.com/documentation/19.0/developer/reference/external_api.html
  /// Example: POST /json/2/res.partner/search_read with body {"domain": [], "fields": ["name"]}
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    CancelToken? cancelToken,
  }) async {
    // Odoo 19 JSON2 API: parameters go directly in body
    final Map<String, dynamic> body = {};

    // Args go directly in body (for positional arguments)
    if (args != null) body['args'] = args;

    // Kwargs are spread directly into body (NOT wrapped in "kwargs" key)
    if (kwargs != null) body.addAll(kwargs);

    // IDs go as a top-level parameter for action methods
    if (ids != null) body['ids'] = ids;

    // Merge default context with any provided context
    final existingContext = body['context'] as Map<String, dynamic>? ?? {};
    body['context'] = {..._defaultContext, ...existingContext};

    try {
      final response = await _httpClient.postJson2(
        '/$model/$method',
        data: body,
        cancelToken: cancelToken,
      );
      final data = response.data;

      // Check for error in response body (Odoo validation errors, warnings, etc.)
      if (data is Map<String, dynamic>) {
        // Check for JSON-RPC style error
        if (data.containsKey('error')) {
          final error = data['error'];
          String message = 'Error desconocido';
          String? technicalDetails;

          if (error is Map<String, dynamic>) {
            // Extract message from error object
            message = error['message']?.toString() ??
                error['data']?['message']?.toString() ??
                'Error en la operación';
            technicalDetails = error['data']?['debug']?.toString();
          } else if (error is String) {
            message = error;
          }

          throw OdooException(
            message: message,
            model: model,
            method: method,
            technicalDetails: technicalDetails,
          );
        }

        // Check for message key (some Odoo responses use this for warnings)
        if (data.containsKey('message') && data['message'] is String) {
          final message = data['message'] as String;
          // If the response also has a 'result' or 'success' key, it might be a success with message
          if (!data.containsKey('result') && !data.containsKey('success')) {
            // This looks like an error/warning response
            throw OdooException(
              message: message,
              model: model,
              method: method,
            );
          }
        }
      }

      return data;
    } on DioException catch (e) {
      // Extract error message from Dio exception
      String message = 'Error de conexión';
      String? technicalDetails;

      if (e.response?.data is Map<String, dynamic>) {
        final data = e.response!.data as Map<String, dynamic>;
        // Try to get message from various error formats
        message = data['message']?.toString() ??
            data['error']?['message']?.toString() ??
            data['error']?.toString() ??
            e.message ??
            'Error de conexión';
        technicalDetails = data['error']?['data']?['debug']?.toString();
      } else if (e.response?.data is String) {
        message = e.response!.data as String;
      } else {
        message = e.message ?? 'Error de conexión';
      }

      final statusCode = e.response?.statusCode ?? 0;

      // Throw specific exception subclasses based on HTTP status code
      switch (statusCode) {
        case 401:
          throw OdooAuthenticationException(message);
        case 403:
          throw OdooAccessDeniedException(message);
        case 404:
          throw OdooNotFoundException(message);
        case 400:
          throw OdooBadRequestException(message);
        case 500:
          throw OdooServerException(message);
        default:
          throw OdooException(
            message: message,
            statusCode: statusCode,
            model: model,
            method: method,
            technicalDetails: technicalDetails,
          );
      }
    }
  }

  /// Search and read records matching a domain.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
    CancelToken? cancelToken,
  }) async {
    final response = await call(
      model: model,
      method: 'search_read',
      kwargs: {
        'domain': domain ?? [],
        'fields': fields,
        'limit': ?limit,
        'offset': ?offset,
        'order': ?order,
      },
      cancelToken: cancelToken,
    );

    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    }
    return [];
  }

  /// Count records matching a domain.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<int?> searchCount({
    required String model,
    List<dynamic>? domain,
    CancelToken? cancelToken,
  }) async {
    final response = await call(
      model: model,
      method: 'search_count',
      kwargs: {'domain': domain ?? []},
      cancelToken: cancelToken,
    );

    return response is int ? response : null;
  }

  /// Get records modified since a timestamp (for incremental sync).
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<List<Map<String, dynamic>>> getModifiedSince({
    required String model,
    required List<String> fields,
    required DateTime lastSync,
    List<dynamic>? additionalDomain,
    CancelToken? cancelToken,
  }) async {
    final domain = [
      ['write_date', '>', formatOdooDateTime(lastSync)!],
      if (additionalDomain != null) ...additionalDomain,
    ];

    return searchRead(
      model: model,
      fields: [...fields, 'write_date'],
      domain: domain,
      cancelToken: cancelToken,
    );
  }

  /// Read specific records by IDs.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<List<Map<String, dynamic>>> read({
    required String model,
    required List<int> ids,
    required List<String> fields,
    CancelToken? cancelToken,
  }) async {
    final response = await call(
      model: model,
      method: 'read',
      kwargs: {'ids': ids, 'fields': fields},
      cancelToken: cancelToken,
    );

    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    }
    return [];
  }

  /// Update existing records.
  ///
  /// JSON-2 API format: POST `/json/2/<model>/write`
  /// Body: {"ids": [1,2,3], "vals": {"field1": "value1", ...}}
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<bool> write({
    required String model,
    required List<int> ids,
    required Map<String, dynamic> values,
    CancelToken? cancelToken,
  }) async {
    final cleanValues = _prepareValues(values);

    final response = await call(
      model: model,
      method: 'write',
      kwargs: {'ids': ids, 'vals': cleanValues},
      cancelToken: cancelToken,
    );

    return response == true;
  }

  /// Create a new record.
  ///
  /// In Odoo 19+, create expects 'vals_list' (list of dicts) not 'vals'.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<int?> create({
    required String model,
    required Map<String, dynamic> values,
    CancelToken? cancelToken,
  }) async {
    final cleanValues = _prepareValues(values);

    final response = await call(
      model: model,
      method: 'create',
      kwargs: {
        'vals_list': [cleanValues],
      },
      cancelToken: cancelToken,
    );

    // Response is always a list of IDs: [123]
    if (response is List && response.isNotEmpty) {
      final firstId = response[0];
      return firstId is int ? firstId : null;
    }
    // Fallback for older Odoo versions that return int directly
    if (response is int) return response;

    return null;
  }

  /// Delete records.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<bool> unlink({
    required String model,
    required List<int> ids,
    CancelToken? cancelToken,
  }) async {
    final response = await call(
      model: model,
      method: 'unlink',
      kwargs: {'ids': ids},
      cancelToken: cancelToken,
    );

    return response == true;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BATCH OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create multiple records in a single API call.
  ///
  /// This is more efficient than calling create() multiple times as it uses
  /// a single HTTP request. Returns a list of created IDs in the same order
  /// as the input values.
  ///
  /// Example:
  /// ```dart
  /// final ids = await crudApi.createBatch(
  ///   model: 'res.partner',
  ///   valuesList: [
  ///     {'name': 'Partner A'},
  ///     {'name': 'Partner B'},
  ///   ],
  /// );
  /// // ids = [101, 102]
  /// ```
  Future<List<int>> createBatch({
    required String model,
    required List<Map<String, dynamic>> valuesList,
  }) async {
    if (valuesList.isEmpty) return [];

    final cleanValuesList = valuesList.map(_prepareValues).toList();

    final response = await call(
      model: model,
      method: 'create',
      kwargs: {
        'vals_list': cleanValuesList,
      },
    );

    // Response is a list of IDs: [123, 124, 125]
    if (response is List) {
      return List<int>.from(response.whereType<int>());
    }

    return [];
  }

  /// Update multiple records with different values in batch.
  ///
  /// Each update is a map containing 'ids' and 'values' keys.
  /// Updates are executed in parallel for better performance.
  ///
  /// Example:
  /// ```dart
  /// final results = await crudApi.updateBatch(
  ///   model: 'res.partner',
  ///   updates: [
  ///     {'ids': [1, 2], 'values': {'active': true}},
  ///     {'ids': [3], 'values': {'name': 'New Name'}},
  ///   ],
  /// );
  /// ```
  ///
  /// Returns a list of booleans indicating success for each update.
  Future<List<bool>> updateBatch({
    required String model,
    required List<BatchUpdate> updates,
  }) async {
    if (updates.isEmpty) return [];

    // Execute all updates in parallel for better performance
    final futures = updates.map((update) async {
      try {
        return await write(
          model: model,
          ids: update.ids,
          values: update.values,
        );
      } catch (_) {
        return false;
      }
    });

    return Future.wait(futures);
  }

  /// Delete multiple records in a single call.
  ///
  /// This is a convenience wrapper around unlink() that provides batch semantics.
  /// All IDs are deleted in a single HTTP request.
  ///
  /// Example:
  /// ```dart
  /// final success = await crudApi.deleteBatch(
  ///   model: 'res.partner',
  ///   ids: [1, 2, 3],
  /// );
  /// ```
  Future<bool> deleteBatch({
    required String model,
    required List<int> ids,
  }) async {
    if (ids.isEmpty) return true;
    return unlink(model: model, ids: ids);
  }

  /// Execute multiple operations of different types in batch.
  ///
  /// This method allows mixing creates, updates, and deletes in a single
  /// logical operation. Operations are executed in order:
  /// 1. Creates (to allow referencing new records)
  /// 2. Updates
  /// 3. Deletes
  ///
  /// Returns a [BatchResult] containing the results of all operations.
  Future<BatchResult> executeBatch({
    required String model,
    List<Map<String, dynamic>> creates = const [],
    List<BatchUpdate> updates = const [],
    List<int> deletes = const [],
  }) async {
    final createdIds = <int>[];
    final updateResults = <bool>[];
    var deleteSuccess = true;
    final errors = <String>[];

    // 1. Creates
    if (creates.isNotEmpty) {
      try {
        createdIds.addAll(await createBatch(model: model, valuesList: creates));
      } catch (e) {
        errors.add('Create batch failed: $e');
      }
    }

    // 2. Updates
    if (updates.isNotEmpty) {
      try {
        updateResults.addAll(await updateBatch(model: model, updates: updates));
      } catch (e) {
        errors.add('Update batch failed: $e');
      }
    }

    // 3. Deletes
    if (deletes.isNotEmpty) {
      try {
        deleteSuccess = await deleteBatch(model: model, ids: deletes);
      } catch (e) {
        errors.add('Delete batch failed: $e');
        deleteSuccess = false;
      }
    }

    return BatchResult(
      createdIds: createdIds,
      updateResults: updateResults,
      deleteSuccess: deleteSuccess,
      errors: errors,
    );
  }

  /// Get field metadata for a model.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<Map<String, dynamic>> fieldsGet({
    required String model,
    List<String>? fields,
    List<String>? attributes,
    CancelToken? cancelToken,
  }) async {
    final response = await call(
      model: model,
      method: 'fields_get',
      kwargs: {
        'allfields': ?fields,
        'attributes': attributes ?? ['type', 'string', 'selection', 'relation'],
      },
      cancelToken: cancelToken,
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return {};
  }

  /// Prepare values for Odoo write/create
  ///
  /// Handles:
  /// - DateTime → Odoo format
  /// - Map with 'id' → extract ID
  /// - Null filtering
  Map<String, dynamic> _prepareValues(Map<String, dynamic> values) {
    final result = <String, dynamic>{};

    for (final entry in values.entries) {
      final value = entry.value;
      if (value == null) continue;

      if (value is DateTime) {
        result[entry.key] = formatOdooDateTime(value)!;
      } else if (value is Map && value.containsKey('id')) {
        result[entry.key] = value['id'];
      } else {
        result[entry.key] = value;
      }
    }

    return result;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BATCH OPERATION TYPES
// ═══════════════════════════════════════════════════════════════════════════

/// Represents a batch update operation.
///
/// Contains the IDs to update and the values to set on them.
class BatchUpdate {
  /// The IDs of records to update.
  final List<int> ids;

  /// The values to set on the records.
  final Map<String, dynamic> values;

  const BatchUpdate({
    required this.ids,
    required this.values,
  });

  /// Create from a map (convenience factory).
  factory BatchUpdate.fromMap(Map<String, dynamic> map) {
    return BatchUpdate(
      ids: List<int>.from(map['ids'] as List),
      values: Map<String, dynamic>.from(map['values'] as Map),
    );
  }

  /// Convert to map representation.
  Map<String, dynamic> toMap() => {
        'ids': ids,
        'values': values,
      };
}

/// Result of a batch operation.
///
/// Contains results from creates, updates, and deletes executed in batch.
class BatchResult {
  /// IDs of newly created records.
  final List<int> createdIds;

  /// Success status for each update operation.
  final List<bool> updateResults;

  /// Whether all deletes succeeded.
  final bool deleteSuccess;

  /// Any errors that occurred during batch execution.
  final List<String> errors;

  const BatchResult({
    this.createdIds = const [],
    this.updateResults = const [],
    this.deleteSuccess = true,
    this.errors = const [],
  });

  /// Whether all operations succeeded without errors.
  bool get success =>
      errors.isEmpty &&
      deleteSuccess &&
      updateResults.every((r) => r);

  /// Whether any operations failed.
  bool get hasErrors => errors.isNotEmpty;

  /// Number of records created.
  int get createCount => createdIds.length;

  /// Number of updates that succeeded.
  int get updateSuccessCount => updateResults.where((r) => r).length;

  /// Number of updates that failed.
  int get updateFailureCount => updateResults.where((r) => !r).length;

  @override
  String toString() => 'BatchResult('
      'created: $createCount, '
      'updates: ${updateResults.length} ($updateSuccessCount ok), '
      'delete: $deleteSuccess, '
      'errors: ${errors.length})';
}
