import 'package:drift/drift.dart';

import 'database.dart';

// ============================================================================
// DatabaseMigrations — Sistema de migraciones Drift
//
// FASE ACTUAL: ALFA (no hay usuarios con datos de producción)
//
// Mientras estemos en alfa, TODA migración hace drop+recreate.
// Esto es seguro porque no hay datos reales que preservar.
//
// Cuando la app entre en producción:
//   1. Marcar la versión actual como BASELINE_PRODUCCION
//   2. A partir de ahí, usar migraciones incrementales exclusivamente
//   3. Agregar cada migración como método aislado (ver plantilla abajo)
//
// CÓMO AGREGAR UNA MIGRACIÓN INCREMENTAL (post-producción):
//   1. Incrementar `schemaVersion` en database.dart
//   2. Modificar las tablas Drift correspondientes
//   3. Ejecutar `dart run build_runner build --delete-conflicting-outputs`
//   4. Agregar un método `_migrateVNaVM(Migrator m, AppDatabase db)`
//   5. Registrar ese método en el mapa `_migrations`
//
// EJEMPLO:
//   static Future<void> _migrateV4aV5(Migrator m, AppDatabase db) async {
//     await m.addColumn(db.saleOrder, db.saleOrder.nuevoCampo);
//   }
// ============================================================================

/// Versión a partir de la cual se usan migraciones incrementales.
///
/// Cambiar este valor cuando la app entre en producción. Toda versión
/// menor a este baseline hará drop+recreate. Toda versión >= baseline
/// usará migraciones incrementales que preservan datos.
// ANTES DE PRODUCCION: cambiar este valor al schemaVersion que tenga la app en
// el momento de lanzamiento (actualmente schemaVersion = 5 en database.dart).
// Mientras _baselineProduccion > schemaVersion, cualquier onUpgrade hace
// drop+recreate — lo cual destruiría los datos reales de los usuarios.
// Pasos para el lanzamiento:
//   1. Decidir la versión de producción (ej: 5)
//   2. Asignar: _baselineProduccion = 5
//   3. A partir de ese momento, cada cambio de esquema DEBE tener su migración
//      incremental registrada en _migrations.
//   4. NUNCA volver a reducir este valor ni hacer drop+recreate en producción.
const _baselineProduccion = 999;

class DatabaseMigrations {
  DatabaseMigrations._();

  /// Ejecuta la migración de [from] a [to].
  ///
  /// Mientras estemos en alfa (from < _baselineProduccion): drop+recreate.
  /// En producción (from >= _baselineProduccion): migraciones incrementales.
  static Future<void> migrate(
    Migrator m,
    int from,
    int to,
    AppDatabase db,
  ) async {
    if (from < _baselineProduccion) {
      // ----------------------------------------------------------------
      // FASE ALFA: drop+recreate seguro. No hay datos de producción.
      // ----------------------------------------------------------------
      _log('Alfa: v$from → v$to — drop + recreate completo');
      await _dropAndRecreate(m, db);

      // Limpieza de tablas huérfanas que _dropAndRecreate() NO puede tocar:
      // itera sobre `db.allTables`, que ya NO incluye tablas eliminadas del
      // esquema (ej. `dirty_fields` removida en v7) — si una instalación
      // existente en campo la tenía creada, quedaría huérfana para siempre
      // sin este paso explícito. Ver _migrateV6aV7 más abajo.
      if (from < 7) await _migrateV6aV7(m, db);

      _log('Esquema recreado en v$to.');
      return;
    }

    // ------------------------------------------------------------------
    // PRODUCCIÓN: migraciones incrementales encadenadas.
    // Ejecuta paso a paso: from → from+1 → ... → to
    // ------------------------------------------------------------------
    _log('Producción: migraciones incrementales v$from → v$to');

    for (int version = from; version < to; version++) {
      final key = '${version}_${version + 1}';
      final migrationFn = _migrations[key];

      if (migrationFn != null) {
        _log('Ejecutando v$version → v${version + 1}...');
        await migrationFn(m, db);
        _log('v$version → v${version + 1} completada.');
      } else {
        _log(
          'AVISO: No hay migración para v$version → v${version + 1}. '
          'Verificar _migrations en migrations.dart.',
        );
      }
    }

    // Validar tablas críticas como red de seguridad
    await _validarTablasCriticas(m, db);
    _log('Migraciones completadas. Esquema en v$to.');
  }

  // --------------------------------------------------------------------------
  // Drop + recreate
  // --------------------------------------------------------------------------

  static Future<void> _dropAndRecreate(Migrator m, AppDatabase db) async {
    final tablas = db.allTables.toList().reversed;
    for (final tabla in tablas) {
      await m.deleteTable(tabla.actualTableName);
    }
    await m.createAll();
  }

  // --------------------------------------------------------------------------
  // Validación post-migración (solo se usa en producción)
  // --------------------------------------------------------------------------

  static const _tablasCriticas = <String>{
    'offline_queue',
    'sync_metadata',
    'collection_session',
    'sale_order',
    'product_product',
  };

  static Future<void> _validarTablasCriticas(Migrator m, AppDatabase db) async {
    _log('Validando tablas críticas...');
    for (final nombre in _tablasCriticas) {
      try {
        final resultado = await db.customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          variables: [Variable.withString(nombre)],
        ).getSingleOrNull();

        if (resultado == null) {
          _log('ALERTA: Tabla "$nombre" faltante. Recreando...');
          final tabla = db.allTables
              .where((t) => t.actualTableName == nombre)
              .firstOrNull;
          if (tabla != null) {
            await m.createTable(tabla);
            _log('Tabla "$nombre" recreada.');
          }
        }
      } catch (e) {
        _log('ERROR validando "$nombre": $e');
      }
    }
  }

  // --------------------------------------------------------------------------
  // Migraciones incrementales (agregar aquí cuando entre en producción)
  // --------------------------------------------------------------------------

  // Ejemplo para cuando _baselineProduccion sea, digamos, 4:
  //
  // static Future<void> _migrateV4aV5(Migrator m, AppDatabase db) async {
  //   _log('[v4→v5] Agregando campo X...');
  //   await m.addColumn(db.saleOrder, db.saleOrder.nuevoCampo);
  // }

  /// v6 → v7: elimina la tabla `dirty_fields` (tracking de campos dirty a
  /// nivel de campo). Nunca tuvo un escritor real en producción — su único
  /// escritor histórico (`WebSocketSyncService.markFieldDirty()`) era código
  /// muerto sin consumidores y ya fue eliminado (ver
  /// theos_pos/lib/shared/providers/notification_provider.dart, que migró
  /// la protección equivalente al criterio `isSynced` a nivel de registro).
  ///
  /// Se llama explícitamente desde el branch alfa de [migrate] (no solo
  /// desde `_migrations`) porque `_dropAndRecreate()` itera `db.allTables`,
  /// que ya no conoce esta tabla tras remover la clase `DirtyFields` — sin
  /// este DROP explícito, instalaciones existentes en campo que ya la tenían
  /// creada la conservarían huérfana para siempre.
  static Future<void> _migrateV6aV7(Migrator m, AppDatabase db) async {
    _log('[v6→v7] Eliminando tabla huérfana dirty_fields...');
    await db.customStatement('DROP TABLE IF EXISTS dirty_fields');
  }

  /// v7 → v8: fixes de esquema detectados por el test de roundtrip de
  /// persistencia (julio 2026):
  /// - `account_move.l10n_ec_sri_payment_id` — columna nueva (el modelo
  ///   declaraba el Many2One pero la tabla solo tenía el nombre).
  /// - `res_partner_bank.odoo_id` ahora UNIQUE — sin esto, el
  ///   `ON CONFLICT ("odoo_id")` del upsert era SQL inválido y TODO sync de
  ///   res.partner.bank fallaba con SqliteException.
  /// - `account_move_line.date/journal_id/company_id` pasan a nullable (el
  ///   modelo read-only nunca los provee).
  /// En alfa el drop+recreate cubre todo; se registra igual para el camino
  /// incremental de producción.
  static Future<void> _migrateV7aV8(Migrator m, AppDatabase db) async {
    _log('[v7→v8] Aplicando fixes de esquema del roundtrip de persistencia...');
    await db.customStatement(
      'ALTER TABLE account_move ADD COLUMN l10n_ec_sri_payment_id INTEGER',
    );
    await db.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_rpb_odoo_id_unique '
      'ON res_partner_bank (odoo_id)',
    );
    // Nota: relajar NOT NULL en SQLite requiere recrear la tabla;
    // account_move_line es cache read-only de reportes (sin datos que
    // preservar), así que se recrea vacía.
    await db.customStatement('DROP TABLE IF EXISTS account_move_line');
    await m.createTable(db.accountMoveLine);
  }

  // --------------------------------------------------------------------------
  // Registro de migraciones — clave: 'from_to', valor: función
  // --------------------------------------------------------------------------

  static final Map<String, Future<void> Function(Migrator, AppDatabase)>
      _migrations = {
    // Registrada desde ya para cuando _baselineProduccion baje a <= 6 — hoy
    // (alfa) se ejecuta igual, pero desde el branch alfa de [migrate], que
    // la llama directo (ver arriba) en vez de pasar por este mapa.
    '6_7': _migrateV6aV7,
    '7_8': _migrateV7aV8,
  };

  // --------------------------------------------------------------------------
  // Logger
  // --------------------------------------------------------------------------

  static void _log(String msg) {
    // ignore: avoid_print
    print('[Database][Migration] $msg');
  }
}

// ============================================================================
// HISTORIAL DE VERSIONES
//
// v1-v3 (alfa)  — Desarrollo inicial. Drop+recreate en cada cambio.
// v4    (alfa)  — Índices en product_product, recovery offline_queue,
//                 sistema de migraciones introducido.
// v5    (alfa)  — Eliminación columnas orphan: partnerInvoiceName,
//                 partnerShippingName, currencyName, collectionConfigId,
//                 collectionConfigName (SaleOrder); lstPrice (ProductProduct);
//                 sessionId duplicado (CollectionSessionCash, Deposit, CashOut).
//                 Índices: sale_order_line(order_id), sale_order(state/partner_id/write_date),
//                 offline_queue(status,priority).
// v6    (alfa)  — account_advance: name nullable (la secuencia ADV-xxxx la
//                 asigna el servidor), company_id nullable y partner_type con
//                 default 'customer' — los inserts offline no los conocen.
// v7    (alfa)  — Eliminada tabla dirty_fields (tracking dirty a nivel de
//                 campo, sin escritor real — reemplazado por isSynced a
//                 nivel de registro). DROP TABLE IF EXISTS explícito en
//                 _migrateV6aV7 porque _dropAndRecreate() no la alcanza al
//                 ya no estar en db.allTables.
//
// Cuando entre en producción, documentar aquí cada versión nueva.
// ============================================================================
