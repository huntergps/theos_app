/// FiscalPositionManager extensions - Business methods beyond generated CRUD
///
/// The base FiscalPositionManager is generated in fiscal_position.model.g.dart.
/// This file adds business-specific query methods via extension.
///
/// FiscalPositionTaxManager remains a full class because
/// FiscalPositionTax does not have @OdooModel and has no generated manager.
library;

import 'package:drift/drift.dart' as drift;

import '../../database/database.dart';
import '../../models/taxes/fiscal_position.model.dart';

/// Extension methods for FiscalPositionManager (generated)
extension FiscalPositionManagerBusiness on FiscalPositionManager {
  /// Get fiscal position by Odoo ID (alias for readLocal)
  Future<FiscalPosition?> getById(int odooId) => readLocal(odooId);

  /// Get all active fiscal positions ordered by name
  Future<List<FiscalPosition>> getAll() async {
    return searchLocal(
      domain: [
        ['active', '=', true],
      ],
      orderBy: 'name asc',
    );
  }
}

/// Manager para los mapeos fiscal-position→tax (tabla local
/// `account_fiscal_position_tax`).
///
/// Manager manual (sin @OdooModel/generador) porque [FiscalPositionTax] no
/// se sincroniza 1:1 desde un modelo de Odoo — desde Odoo >= 18.3 el modelo
/// `account.fiscal.position.tax` fue ELIMINADO del core (verificado en vivo
/// contra erp1.tecnosmart.com.ec, 19.5a1+e, julio 2026), así que las filas
/// se SINTETIZAN localmente a partir de `account.tax.fiscal_position_ids` +
/// `account.tax.original_tax_ids` (ver la documentación completa en
/// `FiscalPositionTax.synthesizeFromAccountTax` en
/// `models/taxes/fiscal_position.model.dart`).
class FiscalPositionTaxManager {
  final AppDatabase _db;

  FiscalPositionTaxManager(this._db);

  String get odooModel => FiscalPositionTax.odooModel;

  List<String> get odooFields => FiscalPositionTax.odooFields;

  /// Upsert fiscal position tax to local database
  Future<void> upsertLocal(FiscalPositionTax record) async {
    if (record.positionId == 0 || record.taxSrcId == 0) return;

    final companion = record.toCompanion();

    final existing = await (_db.select(_db.accountFiscalPositionTax)
          ..where((t) => t.odooId.equals(record.odooId)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.accountFiscalPositionTax)
            ..where((t) => t.odooId.equals(record.odooId)))
          .write(companion);
    } else {
      await _db.into(_db.accountFiscalPositionTax).insert(companion);
    }
  }

  /// Batch upsert de mapeos de impuestos por posición fiscal — UNA sola
  /// transacción Drift para todo el lote, en vez de 2 queries (select +
  /// update/insert) POR REGISTRO como hace [upsertLocal]. Mismo patrón que
  /// `CountryStateManager.upsertLocalBatch`/`CountryManager.upsertLocalBatch`.
  ///
  /// El `ON CONFLICT` usa `odooId` como target — para las filas sintéticas
  /// esto funciona igual que para un ID real, porque
  /// `FiscalPositionTax.syntheticOdooId` es determinístico (misma terna
  /// position/src/dest -> mismo odooId siempre), así que un re-sync
  /// actualiza la fila existente (ej. refresca `write_date`) en vez de
  /// duplicarla.
  Future<void> upsertLocalBatch(List<FiscalPositionTax> records) async {
    final valid =
        records.where((r) => r.positionId != 0 && r.taxSrcId != 0).toList();
    if (valid.isEmpty) return;

    await _db.batch((batch) {
      for (final record in valid) {
        final companion = record.toCompanion();
        batch.insert(
          _db.accountFiscalPositionTax,
          companion,
          onConflict: drift.DoUpdate(
            (_) => companion,
            target: [_db.accountFiscalPositionTax.odooId],
          ),
        );
      }
    });
  }

  /// Reemplaza TODO el contenido de la tabla local con el set sintetizado
  /// dado, en una única transacción atómica (delete-all + batch insert).
  ///
  /// ## Por qué full-replace y no upsert incremental
  ///
  /// Las filas sintéticas no tienen ID de servidor propio que permita
  /// detectar "borrados" — si un mapeo deja de aplicar (ej. un admin quita
  /// una posición fiscal de `fiscal_position_ids`, o un tax de
  /// `original_tax_ids`), un upsert incremental basado en `write_date`
  /// jamás detectaría ni borraría la fila sintética obsoleta, dejando un
  /// mapeo de impuestos INCORRECTO aplicándose indefinidamente en
  /// `tax_calculator_service`. Esta tabla es pequeña (sólo taxes que actúan
  /// como destino de al menos una posición fiscal — normalmente unas pocas
  /// decenas incluso en instalaciones grandes), así que reconstruirla
  /// completa en cada sync es barato y elimina ese riesgo de raíz.
  ///
  /// La transacción Drift (`_db.transaction`) garantiza que no hay una
  /// ventana donde la tabla esté vacía para lectores concurrentes
  /// (`tax_calculator_service` o cualquier `.watch()`) — el delete y el
  /// insert se confirman juntos como una sola unidad atómica.
  Future<void> replaceAllLocal(List<FiscalPositionTax> records) async {
    final valid =
        records.where((r) => r.positionId != 0 && r.taxSrcId != 0).toList();

    await _db.transaction(() async {
      await _db.delete(_db.accountFiscalPositionTax).go();
      if (valid.isEmpty) return;

      await _db.batch((batch) {
        for (final record in valid) {
          batch.insert(_db.accountFiscalPositionTax, record.toCompanion());
        }
      });
    });
  }

  /// Get tax mappings for a fiscal position
  Future<List<AccountFiscalPositionTaxData>> getByPositionId(
      int positionId) async {
    return (_db.select(_db.accountFiscalPositionTax)
          ..where((t) => t.positionId.equals(positionId)))
        .get();
  }
}
