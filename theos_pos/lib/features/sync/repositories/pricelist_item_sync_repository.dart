/// PricelistItemSyncRepository - Sync de líneas de lista de precios por producto
///
/// Extraído de CatalogSyncRepository (Fase E2).
library;

import 'package:drift/drift.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

/// Repository for syncing/deleting `product.pricelist.item` records tied to
/// a specific product (triggered from WebSocket catalog events).
class PricelistItemSyncRepository {
  final AppDatabase _appDb;
  final OdooClient? odooClient;

  /// Callback para resolver el `product_tmpl_id` de un producto local — se
  /// mantiene como referencia al facade (`CatalogSyncRepository.getLocalProductById`)
  /// porque ese método no se movió (sigue siendo parte de la sección "Local
  /// Data Access", fuera del alcance de este split).
  final Future<ProductProductData?> Function(int odooId) getLocalProductById;

  PricelistItemSyncRepository({
    required AppDatabase appDb,
    required this.odooClient,
    required this.getLocalProductById,
  }) : _appDb = appDb;

  bool get isOnline => odooClient != null;

  /// Delete a pricelist item from local database
  Future<void> deletePricelistItem(int pricelistItemId) async {
    try {
      await (_appDb.delete(
        _appDb.productPricelistItem,
      )..where((t) => t.odooId.equals(pricelistItemId))).go();
    } catch (e) {
      logger.e(
        '[CatalogSync]',
        'Error deleting pricelist item $pricelistItemId',
        e,
      );
    }
  }

  /// Sync pricelist items for a specific product
  Future<void> syncPricelistItemsForProduct(int productId) async {
    if (!isOnline) return;

    try {
      // Get product's template ID
      final product = await getLocalProductById(productId);
      final productTmplId = product?.productTmplId;

      // Fetch pricelist items for this product
      final domain = [
        '|',
        ['product_id', '=', productId],
        ['product_tmpl_id', '=', productTmplId ?? productId],
      ];

      final result = await odooClient!.searchRead(
        model: 'product.pricelist.item',
        domain: domain,
        fields: [
          'id',
          'pricelist_id',
          'product_id',
          'product_tmpl_id',
          'compute_price',
          'fixed_price',
          'percent_price',
          'min_quantity',
          'date_start',
          'date_end',
          'applied_on',
        ],
      );

      for (final item in result) {
        final pricelistIdRaw = item['pricelist_id'];
        final pricelistId =
            (pricelistIdRaw is List && pricelistIdRaw.isNotEmpty)
            ? pricelistIdRaw.first as int
            : 0;

        final computePrice = item['compute_price'] as String? ?? 'fixed';
        final fixedPrice = (item['fixed_price'] as num?)?.toDouble() ?? 0.0;
        final percentPrice = (item['percent_price'] as num?)?.toDouble() ?? 0.0;
        final minQuantity = (item['min_quantity'] as num?)?.toDouble() ?? 0.0;
        final appliedOn = item['applied_on'] as String? ?? '3_global';

        await _appDb
            .into(_appDb.productPricelistItem)
            .insertOnConflictUpdate(
              ProductPricelistItemCompanion(
                odooId: Value(item['id'] as int),
                pricelistId: Value(pricelistId),
                productId: Value(
                  item['product_id'] is List
                      ? (item['product_id'] as List).first as int
                      : null,
                ),
                productTmplId: Value(
                  item['product_tmpl_id'] is List
                      ? (item['product_tmpl_id'] as List).first as int
                      : null,
                ),
                computePrice: Value(computePrice),
                fixedPrice: Value(fixedPrice),
                percentPrice: Value(percentPrice),
                minQuantity: Value(minQuantity),
                appliedOn: Value(appliedOn),
              ),
            );
      }
    } catch (e) {
      logger.e(
        '[CatalogSync]',
        'Error syncing pricelist items for product $productId',
        e,
      );
    }
  }
}
