/// Pricelist Managers
///
/// PricelistManager is generated in pricelist.model.g.dart (via @OdooModel).
/// This file keeps PricelistItemManager (not yet migrated to @OdooModel).
library;

import 'package:drift/drift.dart' as drift;
import 'package:odoo_sdk/odoo_sdk.dart';

import '../../database/database.dart';
import '../../models/prices/pricelist.model.dart';

/// Manager for PricelistItem model using existing ProductPricelistItem table.
/// Uses GenericDriftOperations mixin for common CRUD operations.
class PricelistItemManager extends OdooModelManager<PricelistItem>
    with GenericDriftOperations<PricelistItem> {
  final AppDatabase _appDb;

  PricelistItemManager(this._appDb);

  // ═══════════════════════════════════════════════════════════════════════════
  // GenericDriftOperations Requirements
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  AppDatabase get database => _appDb;

  @override
  drift.TableInfo get table => _appDb.productPricelistItem;

  @override
  dynamic createDriftCompanion(PricelistItem record) {
    return record.toCompanion();
  }

  @override
  String get odooModel => 'product.pricelist.item';

  @override
  String get tableName => 'product_pricelist_item';

  @override
  List<String> get odooFields => [
        'id',
        'pricelist_id',
        'product_tmpl_id',
        'product_id',
        'categ_id',
        'applied_on',
        'min_quantity',
        'date_start',
        'date_end',
        'compute_price',
        'fixed_price',
        'percent_price',
        'sequence',
        'uom_id',
        'base',
        'base_pricelist_id',
        'price_discount',
        'price_surcharge',
        'price_round',
        'price_min_margin',
        'price_max_margin',
        'write_date',
      ];

  // ═══════════════════════════════════════════════════════════════════════════
  // Conversion Methods
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  PricelistItem fromOdoo(Map<String, dynamic> data) {
    return PricelistItem.fromOdoo(data);
  }

  @override
  Map<String, dynamic> toOdoo(PricelistItem record) {
    return {
      'pricelist_id': record.pricelistId,
      if (record.productTmplId != null) 'product_tmpl_id': record.productTmplId,
      if (record.productId != null) 'product_id': record.productId,
      if (record.categId != null) 'categ_id': record.categId,
      'applied_on': record.appliedOn,
      'min_quantity': record.minQuantity,
      if (record.dateStart != null)
        'date_start': record.dateStart!.toIso8601String(),
      if (record.dateEnd != null) 'date_end': record.dateEnd!.toIso8601String(),
      'compute_price': record.computePrice,
      'fixed_price': record.fixedPrice,
      'percent_price': record.percentPrice,
    };
  }

  @override
  PricelistItem fromDrift(dynamic row) {
    return PricelistItem.fromDatabase(row as ProductPricelistItemData);
  }

  @override
  int getId(PricelistItem record) => record.odooId;

  @override
  String? getUuid(PricelistItem record) => null;

  @override
  PricelistItem withIdAndUuid(PricelistItem record, int id, String uuid) {
    return record.copyWith(odooId: id);
  }

  @override
  PricelistItem withSyncStatus(PricelistItem record, bool isSynced) {
    return record;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PricelistItem-specific overrides
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<PricelistItem?> readLocalByUuid(String uuid) async => null; // No UUID support

  @override
  Future<List<PricelistItem>> getUnsyncedRecords() async => []; // Always synced

  // ═══════════════════════════════════════════════════════════════════════════
  // Business Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all items for a specific pricelist
  Future<List<PricelistItem>> getForPricelist(int pricelistId) async {
    final query = _appDb.select(_appDb.productPricelistItem)
      ..where((t) => t.pricelistId.equals(pricelistId));
    final results = await query.get();
    return results.map((row) => fromDrift(row)).toList();
  }

  /// Get items applicable to a specific product
  Future<List<PricelistItem>> getForProduct(int productId) async {
    final query = _appDb.select(_appDb.productPricelistItem)
      ..where((t) => t.productId.equals(productId));
    final results = await query.get();
    return results.map((row) => fromDrift(row)).toList();
  }
}
