/// OdooModelManager - Unified Model Management
///
/// A single object that manages all aspects of an Odoo model:
/// - CRUD operations with offline-first pattern
/// - Automatic sync to/from Odoo
/// - WebSocket event handling
/// - Local database operations via Drift
/// - Conflict detection and resolution
///
/// This is the core class of the odoo_model_manager framework.
///
/// The class is composed of mixins for maintainability:
/// - [_ManagerCacheMixin] - LRU cache management
/// - [_ManagerWatchMixin] - Reactive record observation streams
/// - [_ManagerSyncMixin] - Bidirectional sync with Odoo
/// - [_ManagerActionsMixin] - Odoo workflow action calls
/// - [_ManagerBatchMixin] - Batch CRUD operations
/// - [_ManagerConflictsMixin] - Conflict detection and resolution
library;

import 'dart:async';

import 'package:drift/drift.dart';
import '../api/odoo_client.dart';
import '../sync/sync_models.dart';
import '../sync/sync_types.dart';
import '../utils/value_stream.dart';
import 'package:uuid/uuid.dart';

// Local OfflineQueueWrapper (application-specific implementation)
import '../sync/offline_queue.dart';
import '../utils/record_cache.dart';
import 'conflict_resolution.dart';

// Mixin part files
part 'manager_cache_mixin.dart';
part 'manager_watch_mixin.dart';
part 'manager_sync_mixin.dart';
part 'manager_actions_mixin.dart';
part 'manager_batch_mixin.dart';
part 'manager_conflicts_mixin.dart';

/// Cancellation token for long-running operations.
class CancellationToken {
  bool _isCancelled = false;
  final _controller = StreamController<void>.broadcast();

  bool get isCancelled => _isCancelled;
  Stream<void> get onCancelled => _controller.stream;

  void cancel() {
    _isCancelled = true;
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}

// SyncProgress and SyncPhase are now imported from odoo_offline_core

/// Event types for WebSocket notifications.
enum RecordOperation {
  create,
  write,
  unlink,
}

/// Types of record changes for reactive streams.
enum ChangeType {
  /// Record was created
  create,

  /// Record was updated
  update,

  /// Record was deleted
  delete,

  /// Record was synced from server
  sync,
}

/// Event emitted when a record changes.
class RecordChangeEvent<T> {
  /// Type of change
  final ChangeType type;

  /// ID of the changed record
  final int id;

  /// The changed record (null for deletes)
  final T? record;

  /// When the change occurred
  final DateTime timestamp;

  const RecordChangeEvent({
    required this.type,
    required this.id,
    this.record,
    required this.timestamp,
  });

  @override
  String toString() => 'RecordChangeEvent($type, id: $id)';
}

/// Error that occurred during background sync operations.
///
/// Emitted when background sync fails (e.g., network errors, server errors).
/// Subscribe to [OdooModelManager.backgroundErrors] to handle these errors.
class BackgroundSyncError {
  /// The model that failed to sync
  final String model;

  /// The record ID that failed (null for search operations)
  final int? recordId;

  /// The type of operation that failed
  final BackgroundSyncOperation operation;

  /// The error that occurred
  final Object error;

  /// Stack trace of the error
  final StackTrace? stackTrace;

  /// When the error occurred
  final DateTime timestamp;

  const BackgroundSyncError({
    required this.model,
    this.recordId,
    required this.operation,
    required this.error,
    this.stackTrace,
    required this.timestamp,
  });

  @override
  String toString() =>
      'BackgroundSyncError($model${recordId != null ? ':$recordId' : ''}, $operation: $error)';
}

/// Types of background sync operations.
enum BackgroundSyncOperation {
  /// Syncing a single record by ID
  syncRecord,

  /// Syncing search results
  syncSearch,
}

/// WebSocket event for record changes.
class ModelRecordEvent {
  final String model;
  final int recordId;
  final RecordOperation operation;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  const ModelRecordEvent({
    required this.model,
    required this.recordId,
    required this.operation,
    this.data,
    required this.timestamp,
  });
}

/// Base configuration for model managers.
class ModelManagerConfig {
  /// Batch size for sync operations.
  final int syncBatchSize;

  /// Interval between progress callbacks.
  final int progressInterval;

  /// Whether to sync in background after local operations.
  final bool backgroundSync;

  /// Maximum retries for failed operations.
  final int maxRetries;

  /// Delay between retries in milliseconds.
  final int retryDelayMs;

  /// Configuration for the record cache.
  /// Controls cache size, TTL, and cleanup behavior.
  final RecordCacheConfig cacheConfig;

  const ModelManagerConfig({
    this.syncBatchSize = 100,
    this.progressInterval = 50,
    this.backgroundSync = true,
    this.maxRetries = 3,
    this.retryDelayMs = 1000,
    this.cacheConfig = RecordCacheConfig.defaultConfig,
  });

  /// Configuration with a larger cache for models with many records.
  static const ModelManagerConfig largeModel = ModelManagerConfig(
    cacheConfig: RecordCacheConfig.largeDataset,
  );

  /// Configuration with a smaller, faster cache for frequently accessed models.
  static const ModelManagerConfig frequentAccess = ModelManagerConfig(
    cacheConfig: RecordCacheConfig.smallFrequent,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Base class with shared state - extended by OdooModelManager
// ═══════════════════════════════════════════════════════════════════════════════

/// Internal base class that holds shared state and abstract contracts.
///
/// This is not part of the public API. Use [OdooModelManager] instead.
abstract class _OdooModelManagerBase<T> {
  // ═══════════════════════════════════════════════════════════════════════════
  // Abstract Properties - Must be implemented by generated subclasses
  // ═══════════════════════════════════════════════════════════════════════════

  /// The Odoo model name (e.g., 'product.product').
  String get odooModel;

  /// The local database table name.
  String get tableName;

  /// List of Odoo field names to fetch by default.
  List<String> get odooFields;

  /// Whether the model supports soft delete (active field).
  bool get supportsSoftDelete => true;

  /// Whether to track write_date for incremental sync.
  bool get trackWriteDate => true;

  // ═══════════════════════════════════════════════════════════════════════════
  // Abstract Methods - Must be implemented by generated subclasses
  // ═══════════════════════════════════════════════════════════════════════════

  /// Convert Odoo API response to domain model.
  T fromOdoo(Map<String, dynamic> data);

  /// Convert domain model to Odoo API format.
  Map<String, dynamic> toOdoo(T record);

  /// Convert Drift database row to domain model.
  T fromDrift(dynamic row);

  /// Get the ID from a record.
  int getId(T record);

  /// Get the UUID from a record (for offline-created records).
  String? getUuid(T record);

  /// Create a copy of the record with updated ID and UUID.
  T withIdAndUuid(T record, int id, String uuid);

  /// Create a copy with sync status updated.
  T withSyncStatus(T record, bool isSynced);

  // ═══════════════════════════════════════════════════════════════════════════
  // Local Database Operations - Override in generated subclasses
  // ═══════════════════════════════════════════════════════════════════════════

  /// Read a record from local database by ID.
  Future<T?> readLocal(int id);

  /// Read a record from local database by UUID.
  Future<T?> readLocalByUuid(String uuid);

  /// Search records in local database.
  Future<List<T>> searchLocal({
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? orderBy,
  });

  /// Count records in local database.
  Future<int> countLocal({List<dynamic>? domain});

  /// Insert or update a record in local database.
  Future<void> upsertLocal(T record);

  /// Delete a record from local database.
  Future<void> deleteLocal(int id);

  /// Get all unsynced records.
  Future<List<T>> getUnsyncedRecords();

  /// Get the most recent write_date from local records.
  Future<DateTime?> getLastWriteDate();

  // ═══════════════════════════════════════════════════════════════════════════
  // Reactive Watch - Database-level reactivity via Drift .watch()
  // ═══════════════════════════════════════════════════════════════════════════

  /// Watch a single record by ID using database-level reactivity.
  ///
  /// Returns a stream that automatically re-emits whenever the underlying
  /// row changes in the database — regardless of who made the change
  /// (CRUD, sync, WebSocket, batch operations).
  Stream<T?> watchLocalRecord(int id);

  /// Watch records matching criteria using database-level reactivity.
  ///
  /// Returns a stream that automatically re-emits whenever any matching
  /// row changes in the database.
  Stream<List<T>> watchLocalSearch({
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? orderBy,
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SmartOdooModel Integration - Override in generated subclasses
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get a field value from a record by name.
  dynamic getRecordFieldValue(T record, String fieldName) => null;

  /// Apply WebSocket changes to a record, returning updated copy.
  T applyWebSocketChangesToRecord(T record, Map<String, dynamic> changes) =>
      record;

  /// Dispatch an onchange handler for a field.
  T dispatchOnchange(T record, String field, dynamic value) => record;

  /// Validate constraints for changed fields.
  Map<String, String> validateConstraintsFor(
          T record, Set<String> changedFields) =>
      const {};

  /// The state machine field name (e.g., 'state'), or null if no state machine.
  String? get stateField => null;

  /// Map of state -> list of allowed target states.
  Map<String, List<String>> get stateTransitionMap => const {};

  /// Map of field -> onchange handler method name.
  Map<String, String> get onchangeHandlerMap => const {};

  /// Map of constraint name -> list of fields it watches.
  Map<String, List<String>> get constraintFieldsMap => const {};

  /// List of computed field names.
  List<String> get computedFieldNames => const [];

  /// List of stored (Drift) field names.
  List<String> get storedFieldNames => const [];

  /// List of fields that should be sent to Odoo on write.
  List<String> get writableFieldNames => const [];

  // ═══════════════════════════════════════════════════════════════════════════
  // Injected Dependencies
  // ═══════════════════════════════════════════════════════════════════════════

  /// OdooClient from odoo_offline_core (single connection point to Odoo)
  OdooClient? _client;
  GeneratedDatabase? _db;
  OfflineQueueWrapper? _queue;
  ModelManagerConfig _config = const ModelManagerConfig();

  /// The injected Drift database instance.
  ///
  /// Used by generated managers' `database` getter override.
  /// Returns null if [initialize] hasn't been called yet.
  GeneratedDatabase? get db => _db;

  final _uuid = const Uuid();

  // State streams
  final _syncInProgress = ValueStream<bool>(false);
  final _lastSyncTime = ValueStream<DateTime?>(null);
  final _unsyncedCount = ValueStream<int>(0);

  // Reactive record change streams
  final _recordChanges = StreamController<RecordChangeEvent<T>>.broadcast();

  // Background sync error stream
  final _backgroundErrors = StreamController<BackgroundSyncError>.broadcast();

  /// Stream indicating if sync is in progress.
  Stream<bool> get syncInProgress => _syncInProgress.stream;

  /// Current sync-in-progress value (synchronous).
  bool get isSyncInProgress => _syncInProgress.value;

  /// Stream of last successful sync time.
  Stream<DateTime?> get lastSyncTime => _lastSyncTime.stream;

  /// Current last sync time value (synchronous).
  DateTime? get lastSyncTimeValue => _lastSyncTime.value;

  /// Stream of unsynced record count.
  Stream<int> get unsyncedCount => _unsyncedCount.stream;

  /// Current unsynced record count (synchronous).
  int get unsyncedCountValue => _unsyncedCount.value;

  /// Stream of record change events.
  ///
  /// Emits events whenever a record is created, updated, or deleted.
  /// Use this to react to changes in real-time.
  ///
  /// ```dart
  /// manager.recordChanges.listen((event) {
  ///   if (event.type == ChangeType.update && event.id == myOrderId) {
  ///     // Refresh UI
  ///   }
  /// });
  /// ```
  Stream<RecordChangeEvent<T>> get recordChanges => _recordChanges.stream;

  /// Stream of background sync errors.
  ///
  /// Emits errors that occur during background sync operations (e.g., when
  /// [read] or [search] trigger background refreshes that fail).
  ///
  /// Subscribe to this stream to handle background sync failures gracefully:
  /// - Show notifications to users about stale data
  /// - Log errors for debugging
  /// - Trigger manual sync attempts
  ///
  /// ```dart
  /// manager.backgroundErrors.listen((error) {
  ///   print('Background sync failed: ${error.model}:${error.recordId}');
  ///   print('Error: ${error.error}');
  ///   // Show notification, log to analytics, etc.
  /// });
  /// ```
  Stream<BackgroundSyncError> get backgroundErrors =>
      _backgroundErrors.stream;

  /// Whether the Odoo client is configured and ready.
  bool get isOnline => _client?.isConfigured ?? false;

  /// The Odoo client (from odoo_offline_core).
  ///
  /// Throws [StateError] if the manager has not been initialized.
  OdooClient get client {
    if (_client == null) {
      throw StateError(
        'Manager not initialized. Call initialize() first.',
      );
    }
    return _client!;
  }

  /// Emit a record change event.
  void _emitChange(ChangeType type, int id, {T? record}) {
    _recordChanges.add(RecordChangeEvent(
      type: type,
      id: id,
      record: record,
      timestamp: DateTime.now(),
    ));

    // Update LRU cache - O(1) operations
    if (this is _ManagerCacheMixin<T>) {
      final cacheMixin = this as _ManagerCacheMixin<T>;
      if (record != null && type != ChangeType.delete) {
        cacheMixin._cache.put(id, record);
      } else if (type == ChangeType.delete) {
        cacheMixin._cache.remove(id);
      }
    }
  }

  Future<void> _syncRecordInBackground(int id) async {
    if (!isOnline) return;

    try {
      final records = await _client!.read(
        model: odooModel,
        ids: [id],
        fields: odooFields,
      );

      if (records.isNotEmpty) {
        final record = fromOdoo(records.first);
        final syncedRecord = withSyncStatus(record, true);
        await upsertLocal(syncedRecord);

        // Emit sync event for the refreshed record
        _emitChange(ChangeType.sync, id, record: syncedRecord);
      }
    } catch (e, stackTrace) {
      // Emit background sync error instead of silently failing
      _backgroundErrors.add(BackgroundSyncError(
        model: odooModel,
        recordId: id,
        operation: BackgroundSyncOperation.syncRecord,
        error: e,
        stackTrace: stackTrace,
        timestamp: DateTime.now(),
      ));
    }
  }

  Future<void> _syncSearchInBackground(
    List<dynamic>? domain,
    int? limit,
    int? offset,
  ) async {
    if (!isOnline) return;

    try {
      final records = await _client!.searchRead(
        model: odooModel,
        domain: domain,
        fields: odooFields,
        limit: limit,
        offset: offset,
      );

      for (final data in records) {
        final record = fromOdoo(data);
        final syncedRecord = withSyncStatus(record, true);
        await upsertLocal(syncedRecord);

        // Emit sync event for each refreshed record
        final id = getId(syncedRecord);
        _emitChange(ChangeType.sync, id, record: syncedRecord);
      }
    } catch (e, stackTrace) {
      // Emit background sync error instead of silently failing
      _backgroundErrors.add(BackgroundSyncError(
        model: odooModel,
        recordId: null, // Search operation, no specific record
        operation: BackgroundSyncOperation.syncSearch,
        error: e,
        stackTrace: stackTrace,
        timestamp: DateTime.now(),
      ));
    }
  }

  Future<void> _queueOperation(
    OfflineOperationType type,
    int recordId,
    String? uuid,
    T? record,
  ) async {
    // Prepare values including uuid for record tracking
    final values = <String, dynamic>{
      if (record != null) ...toOdoo(record),
      if (uuid != null) 'uuid': uuid,
    };

    await _queue?.enqueue(
      model: odooModel,
      method: type.name,
      recordId: recordId,
      values: values,
    );
  }

  Future<void> _processQueuedOperation(OfflineOperation op) async {
    final recordId = op.recordId;
    final values = op.values;
    final uuid = values['uuid'] as String?;

    // Determine operation type from method name
    final type = _parseOperationType(op.method);

    switch (type) {
      case OfflineOperationType.create:
        // Remove uuid from values before sending to Odoo
        final odooValues = Map<String, dynamic>.from(values)..remove('uuid');
        if (odooValues.isNotEmpty) {
          final odooId = await _client!.create(
            model: odooModel,
            values: odooValues,
          );

          // Update local record with real ID
          if (odooId != null &&
              recordId != null &&
              recordId < 0 &&
              uuid != null) {
            final local = await readLocalByUuid(uuid);
            if (local != null) {
              final updated = withIdAndUuid(local, odooId, uuid);
              final synced = withSyncStatus(updated, true);
              await deleteLocal(recordId);
              await upsertLocal(synced);
            }
          }
        }
        break;

      case OfflineOperationType.write:
        final odooValues = Map<String, dynamic>.from(values)..remove('uuid');
        if (odooValues.isNotEmpty && recordId != null && recordId > 0) {
          await _client!.write(
            model: odooModel,
            ids: [recordId],
            values: odooValues,
          );

          // Mark local as synced
          final local = await readLocal(recordId);
          if (local != null) {
            await upsertLocal(withSyncStatus(local, true));
          }
        }
        break;

      case OfflineOperationType.unlink:
        if (recordId != null && recordId > 0) {
          await _client!.unlink(
            model: odooModel,
            ids: [recordId],
          );
        }
        break;
    }
  }

  /// Parse operation type from method name.
  OfflineOperationType _parseOperationType(String method) {
    switch (method) {
      case 'create':
        return OfflineOperationType.create;
      case 'write':
        return OfflineOperationType.write;
      case 'unlink':
        return OfflineOperationType.unlink;
      default:
        return OfflineOperationType.write;
    }
  }

  Future<void> _updateUnsyncedCount() async {
    final unsynced = await getUnsyncedRecords();
    _unsyncedCount.add(unsynced.length);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Public OdooModelManager class - composed from base + mixins
// ═══════════════════════════════════════════════════════════════════════════════

/// Abstract base class for Odoo model managers.
///
/// Subclasses are generated by build_runner and provide:
/// - Model-specific field definitions
/// - fromOdoo/toOdoo conversion methods
/// - Local database operations
///
/// Usage:
/// ```dart
/// @OdooModel('product.product')
/// @freezed
/// class Product with _$Product {
///   // Fields with OdooField annotations
/// }
///
/// // Generated: ProductManager extends OdooModelManager<Product>
/// ```
abstract class OdooModelManager<T> extends _OdooModelManagerBase<T>
    with
        _ManagerCacheMixin<T>,
        _ManagerWatchMixin<T>,
        _ManagerSyncMixin<T>,
        _ManagerActionsMixin<T>,
        _ManagerBatchMixin<T>,
        _ManagerConflictsMixin<T> {
  /// Initialize the manager with all dependencies.
  ///
  /// Uses OdooClient from odoo_offline_core as the single connection point.
  void initialize({
    required OdooClient client,
    required GeneratedDatabase db,
    required OfflineQueueWrapper queue,
    ModelManagerConfig? config,
  }) {
    _client = client;
    _db = db;
    _queue = queue;
    if (config != null) _config = config;
  }

  /// Initialize only database access for local CRUD operations.
  ///
  /// Use this for managers that only need local read/write (e.g., catalog
  /// models synced via [GenericSyncRepository]) without the full
  /// [initialize] which requires OdooClient and OfflineQueueWrapper.
  void initDb(GeneratedDatabase db) {
    _db = db;
  }

  /// Dispose resources.
  void dispose() {
    _syncInProgress.close();
    _lastSyncTime.close();
    _unsyncedCount.close();
    _recordChanges.close();
    _recordCache?.dispose();
    _backgroundErrors.close();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Convenience Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check if a record exists locally by ID.
  Future<bool> exists(int id) async {
    final record = await readLocal(id);
    return record != null;
  }

  /// Check if a record exists locally by UUID.
  Future<bool> existsByUuid(String uuid) async {
    final record = await readLocalByUuid(uuid);
    return record != null;
  }

  /// Find record by ID, returns null if not found.
  /// Alias for readLocal.
  Future<T?> findById(int id) => readLocal(id);

  /// Find record by UUID.
  /// Alias for readLocalByUuid.
  Future<T?> findByUuid(String uuid) => readLocalByUuid(uuid);

  /// Find multiple records by IDs.
  Future<List<T>> findByIds(List<int> ids) async {
    final results = <T>[];
    for (final id in ids) {
      final record = await readLocal(id);
      if (record != null) results.add(record);
    }
    return results;
  }

  /// Upsert multiple records in batch.
  Future<void> upsertMany(List<T> records) async {
    for (final record in records) {
      await upsertLocal(record);
    }
  }

  /// Delete multiple records by IDs.
  Future<void> deleteMany(List<int> ids) async {
    for (final id in ids) {
      await deleteLocal(id);
    }
  }

  /// Get first record matching criteria or null.
  Future<T?> first({List<dynamic>? domain}) async {
    final results = await searchLocal(domain: domain, limit: 1);
    return results.isEmpty ? null : results.first;
  }

  /// Get all records (use with caution on large tables).
  Future<List<T>> all({int? limit, int? offset, String? orderBy}) async {
    return searchLocal(limit: limit, offset: offset, orderBy: orderBy);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD Operations - Offline-First
  // ═══════════════════════════════════════════════════════════════════════════

  /// Read a record by ID.
  ///
  /// Always reads from local database first. If online and configured,
  /// triggers background sync to refresh the record.
  Future<T?> read(int id) async {
    // 1. Read from local first
    final local = await readLocal(id);

    // 2. Optionally sync in background
    if (isOnline && _config.backgroundSync && local != null) {
      _syncRecordInBackground(id);
    }

    return local;
  }

  /// Create a new record.
  ///
  /// Creates locally with temporary negative ID and UUID.
  /// If online, attempts immediate sync. Otherwise queues for later.
  /// Returns the local ID (negative if not yet synced).
  Future<int> create(T record) async {
    final uuid = _uuid.v4();
    final localId = -(DateTime.now().millisecondsSinceEpoch % 1000000000);

    // Create record with temporary ID and UUID
    final localRecord = withIdAndUuid(record, localId, uuid);
    final unsyncedRecord = withSyncStatus(localRecord, false);

    // 1. Save locally
    await upsertLocal(unsyncedRecord);
    await _updateUnsyncedCount();

    // Emit create event
    _emitChange(ChangeType.create, localId, record: unsyncedRecord);

    // 2. Try to sync immediately if online
    if (isOnline) {
      try {
        final odooId = await _client!.create(
          model: odooModel,
          values: toOdoo(record),
        );

        if (odooId == null) {
          throw Exception('Server returned null ID for create');
        }

        // Update local record with real ID
        final syncedRecord = withSyncStatus(
          withIdAndUuid(record, odooId, uuid),
          true,
        );
        await deleteLocal(localId);
        await upsertLocal(syncedRecord);
        await _updateUnsyncedCount();

        // Emit sync event with new ID
        _emitChange(ChangeType.sync, odooId, record: syncedRecord);

        return odooId;
      } catch (e) {
        // Failed to sync - queue for later
        await _queueOperation(
            OfflineOperationType.create, localId, uuid, record);
        return localId;
      }
    } else {
      // Offline - queue for later
      await _queueOperation(
          OfflineOperationType.create, localId, uuid, record);
      return localId;
    }
  }

  /// Update an existing record.
  ///
  /// Updates locally immediately. If online, attempts sync.
  /// Otherwise queues for later.
  Future<bool> update(T record) async {
    final id = getId(record);
    final uuid = getUuid(record);

    // 1. Update locally
    final unsyncedRecord = withSyncStatus(record, false);
    await upsertLocal(unsyncedRecord);
    await _updateUnsyncedCount();

    // Emit update event
    _emitChange(ChangeType.update, id, record: unsyncedRecord);

    // 2. Try to sync if online and has real ID
    if (isOnline && id > 0) {
      try {
        final success = await _client!.write(
          model: odooModel,
          ids: [id],
          values: toOdoo(record),
        );

        if (success) {
          final syncedRecord = withSyncStatus(record, true);
          await upsertLocal(syncedRecord);
          await _updateUnsyncedCount();

          // Emit sync event
          _emitChange(ChangeType.sync, id, record: syncedRecord);
        }

        return success;
      } catch (e) {
        // Failed - queue for later
        await _queueOperation(OfflineOperationType.write, id, uuid, record);
        return true; // Local update succeeded
      }
    } else {
      // Offline or local-only record - queue
      await _queueOperation(OfflineOperationType.write, id, uuid, record);
      return true;
    }
  }

  /// Delete a record.
  ///
  /// Deletes locally immediately. If online, attempts sync.
  /// Otherwise queues for later.
  Future<bool> delete(int id) async {
    // Get UUID before deleting
    final existing = await readLocal(id);
    final uuid = existing != null ? getUuid(existing) : null;

    // 1. Delete locally
    await deleteLocal(id);
    await _updateUnsyncedCount();

    // Emit delete event
    _emitChange(ChangeType.delete, id);

    // 2. Try to sync if online and has real ID
    if (isOnline && id > 0) {
      try {
        return await _client!.unlink(
          model: odooModel,
          ids: [id],
        );
      } catch (e) {
        // Failed - queue for later
        await _queueOperation(OfflineOperationType.unlink, id, uuid, null);
        return true; // Local delete succeeded
      }
    } else if (id > 0) {
      // Offline but has real ID - queue
      await _queueOperation(OfflineOperationType.unlink, id, uuid, null);
    }
    // If id < 0, record was never synced, no need to queue

    return true;
  }

  /// Search for records.
  ///
  /// Searches local database. If online and configured,
  /// triggers background sync to fetch updates.
  Future<List<T>> search({
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? orderBy,
  }) async {
    // 1. Search locally
    final results = await searchLocal(
      domain: domain,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
    );

    // 2. Optionally sync in background
    if (isOnline && _config.backgroundSync) {
      _syncSearchInBackground(domain, limit, offset);
    }

    return results;
  }

  /// Count records matching domain.
  Future<int> count({List<dynamic>? domain}) async {
    return countLocal(domain: domain);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WebSocket Event Handling
  // ═══════════════════════════════════════════════════════════════════════════

  /// Handle a WebSocket event for this model.
  ///
  /// Called by ModelRegistry when a relevant event is received.
  void handleWebSocketEvent(ModelRecordEvent event) {
    if (event.model != odooModel) return;

    switch (event.operation) {
      case RecordOperation.create:
      case RecordOperation.write:
        _syncRecordInBackground(event.recordId);
        break;
      case RecordOperation.unlink:
        deleteLocal(event.recordId).then((_) {
          _emitChange(ChangeType.delete, event.recordId);
        });
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Convenience Methods for OdooRecord
  // ═══════════════════════════════════════════════════════════════════════════

  /// Save a record (create or update based on ID).
  ///
  /// This is called by OdooRecord.save() to persist changes.
  Future<T> save(T record) async {
    final id = getId(record);

    if (id <= 0) {
      // Create
      final newId = await create(record);
      final saved = await readLocal(newId);
      if (saved == null) {
        throw StateError('Failed to read saved record with ID $newId');
      }
      return saved;
    } else {
      // Update
      await update(record);
      final updated = await readLocal(id);
      if (updated == null) {
        throw StateError('Failed to read updated record with ID $id');
      }
      return updated;
    }
  }
}
