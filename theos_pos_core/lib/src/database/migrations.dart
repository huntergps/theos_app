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
const _baselineProduccion = 999; // TODO: Cambiar al schemaVersion real cuando entre en producción

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

  // --------------------------------------------------------------------------
  // Registro de migraciones — clave: 'from_to', valor: función
  // --------------------------------------------------------------------------

  static final Map<String, Future<void> Function(Migrator, AppDatabase)>
      _migrations = {
    // Descomentar y agregar cuando haya migraciones reales:
    // '4_5': _migrateV4aV5,
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
//
// Cuando entre en producción, documentar aquí cada versión nueva.
// ============================================================================
