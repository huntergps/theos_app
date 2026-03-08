import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

/// Repositorio consolidado de productos - OFFLINE-FIRST
///
/// Maneja búsqueda de productos, consultas de stock, y llamadas onchange.
/// Reemplaza el ProductRepository anterior con soporte para modelos Freezed.
///
/// Uso:
/// ```dart
/// final repository = ref.read(productRepositoryProvider);
///
/// // Buscar productos
/// final products = await repository.searchProducts('termo');
///
/// // Obtener producto por ID
/// final product = await repository.getById(42);
///
/// // Obtener producto por barcode
/// final product = await repository.getByBarcode('1234567890123');
/// ```
class ProductRepository {
  final AppDatabase _db;
  final OdooClient? _odooClient;

  ProductRepository({
    required AppDatabase db,
    OdooClient? odooClient,
  })  : _db = db,
        _odooClient = odooClient;

  /// Indica si hay conexión con Odoo
  bool get isOnline => _odooClient != null;

  // ============ Product Search ============

  /// Busca productos — offline-first con fallback a Odoo
  ///
  /// 1. Busca en base de datos local (Drift)
  /// 2. Si no encuentra resultados y hay conexión, busca en Odoo
  /// 3. Guarda resultados de Odoo en local para futuras búsquedas offline
  /// 4. Retorna resultados combinados (local + Odoo sin duplicados)
  Future<List<Product>> searchProducts(String query, {int limit = 50}) async {
    try {
      logger.d('[ProductRepository]', 'Searching products: "$query"');

      if (query.isEmpty) return [];

      // 1. Buscar en local primero
      final localResults = await _searchProductsLocal(query, limit: limit);

      // 2. Si hay pocos resultados y estamos online, buscar en Odoo
      if (localResults.length < 3 && isOnline && query.length >= 2) {
        try {
          final odooResults = await _searchProductsOdoo(query, limit: limit);
          if (odooResults.isNotEmpty) {
            // 3. Guardar en local para futuras búsquedas offline
            await productManager.upsertLocalBatch(odooResults);
            logger.d(
              '[ProductRepository]',
              'Saved ${odooResults.length} products from Odoo to local DB',
            );

            // 4. Combinar resultados sin duplicados
            final existingIds = localResults.map((p) => p.id).toSet();
            final merged = [...localResults];
            for (final product in odooResults) {
              if (!existingIds.contains(product.id)) {
                merged.add(product);
                if (merged.length >= limit) break;
              }
            }
            return merged;
          }
        } catch (e) {
          logger.w('[ProductRepository]', 'Odoo search failed, using local: $e');
        }
      }

      return localResults;
    } catch (e, stack) {
      logger.e('[ProductRepository]', 'Error searching products: $e', e, stack);
      return [];
    }
  }

  /// Búsqueda local pura en Drift
  Future<List<Product>> _searchProductsLocal(String query, {int limit = 50}) async {
    final pattern = '%${query.toLowerCase()}%';

    final results = await (_db.select(_db.productProduct)
          ..where((t) => t.active.equals(true))
          ..where((t) => t.saleOk.equals(true))
          ..where(
            (t) =>
                t.name.lower().like(pattern) |
                t.displayName.lower().like(pattern) |
                t.defaultCode.lower().like(pattern) |
                t.barcode.like(pattern),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)])
          ..limit(limit))
        .get();

    final products = results.map((p) => productManager.fromDrift(p)).toList();
    logger.d('[ProductRepository]', 'Found ${products.length} products (local)');
    return products;
  }

  /// Búsqueda en Odoo — retorna productos parseados
  Future<List<Product>> _searchProductsOdoo(String query, {int limit = 50}) async {
    final response = await _odooClient!.searchRead(
      model: 'product.product',
      fields: _productSearchFields,
      domain: [
        '&',
        ['active', '=', true],
        ['sale_ok', '=', true],
        '|', '|', '|',
        ['name', 'ilike', query],
        ['display_name', 'ilike', query],
        ['default_code', 'ilike', query],
        ['barcode', 'ilike', query],
      ],
      limit: limit,
    );

    logger.d('[ProductRepository]', 'Found ${response.length} products (Odoo)');
    return response.map((r) => productManager.fromOdoo(r)).toList();
  }

  /// Campos para búsqueda de productos en Odoo
  static const _productSearchFields = [
    'id', 'name', 'display_name', 'default_code', 'barcode',
    'list_price', 'standard_price', 'qty_available', 'free_qty',
    'type', 'tracking', 'is_storable', 'uom_id', 'categ_id',
    'taxes_id', 'description_sale', 'sale_ok', 'active',
    'product_tmpl_id',
  ];

  /// Busca productos usando búsqueda fuzzy (tolerante a errores tipográficos)
  ///
  /// Utiliza distancia de Levenshtein para encontrar coincidencias aproximadas.
  /// Ideal para búsquedas donde el usuario puede cometer errores de escritura.
  ///
  /// [query] - Término de búsqueda
  /// [limit] - Máximo de resultados (default: 50)
  /// [threshold] - Similitud mínima 0.0-1.0 (default: 0.3 = 30%)
  ///
  /// Ejemplo: buscar "terma" encontrará "termo", "termos", etc.
  Future<List<FuzzySearchResult<Product>>> searchProductsFuzzy(
    String query, {
    int limit = 50,
    double threshold = 0.3,
  }) async {
    try {
      logger.d('[ProductRepository]', 'Fuzzy searching products: "$query"');

      if (query.isEmpty) return [];

      // Obtener todos los productos activos y vendibles
      final allProducts = await (_db.select(_db.productProduct)
            ..where((t) => t.active.equals(true))
            ..where((t) => t.saleOk.equals(true)))
          .get();

      final products = allProducts.map((p) => productManager.fromDrift(p)).toList();

      // Aplicar búsqueda fuzzy
      final results = FuzzySearch.search<Product>(
        query: query,
        items: products,
        getSearchableStrings: (p) => [
          p.name,
          p.displayName,
          p.defaultCode ?? '',
          p.barcode ?? '',
        ],
        threshold: threshold,
        limit: limit,
      );

      logger.d(
        '[ProductRepository]',
        'Fuzzy search found ${results.length} products '
            '(best score: ${results.isNotEmpty ? results.first.scorePercent : 0}%)',
      );

      return results;
    } catch (e, stack) {
      logger.e(
        '[ProductRepository]',
        'Error in fuzzy search: $e',
        e,
        stack,
      );
      return [];
    }
  }

  /// Búsqueda combinada: primero exacta/LIKE, luego fuzzy si no hay resultados
  ///
  /// Esta es la búsqueda recomendada para UI ya que combina velocidad
  /// (búsqueda SQL) con tolerancia a errores (fuzzy).
  Future<List<Product>> searchProductsSmart(
    String query, {
    int limit = 50,
    double fuzzyThreshold = 0.4,
  }) async {
    if (query.isEmpty) return [];

    // Primero intentar búsqueda exacta (más rápida)
    var results = await searchProducts(query, limit: limit);

    // Si hay pocos resultados, complementar con fuzzy
    if (results.length < 5 && query.length >= 3) {
      logger.d(
        '[ProductRepository]',
        'Few results (${results.length}), trying fuzzy search...',
      );

      final fuzzyResults = await searchProductsFuzzy(
        query,
        limit: limit - results.length,
        threshold: fuzzyThreshold,
      );

      // Agregar solo productos que no estén ya en results
      final existingIds = results.map((p) => p.id).toSet();
      for (final fuzzyResult in fuzzyResults) {
        if (!existingIds.contains(fuzzyResult.item.id)) {
          results.add(fuzzyResult.item);
          if (results.length >= limit) break;
        }
      }
    }

    return results;
  }

  /// Busca productos con información enriquecida de impuestos
  ///
  /// Retorna lista de mapas con datos adicionales de impuestos
  Future<List<Map<String, dynamic>>> searchProductsEnriched(
    String query, {
    int limit = 50,
  }) async {
    try {
      final products = await searchProducts(query, limit: limit);

      // Recolectar todos los IDs de impuestos únicos
      final allTaxIds = <int>{};
      for (final p in products) {
        allTaxIds.addAll(p.taxIdsList);
      }

      // Obtener detalles de impuestos de la base local
      final taxMap = <int, AccountTaxData>{};
      if (allTaxIds.isNotEmpty) {
        try {
          final taxes = await (_db.select(_db.accountTax)
                ..where((t) => t.odooId.isIn(allTaxIds.toList())))
              .get();
          for (final tax in taxes) {
            taxMap[tax.odooId] = tax;
          }
        } catch (e) {
          logger.w('[ProductRepository]', 'Could not fetch local taxes: $e');
        }
      }

      // Convertir a formato enriquecido
      return products.map((p) {
        final taxInfoList = <Map<String, dynamic>>[];
        final taxNames = <String>[];
        double totalTaxPercent = 0;

        for (final taxId in p.taxIdsList) {
          final tax = taxMap[taxId];
          if (tax != null) {
            taxInfoList.add({
              'id': tax.odooId,
              'name': tax.name,
              'amount': tax.amount,
              'amount_type': tax.amountType,
            });
            taxNames.add(tax.name);
            if (tax.amountType == 'percent') {
              totalTaxPercent += tax.amount;
            }
          }
        }

        return {
          'id': p.id,
          'name': p.name,
          'display_name': p.displayName,
          'default_code': p.defaultCode,
          'barcode': p.barcode,
          'list_price': p.listPrice,
          'standard_price': p.standardPrice,
          'type': p.type.name,
          'uom_id': p.uomId != null ? [p.uomId, p.uomName ?? ''] : false,
          'categ_id': p.categId != null ? [p.categId, p.categName ?? ''] : false,
          'taxes_id': p.taxIdsList,
          'tax_info': taxInfoList,
          'tax_names': taxNames.join(', '),
          'tax_percent': totalTaxPercent,
          'qty_available': p.qtyAvailable,
          'virtual_available': p.virtualAvailable,
          'image_128': p.image128,
          'description_sale': p.descriptionSale,
        };
      }).toList();
    } catch (e, stack) {
      logger.e(
        '[ProductRepository]',
        'Error searching products enriched: $e',
        e,
        stack,
      );
      return [];
    }
  }

  // ============ Product by ID ============

  /// Obtiene producto por odooId desde base local
  Future<Product?> getById(int productId) async {
    try {
      return await productManager.readLocal(productId);
    } catch (e, stack) {
      logger.e('[ProductRepository]', 'Error getting product $productId', e, stack);
      return null;
    }
  }

  /// Obtiene productos por lista de IDs
  Future<List<Product>> getByIds(List<int> productIds) async {
    if (productIds.isEmpty) return [];

    try {
      final results = <Product>[];
      for (final id in productIds) {
        final product = await productManager.readLocal(id);
        if (product != null) results.add(product);
      }
      return results;
    } catch (e, stack) {
      logger.e('[ProductRepository]', 'Error getting products by IDs', e, stack);
      return [];
    }
  }

  // ============ Product by Barcode/Code ============

  /// Obtiene producto por código de barras
  Future<Product?> getByBarcode(String barcode) async {
    if (barcode.isEmpty) return null;

    try {
      final result = await (_db.select(_db.productProduct)
            ..where((t) => t.barcode.equals(barcode))
            ..where((t) => t.active.equals(true)))
          .getSingleOrNull();

      if (result != null) {
        return productManager.fromDrift(result);
      }
      return null;
    } catch (e, stack) {
      logger.e('[ProductRepository]', 'Error getting product by barcode', e, stack);
      return null;
    }
  }

  /// Obtiene producto por código interno (default_code)
  Future<Product?> getByCode(String code) async {
    if (code.isEmpty) return null;

    try {
      final result = await (_db.select(_db.productProduct)
            ..where((t) => t.defaultCode.lower().equals(code.toLowerCase()))
            ..where((t) => t.active.equals(true)))
          .getSingleOrNull();

      if (result != null) {
        return productManager.fromDrift(result);
      }
      return null;
    } catch (e, stack) {
      logger.e('[ProductRepository]', 'Error getting product by code', e, stack);
      return null;
    }
  }

  // ============ Product Details (Odoo integration) ============

  /// Obtiene información detallada del producto
  /// Primero busca en local, luego intenta actualizar desde Odoo si hay conexión
  Future<Map<String, dynamic>?> getDetailedInfo(int productId) async {
    try {
      // Primero intentar obtener de la base de datos local
      final localProduct = await _getProductMapFromLocal(productId);

      // Si hay conexión, intentar obtener datos actualizados de Odoo
      if (_odooClient != null) {
        try {
          final result = await _odooClient.searchRead(
            model: 'product.product',
            fields: [
              'id',
              'name',
              'display_name',
              'default_code',
              'barcode',
              'list_price',
              'standard_price',
              'qty_available',
              'free_qty',
              'type',
              'tracking',
              'is_storable',
              'uom_id',
              'categ_id',
              'taxes_id',
              'description_sale',
              'image_128',
              'uom_ids',
              'product_tmpl_id',
            ],
            domain: [
              ['id', '=', productId],
            ],
            limit: 1,
          );

          if (result.isNotEmpty) {
            return result.first;
          }
        } catch (e) {
          logger.w(
            '[ProductRepository]',
            'Error getting product from Odoo, using local: $e',
          );
        }
      }

      return localProduct;
    } catch (e, stack) {
      logger.e('[ProductRepository]', 'Error getting detailed info', e, stack);
      return null;
    }
  }

  /// Obtiene producto desde base local en formato Map
  Future<Map<String, dynamic>?> _getProductMapFromLocal(int productId) async {
    try {
      final result = await _db
          .customSelect(
            '''
        SELECT
          odoo_id as id,
          name,
          display_name,
          default_code,
          barcode,
          list_price,
          standard_price,
          qty_available,
          virtual_available as free_qty,
          type,
          tracking,
          uom_id,
          uom_name,
          categ_id,
          categ_name,
          taxes_id,
          description_sale,
          image128,
          product_tmpl_id,
          uom_ids
        FROM product_product
        WHERE odoo_id = ?
        LIMIT 1
      ''',
            variables: [Variable.withInt(productId)],
          )
          .get();

      if (result.isEmpty) return null;

      final row = result.first;

      // Parse uom_ids from comma-separated string
      List<int> uomIds = [];
      final uomIdsStr = row.read<String?>('uom_ids');
      if (uomIdsStr != null && uomIdsStr.isNotEmpty) {
        uomIds = uomIdsStr
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>()
            .toList();
      }

      return {
        'id': row.read<int>('id'),
        'name': row.read<String>('name'),
        'display_name': row.read<String?>('display_name') ?? row.read<String>('name'),
        'default_code': row.read<String?>('default_code'),
        'barcode': row.read<String?>('barcode'),
        'list_price': row.read<double?>('list_price') ?? 0.0,
        'standard_price': row.read<double?>('standard_price') ?? 0.0,
        'qty_available': row.read<double?>('qty_available') ?? 0.0,
        'free_qty': row.read<double?>('free_qty') ?? 0.0,
        'type': row.read<String?>('type') ?? 'consu',
        'tracking': row.read<String?>('tracking') ?? 'none',
        'uom_id': row.read<int?>('uom_id') != null
            ? [row.read<int?>('uom_id'), row.read<String?>('uom_name')]
            : null,
        'categ_id': row.read<int?>('categ_id') != null
            ? [row.read<int?>('categ_id'), row.read<String?>('categ_name')]
            : null,
        'taxes_id': _parseIntList(row.read<String?>('taxes_id')),
        'description_sale': row.read<String?>('description_sale'),
        'image_128': row.read<String?>('image_128'),
        'product_tmpl_id': row.read<int?>('product_tmpl_id'),
        'uom_ids': uomIds,
      };
    } catch (e, stack) {
      logger.e('[ProductRepository]', 'Error getting product from local DB', e, stack);
      return null;
    }
  }

  // ============ Product UoMs ============

  /// Obtiene los UoMs del producto desde la tabla product_uom
  Future<List<ProductUom>> getProductUoms(int productId) async {
    try {
      return await productUomManager.searchLocal(
        domain: [['product_id', '=', productId]],
      );
    } catch (e, stack) {
      logger.e('[ProductRepository]', 'Error getting product UoMs', e, stack);
      return [];
    }
  }

  /// Obtiene packaging/barcodes del producto - offline-first
  ///
  /// Tries local product_uom table first, then fetches from Odoo if online.
  Future<List<Map<String, dynamic>>> getPackagingBarcodes(int productId) async {
    // Try local first
    try {
      final localUoms = await getProductUoms(productId);
      if (localUoms.isNotEmpty) {
        final localMaps = localUoms
            .where((u) => u.barcode.isNotEmpty)
            .map((u) => <String, dynamic>{
                  'id': u.id,
                  'uom_id': u.uomId,
                  'name': u.uomName ?? '',
                  'barcode': u.barcode,
                })
            .toList();
        if (localMaps.isNotEmpty || _odooClient == null) return localMaps;
      }
    } catch (e) {
      logger.w('[ProductRepository]', 'Error getting local packaging barcodes: $e');
    }

    if (_odooClient == null) return [];

    try {
      final packagingBarcodes = await _odooClient.searchRead(
        model: 'product.uom',
        fields: ['id', 'uom_id', 'barcode'],
        domain: [
          ['product_id', '=', productId],
        ],
      );

      logger.d(
        '[ProductRepository]',
        'Fetched ${packagingBarcodes.length} packaging barcodes',
      );

      final result = <Map<String, dynamic>>[];
      for (final pkg in packagingBarcodes) {
        final uomData = pkg['uom_id'];
        int? uomId;
        String uomName = '';

        if (uomData is List && uomData.length >= 2) {
          uomId = uomData[0] as int;
          uomName = uomData[1] as String;
        }

        if (uomId != null) {
          result.add({
            'id': pkg['id'],
            'uom_id': uomId,
            'name': uomName,
            'barcode': pkg['barcode'],
          });
        }
      }

      return result;
    } catch (e, stack) {
      logger.e('[ProductRepository]', 'Error getting packaging barcodes', e, stack);
      return [];
    }
  }

  // ============ Stock Queries ============

  /// Cache key prefix for per-product warehouse stock JSON in SyncMetadata.
  static const String _stockCachePrefix = 'stock_by_warehouse_';

  /// Obtiene stock por almacén para un producto
  /// Llama al método get_stock_by_warehouse de Odoo
  ///
  /// OFFLINE-FIRST with per-warehouse caching:
  /// - Online: fetches real-time stock from Odoo RPC, caches the full response
  ///   as JSON in SyncMetadata keyed by product ID.
  /// - Offline/Error: returns the last cached per-warehouse data. Falls back to
  ///   aggregate product qty_available if no cached data exists.
  Future<List<Map<String, dynamic>>> getStockByWarehouse(int productId) async {
    if (_odooClient == null) {
      return _getStockFromCache(productId);
    }

    try {
      logger.d(
        '[ProductRepository]',
        'Getting stock by warehouse for product $productId',
      );

      final result = await _odooClient.crud.call(
        model: 'product.template',
        method: 'get_stock_by_warehouse',
        args: [productId, null, true],
      );

      if (result is List) {
        final list = <Map<String, dynamic>>[];
        for (final item in result) {
          if (item is Map) {
            list.add(Map<String, dynamic>.from(item));
          }
        }
        logger.d(
          '[ProductRepository]',
          'Stock by warehouse: ${list.length} warehouses',
        );

        // Cache the full API response for offline use
        _cacheStockByWarehouse(productId, list);

        return list;
      }

      return [];
    } catch (e, stack) {
      logger.e('[ProductRepository]', 'Error getting stock by warehouse', e, stack);
      // Fallback to cached per-warehouse data on server error
      return _getStockFromCache(productId);
    }
  }

  /// Caches the per-warehouse stock API response as JSON in SyncMetadata.
  Future<void> _cacheStockByWarehouse(
    int productId,
    List<Map<String, dynamic>> stockData,
  ) async {
    try {
      final key = '$_stockCachePrefix$productId';
      final jsonValue = jsonEncode(stockData);
      await _db
          .into(_db.syncMetadata)
          .insertOnConflictUpdate(
            SyncMetadataCompanion.insert(key: key, value: jsonValue),
          );
    } catch (e) {
      logger.w('[ProductRepository]', 'Error caching stock by warehouse: $e');
    }
  }

  /// Returns cached per-warehouse stock from SyncMetadata, or falls back to
  /// the aggregate qty_available on the product record.
  Future<List<Map<String, dynamic>>> _getStockFromCache(int productId) async {
    try {
      final key = '$_stockCachePrefix$productId';
      final row = await (_db.select(_db.syncMetadata)
            ..where((tbl) => tbl.key.equals(key)))
          .getSingleOrNull();

      if (row != null) {
        final decoded = jsonDecode(row.value);
        if (decoded is List) {
          final list = <Map<String, dynamic>>[];
          for (final item in decoded) {
            if (item is Map) {
              final entry = Map<String, dynamic>.from(item);
              entry['is_cached'] = true;
              list.add(entry);
            }
          }
          if (list.isNotEmpty) {
            logger.d(
              '[ProductRepository]',
              'Returning cached stock for product $productId: '
              '${list.length} warehouses',
            );
            return list;
          }
        }
      }
    } catch (e) {
      logger.w('[ProductRepository]', 'Error reading stock cache: $e');
    }

    // Ultimate fallback: aggregate product qty as a single entry
    try {
      final product = await productManager.readLocal(productId);
      if (product != null) {
        return [
          {
            'warehouse': 'Local (offline)',
            'qty_available': product.qtyAvailable,
            'virtual_available': product.virtualAvailable,
            'is_offline': true,
          },
        ];
      }
    } catch (e) {
      logger.w('[ProductRepository]', 'Error getting local stock fallback: $e');
    }
    return [];
  }

  // ============ Product History ============

  /// Obtiene historial de compras del producto para un cliente
  ///
  /// NOTE: Server-only - sale order line history is not cached locally.
  /// Requires live connection to Odoo to query sale.order.line records.
  Future<List<Map<String, dynamic>>> getHistoryForCustomer({
    required int productId,
    required int partnerId,
  }) async {
    if (_odooClient == null) return [];

    try {
      return await _odooClient.searchRead(
        model: 'sale.order.line',
        fields: [
          'id',
          'order_id',
          'product_uom_qty',
          'price_unit',
          'discount',
          'price_subtotal',
        ],
        domain: [
          ['product_id', '=', productId],
          ['order_partner_id', '=', partnerId],
          ['state', 'in', ['sale', 'done']],
        ],
        order: 'create_date desc',
        limit: 10,
      );
    } catch (e, stack) {
      logger.e('[ProductRepository]', 'Error getting product history', e, stack);
      return [];
    }
  }

  // ============ Tax & UoM Remote Lookups ============

  /// Obtiene nombres de impuestos por IDs - offline-first
  ///
  /// Tries local account_tax table first, then fetches from Odoo if online.
  Future<List<String>> getTaxNames(List<int> taxIds) async {
    if (taxIds.isEmpty) return [];

    // Try local first
    try {
      final localTaxes = await (_db.select(_db.accountTax)
            ..where((t) => t.odooId.isIn(taxIds)))
          .get();
      if (localTaxes.isNotEmpty) {
        return localTaxes.map((t) => t.name).toList();
      }
    } catch (e) {
      logger.w('[ProductRepository]', 'Error getting local tax names: $e');
    }

    // Try server if available
    if (_odooClient == null) return [];

    try {
      final result = await _odooClient.searchRead(
        model: 'account.tax',
        fields: ['id', 'name'],
        domain: [
          ['id', 'in', taxIds],
        ],
      );

      return result.map((t) => t['name'] as String? ?? '').toList();
    } catch (e, stack) {
      logger.e('[ProductRepository]', 'Error getting tax names', e, stack);
      return [];
    }
  }

  /// Obtiene UoMs por IDs - offline-first
  ///
  /// Tries local uom_uom table first, then fetches from Odoo if online.
  Future<List<Map<String, dynamic>>> getUomsFromOdoo(List<int> uomIds) async {
    if (uomIds.isEmpty) return [];

    // Try local first
    try {
      final localUoms = await (_db.select(_db.uomUom)
            ..where((t) => t.odooId.isIn(uomIds)))
          .get();
      if (localUoms.isNotEmpty) {
        return localUoms.map((u) => <String, dynamic>{
          'id': u.odooId,
          'name': u.name,
          'factor': u.factor,
          'relative_factor': u.factorInv,
        }).toList();
      }
    } catch (e) {
      logger.w('[ProductRepository]', 'Error getting local UoMs: $e');
    }

    // Try server if available
    if (_odooClient == null) return [];

    try {
      final result = await _odooClient.searchRead(
        model: 'uom.uom',
        fields: ['id', 'name', 'factor', 'relative_factor'],
        domain: [
          ['id', 'in', uomIds],
        ],
      );

      logger.d('[ProductRepository]', 'Fetched ${result.length} UoMs from Odoo');
      return result;
    } catch (e, stack) {
      logger.e('[ProductRepository]', 'Error getting UoMs from Odoo', e, stack);
      return [];
    }
  }

  // ============ Onchange Methods ============

  /// Llama onchange para producto para obtener defaults (precio, UoM, impuestos)
  ///
  /// OFFLINE-FIRST: Intenta servidor primero; si offline o falla,
  /// calcula valores desde datos locales del producto.
  Future<Map<String, dynamic>?> onchangeProduct({
    required int orderId,
    required int productId,
    int? partnerId,
    int? pricelistId,
    double qty = 1.0,
  }) async {
    // Try server first if online
    if (_odooClient != null) {
      try {
        logger.d(
          '[ProductRepository]',
          'Calling product_id_change for product $productId...',
        );

        final result = await _odooClient.call(
          model: 'sale.order.line',
          method: 'onchange',
          args: [
            [],
            {
              'order_id': orderId,
              'product_id': productId,
              'product_uom_qty': qty,
            },
            ['product_id'],
          ],
          kwargs: {},
        );

        if (result is Map<String, dynamic> && result.containsKey('value')) {
          logger.i(
            '[ProductRepository]',
            'Product onchange returned: ${result['value']}',
          );
          return result['value'] as Map<String, dynamic>;
        }
      } catch (e) {
        logger.w(
          '[ProductRepository]',
          'Server onchange failed, falling back to local: $e',
        );
      }
    }

    // Local fallback: compute from local product data
    try {
      final product = await productManager.readLocal(productId);
      if (product == null) {
        logger.w('[ProductRepository]', 'Product $productId not found locally for onchange fallback');
        return null;
      }

      logger.d(
        '[ProductRepository]',
        'Using local fallback for product onchange: ${product.name}',
      );

      return {
        'name': product.descriptionSale ?? product.name,
        'product_uom': product.uomId != null
            ? [product.uomId, product.uomName ?? '']
            : null,
        'product_uom_qty': qty,
        'price_unit': product.listPrice,
        'tax_id': product.taxIdsList,
      };
    } catch (e, stack) {
      logger.e('[ProductRepository]', 'Error in local onchange fallback', e, stack);
    }
    return null;
  }

  /// Llama onchange para UoM para obtener precio actualizado
  ///
  /// OFFLINE-FIRST: Intenta servidor primero; si offline o falla,
  /// calcula precio convertido usando factores de UoM locales.
  Future<Map<String, dynamic>?> onchangeUom({
    required int orderId,
    required int productId,
    required int uomId,
    int? partnerId,
    int? pricelistId,
    double qty = 1.0,
  }) async {
    // Try server first if online
    if (_odooClient != null) {
      try {
        logger.d(
          '[ProductRepository]',
          'Calling onchange for UoM change: product=$productId, uom=$uomId...',
        );

        final result = await _odooClient.call(
          model: 'sale.order.line',
          method: 'onchange',
          args: [
            [],
            {
              'order_id': orderId,
              'product_id': productId,
              'product_uom_id': uomId,
              'product_uom_qty': qty,
            },
            ['product_uom_id'],
          ],
          kwargs: {},
        );

        if (result is Map<String, dynamic> && result.containsKey('value')) {
          logger.i(
            '[ProductRepository]',
            'UoM onchange returned: ${result['value']}',
          );
          return result['value'] as Map<String, dynamic>;
        }
      } catch (e) {
        logger.w(
          '[ProductRepository]',
          'Server UoM onchange failed, falling back to local: $e',
        );
      }
    }

    // Local fallback: compute price conversion using UoM factors
    try {
      final product = await productManager.readLocal(productId);
      if (product == null) {
        logger.w('[ProductRepository]', 'Product $productId not found locally for UoM onchange fallback');
        return null;
      }

      double priceUnit = product.listPrice;

      // If the new UoM differs from the product's default UoM, convert price
      if (product.uomId != null && uomId != product.uomId) {
        final productUom = await uomManager.readLocal(product.uomId!);
        final newUom = await uomManager.readLocal(uomId);

        if (productUom != null && newUom != null) {
          // Convert: product price is per product UoM
          // New price = listPrice * (productUom.conversionFactor / newUom.conversionFactor)
          if (newUom.conversionFactor != 0) {
            priceUnit = product.listPrice *
                (productUom.conversionFactor / newUom.conversionFactor);
          }
          logger.d(
            '[ProductRepository]',
            'Local UoM conversion: ${product.listPrice} (${productUom.name}) -> $priceUnit (${newUom.name})',
          );
        }
      }

      return {
        'price_unit': priceUnit,
      };
    } catch (e, stack) {
      logger.e('[ProductRepository]', 'Error in local UoM onchange fallback', e, stack);
    }
    return null;
  }

  // ============ Helpers ============

  /// Parsea string de IDs a lista de enteros
  List<int> _parseIntList(String? str) {
    if (str == null || str.isEmpty) return [];
    try {
      // Handle both JSON array format "[1,2,3]" and CSV format "1,2,3"
      final cleaned = str.startsWith('[') ? str.substring(1, str.length - 1) : str;
      return cleaned
          .split(',')
          .where((s) => s.trim().isNotEmpty)
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
    } catch (e) {
      return [];
    }
  }
}
