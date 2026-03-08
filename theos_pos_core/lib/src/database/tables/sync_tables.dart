import 'package:drift/drift.dart';

// ============================================================================
// P0 NOTE: These 5 tables (OfflineQueue, SyncAuditLog, SyncMetadata,
// FieldSelections, RelatedRecordCache) mirror the definitions in
// odoo_offline_core/lib/src/database/tables/.
//
// WHY DUPLICATED: Drift code generation cannot resolve Table classes from
// external packages. The @DriftDatabase annotation in database.dart requires
// all table classes to be locally resolvable at build time.
//
// CANONICAL SOURCE: odoo_offline_core defines the authoritative schemas.
// Any schema changes MUST be applied to both locations.
//
// Tables exclusive to theos_pos_core: DirtyFields, SyncConflict.
// ============================================================================

/// OfflineQueue - Cola de operaciones offline pendientes de sincronización
///
/// Schema aligned with odoo_offline_core's OfflineQueue table.
class OfflineQueue extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Tipo de operación: 'create', 'write', 'unlink'
  TextColumn get operation => text().withDefault(const Constant('write'))();

  /// Nombre del modelo Odoo
  TextColumn get model => text()();

  /// Método HTTP o tipo de operación específica
  TextColumn get method => text().nullable()();

  /// ID del registro local
  IntColumn get recordId => integer().nullable()();

  /// Datos JSON de la operación
  TextColumn get values => text()();

  /// Timestamp de creación
  DateTimeColumn get createdAt => dateTime()();

  /// write_date del registro al momento de encolar (para detección de conflictos)
  DateTimeColumn get baseWriteDate => dateTime().nullable()();

  /// ID de la orden padre (para sale.order.line -> sale.order)
  IntColumn get parentOrderId => integer().nullable()();

  /// Priority: 0=critical (sessions), 1=high (payments), 2=normal (default), 3=low
  IntColumn get priority => integer().withDefault(const Constant(2))();

  /// Device ID that created this operation (for multi-device tracking)
  TextColumn get deviceId => text().nullable()();

  /// Estado de la operación: 'pending', 'processing', 'completed', 'failed'
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Número máximo de reintentos
  IntColumn get maxRetries => integer().withDefault(const Constant(3))();

  /// Indica si la operación requiere conexión de red
  BoolColumn get requiresNetwork => boolean().withDefault(const Constant(true))();

  // Retry backoff fields
  /// Number of retry attempts
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  /// Last retry attempt timestamp
  DateTimeColumn get lastRetryAt => dateTime().nullable()();

  /// Next scheduled retry timestamp (for exponential backoff)
  DateTimeColumn get nextRetryAt => dateTime().nullable()();

  /// Último mensaje de error (para debugging)
  TextColumn get lastError => text().nullable()();
}

/// Audit log for tracking synced operations
///
/// Schema aligned with odoo_offline_core's SyncAuditLog table.
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

/// SyncMetadata - Key-value storage for sync state
class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// FieldSelections - Cache de selecciones de campos por modelo
class FieldSelections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get model => text()();
  TextColumn get field => text()();
  TextColumn get selections => text()(); // JSON string
}

/// RelatedRecordCache - Cache de registros relacionados genérico
class RelatedRecordCache extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get model => text()(); // Odoo model name
  IntColumn get odooId => integer()(); // Odoo record ID
  TextColumn get name => text()(); // Record display name
  TextColumn get data => text().nullable()(); // JSON data
  DateTimeColumn get cachedAt => dateTime()();
  DateTimeColumn get writeDate => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {model, odooId},
  ];
}

/// DirtyFields - Seguimiento de campos modificados localmente
class DirtyFields extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get model => text()();
  IntColumn get recordId => integer()();
  TextColumn get fieldName => text()();
  TextColumn get oldValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
  TextColumn get localValue => text().nullable()(); // Alias for newValue
  TextColumn get serverValue => text().nullable()(); // Server value for conflict detection
  DateTimeColumn get lastSyncAt => dateTime().nullable()(); // Last sync timestamp
  DateTimeColumn get modifiedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}

/// SyncConflict - Registro de conflictos de sincronización
class SyncConflict extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get model => text()();
  IntColumn get localId => integer()();
  IntColumn get remoteId => integer()();
  TextColumn get conflictType => text()(); // 'local_modified', 'remote_modified', 'both_modified'
  TextColumn get localData => text()(); // JSON local data
  TextColumn get remoteData => text()(); // JSON remote data
  TextColumn get resolution => text().nullable()(); // 'local_wins', 'remote_wins', 'merge', 'manual'
  DateTimeColumn get detectedAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  BoolColumn get isResolved => boolean().withDefault(const Constant(false))();
}
