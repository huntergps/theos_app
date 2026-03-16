import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    hide DatabaseHelper, CreditIssue, PartnerBank;

import '../../../../../core/managers/manager_providers.dart'
    show appDatabaseProvider;
import '../../../../products/providers/product_providers.dart'
    show catalogChangesProvider, catalogServiceProvider;
import '../../../../products/services/catalog_service.dart';

// ============================================================================
// Modelos de datos del panel de favoritos
// ============================================================================

/// Categoría de filtro para el panel de favoritos
class FavoriteFilterCategory {
  final int? id; // null → pestaña "Frecuentes"
  final String name;
  final bool isFrecuentes;

  const FavoriteFilterCategory({
    required this.id,
    required this.name,
    this.isFrecuentes = false,
  });

  static const frecuentes = FavoriteFilterCategory(
    id: null,
    name: 'Frecuentes',
    isFrecuentes: true,
  );

  @override
  bool operator ==(Object other) =>
      other is FavoriteFilterCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ============================================================================
// Provider: Categoría seleccionada en el panel de favoritos
// ============================================================================

/// Categoría actualmente activa en el filtro de favoritos.
///
/// `FavoriteFilterCategory.frecuentes` (default) → muestra los 20 productos
/// más vendidos. Cualquier otra categoría → filtra el catálogo por categoría.
class FavoritesSelectedCategoryNotifier
    extends Notifier<FavoriteFilterCategory> {
  @override
  FavoriteFilterCategory build() => FavoriteFilterCategory.frecuentes;

  void select(FavoriteFilterCategory category) {
    state = category;
  }
}

final favoritesSelectedCategoryProvider =
    NotifierProvider<FavoritesSelectedCategoryNotifier,
        FavoriteFilterCategory>(() => FavoritesSelectedCategoryNotifier());

// ============================================================================
// Provider: Conteos de productos frecuentes desde Drift (stream reactivo)
// ============================================================================

/// Stream reactivo de pares (productId, count) para los 20 productos
/// más vendidos en los últimos 30 días, basado en `sale_order_line` local.
///
/// El stream se reactualiza automáticamente cuando se insertan nuevas líneas
/// (porque Drift observa la tabla `sale_order_line`).
final frequentProductCountsProvider =
    StreamProvider<List<({int productId, int count})>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final cutoff = DateTime.now().subtract(const Duration(days: 30));

  final query = db.customSelect(
    '''
    SELECT product_id, COUNT(*) AS cnt
    FROM sale_order_line
    WHERE product_id IS NOT NULL
      AND (display_type IS NULL OR display_type = '')
      AND (write_date IS NULL OR write_date >= ?)
    GROUP BY product_id
    ORDER BY cnt DESC
    LIMIT 20
    ''',
    variables: [Variable.withDateTime(cutoff)],
    readsFrom: {db.saleOrderLine},
  );

  return query.watch().map((rows) {
    return rows
        .map((row) => (
              productId: row.read<int>('product_id'),
              count: row.read<int>('cnt'),
            ))
        .toList();
  });
});

// ============================================================================
// Provider: Productos frecuentes resueltos desde el catálogo local
// ============================================================================

/// Lista reactiva de los 20 productos más frecuentes del POS,
/// resueltos desde el catálogo en memoria (sin llamadas a BD adicionales).
///
/// Fallback: si hay menos de 8 productos en el historial, completa hasta 20
/// con los primeros productos activos vendibles del catálogo (orden alfabético).
final frequentProductsProvider = Provider<List<Product>>((ref) {
  ref.watch(catalogChangesProvider);
  final catalog = ref.watch(catalogServiceProvider);
  final countsAsync = ref.watch(frequentProductCountsProvider);

  if (!catalog.isLoaded) return [];

  final counts = countsAsync.value ?? [];
  final List<Product> result = [];
  final seenIds = <int>{};

  // 1. Resolver productos del historial (ya ordenados por frecuencia)
  for (final entry in counts) {
    final product = catalog.getProduct(entry.productId);
    if (product != null && product.active && product.saleOk) {
      result.add(product);
      seenIds.add(product.id);
    }
  }

  // 2. Fallback: completar con productos activos si no hay suficiente historial
  if (result.length < 8) {
    final fallback = _searchCatalogFallback(catalog, seenIds, 20 - result.length);
    result.addAll(fallback);
  }

  return result.take(20).toList();
});

/// Búsqueda amplia en el catálogo para obtener productos activos vendibles
/// que no estén ya en [seenIds], retornando como máximo [limit] productos.
///
/// CatalogService no expone `allProducts` directamente, así que hacemos
/// búsquedas con vocales y dígitos para cubrir la mayoría de nombres.
List<Product> _searchCatalogFallback(
  CatalogService catalog,
  Set<int> seenIds,
  int limit,
) {
  final candidates = <Product>[];
  final localSeen = <int>{...seenIds};

  for (final char in const ['a', 'e', 'i', 'o', 'u', '1', '2', 's', 'r']) {
    if (candidates.length >= limit * 2) break; // margen para deduplicar
    final found = catalog.searchProducts(char, limit: 60);
    for (final p in found) {
      if (!localSeen.contains(p.id) && p.active && p.saleOk) {
        candidates.add(p);
        localSeen.add(p.id);
      }
    }
  }

  candidates.sort((a, b) => a.name.compareTo(b.name));
  return candidates.take(limit).toList();
}

// ============================================================================
// Provider: Productos filtrados por la categoría activa
// ============================================================================

/// Productos que se muestran en el grid de favoritos según el filtro activo.
///
/// - "Frecuentes": retorna los 20 productos más vendidos
/// - Otra categoría: retorna los productos de esa categoría (frecuentes primero)
final favoriteGridProductsProvider = Provider<List<Product>>((ref) {
  final selected = ref.watch(favoritesSelectedCategoryProvider);
  final frequent = ref.watch(frequentProductsProvider);

  if (selected.isFrecuentes) {
    return frequent;
  }

  final categoryId = selected.id;
  if (categoryId == null) return frequent;

  ref.watch(catalogChangesProvider);
  final catalog = ref.watch(catalogServiceProvider);
  if (!catalog.isLoaded) return [];

  // Primero los frecuentes de esta categoría
  final fromFrequent =
      frequent.where((p) => p.categId == categoryId).toList();

  // Luego completar con otros productos de la categoría del catálogo
  final existingIds = fromFrequent.map((p) => p.id).toSet();
  final additional = <Product>[];
  final localSeen = <int>{...existingIds};

  for (final char in const ['a', 'e', 'i', 'o', 'u', '1', '2', 's', 'r']) {
    if (additional.length >= 40) break;
    final found = catalog.searchProducts(char, limit: 60);
    for (final p in found) {
      if (!localSeen.contains(p.id) &&
          p.categId == categoryId &&
          p.active &&
          p.saleOk) {
        additional.add(p);
        localSeen.add(p.id);
      }
    }
  }
  additional.sort((a, b) => a.name.compareTo(b.name));

  final combined = [...fromFrequent, ...additional];
  return combined.take(20).toList();
});

// ============================================================================
// Provider: Categorías disponibles para el filtro
// ============================================================================

/// Lista de categorías de filtro del panel de favoritos.
///
/// Siempre incluye "Frecuentes" como primer elemento, seguido de las
/// categorías de los productos frecuentes (en orden de aparición).
final favoriteFilterCategoriesProvider =
    Provider<List<FavoriteFilterCategory>>((ref) {
  ref.watch(catalogChangesProvider);
  final catalog = ref.watch(catalogServiceProvider);
  final frequent = ref.watch(frequentProductsProvider);

  final categories = <FavoriteFilterCategory>[
    FavoriteFilterCategory.frecuentes,
  ];

  final seenCategIds = <int>{};
  for (final product in frequent) {
    final categId = product.categId;
    if (categId != null && !seenCategIds.contains(categId)) {
      seenCategIds.add(categId);
      final category = catalog.getCategory(categId);
      if (category != null) {
        categories.add(
          FavoriteFilterCategory(id: categId, name: category.name),
        );
      }
    }
  }

  return categories;
});
