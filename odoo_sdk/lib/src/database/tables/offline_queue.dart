import 'package:drift/drift.dart';

/// OfflineQueue - Cola de operaciones offline pendientes de sincronización
///
/// Esquema unificado que soporta:
/// - Operaciones CRUD (create, write, unlink)
/// - Detección de conflictos con baseWriteDate
/// - Multi-dispositivo con deviceId
/// - Reintentos con backoff exponencial
/// - Estado de operación (pending, processing, completed, failed)
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
