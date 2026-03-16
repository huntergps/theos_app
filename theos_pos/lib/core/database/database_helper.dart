import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import 'database_helper_file_ops.dart'
    if (dart.library.js_interop) 'database_helper_file_ops_stub.dart'
    as file_ops;
import 'package:theos_pos_core/theos_pos_core.dart' show AppDatabase, IOdooDatabase, ProductProductData, OfflineQueueCompanion, SyncAuditLogCompanion, SyncAuditLogData;
import 'package:odoo_sdk/odoo_sdk.dart';

/// Drift-based database helper for offline-first storage
/// Works on all platforms including web
///
/// ## Multi-Server Support
/// This helper now supports per-server databases. Each Odoo server/database
/// combination gets its own SQLite file to prevent data conflicts.
///
/// Use [initializeForServer] when connecting to a specific server.
/// Use [initialize] for backwards compatibility (uses default DB name).
///
/// ## DEPRECATION NOTICE
/// Feature-specific methods are being migrated to datasources:
/// - Partner/Client: Use clientManager from theos_pos_core (ClientManager extensions)
/// - User: Use userManager from theos_pos_core (UserManager extensions)
/// - Activity: Use ActivityDatasource from features/activities/datasources/
/// - Sale Order: Use saleOrderManager from theos_pos_core (SaleOrderManager extensions)
/// - Sale Order Lines: Use saleOrderLineManager from theos_pos_core (SaleOrderLineManager extensions)
/// - UoM (uom.uom): Use UomDatasource from features/products/datasources/
///
/// NOTE: SyncAudit methods (logSyncOperation, getSyncAuditLogs, getAuditStats,
/// clearOldAuditLogs) MUST remain in DatabaseHelper as they implement the
/// IOdooDatabase interface required by odoo_offline_core package.
///
/// See database_helper_extension.dart for collection, advances and invoice
/// datasource migration notes.
class DatabaseHelper extends IOdooDatabase {
  static AppDatabase? _database;
  static String? _currentDatabaseName;

  DatabaseHelper._();

  /// Initialize with default database name (backwards compatible)
  static Future<DatabaseHelper> initialize() async {
    return initializeForServer(AppDatabase.defaultDatabaseName);
  }

  /// Initialize database for a specific server
  ///
  /// Creates a separate SQLite file for each server/database combination.
  /// If already initialized with a DIFFERENT database, closes the old one first.
  ///
  /// Example:
  /// ```dart
  /// await DatabaseHelper.initializeForServer('theos_pos_localhost_empresa_a');
  /// ```
  static Future<DatabaseHelper> initializeForServer(String databaseName) async {
    logger.i('[DatabaseHelper]', 'START initializeForServer: $databaseName');

    // If switching to a different database, close the current one
    if (_database != null && _currentDatabaseName != databaseName) {
      logger.d('[DatabaseHelper]', 'Switching database from $_currentDatabaseName to $databaseName');
      try {
        await _database!.close().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            logger.w('[DatabaseHelper]', 'Database close timed out after 5s, forcing release');
          },
        );
        logger.d('[DatabaseHelper]', 'Previous database closed');
      } catch (e) {
        logger.w('[DatabaseHelper]', 'Error closing previous database: $e');
      }
      _database = null;
      _currentDatabaseName = null;
    }

    if (_database == null) {
      logger.i('[DatabaseHelper]', 'Initializing Drift database: $databaseName');

      logger.d('[DatabaseHelper]', 'Step 1: Creating QueryExecutor...');
      final executor = driftDatabase(
        name: databaseName,
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.dart.js'),
        ),
      );
      logger.d('[DatabaseHelper]', 'QueryExecutor created');

      logger.d('[DatabaseHelper]', 'Step 2: Creating AppDatabase instance...');
      _database = AppDatabase(
        executor,
        databaseName: databaseName,
      );
      logger.d('[DatabaseHelper]', 'AppDatabase instance created');

      _currentDatabaseName = databaseName;
      logger.i('[DatabaseHelper]', 'Drift database initialized: $databaseName');
    } else {
      logger.d('[DatabaseHelper]', 'Database already initialized: $databaseName');
    }

    logger.d('[DatabaseHelper]', 'Creating DatabaseHelper instance...');
    _instance ??= DatabaseHelper._();
    logger.i('[DatabaseHelper]', 'END initializeForServer - SUCCESS');
    return _instance!;
  }

  /// Get current database name
  static String? get currentDatabaseName => _currentDatabaseName;

  /// Check if database is initialized
  static bool get isInitialized => _database != null;

  /// Internal accessor for the database instance.
  /// Use this within DatabaseHelper to avoid triggering deprecation warnings.
  static AppDatabase get _db {
    if (_database == null) {
      throw StateError('DatabaseHelper not initialized');
    }
    return _database!;
  }

  @Deprecated('Use appDatabaseProvider instead')
  static AppDatabase get db => _db;

  static DatabaseHelper? _instance;
  static DatabaseHelper get instance {
    if (_instance == null) {
      throw StateError('DatabaseHelper not initialized');
    }
    return _instance!;
  }

  /// Close the database connection and reset the instance
  /// Used when deleting the database file
  static Future<void> closeAndReset() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _instance = null;
    logger.d('[DatabaseHelper] 🗄️ Database closed and instance reset');
  }

  // ============ Products ============

  /// Get product by Odoo ID
  Future<ProductProductData?> getProduct(int odooId) async {
    return await (_db.select(
      _db.productProduct,
    )..where((tbl) => tbl.odooId.equals(odooId))).getSingleOrNull();
  }

  // ============ Offline Queue ============

  @override
  Future<int> queueOfflineOperation(
    String model,
    String method,
    int recordId,
    Map<String, dynamic> values,
  ) async {
    final result = await _db
        .into(_db.offlineQueue)
        .insertReturning(
          OfflineQueueCompanion.insert(
            model: model,
            method: drift.Value(method),
            operation: drift.Value(method),
            values: jsonEncode(values),
            createdAt: DateTime.now().toUtc(),
            recordId: drift.Value(recordId),
          ),
        );
    return result.id;
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingOperations({
    String? model,
  }) async {
    final query = _db.select(_db.offlineQueue);
    if (model != null) {
      query.where((tbl) => tbl.model.equals(model));
    }
    final results = await query.get();
    return results
        .map(
          (r) => {
            'id': r.id,
            'model': r.model,
            'method': r.method,
            'record_id': r.recordId,
            'values': jsonDecode(r.values),
            'created_at': r.createdAt,
          },
        )
        .toList();
  }

  @override
  Future<void> removeOperation(int id) async {
    await (_db.delete(_db.offlineQueue)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ============ Sale Orders (MIGRATED) ============
  // Sale Order and Sale Order Line methods have been migrated to:
  // - Sale Orders: use saleOrderManager (global manager from theos_pos_core)
  // - Sale Order Lines: use saleOrderLineManager (global manager from theos_pos_core)

  // The old Sale Order methods (1300+ lines) have been removed.
  // See the SaleOrderManagerBusiness extension in theos_pos_core for the implementations.

  // Methods removed from this file:
  // - upsertSaleOrder, upsertSaleOrders, getSaleOrder, getSaleOrderByUuid
  // - getSaleOrders, getSaleOrdersForPOS, countSaleOrdersForPOS
  // - searchSaleOrdersForPOS, getEditableOrdersForPOS
  // - deleteSaleOrder, updateSaleOrderState, clearSaleOrderPendingConfirm
  // - updateSaleOrderLocked, updateSaleOrderRemoteId
  // - upsertSaleOrderLine, upsertSaleOrderLines, getSaleOrderLines
  // - getSaleOrderLine, deleteSaleOrderLine, deleteSaleOrderLinesByOrderId
  // - upsertSaleOrderLineFromWebSocket, insertSaleOrderLineOffline
  // - getSaleOrderLineByUuid, updateSaleOrderLineRemoteId
  // - updateSaleOrderLineValues, getUnsyncedSaleOrderLines, saleOrderLineExists
  // - _saleOrderFromRow, _saleOrderLineFromRow, enum converters

  // ============ Clear All ============

  Future<void> clearAll() async {
    logger.d('[DatabaseHelper] 🗑️ Clearing all data...');
    await _db.delete(_db.resUsers).go();
    await _db.delete(_db.resPartner).go();
    await _db.delete(_db.resCountry).go();
    await _db.delete(_db.resCountryState).go();
    await _db.delete(_db.resLang).go();
    await _db.delete(_db.resCompanyTable).go();
    await _db.delete(_db.stockWarehouse).go();
    await _db.delete(_db.resourceCalendar).go();
    await _db.delete(_db.mailActivityTable).go();
    await _db.delete(_db.offlineQueue).go();
    await _db.delete(_db.syncMetadata).go();
    await _db.delete(_db.fieldSelections).go();
    // Collection tables
    await _db.delete(_db.collectionConfig).go();
    await _db.delete(_db.collectionSession).go();
    await _db.delete(_db.accountPayment).go();
    await _db.delete(_db.cashOut).go();
    await _db.delete(_db.collectionSessionCash).go();
    await _db.delete(_db.collectionSessionDeposit).go();
    // Sale order tables
    await _db.delete(_db.saleOrderLine).go();
    await _db.delete(_db.saleOrder).go();
    logger.d('[DatabaseHelper] ✅ All data cleared');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Reset the singleton instance (used when switching users)
  static void resetInstance() {
    _database = null;
    _instance = null;
    logger.d('[DatabaseHelper] 🔄 Instance reset');
  }

  // ============ Database Cleanup (M10 improvement) ============

  /// Information about a database file
  static Future<List<DatabaseFileInfo>> listDatabaseFiles() async {
    if (kIsWeb) return [];

    final results = <DatabaseFileInfo>[];

    try {
      final rawFiles = await file_ops.listDbFiles();

      for (final raw in rawFiles) {
        results.add(
          DatabaseFileInfo(
            path: raw['path'] as String,
            name: raw['name'] as String,
            sizeBytes: raw['sizeBytes'] as int,
            lastModified: raw['lastModified'] as DateTime,
            isCurrent:
                _currentDatabaseName != null &&
                (raw['path'] as String).contains(_currentDatabaseName!),
          ),
        );
      }

      // Sort by last modified (most recent first)
      results.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    } catch (e) {
      logger.e('[DatabaseHelper] Error listing database files: $e');
    }

    return results;
  }

  /// Clean up old database files, keeping only the specified number of most recent
  ///
  /// [keepCount] - Number of databases to keep (excluding current). Default is 2.
  /// Returns the number of files deleted and total bytes freed.
  static Future<DatabaseCleanupResult> cleanupOldDatabases({
    int keepCount = 2,
  }) async {
    int deletedCount = 0;
    int bytesFreed = 0;
    final errors = <String>[];

    try {
      final files = await listDatabaseFiles();

      // Never delete the current database
      final toConsider = files.where((f) => !f.isCurrent).toList();

      // Keep the most recent N databases (sorted by lastModified desc)
      if (toConsider.length <= keepCount) {
        logger.d(
          '[DatabaseHelper] No old databases to clean up '
          '(${toConsider.length} <= $keepCount)',
        );
        return DatabaseCleanupResult(
          deletedCount: 0,
          bytesFreed: 0,
          errors: [],
        );
      }

      // Delete older databases (everything after keepCount)
      final toDelete = toConsider.skip(keepCount).toList();

      for (final dbInfo in toDelete) {
        try {
          final deleted = await file_ops.deleteFileAt(dbInfo.path);
          if (deleted) {
            deletedCount++;
            bytesFreed += dbInfo.sizeBytes;
            logger.d(
              '[DatabaseHelper] 🗑️ Deleted old database: ${dbInfo.name} '
              '(${_formatBytes(dbInfo.sizeBytes)})',
            );
          }
        } catch (e) {
          final error = 'Failed to delete ${dbInfo.name}: $e';
          errors.add(error);
          logger.w('[DatabaseHelper] $error');
        }
      }

      if (deletedCount > 0) {
        logger.i(
          '[DatabaseHelper] 🧹 Cleaned up $deletedCount old database(s), '
          'freed ${_formatBytes(bytesFreed)}',
        );
      }
    } catch (e) {
      errors.add('Cleanup failed: $e');
      logger.e('[DatabaseHelper] Error during cleanup: $e');
    }

    return DatabaseCleanupResult(
      deletedCount: deletedCount,
      bytesFreed: bytesFreed,
      errors: errors,
    );
  }

  /// Delete a specific database file by name
  static Future<bool> deleteDatabase(String databaseName) async {
    if (kIsWeb) return false;

    if (databaseName == _currentDatabaseName) {
      logger.e(
        '[DatabaseHelper] Cannot delete current database: $databaseName',
      );
      return false;
    }

    try {
      final deleted = await file_ops.deleteDbFile(databaseName);
      if (deleted) {
        logger.d('[DatabaseHelper] 🗑️ Deleted database: $databaseName');
      } else {
        logger.w('[DatabaseHelper] Database not found: $databaseName');
      }
      return deleted;
    } catch (e) {
      logger.e('[DatabaseHelper] Error deleting database $databaseName: $e');
      return false;
    }
  }

  /// Get total size of all database files
  static Future<int> getTotalDatabaseSize() async {
    final files = await listDatabaseFiles();
    return files.fold<int>(0, (sum, f) => sum + f.sizeBytes);
  }

  /// Format bytes as human-readable string
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // ===========================================================================
  // SYNC AUDIT LOG METHODS (M9 - FASE 3)
  // ===========================================================================

  /// Log a sync operation for audit trail
  @override
  Future<void> logSyncOperation({
    required String model,
    required String method,
    required int? odooId,
    required int? localId,
    String? recordUuid,
    String? deviceId,
    DateTime? createdOfflineAt,
    required String result,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) async {
    final syncedAt = DateTime.now().toUtc();
    final offlineAt = createdOfflineAt ?? syncedAt; // Fallback if not provided
    final gapSeconds = syncedAt.difference(offlineAt).inSeconds;

    await _db
        .into(_db.syncAuditLog)
        .insertReturning(
          SyncAuditLogCompanion.insert(
            model: model,
            method: method,
            createdOfflineAt: offlineAt,
            syncedAt: syncedAt,
            gapSeconds: gapSeconds,
            result: result,
            odooId: drift.Value(odooId),
            localId: drift.Value(localId),
            recordUuid: drift.Value(recordUuid),
            deviceId: drift.Value(deviceId),
            errorMessage: drift.Value(errorMessage),
            metadata: drift.Value(
              metadata != null ? jsonEncode(metadata) : null,
            ),
          ),
        );
  }

  /// Get sync audit logs with optional filters (returns typed data)
  Future<List<SyncAuditLogData>> getSyncAuditLogsData({
    String? model,
    String? result,
    String? deviceId,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 100,
  }) async {
    var query = _db.select(_db.syncAuditLog);

    if (model != null) {
      query = query..where((tbl) => tbl.model.equals(model));
    }
    if (result != null) {
      query = query..where((tbl) => tbl.result.equals(result));
    }
    if (deviceId != null) {
      query = query..where((tbl) => tbl.deviceId.equals(deviceId));
    }
    if (fromDate != null) {
      query = query
        ..where((tbl) => tbl.syncedAt.isBiggerOrEqualValue(fromDate));
    }
    if (toDate != null) {
      query = query..where((tbl) => tbl.syncedAt.isSmallerOrEqualValue(toDate));
    }

    query = query
      ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.syncedAt)])
      ..limit(limit);

    return query.get();
  }

  /// Get sync audit logs - implements IOdooDatabase interface
  @override
  Future<List<Map<String, dynamic>>> getSyncAuditLogs({
    String? model,
    String? result,
    DateTime? since,
    int? limit,
  }) async {
    final logs = await getSyncAuditLogsData(
      model: model,
      result: result,
      fromDate: since,
      limit: limit ?? 100,
    );
    return logs.map((l) => {
      'id': l.id,
      'model': l.model,
      'method': l.method,
      'odoo_id': l.odooId,
      'local_id': l.localId,
      'result': l.result,
      'error_message': l.errorMessage,
      'synced_at': l.syncedAt.toIso8601String(),
    }).toList();
  }

  /// Get audit statistics
  Future<Map<String, dynamic>> getAuditStats({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final logs = await getSyncAuditLogsData(
      fromDate: fromDate,
      toDate: toDate,
      limit: 10000,
    );

    final successCount = logs.where((l) => l.result == 'success').length;
    final errorCount = logs.where((l) => l.result == 'error').length;
    final conflictCount = logs.where((l) => l.result == 'conflict').length;

    final gapTimes = logs.map((l) => l.gapSeconds).toList();
    final avgGap = gapTimes.isNotEmpty
        ? gapTimes.reduce((a, b) => a + b) / gapTimes.length
        : 0;
    final maxGap = gapTimes.isNotEmpty
        ? gapTimes.reduce((a, b) => a > b ? a : b)
        : 0;

    final byModel = <String, int>{};
    for (final log in logs) {
      byModel[log.model] = (byModel[log.model] ?? 0) + 1;
    }

    final byDevice = <String, int>{};
    for (final log in logs) {
      if (log.deviceId != null) {
        byDevice[log.deviceId!] = (byDevice[log.deviceId!] ?? 0) + 1;
      }
    }

    return {
      'total': logs.length,
      'success': successCount,
      'error': errorCount,
      'conflict': conflictCount,
      'avg_gap_seconds': avgGap.round(),
      'max_gap_seconds': maxGap,
      'by_model': byModel,
      'by_device': byDevice,
    };
  }

  /// Clear old audit logs - implements IOdooDatabase interface
  @override
  Future<int> clearOldAuditLogs(DateTime olderThan) async {
    final deleted = await (_db.delete(
      _db.syncAuditLog,
    )..where((tbl) => tbl.syncedAt.isSmallerThanValue(olderThan))).go();
    logger.d('[DatabaseHelper] 🗑️ Deleted $deleted old audit logs');
    return deleted;
  }

  /// Clear old audit logs (keep last N days) - convenience method
  Future<int> clearOldAuditLogsByDays({int keepDays = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: keepDays));
    return clearOldAuditLogs(cutoff);
  }

  // ============ UoM (MIGRATED) ============
  // UoM WebSocket methods migrated to:
  // - UomDatasource: features/products/datasources/uom_datasource.dart
  //
  // Methods removed:
  // - upsertUomUomFromWebSocket -> uomDatasource.upsertUomFromWebSocket()
  // - deleteUomUomByOdooId -> uomDatasource.deleteUom()
}

// ============ Support Classes for Database Cleanup ============

/// Information about a database file on disk
class DatabaseFileInfo {
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime lastModified;
  final bool isCurrent;

  const DatabaseFileInfo({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.lastModified,
    required this.isCurrent,
  });

  /// Size formatted as human-readable string
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  String toString() =>
      'DatabaseFileInfo($name, $formattedSize, current=$isCurrent)';
}

/// Result of database cleanup operation
class DatabaseCleanupResult {
  final int deletedCount;
  final int bytesFreed;
  final List<String> errors;

  const DatabaseCleanupResult({
    required this.deletedCount,
    required this.bytesFreed,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;

  /// Bytes freed formatted as human-readable string
  String get formattedBytesFreed {
    if (bytesFreed < 1024) return '$bytesFreed B';
    if (bytesFreed < 1024 * 1024) {
      return '${(bytesFreed / 1024).toStringAsFixed(1)} KB';
    }
    if (bytesFreed < 1024 * 1024 * 1024) {
      return '${(bytesFreed / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytesFreed / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  String toString() =>
      'DatabaseCleanupResult(deleted=$deletedCount, freed=$formattedBytesFreed, errors=${errors.length})';
}
