import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'database.dart';
import 'datasources/offline_queue_datasource.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

/// Drift-based database helper for offline-first storage
/// Pure Dart implementation - works on all platforms.
///
/// ## Usage
///
/// Initialize with an AppDatabase instance:
/// ```dart
/// // In Flutter app (using drift_flutter):
/// final db = AppDatabase(driftDatabase(name: 'theos_pos'));
/// await DatabaseHelper.initializeWithDatabase(db);
///
/// // In CLI tool:
/// final db = AppDatabase(NativeDatabase.memory());
/// await DatabaseHelper.initializeWithDatabase(db);
/// ```
///
/// ## Multi-Server Support
///
/// For multi-server support, create separate AppDatabase instances
/// for each server and switch using [initializeWithDatabase].
class DatabaseHelper extends IOdooDatabase {
  static AppDatabase? _database;
  static String? _currentDatabaseName;

  DatabaseHelper._();

  /// Initialize with an existing AppDatabase instance
  ///
  /// This is the preferred method for pure Dart usage.
  /// The caller is responsible for creating the AppDatabase
  /// with the appropriate QueryExecutor for their platform.
  static Future<DatabaseHelper> initializeWithDatabase(
    AppDatabase database, {
    String? databaseName,
  }) async {
    // If switching to a different database, close the current one
    if (_database != null && _database != database) {
      logger.d(
        '[DatabaseHelper] 🔄 Switching database from $_currentDatabaseName to $databaseName',
      );
      await _database!.close();
      _database = null;
      _currentDatabaseName = null;
    }

    if (_database == null) {
      logger.d(
        '[DatabaseHelper] 🗄️  Initializing Drift database: ${databaseName ?? 'unnamed'}',
      );
      _database = database;
      _currentDatabaseName = databaseName ?? AppDatabase.defaultDatabaseName;
      logger.d('[DatabaseHelper] ✅ Drift database initialized');
    }

    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  /// Get current database name
  static String? get currentDatabaseName => _currentDatabaseName;

  /// Check if database is initialized
  static bool get isInitialized => _database != null;

  /// Get the database instance
  ///
  /// Throws [StateError] if not initialized.
  static AppDatabase get db {
    if (_database == null) {
      throw StateError('DatabaseHelper not initialized. Call initializeWithDatabase first.');
    }
    return _database!;
  }

  static DatabaseHelper? _instance;

  /// Get the singleton instance
  ///
  /// Throws [StateError] if not initialized.
  static DatabaseHelper get instance {
    if (_instance == null) {
      throw StateError('DatabaseHelper not initialized. Call initializeWithDatabase first.');
    }
    return _instance!;
  }

  /// Close the database connection and reset the instance
  static Future<void> closeAndReset() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _instance = null;
    _currentDatabaseName = null;
    logger.d('[DatabaseHelper] 🗄️ Database closed and instance reset');
  }

  /// Reset the singleton instance (used when switching users)
  static void resetInstance() {
    _database = null;
    _instance = null;
    _currentDatabaseName = null;
    logger.d('[DatabaseHelper] 🔄 Instance reset');
  }

  // ============ Products ============

  /// Get product by Odoo ID
  Future<Map<String, dynamic>?> getProduct(int odooId) async {
    try {
      final query = db.select(db.productProduct)
        ..where((t) => t.odooId.equals(odooId));
      final result = await query.getSingleOrNull();
      return result != null ? {
        'id': result.id,
        'odooId': result.odooId,
        'name': result.name,
        'defaultCode': result.defaultCode,
        'listPrice': result.listPrice,
        'standardPrice': result.standardPrice,
        'type': result.type,
        'saleOk': result.saleOk,
        'purchaseOk': result.purchaseOk,
        'active': result.active,
        'writeDate': result.writeDate?.toIso8601String(),
      } : null;
    } catch (e) {
      logger.e('[DatabaseHelper] Error getting product $odooId: $e');
      return null;
    }
  }

  // ============ Offline Queue ============

  OfflineQueueDataSource? _queueDataSource;
  OfflineQueueDataSource get _queue {
    _queueDataSource ??= OfflineQueueDataSource(db);
    return _queueDataSource!;
  }

  @override
  Future<int> queueOfflineOperation(
    String model,
    String method,
    int recordId,
    Map<String, dynamic> values,
  ) async {
    return _queue.queueOperation(
      model: model,
      method: method,
      recordId: recordId,
      values: values,
    );
  }

  /// Clear a queued operation
  Future<void> clearQueuedOperation(int id) async {
    await _queue.removeOperation(id);
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingOperations({
    String? model,
  }) async {
    if (model != null) {
      final ops = await _queue.getOperationsForModel(model);
      return ops.map((op) => op.toMap()).toList();
    }
    final ops = await _queue.getPendingOperations();
    return ops.map((op) => op.toMap()).toList();
  }

  @override
  Future<void> removeOperation(int id) async {
    await _queue.removeOperation(id);
  }

  // ============ Clear All ============

  Future<void> clearAll() async {
    logger.d('[DatabaseHelper] 🗑️ Clearing all data...');
    // Implementation depends on which tables exist
    // This will be populated after code generation
    logger.w('[DatabaseHelper] clearAll not fully implemented yet');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  // ===========================================================================
  // SYNC AUDIT LOG METHODS
  // ===========================================================================

  /// Log a sync operation for audit trail (IOdooDatabase interface)
  @override
  Future<void> logSyncOperation({
    required String model,
    required String method,
    required int? odooId,
    required int? localId,
    required String result,
    String? errorMessage,
    String? recordUuid,
    DateTime? createdOfflineAt,
  }) async {
    final now = DateTime.now().toUtc();
    final offlineAt = createdOfflineAt ?? now;
    final gapSeconds = now.difference(offlineAt).inSeconds;
    final metadata = jsonEncode({
      'odoo_id': odooId,
      'local_id': localId,
      'error': errorMessage,
      'uuid': recordUuid,
      'created_offline_at': offlineAt.toIso8601String(),
    });

    await db.into(db.syncAuditLog).insert(
          SyncAuditLogCompanion.insert(
            method: method,
            model: model,
            createdOfflineAt: offlineAt,
            syncedAt: now,
            gapSeconds: gapSeconds,
            result: result,
            odooId: drift.Value(odooId),
            localId: drift.Value(localId),
            recordUuid: drift.Value(recordUuid),
            errorMessage: drift.Value(errorMessage),
            metadata: drift.Value(metadata),
          ),
        );

    logger.d('[DatabaseHelper] 📝 Audit: $method $model ($result)');
  }

  /// Get sync audit logs with optional filters (IOdooDatabase interface)
  @override
  Future<List<Map<String, dynamic>>> getSyncAuditLogs({
    String? model,
    String? result,
    DateTime? since,
    int? limit,
  }) async {
    var query = db.select(db.syncAuditLog);

    if (model != null) {
      query = query..where((t) => t.model.equals(model));
    }
    if (result != null) {
      query = query..where((t) => t.result.equals(result));
    }
    if (since != null) {
      query = query..where((t) => t.syncedAt.isBiggerOrEqualValue(since));
    }

    query = query..orderBy([(t) => drift.OrderingTerm.desc(t.syncedAt)]);

    if (limit != null) {
      query = query..limit(limit);
    }

    final rows = await query.get();
    return rows.map((r) => {
      'id': r.id,
      'method': r.method,
      'model': r.model,
      'result': r.result,
      'errorMessage': r.errorMessage,
      'metadata': r.metadata,
      'syncedAt': r.syncedAt.toIso8601String(),
      'gapSeconds': r.gapSeconds,
    }).toList();
  }

  /// Get audit statistics
  Future<Map<String, dynamic>> getAuditStats({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var query = db.select(db.syncAuditLog);

    if (fromDate != null) {
      query = query..where((t) => t.syncedAt.isBiggerOrEqualValue(fromDate));
    }
    if (toDate != null) {
      query = query..where((t) => t.syncedAt.isSmallerOrEqualValue(toDate));
    }

    final rows = await query.get();

    final successCount = rows.where((r) => r.result == 'success').length;
    final errorCount = rows.where((r) => r.result == 'error').length;
    final conflictCount = rows.where((r) => r.result == 'conflict').length;
    final total = rows.length;

    final byModel = <String, int>{};
    for (final row in rows) {
      byModel[row.model] = (byModel[row.model] ?? 0) + 1;
    }

    return {
      'total_operations': total,
      'success_count': successCount,
      'error_count': errorCount,
      'conflict_count': conflictCount,
      'success_rate': total > 0 ? successCount / total : 0.0,
      'by_model': byModel,
    };
  }

  /// Clear old audit logs (IOdooDatabase interface)
  @override
  Future<int> clearOldAuditLogs(DateTime olderThan) async {
    final deleted = await (db.delete(db.syncAuditLog)
          ..where((t) => t.syncedAt.isSmallerThanValue(olderThan)))
        .go();
    logger.d('[DatabaseHelper] 🧹 Cleared $deleted old audit logs');
    return deleted;
  }
}
