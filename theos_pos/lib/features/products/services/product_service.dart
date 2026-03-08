
import '../repositories/product_repository.dart';
import 'catalog_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Servicio unificado de productos - API de alto nivel
///
/// Combina el CatalogService (cache en memoria) con el ProductRepository
/// (acceso a base de datos y Odoo) para ofrecer una API completa.
///
/// Uso:
/// ```dart
/// final productService = ref.read(productServiceProvider);
///
/// // Búsqueda rápida desde cache
/// final products = productService.searchFromCache('termo');
///
/// // Búsqueda completa desde DB (más precisa, más lenta)
/// final products = await productService.search('termo');
///
/// // Obtener producto con fallback a DB
/// final product = await productService.getProduct(42);
///
/// // Información detallada (puede consultar Odoo si online)
/// final info = await productService.getDetailedInfo(42);
/// ```
class ProductService {
  final CatalogService _catalog;
  final ProductRepository _repository;

  ProductService({
    required CatalogService catalog,
    required ProductRepository repository,
  })  : _catalog = catalog,
        _repository = repository;

  /// Indica si el cache está cargado
  bool get isCacheLoaded => _catalog.isLoaded;

  /// Indica si hay conexión con Odoo
  bool get isOnline => _repository.isOnline;

  // ============ Initialization ============

  /// Inicializa el cache de catálogos
  Future<void> initialize() async {
    await _catalog.initialize();
  }

  /// Recarga el cache
  Future<void> refreshCache() async {
    await _catalog.refresh();
  }

  // ============ Product Search ============

  /// Búsqueda rápida desde cache (síncrona)
  /// Ideal para autocomplete y búsquedas en tiempo real
  List<Product> searchFromCache(String query, {int limit = 20}) {
    return _catalog.searchProducts(query, limit: limit);
  }

  /// Búsqueda completa desde base de datos (asíncrona)
  /// Más precisa pero más lenta que searchFromCache
  Future<List<Product>> search(String query, {int limit = 50}) async {
    return _repository.searchProducts(query, limit: limit);
  }

  /// Búsqueda con información enriquecida de impuestos
  Future<List<Map<String, dynamic>>> searchEnriched(
    String query, {
    int limit = 50,
  }) async {
    return _repository.searchProductsEnriched(query, limit: limit);
  }

  // ============ Product Lookup ============

  /// Obtiene producto por ID - primero intenta cache, luego DB
  Future<Product?> getProduct(int productId) async {
    // Intentar desde cache primero (O(1))
    final cached = _catalog.getProduct(productId);
    if (cached != null) return cached;

    // Fallback a base de datos
    return _repository.getById(productId);
  }

  /// Obtiene producto por ID solo desde cache (síncrono)
  Product? getProductFromCache(int productId) {
    return _catalog.getProduct(productId);
  }

  /// Obtiene producto por barcode - primero cache, luego DB
  Future<Product?> getByBarcode(String barcode) async {
    // Intentar desde cache primero
    final cached = _catalog.getProductByBarcode(barcode);
    if (cached != null) return cached;

    // Fallback a base de datos
    return _repository.getByBarcode(barcode);
  }

  /// Obtiene producto por código interno - primero cache, luego DB
  Future<Product?> getByCode(String code) async {
    // Intentar desde cache primero
    final cached = _catalog.getProductByCode(code);
    if (cached != null) return cached;

    // Fallback a base de datos
    return _repository.getByCode(code);
  }

  /// Obtiene varios productos por IDs
  Future<List<Product>> getByIds(List<int> productIds) async {
    return _repository.getByIds(productIds);
  }

  // ============ Name Resolution ============

  /// Resuelve nombre de producto (desde cache)
  String resolveProductName(int? productId, [String? fallback]) {
    return _catalog.resolveProductName(productId, fallback);
  }

  /// Resuelve display name de producto (con código si existe)
  String resolveProductDisplayName(int? productId, [String? fallback]) {
    return _catalog.resolveProductDisplayName(productId, fallback);
  }

  /// Resuelve código de producto
  String? resolveProductCode(int? productId, [String? fallback]) {
    return _catalog.resolveProductCode(productId, fallback);
  }

  // ============ UoM Operations ============

  /// Obtiene UoM por ID (desde cache)
  Uom? getUom(int uomId) {
    return _catalog.getUom(uomId);
  }

  /// Resuelve nombre de UoM
  String resolveUomName(int? uomId, [String? fallback]) {
    return _catalog.resolveUomName(uomId, fallback);
  }

  /// Obtiene todos los UoMs
  List<Uom> getAllUoms() {
    return _catalog.allUoms;
  }

  /// Obtiene UoMs específicos de un producto
  Future<List<ProductUom>> getProductUoms(int productId) async {
    return _repository.getProductUoms(productId);
  }

  // ============ Category Operations ============

  /// Obtiene categoría por ID (desde cache)
  ProductCategory? getCategory(int categId) {
    return _catalog.getCategory(categId);
  }

  /// Resuelve nombre de categoría
  String resolveCategoryName(int? categId, [String? fallback]) {
    return _catalog.resolveCategoryName(categId, fallback);
  }

  /// Obtiene todas las categorías
  List<ProductCategory> getAllCategories() {
    return _catalog.allCategories;
  }

  // ============ Tax Operations ============

  /// Resuelve nombres de impuestos desde string de IDs
  String resolveTaxNames(String? taxIdsString, [String? fallback]) {
    return _catalog.resolveTaxNames(taxIdsString, fallback);
  }

  // ============ Detailed Info (Odoo Integration) ============

  /// Obtiene información detallada del producto
  /// Puede consultar Odoo si está online para datos actualizados
  Future<Map<String, dynamic>?> getDetailedInfo(int productId) async {
    return _repository.getDetailedInfo(productId);
  }

  /// Obtiene historial de compras del producto para un cliente
  Future<List<Map<String, dynamic>>> getHistoryForCustomer({
    required int productId,
    required int partnerId,
  }) async {
    return _repository.getHistoryForCustomer(
      productId: productId,
      partnerId: partnerId,
    );
  }

  /// Obtiene stock por almacén (requiere conexión Odoo)
  Future<List<Map<String, dynamic>>> getStockByWarehouse(int productId) async {
    return _repository.getStockByWarehouse(productId);
  }

  /// Obtiene packaging/barcodes del producto (requiere conexión Odoo)
  Future<List<Map<String, dynamic>>> getPackagingBarcodes(int productId) async {
    return _repository.getPackagingBarcodes(productId);
  }

  // ============ Onchange Methods (Odoo Integration) ============

  /// Ejecuta onchange de producto para obtener defaults
  Future<Map<String, dynamic>?> onchangeProduct({
    required int orderId,
    required int productId,
    int? partnerId,
    int? pricelistId,
    double qty = 1.0,
  }) async {
    return _repository.onchangeProduct(
      orderId: orderId,
      productId: productId,
      partnerId: partnerId,
      pricelistId: pricelistId,
      qty: qty,
    );
  }

  /// Ejecuta onchange de UoM para obtener precio actualizado
  Future<Map<String, dynamic>?> onchangeUom({
    required int orderId,
    required int productId,
    required int uomId,
    int? partnerId,
    int? pricelistId,
    double qty = 1.0,
  }) async {
    return _repository.onchangeUom(
      orderId: orderId,
      productId: productId,
      uomId: uomId,
      partnerId: partnerId,
      pricelistId: pricelistId,
      qty: qty,
    );
  }

  // ============ UoM Conversion ============

  /// Convierte cantidad entre UoMs
  double convertQty(double qty, Uom fromUom, Uom toUom) {
    if (fromUom.id == toUom.id) return qty;

    // Convertir a unidad de referencia primero, luego a destino
    final inReference = fromUom.toReference(qty);
    return toUom.fromReference(inReference);
  }

  /// Redondea cantidad según precisión del UoM
  double roundToUom(double qty, Uom uom) {
    return uom.roundQty(qty);
  }

  // ============ Statistics ============

  /// Estadísticas del cache
  Map<String, int> get cacheStats => _catalog.stats;

  /// Log de diagnóstico
  void logDiagnostics() {
    logger.i('[ProductService]', '''
Cache Statistics:
  Products: ${_catalog.productCount}
  UoMs: ${_catalog.uomCount}
  Categories: ${_catalog.categoryCount}
  Loaded: ${_catalog.isLoaded}
  Needs Refresh: ${_catalog.needsRefresh}
Connection:
  Online: ${_repository.isOnline}
''');
  }
}
