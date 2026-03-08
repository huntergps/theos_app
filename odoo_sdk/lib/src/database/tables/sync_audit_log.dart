import 'package:drift/drift.dart';

/// Audit log for tracking synced operations (M9)
class SyncAuditLog extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Model name (e.g., 'sale.order')
  TextColumn get model => text()();

  /// Method executed (e.g., 'create', 'write')
  TextColumn get method => text()();

  /// Record ID in Odoo (after sync)
  IntColumn get odooId => integer().nullable()();

  /// Local record ID (before sync)
  IntColumn get localId => integer().nullable()();

  /// UUID of the record if applicable
  TextColumn get recordUuid => text().nullable()();

  /// Device ID that originated the operation
  TextColumn get deviceId => text().nullable()();

  /// When the operation was created locally
  DateTimeColumn get createdOfflineAt => dateTime()();

  /// When the operation was synced to Odoo
  DateTimeColumn get syncedAt => dateTime()();

  /// Gap time in seconds (synced_at - created_offline_at)
  IntColumn get gapSeconds => integer()();

  /// Result: 'success', 'conflict', 'error'
  TextColumn get result => text()();

  /// Error message if result is 'error'
  TextColumn get errorMessage => text().nullable()();

  /// Additional data (JSON)
  TextColumn get metadata => text().nullable()();
}
