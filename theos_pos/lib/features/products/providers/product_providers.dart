import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/repositories/repository_providers.dart';
import '../../../core/managers/manager_providers.dart' show appDatabaseProvider;

import '../repositories/product_repository.dart';
import '../services/catalog_service.dart';
import '../services/product_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

part 'product_providers.g.dart';

// ============ Core Providers ============

@Riverpod(keepAlive: true)
CatalogService catalogService(Ref ref) {
  return CatalogService();
}

@Riverpod(keepAlive: true)
Future<CatalogService> catalogInit(Ref ref) async {
  final catalog = ref.watch(catalogServiceProvider);
  if (!catalog.isLoaded || catalog.needsRefresh) {
    await catalog.loadCatalogs();
  }
  return catalog;
}

// ============ Quick Lookup Providers ============

@Riverpod(keepAlive: true)
String productName(Ref ref, int? productId) {
  if (productId == null) return '';
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.resolveProductName(productId);
}

@Riverpod(keepAlive: true)
String uomName(Ref ref, int? uomId) {
  if (uomId == null) return 'Unid.';
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.resolveUomName(uomId);
}

@Riverpod(keepAlive: true)
String categoryName(Ref ref, int? categId) {
  if (categId == null) return '';
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.resolveCategoryName(categId);
}

// ============ Product Access Providers ============

@Riverpod(keepAlive: true)
Product? productByIdCache(Ref ref, int? productId) {
  if (productId == null) return null;
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.getProduct(productId);
}

@Riverpod(keepAlive: true)
Product? productByBarcode(Ref ref, String? barcode) {
  if (barcode == null || barcode.isEmpty) return null;
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.getProductByBarcode(barcode);
}

@Riverpod(keepAlive: true)
Product? productByCode(Ref ref, String? code) {
  if (code == null || code.isEmpty) return null;
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.getProductByCode(code);
}

// ============ UoM Access Providers ============

@Riverpod(keepAlive: true)
Uom? uomById(Ref ref, int? uomId) {
  if (uomId == null) return null;
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.getUom(uomId);
}

@Riverpod(keepAlive: true)
List<Uom> allUoms(Ref ref) {
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.allUoms;
}

// ============ Category Access Providers ============

@Riverpod(keepAlive: true)
ProductCategory? categoryById(Ref ref, int? categId) {
  if (categId == null) return null;
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.getCategory(categId);
}

@Riverpod(keepAlive: true)
List<ProductCategory> allCategories(Ref ref) {
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.allCategories;
}

// ============ Search Providers ============

@Riverpod(keepAlive: true)
List<Product> productSearchCache(Ref ref, String query) {
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.searchProducts(query);
}

// ============ Statistics Provider ============

@Riverpod(keepAlive: true)
Map<String, int> catalogStats(Ref ref) {
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.stats;
}

// ============ Repository Provider ============

@Riverpod(keepAlive: true)
ProductRepository productRepository(Ref ref) {
  final odooClient = ref.watch(odooClientProvider);
  return ProductRepository(db: ref.watch(appDatabaseProvider), odooClient: odooClient);
}

// ============ Service Provider ============

@Riverpod(keepAlive: true)
ProductService productService(Ref ref) {
  final catalog = ref.watch(catalogServiceProvider);
  final repository = ref.watch(productRepositoryProvider);
  return ProductService(catalog: catalog, repository: repository);
}

@Riverpod(keepAlive: true)
Future<ProductService> productServiceInit(Ref ref) async {
  final service = ref.watch(productServiceProvider);
  if (!service.isCacheLoaded) {
    await service.initialize();
  }
  return service;
}

// ============ Async Product Providers ============

@Riverpod(keepAlive: true)
Future<List<Product>> productSearch(Ref ref, String query) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.searchProducts(query);
}

@Riverpod(keepAlive: true)
Future<List<Map<String, dynamic>>> productSearchEnriched(Ref ref, String query) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.searchProductsEnriched(query);
}

@Riverpod(keepAlive: true)
Future<Product?> productById(Ref ref, int productId) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getById(productId);
}

@Riverpod(keepAlive: true)
Future<Map<String, dynamic>?> productDetailedInfo(Ref ref, int productId) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getDetailedInfo(productId);
}

@Riverpod(keepAlive: true)
Future<List<ProductUom>> productUoms(Ref ref, int productId) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProductUoms(productId);
}

@Riverpod(keepAlive: true)
Future<List<Map<String, dynamic>>> productStockByWarehouse(Ref ref, int productId) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getStockByWarehouse(productId);
}
