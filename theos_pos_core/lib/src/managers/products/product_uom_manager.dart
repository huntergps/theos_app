/// ProductUomManager extensions - Business methods beyond generated CRUD
///
/// The base ProductUomManager is generated in product_uom.model.g.dart.
/// This file adds business-specific query methods.
library;

import '../../models/products/product_uom.model.dart';

/// Extension methods for ProductUomManager
extension ProductUomManagerBusiness on ProductUomManager {
  /// Find ProductUom by barcode
  Future<ProductUom?> findByBarcode(String barcode) async {
    final results = await searchLocal(
      domain: [
        ['barcode', '=', barcode]
      ],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Get all UoMs for a specific product
  Future<List<ProductUom>> getForProduct(int productId) async {
    return searchLocal(domain: [
      ['product_id', '=', productId]
    ]);
  }
}
