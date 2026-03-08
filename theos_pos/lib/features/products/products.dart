// Products feature module
//
// Centralized product management following Odoo patterns.
//
// Usage:
// ```dart
// import 'package:theos_pos/features/products/products.dart';
//
// // Quick lookup from cache (synchronous)
// final productService = ref.read(productServiceProvider);
// final productName = productService.resolveProductName(productId);
// final uomName = productService.resolveUomName(uomId);
//
// // Access product by ID from cache (synchronous)
// final product = ref.read(productByIdCacheProvider(42));
//
// // Access product by ID from database (async)
// final product = await ref.read(productByIdProvider(42).future);
//
// // Search products
// final products = await ref.read(productSearchProvider('query').future);
//
// // Get catalog service for fast lookups
// final catalog = ref.read(catalogServiceProvider);
// final productName = catalog.resolveProductName(productId);
// ```

// Models
// Services
export 'services/services.dart';

// Repositories
export 'repositories/repositories.dart';

// Providers
export 'providers/providers.dart';

// Utils
export 'utils/product_constants.dart';

// Widgets (re-exported from sales until fully migrated)
export 'widgets/widgets.dart';
