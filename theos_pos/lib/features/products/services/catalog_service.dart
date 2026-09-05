import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:theos_pos_core/theos_pos_core.dart';

typedef CatalogLoader<T> = Future<List<T>> Function();
typedef CatalogWatcher<T> = Stream<List<T>> Function();

/// Servicio que mantiene un caché de los catálogos locales
/// para poder resolver nombres de forma síncrona en la UI.
///
/// El caché es un HashMap O(1) que se actualiza reactivamente cuando
/// Drift recibe cambios vía sincronización HTTP (upsert → stream → actualización
/// de los mapas internos). No depende de TTL para reflejar precios
/// actualizados.
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
  final CatalogLoader<Product> _loadProducts;
  final CatalogLoader<Uom> _loadUoms;
  final CatalogLoader<ProductCategory> _loadCategories;
  final CatalogLoader<Tax> _loadTaxes;
  final CatalogWatcher<Product> _watchProducts;
  final CatalogWatcher<Uom> _watchUoms;
  final CatalogWatcher<ProductCategory> _watchCategories;
  final CatalogWatcher<Tax> _watchTaxes;
  @visibleForTesting
  final Duration debounceDuration;

  // Caches indexados por odooId para acceso O(1)
  final Map<int, Product> _productsById = {};
  final Map<String, Product> _productsByBarcode = {};
  final Map<String, Product> _productsByCode = {};
  final Map<int, Uom> _uomsById = {};
  final Map<int, ProductCategory> _categoriesById = {};
  final Map<int, Tax> _taxesById = {};

  bool _isLoaded = false;
  bool _isWatching = false;
  bool _isDisposed = false;
  DateTime? _lastLoadTime;
  Future<void>? _loadFuture;
  Future<void>? _refreshFuture;

  // Stream de cambios para que los providers de UI sepan cuándo re-renderizar.
  // Emite un entero que se incrementa con cada actualización del caché.
  final StreamController<int> _changesController =
      StreamController<int>.broadcast();
  final StreamController<int> _productChangesController =
      StreamController<int>.broadcast();
  final StreamController<int> _uomChangesController =
      StreamController<int>.broadcast();
  final StreamController<int> _categoryChangesController =
      StreamController<int>.broadcast();
  final StreamController<int> _taxChangesController =
      StreamController<int>.broadcast();
  int _changeVersion = 0;
  int _productChangeVersion = 0;
  int _uomChangeVersion = 0;
  int _categoryChangeVersion = 0;
  int _taxChangeVersion = 0;

  // Suscripciones a los streams de Drift (para cancelar en dispose)
  final List<StreamSubscription<dynamic>> _watchSubscriptions = [];

  // Debounce: agrupa cambios rápidos en una sola actualización
  Timer? _debounceTimer;

  CatalogService({
    CatalogLoader<Product>? loadProducts,
    CatalogLoader<Uom>? loadUoms,
    CatalogLoader<ProductCategory>? loadCategories,
    CatalogLoader<Tax>? loadTaxes,
    CatalogWatcher<Product>? watchProducts,
    CatalogWatcher<Uom>? watchUoms,
    CatalogWatcher<ProductCategory>? watchCategories,
    CatalogWatcher<Tax>? watchTaxes,
    this.debounceDuration = const Duration(milliseconds: 500),
  }) : _loadProducts = loadProducts ?? (() => productManager.searchLocal()),
       _loadUoms = loadUoms ?? (() => uomManager.searchLocal()),
       _loadCategories =
           loadCategories ?? (() => productCategoryManager.searchLocal()),
       _loadTaxes = loadTaxes ?? (() => taxManager.searchLocal()),
       _watchProducts = watchProducts ?? (() => productManager.watchAll()),
       _watchUoms = watchUoms ?? (() => uomManager.watchAll()),
       _watchCategories =
           watchCategories ?? (() => productCategoryManager.watchAll()),
       _watchTaxes = watchTaxes ?? (() => taxManager.watchAll());

  /// Stream que emite un entero incremental cada vez que el caché cambia.
  ///
  /// Los providers de UI deben hacer `ref.watch(catalogChangesProvider)`
  /// para recibir rebuilds cuando los datos del catálogo se actualicen.
  Stream<int> get onChanged => _changesController.stream;

  /// Product-only cache revisions. Product lookups avoid rebuilding when an
  /// unrelated UoM, category, or tax row changes.
  Stream<int> get onProductsChanged => _productChangesController.stream;

  /// UoM-only cache revisions.
  Stream<int> get onUomsChanged => _uomChangesController.stream;

  /// Category-only cache revisions.
  Stream<int> get onCategoriesChanged => _categoryChangesController.stream;

  /// Tax-only cache revisions.
  Stream<int> get onTaxesChanged => _taxChangesController.stream;

  /// Indica si el caché está cargado
  bool get isLoaded => _isLoaded;

  /// Indica si el caché necesita recargarse (nunca cargado).
  /// Con reactividad basada en streams, el TTL ya no es necesario.
  /// Solo se usa para la carga inicial.
  bool get needsRefresh => _lastLoadTime == null;

  /// Cantidad de productos en caché
  int get productCount => _productsById.length;

  /// Cantidad de UoMs en caché
  int get uomCount => _uomsById.length;

  /// Cantidad de categorías en caché
  int get categoryCount => _categoriesById.length;

  @visibleForTesting
  int get activeWatchSubscriptionCount => _watchSubscriptions.length;

  /// Carga todos los catálogos en memoria
  Future<void> initialize() async {
    if (_isLoaded && !needsRefresh) return;
    await loadCatalogs();
  }

  /// Recarga los catálogos
  Future<void> refresh() {
    final inFlight = _refreshFuture;
    if (inFlight != null) return inFlight;

    final future = _refreshCatalogs();
    _refreshFuture = future;
    return future.whenComplete(() {
      if (identical(_refreshFuture, future)) _refreshFuture = null;
    });
  }

  Future<void> _refreshCatalogs() async {
    final currentLoad = _loadFuture;
    if (currentLoad != null) await currentLoad;
    clear();
    await loadCatalogs();
  }

  /// Inicia la suscripción reactiva a los streams de Drift.
  ///
  /// Debe llamarse una sola vez después de la carga inicial. Cuando Drift
  /// recibe un upsert (vía sincronización HTTP), los streams emiten los datos
  /// actualizados. Con un debounce de 500 ms se agrupan cambios rápidos
  /// (p.ej. sync masivo) en una sola actualización del HashMap.
  ///
  /// Los subscriptions se cancelan en [dispose].
  void startWatching() {
    if (_isDisposed || _isWatching || !_isLoaded) return;
    _isWatching = true;

    try {
      // Productos — se actualiza el mapa en lugar de reemplazarlo completo
      _watchSubscriptions.add(
        _watchProducts().listen(
          (products) => _scheduleProductsUpdate(products),
          onError: (Object e) =>
              logger.w('[CatalogService]', 'Products stream error: $e'),
        ),
      );

      // UoMs
      _watchSubscriptions.add(
        _watchUoms().listen(
          (uoms) => _scheduleUomsUpdate(uoms),
          onError: (Object e) =>
              logger.w('[CatalogService]', 'Uoms stream error: $e'),
        ),
      );

      // Categorías
      _watchSubscriptions.add(
        _watchCategories().listen(
          (categories) => _scheduleCategoriesUpdate(categories),
          onError: (Object e) =>
              logger.w('[CatalogService]', 'Categories stream error: $e'),
        ),
      );

      // Impuestos
      _watchSubscriptions.add(
        _watchTaxes().listen(
          (taxes) => _scheduleTaxesUpdate(taxes),
          onError: (Object e) =>
              logger.w('[CatalogService]', 'Taxes stream error: $e'),
        ),
      );
    } catch (error, stackTrace) {
      // A factory may fail synchronously. Reset the partial set so a later
      // initialization can retry without leaking subscriptions.
      unawaited(_cancelWatchSubscriptions());
      Error.throwWithStackTrace(error, stackTrace);
    }

    logger.d('[CatalogService]', 'Watching Drift streams for reactive updates');
  }

  /// Libera recursos: cancela suscripciones y cierra el stream de cambios.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _debounceTimer?.cancel();
    await _cancelWatchSubscriptions();
    await Future.wait([
      _changesController.close(),
      _productChangesController.close(),
      _uomChangesController.close(),
      _categoryChangesController.close(),
      _taxChangesController.close(),
    ]);
  }

  // ============ Actualización reactiva de mapas ============

  void _scheduleProductsUpdate(List<Product> products) {
    _pendingProducts = products;
    _scheduleFlush();
  }

  void _scheduleUomsUpdate(List<Uom> uoms) {
    _pendingUoms = uoms;
    _scheduleFlush();
  }

  void _scheduleCategoriesUpdate(List<ProductCategory> categories) {
    _pendingCategories = categories;
    _scheduleFlush();
  }

  void _scheduleTaxesUpdate(List<Tax> taxes) {
    _pendingTaxes = taxes;
    _scheduleFlush();
  }

  // Datos pendientes de aplicar (los streams pueden emitir antes de que
  // expire el debounce)
  List<Product>? _pendingProducts;
  List<Uom>? _pendingUoms;
  List<ProductCategory>? _pendingCategories;
  List<Tax>? _pendingTaxes;

  /// Debounce de 500 ms: agrupa cambios rápidos en una sola actualización.
  void _scheduleFlush() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, _flush);
  }

  void _flush() {
    if (!_isLoaded) return; // No actualizar antes de la carga inicial

    var productsChanged = false;
    var uomsChanged = false;
    var categoriesChanged = false;
    var taxesChanged = false;

    if (_pendingProducts != null) {
      productsChanged = _applyProductsUpdate(_pendingProducts!);
      _pendingProducts = null;
    }
    if (_pendingUoms != null) {
      uomsChanged = _applyUomsUpdate(_pendingUoms!);
      _pendingUoms = null;
    }
    if (_pendingCategories != null) {
      categoriesChanged = _applyCategoriesUpdate(_pendingCategories!);
      _pendingCategories = null;
    }
    if (_pendingTaxes != null) {
      taxesChanged = _applyTaxesUpdate(_pendingTaxes!);
      _pendingTaxes = null;
    }

    if (productsChanged || uomsChanged || categoriesChanged || taxesChanged) {
      _notifyChanges(
        products: productsChanged,
        uoms: uomsChanged,
        categories: categoriesChanged,
        taxes: taxesChanged,
      );
    }
  }

  bool _applyProductsUpdate(List<Product> products) {
    if (_sameById(_productsById, products, (product) => product.id)) {
      return false;
    }
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
    logger.d(
      '[CatalogService]',
      'Products map updated reactively: ${_productsById.length} products',
    );
    return true;
  }

  bool _applyUomsUpdate(List<Uom> uoms) {
    if (_sameById(_uomsById, uoms, (uom) => uom.id)) return false;
    _uomsById.clear();
    for (final u in uoms) {
      _uomsById[u.id] = u;
    }
    logger.d('[CatalogService]', 'UoMs map updated: ${_uomsById.length}');
    return true;
  }

  bool _applyCategoriesUpdate(List<ProductCategory> categories) {
    if (_sameById(_categoriesById, categories, (category) => category.id)) {
      return false;
    }
    _categoriesById.clear();
    for (final c in categories) {
      _categoriesById[c.id] = c;
    }
    logger.d(
      '[CatalogService]',
      'Categories map updated: ${_categoriesById.length}',
    );
    return true;
  }

  bool _applyTaxesUpdate(List<Tax> taxes) {
    if (_sameById(_taxesById, taxes, (tax) => tax.id)) return false;
    _taxesById.clear();
    for (final t in taxes) {
      _taxesById[t.id] = t;
    }
    logger.d('[CatalogService]', 'Taxes map updated: ${_taxesById.length}');
    return true;
  }

  bool _sameById<T>(Map<int, T> current, List<T> next, int Function(T) idOf) {
    if (current.length != next.length) return false;
    for (final value in next) {
      if (current[idOf(value)] != value) return false;
    }
    return true;
  }

  void _notifyChanges({
    required bool products,
    required bool uoms,
    required bool categories,
    required bool taxes,
  }) {
    _changeVersion++;
    if (!_changesController.isClosed) {
      _changesController.add(_changeVersion);
      logger.d('[CatalogService]', 'Catalog updated (version $_changeVersion)');
    }
    if (products && !_productChangesController.isClosed) {
      _productChangesController.add(++_productChangeVersion);
    }
    if (uoms && !_uomChangesController.isClosed) {
      _uomChangesController.add(++_uomChangeVersion);
    }
    if (categories && !_categoryChangesController.isClosed) {
      _categoryChangesController.add(++_categoryChangeVersion);
    }
    if (taxes && !_taxChangesController.isClosed) {
      _taxChangesController.add(++_taxChangeVersion);
    }
  }

  Future<void> _cancelWatchSubscriptions() async {
    final subscriptions = List<StreamSubscription<dynamic>>.of(
      _watchSubscriptions,
    );
    _watchSubscriptions.clear();
    _isWatching = false;
    await Future.wait(subscriptions.map((sub) => sub.cancel()));
  }

  /// Carga todos los catálogos en memoria
  Future<void> loadCatalogs() {
    if (_isDisposed) {
      return Future.error(StateError('CatalogService is disposed'));
    }
    if (_isLoaded && !needsRefresh) return Future.value();
    final inFlight = _loadFuture;
    if (inFlight != null) return inFlight;

    final future = _loadCatalogs();
    _loadFuture = future;
    return future.whenComplete(() {
      if (identical(_loadFuture, future)) _loadFuture = null;
    });
  }

  Future<void> _loadCatalogs() async {
    try {
      logger.d('[CatalogService]', 'Loading catalogs...');
      final sw = Stopwatch()..start();

      // These catalogs are independent. Loading them concurrently shortens
      // the first usable POS frame without changing the atomic publication of
      // the in-memory indexes below.
      final results = await Future.wait<Object>([
        _loadProducts(),
        _loadUoms(),
        _loadCategories(),
        _loadTaxes(),
      ]);
      if (_isDisposed) return;
      final products = results[0] as List<Product>;
      final uoms = results[1] as List<Uom>;
      final categories = results[2] as List<ProductCategory>;
      final taxes = results[3] as List<Tax>;

      _applyProductsUpdate(products);
      _applyUomsUpdate(uoms);
      _applyCategoriesUpdate(categories);
      _applyTaxesUpdate(taxes);

      _isLoaded = true;
      _lastLoadTime = DateTime.now();
      if (_pendingProducts != null ||
          _pendingUoms != null ||
          _pendingCategories != null ||
          _pendingTaxes != null) {
        _scheduleFlush();
      }

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
      rethrow;
    }
  }

  /// Limpia el caché
  void clear() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingProducts = null;
    _pendingUoms = null;
    _pendingCategories = null;
    _pendingTaxes = null;
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
      final matchesCode =
          product.defaultCode?.toLowerCase().contains(queryLower) ?? false;
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
