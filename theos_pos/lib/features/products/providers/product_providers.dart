import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/managers/manager_providers.dart' show appDatabaseProvider;

import '../repositories/product_repository.dart';
import '../services/catalog_service.dart';
import '../services/product_service.dart';

import 'package:theos_pos_core/theos_pos_core.dart';

part 'product_providers.g.dart';

// ============ Core Providers ============

@Riverpod(keepAlive: true)
CatalogService catalogService(Ref ref) {
  final catalog = CatalogService();
  // Cancelar suscripciones Drift al destruir el provider (p.ej. logout)
  ref.onDispose(() => unawaited(catalog.dispose()));
  return catalog;
}

/// Stream que emite un entero incremental cada vez que el catálogo cambia.
///
/// Los providers de lookup escuchan este stream para saber cuándo
/// deben reconstruirse. El valor en sí (el entero) no es relevante;
/// solo importa que emita para disparar el rebuild de Riverpod.
@riverpod
Stream<int> catalogChanges(Ref ref) {
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.onChanged;
}

@riverpod
Stream<int> productCatalogChanges(Ref ref) {
  return ref.watch(catalogServiceProvider).onProductsChanged;
}

@riverpod
Stream<int> uomCatalogChanges(Ref ref) {
  return ref.watch(catalogServiceProvider).onUomsChanged;
}

@riverpod
Stream<int> categoryCatalogChanges(Ref ref) {
  return ref.watch(catalogServiceProvider).onCategoriesChanged;
}

@riverpod
Stream<int> taxCatalogChanges(Ref ref) {
  return ref.watch(catalogServiceProvider).onTaxesChanged;
}

/// Inicializa el catálogo y arranca la escucha reactiva de Drift.
///
/// Debe usarse con `ref.watch(catalogInitProvider)` en la pantalla raíz
/// para garantizar que los HashMaps estén poblados antes de usarlos.
@Riverpod(keepAlive: true)
Future<CatalogService> catalogInit(Ref ref) async {
  final catalog = ref.watch(catalogServiceProvider);
  await catalog.initialize();
  // Always attempt to attach the watchers: another consumer may have loaded
  // the cache before this provider was first watched. startWatching() is a
  // no-op when the four Drift subscriptions are already active.
  catalog.startWatching();
  return catalog;
}

// ============ Quick Lookup Providers ============

@riverpod
String productName(Ref ref, int? productId) {
  if (productId == null) return '';
  // Escuchar cambios del catálogo para rebuilds reactivos
  ref.watch(productCatalogChangesProvider);
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.resolveProductName(productId);
}

@riverpod
String uomName(Ref ref, int? uomId) {
  if (uomId == null) return 'Unid.';
  ref.watch(uomCatalogChangesProvider);
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.resolveUomName(uomId);
}

@riverpod
String categoryName(Ref ref, int? categId) {
  if (categId == null) return '';
  ref.watch(categoryCatalogChangesProvider);
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.resolveCategoryName(categId);
}

// ============ Product Access Providers ============

@riverpod
Product? productByIdCache(Ref ref, int? productId) {
  if (productId == null) return null;
  ref.watch(productCatalogChangesProvider);
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.getProduct(productId);
}

@riverpod
Product? productByBarcode(Ref ref, String? barcode) {
  if (barcode == null || barcode.isEmpty) return null;
  ref.watch(productCatalogChangesProvider);
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.getProductByBarcode(barcode);
}

@riverpod
Product? productByCode(Ref ref, String? code) {
  if (code == null || code.isEmpty) return null;
  ref.watch(productCatalogChangesProvider);
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.getProductByCode(code);
}

// ============ UoM Access Providers ============

@riverpod
Uom? uomById(Ref ref, int? uomId) {
  if (uomId == null) return null;
  ref.watch(uomCatalogChangesProvider);
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.getUom(uomId);
}

@riverpod
List<Uom> allUoms(Ref ref) {
  ref.watch(uomCatalogChangesProvider);
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.allUoms;
}

// ============ Category Access Providers ============

@riverpod
ProductCategory? categoryById(Ref ref, int? categId) {
  if (categId == null) return null;
  ref.watch(categoryCatalogChangesProvider);
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.getCategory(categId);
}

@riverpod
List<ProductCategory> allCategories(Ref ref) {
  ref.watch(categoryCatalogChangesProvider);
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.allCategories;
}

// ============ Search Providers ============

@riverpod
List<Product> productSearchCache(Ref ref, String query) {
  ref.watch(productCatalogChangesProvider);
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.searchProducts(query);
}

// ============ Statistics Provider ============

@riverpod
Map<String, int> catalogStats(Ref ref) {
  ref.watch(catalogChangesProvider);
  final catalog = ref.watch(catalogServiceProvider);
  return catalog.stats;
}

// ============ Repository Provider ============

@Riverpod(keepAlive: true)
ProductRepository productRepository(Ref ref) {
  // F5: ProductRepository ya no recibe OdooClient — ver
  // repository_providers.dart para el detalle del trade-off documentado.
  return ProductRepository(db: ref.watch(appDatabaseProvider));
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

@riverpod
Future<List<Product>> productSearch(Ref ref, String query) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.searchProducts(query);
}

@riverpod
Future<List<Map<String, dynamic>>> productSearchEnriched(
  Ref ref,
  String query,
) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.searchProductsEnriched(query);
}

@riverpod
Future<Product?> productById(Ref ref, int productId) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getById(productId);
}

@riverpod
Future<Map<String, dynamic>?> productDetailedInfo(
  Ref ref,
  int productId,
) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getDetailedInfo(productId);
}

@riverpod
Future<List<ProductUom>> productUoms(Ref ref, int productId) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProductUoms(productId);
}

@riverpod
Future<List<Map<String, dynamic>>> productStockByWarehouse(
  Ref ref,
  int productId,
) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getStockByWarehouse(productId);
}
