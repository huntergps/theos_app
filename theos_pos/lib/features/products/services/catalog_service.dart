import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:theos_pos_core/theos_pos_core.dart';

/// Servicio que mantiene un caché de los catálogos locales
/// para poder resolver nombres de forma síncrona en la UI.
///
/// Reemplaza a CatalogLookupService con soporte para los nuevos modelos Freezed.
///
/// Uso:
/// ```dart
/// final catalog = ref.watch(catalogServiceProvider);
///
/// // Resolver nombre de producto (usa local si existe, sino embebido)
/// final productName = catalog.resolveProductName(line.productId, line.productName);
/// final uomName = catalog.resolveUomName(line.productUomId, line.productUomName);
///
/// // Obtener producto completo
/// final product = catalog.getProduct(productId);
/// if (product != null) {
///   print('Stock: ${product.qtyAvailable}');
/// }
/// ```
class CatalogService {
  // Caches indexados por odooId para acceso O(1)
  final Map<int, Product> _productsById = {};
  final Map<String, Product> _productsByBarcode = {};
  final Map<String, Product> _productsByCode = {};
  final Map<int, Uom> _uomsById = {};
  final Map<int, ProductCategory> _categoriesById = {};
  final Map<int, Tax> _taxesById = {};

  bool _isLoaded = false;
  DateTime? _lastLoadTime;

  CatalogService();

  /// Indica si el caché está cargado
  bool get isLoaded => _isLoaded;

  /// Indica si el caché necesita recargarse (más de 5 minutos)
  bool get needsRefresh {
    if (_lastLoadTime == null) return true;
    return DateTime.now().difference(_lastLoadTime!).inMinutes > 5;
  }

  /// Cantidad de productos en caché
  int get productCount => _productsById.length;

  /// Cantidad de UoMs en caché
  int get uomCount => _uomsById.length;

  /// Cantidad de categorías en caché
  int get categoryCount => _categoriesById.length;

  /// Carga todos los catálogos en memoria
  Future<void> initialize() async {
    if (_isLoaded && !needsRefresh) return;
    await loadCatalogs();
  }

  /// Recarga los catálogos
  Future<void> refresh() async {
    clear();
    await loadCatalogs();
  }

  /// Carga todos los catálogos en memoria
  Future<void> loadCatalogs() async {
    try {
      logger.d('[CatalogService]', 'Loading catalogs...');
      final sw = Stopwatch()..start();

      // Cargar productos via manager
      final products = await productManager.searchLocal();
      _productsById.clear();
      _productsByBarcode.clear();
      _productsByCode.clear();

      for (final product in products) {
        _productsById[product.id] = product;

        if (product.hasBarcode) {
          _productsByBarcode[product.barcode!] = product;
        }
        if (product.hasDefaultCode) {
          _productsByCode[product.defaultCode!.toLowerCase()] = product;
        }
      }

      // Cargar UoMs via manager
      final uoms = await uomManager.searchLocal();
      _uomsById.clear();
      for (final u in uoms) {
        _uomsById[u.id] = u;
      }

      // Cargar categorías via manager
      final categories = await productCategoryManager.searchLocal();
      _categoriesById.clear();
      for (final c in categories) {
        _categoriesById[c.id] = c;
      }

      // Cargar impuestos via manager
      final taxes = await taxManager.searchLocal();
      _taxesById.clear();
      for (final t in taxes) {
        _taxesById[t.id] = t;
      }

      _isLoaded = true;
      _lastLoadTime = DateTime.now();

      sw.stop();
      logger.i(
        '[CatalogService]',
        'Catalogs loaded in ${sw.elapsedMilliseconds}ms: '
            '${_productsById.length} products, '
            '${_uomsById.length} uoms, '
            '${_categoriesById.length} categories, '
            '${_taxesById.length} taxes',
      );
    } catch (e, stack) {
      logger.e('[CatalogService]', 'Error loading catalogs', e, stack);
      _isLoaded = false;
    }
  }

  /// Limpia el caché
  void clear() {
    _productsById.clear();
    _productsByBarcode.clear();
    _productsByCode.clear();
    _uomsById.clear();
    _categoriesById.clear();
    _taxesById.clear();
    _isLoaded = false;
    _lastLoadTime = null;
  }

  // ============ Product Operations ============

  /// Obtiene el producto por ID (odooId), o null si no existe
  Product? getProduct(int? odooId) {
    if (odooId == null) return null;
    return _productsById[odooId];
  }

  /// Obtiene el producto por barcode, o null si no existe
  Product? getProductByBarcode(String? barcode) {
    if (barcode == null || barcode.isEmpty) return null;
    return _productsByBarcode[barcode];
  }

  /// Obtiene el producto por código interno, o null si no existe
  Product? getProductByCode(String? code) {
    if (code == null || code.isEmpty) return null;
    return _productsByCode[code.toLowerCase()];
  }

  /// Busca productos por nombre, código o barcode
  List<Product> searchProducts(String query, {int limit = 20}) {
    if (query.isEmpty) return [];

    final queryLower = query.toLowerCase();
    final results = <Product>[];

    for (final product in _productsById.values) {
      if (results.length >= limit) break;

      final matchesName = product.name.toLowerCase().contains(queryLower);
      final matchesCode = product.defaultCode?.toLowerCase().contains(queryLower) ?? false;
      final matchesBarcode = product.barcode?.contains(query) ?? false;

      if (matchesName || matchesCode || matchesBarcode) {
        results.add(product);
      }
    }

    return results;
  }

  /// Resuelve el nombre del producto:
  /// - Si existe en catálogo local, retorna el nombre local
  /// - Si no existe, retorna el nombre embebido (fallback)
  String resolveProductName(int? productId, [String? embeddedName]) {
    final product = getProduct(productId);
    if (product != null) {
      return product.name;
    }
    return embeddedName ?? '';
  }

  /// Resuelve el display name del producto (con código si existe)
  String resolveProductDisplayName(int? productId, [String? embeddedName]) {
    final product = getProduct(productId);
    if (product != null) {
      return product.displayName;
    }
    return embeddedName ?? '';
  }

  /// Resuelve el código del producto (default_code)
  String? resolveProductCode(int? productId, [String? embeddedCode]) {
    final product = getProduct(productId);
    if (product != null) {
      return product.defaultCode;
    }
    return embeddedCode;
  }

  // ============ UoM Operations ============

  /// Obtiene el UoM por ID (odooId), o null si no existe
  Uom? getUom(int? odooId) {
    if (odooId == null) return null;
    return _uomsById[odooId];
  }

  /// Resuelve el nombre del UoM:
  /// - Si existe en catálogo local, retorna el nombre local
  /// - Si no existe, retorna el nombre embebido (fallback)
  String resolveUomName(int? uomId, [String? embeddedName]) {
    final uom = getUom(uomId);
    if (uom != null) {
      return uom.name;
    }
    return embeddedName ?? 'Unid.';
  }

  /// Lista de todos los UoMs en caché
  List<Uom> get allUoms => _uomsById.values.toList();

  // ============ Category Operations ============

  /// Obtiene la categoría por ID (odooId), o null si no existe
  ProductCategory? getCategory(int? odooId) {
    if (odooId == null) return null;
    return _categoriesById[odooId];
  }

  /// Resuelve el nombre de la categoría
  String resolveCategoryName(int? categId, [String? embeddedName]) {
    final category = getCategory(categId);
    if (category != null) {
      return category.displayName;
    }
    return embeddedName ?? '';
  }

  /// Lista de todas las categorías en caché
  List<ProductCategory> get allCategories => _categoriesById.values.toList();

  // ============ Tax Operations ============

  /// Obtiene el impuesto por ID (odooId), o null si no existe
  Tax? getTax(int? odooId) {
    if (odooId == null) return null;
    return _taxesById[odooId];
  }

  /// Resuelve los nombres de impuestos desde una lista de IDs
  /// taxIdsString es un string JSON o CSV de IDs
  String resolveTaxNames(String? taxIdsString, [String? embeddedNames]) {
    if (taxIdsString == null || taxIdsString.isEmpty) {
      return embeddedNames ?? '';
    }

    try {
      // Parse as CSV (taxIds is stored as "1,2,3" from extractMany2manyIdsAsString)
      final ids = taxIdsString
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();

      final names = <String>[];
      for (final id in ids) {
        final tax = getTax(id);
        if (tax != null) {
          names.add(tax.name);
        }
      }

      if (names.isNotEmpty) {
        return names.join(', ');
      }
    } catch (e) {
      // En caso de error parsing, usar fallback
    }

    return embeddedNames ?? '';
  }

  /// Resuelve el nombre del grupo de impuesto para mostrar en totales.
  ///
  /// Construye un nombre tipo "IVA 15%" a partir del porcentaje del impuesto,
  /// similar a como Odoo muestra el nombre del tax group en los totales.
  /// Esto es necesario porque account.tax.name en Odoo Ecuador es en inglés
  /// ("VAT 15% G") pero los totales deben mostrar "IVA 15%".
  String resolveTaxGroupName(String? taxIdsString, [String? embeddedNames]) {
    if (taxIdsString == null || taxIdsString.isEmpty) {
      return embeddedNames ?? '';
    }

    try {
      final ids = taxIdsString
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();

      final groupNames = <String>[];
      for (final id in ids) {
        final tax = getTax(id);
        if (tax != null) {
          final pct = tax.amount;
          final pctStr = pct == pct.truncateToDouble()
              ? pct.toInt().toString()
              : pct.toString();
          groupNames.add('IVA $pctStr%');
        }
      }

      if (groupNames.isNotEmpty) {
        return groupNames.toSet().join(', ');
      }
    } catch (e) {
      // Fallback
    }

    return embeddedNames ?? '';
  }

  /// Lista de todos los impuestos en caché
  List<Tax> get allTaxes => _taxesById.values.toList();

  // ============ Statistics ============

  /// Devuelve estadísticas del caché
  Map<String, int> get stats => {
        'products': _productsById.length,
        'productsByBarcode': _productsByBarcode.length,
        'productsByCode': _productsByCode.length,
        'uoms': _uomsById.length,
        'categories': _categoriesById.length,
        'taxes': _taxesById.length,
      };

  // ============ Testing Support ============

  /// Populates the caches directly for testing purposes.
  ///
  /// This avoids the need to mock global manager singletons in unit tests.
  @visibleForTesting
  void populateForTesting({
    List<Product>? products,
    List<Uom>? uoms,
    List<ProductCategory>? categories,
    List<Tax>? taxes,
  }) {
    if (products != null) {
      _productsById.clear();
      _productsByBarcode.clear();
      _productsByCode.clear();
      for (final product in products) {
        _productsById[product.id] = product;
        if (product.hasBarcode) {
          _productsByBarcode[product.barcode!] = product;
        }
        if (product.hasDefaultCode) {
          _productsByCode[product.defaultCode!.toLowerCase()] = product;
        }
      }
    }
    if (uoms != null) {
      _uomsById.clear();
      for (final u in uoms) {
        _uomsById[u.id] = u;
      }
    }
    if (categories != null) {
      _categoriesById.clear();
      for (final c in categories) {
        _categoriesById[c.id] = c;
      }
    }
    if (taxes != null) {
      _taxesById.clear();
      for (final t in taxes) {
        _taxesById[t.id] = t;
      }
    }
    _isLoaded = true;
    _lastLoadTime = DateTime.now();
  }
}
