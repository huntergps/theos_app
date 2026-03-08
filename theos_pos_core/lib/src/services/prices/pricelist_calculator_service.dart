import 'package:drift/drift.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Unified service for all price-related operations
///
/// This is the single source of truth for prices in the application.
/// Like Odoo's product.pricelist model, this class centralizes:
///
/// **Instance methods (require database):**
/// - `calculatePrice()` - Calculate price from pricelist rules
/// - `preloadPricelistRules()` - Preload rules for performance
/// - UoM conversion with caching
/// - Category hierarchy matching
///
/// **Static methods (no database needed):**
/// - `applyDiscount()` - Apply discount percentage to a price
/// - `calculateDiscountAmount()` - Calculate discount amount
/// - `calculateSubtotal()` - Calculate line subtotal
/// - `convertPriceByFactor()` - Convert price between UoMs
///
/// Usage:
/// ```dart
/// final priceService = PricelistCalculatorService(db);
///
/// // Calculate price from pricelist
/// final result = await priceService.calculatePrice(
///   productId: 123,
///   productTmplId: 45,
///   pricelistId: 1,
///   quantity: 2.0,
///   listPrice: 100.0,
/// );
///
/// // Static calculations (no DB needed)
/// final discounted = PricelistCalculatorService.applyDiscount(100.0, 10.0);
/// // Returns: 90.0
/// ```
class PricelistCalculatorService {
  final AppDatabase _db;

  /// Cache for pricelist rules by pricelist ID
  final Map<int, List<ProductPricelistItemData>> _pricelistRulesCache = {};

  /// Cache for UoM conversion factors (key: "fromId_toId")
  final Map<String, double> _uomFactorCache = {};

  /// Cache for category parent IDs (key: category ID, value: list of parent IDs)
  final Map<int, List<int>> _categoryHierarchyCache = {};

  /// Cache for UoM data (key: uom ID, value: factor)
  final Map<int, double> _uomFactorByIdCache = {};

  /// Maximum cache age before auto-invalidation (in minutes)
  static const int _cacheMaxAgeMinutes = 30;

  /// Timestamp of last cache clear
  DateTime _lastCacheClear = DateTime.now();

  PricelistCalculatorService(this._db);

  /// Clear all caches (call after sync)
  void clearCache() {
    _pricelistRulesCache.clear();
    _uomFactorCache.clear();
    _categoryHierarchyCache.clear();
    _uomFactorByIdCache.clear();
    _lastCacheClear = DateTime.now();
    logger.d('[PricelistCalculator]', 'All caches cleared');
  }

  /// Check if cache is stale and clear if needed
  void _checkCacheAge() {
    final age = DateTime.now().difference(_lastCacheClear).inMinutes;
    if (age > _cacheMaxAgeMinutes) {
      logger.d(
        '[PricelistCalculator]',
        'Cache age ($age min) exceeds max ($_cacheMaxAgeMinutes min), clearing',
      );
      clearCache();
    }
  }

  /// Preload pricelist rules for specified pricelist IDs
  /// Call this during app initialization or when changing pricelists
  Future<void> preloadPricelistRules(List<int> pricelistIds) async {
    for (final pricelistId in pricelistIds) {
      if (_pricelistRulesCache.containsKey(pricelistId)) continue;

      final rules = await (_db.select(_db.productPricelistItem)
            ..where((t) => t.pricelistId.equals(pricelistId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.appliedOn),
              (t) => OrderingTerm.desc(t.minQuantity),
              (t) => OrderingTerm.desc(t.categId),
              (t) => OrderingTerm.desc(t.odooId),
            ]))
          .get();

      _pricelistRulesCache[pricelistId] = rules;
      logger.d(
        '[PricelistCalculator]',
        'Preloaded ${rules.length} rules for pricelist $pricelistId',
      );
    }
  }

  /// Calculate the product price based on pricelist rules
  ///
  /// Mimics Odoo's _compute_price_rule method:
  /// 1. Find applicable rules ordered by priority
  /// 2. Apply the first matching rule
  /// 3. Calculate the price based on compute_price type
  ///
  /// [productId] - product.product ID (variant)
  /// [productTmplId] - product.template ID
  /// [pricelistId] - product.pricelist ID
  /// [quantity] - quantity in product UoM
  /// [uomId] - UoM ID being sold (for UoM-specific pricing from l10n_ec_sale_base)
  /// [productUomId] - Product's base UoM ID (for UoM conversion)
  /// [listPrice] - product's list_price (in product UoM)
  /// [standardPrice] - product's standard_price/cost (in product UoM) - for cost-based rules
  /// [productUomFactor] - DEPRECATED: UoM conversion factor (now calculated internally)
  Future<PriceCalculationResult> calculatePrice({
    required int productId,
    required int productTmplId,
    required int pricelistId,
    required double quantity,
    int? uomId,
    int? productUomId,
    required double listPrice,
    double? standardPrice,
    double productUomFactor = 1.0,
  }) async {
    // Check cache age and clear if stale
    _checkCacheAge();

    try {
      logger.d(
        '[PricelistCalculator]',
        'Calculating price: product=$productId, tmpl=$productTmplId, pricelist=$pricelistId, qty=$quantity, saleUom=$uomId, productUom=$productUomId, listPrice=$listPrice, standardPrice=$standardPrice',
      );

      // Get product category for category-based rules
      final product = await (_db.select(
        _db.productProduct,
      )..where((t) => t.odooId.equals(productId))).getSingleOrNull();

      final int? categId = product?.categId;
      // Use product's uom_id if not provided
      final effectiveProductUomId = productUomId ?? product?.uomId;
      // Use product's standard_price (cost) if not provided
      final effectiveStandardPrice =
          standardPrice ?? product?.standardPrice ?? 0.0;

      // Calculate UoM conversion factor
      // In Odoo, list_price is in product's UoM, but we need to convert to sale UoM
      double uomConversionFactor = 1.0;
      if (uomId != null &&
          effectiveProductUomId != null &&
          uomId != effectiveProductUomId) {
        uomConversionFactor = await _getUomConversionFactor(
          fromUomId: effectiveProductUomId,
          toUomId: uomId,
        );
        logger.d(
          '[PricelistCalculator]',
          'UoM conversion: from $effectiveProductUomId to $uomId, factor=$uomConversionFactor',
        );
      }

      // Find applicable rules
      final rule = await _findApplicableRule(
        productId: productId,
        productTmplId: productTmplId,
        pricelistId: pricelistId,
        categId: categId,
        quantity: quantity,
        uomId: uomId,
        productUomId: effectiveProductUomId,
      );

      // Convert list_price and standard_price to sale UoM for base price calculation
      final listPriceInSaleUom = listPrice * uomConversionFactor;
      final standardPriceInSaleUom =
          effectiveStandardPrice * uomConversionFactor;

      if (rule == null) {
        logger.d(
          '[PricelistCalculator]',
          'No applicable rule found, using list price in sale UoM: $listPriceInSaleUom (listPrice=$listPrice * factor=$uomConversionFactor)',
        );
        return PriceCalculationResult(
          price: listPriceInSaleUom,
          basePrice: listPriceInSaleUom,
          discount: 0.0,
          ruleId: null,
          computeType: 'list_price',
        );
      }

      // Handle recursive pricelist base calculation
      // If rule is formula-based with pricelist base, calculate from base pricelist first
      double effectiveListPrice = listPriceInSaleUom;
      if (rule.computePrice == 'formula' &&
          rule.base == 'pricelist' &&
          rule.basePricelistId != null) {
        effectiveListPrice = await _getBasePricelistPrice(
          basePricelistId: rule.basePricelistId!,
          productId: productId,
          productTmplId: productTmplId,
          quantity: quantity,
          uomId: uomId,
          productUomId: productUomId,
          listPrice: listPrice,
          standardPrice: effectiveStandardPrice,
        );
        logger.d(
          '[PricelistCalculator]',
          'Base pricelist ${rule.basePricelistId} returned price: $effectiveListPrice',
        );
      }

      // Calculate price based on rule type
      // Pass the UoM conversion factor for fixed prices and surcharges
      final priceResult = _computePriceWithDiscount(
        rule: rule,
        listPrice: effectiveListPrice,
        standardPrice: standardPriceInSaleUom,
        productUomFactor: uomConversionFactor,
      );

      logger.d(
        '[PricelistCalculator]',
        'Rule ${rule.odooId} (${rule.computePrice}) applied: price=${priceResult.price}, basePrice=${priceResult.basePrice}, discount=${priceResult.discount}%',
      );

      return PriceCalculationResult(
        price: priceResult.price,
        basePrice: priceResult.basePrice,
        discount: priceResult.discount,
        ruleId: rule.odooId,
        computeType: rule.computePrice,
      );
    } catch (e) {
      logger.e('[PricelistCalculator]', 'Error calculating price: $e');
      return PriceCalculationResult(
        price: listPrice,
        basePrice: listPrice,
        discount: 0.0,
        ruleId: null,
        computeType: 'error',
      );
    }
  }

  /// Calculate the conversion factor between two UoMs
  /// Returns the factor to multiply prices from [fromUomId] to [toUomId]
  ///
  /// Example: If Units has factor=1.0 and Caja has factor=12.0
  /// - Converting from Units to Caja: 1 Caja = 12 Units, so price_per_caja = price_per_unit * 12
  ///
  /// Uses cache to avoid repeated DB queries.
  Future<double> _getUomConversionFactor({
    required int fromUomId,
    required int toUomId,
  }) async {
    if (fromUomId == toUomId) return 1.0;

    // Check cache first
    final cacheKey = '${fromUomId}_$toUomId';
    if (_uomFactorCache.containsKey(cacheKey)) {
      return _uomFactorCache[cacheKey]!;
    }

    try {
      final fromUom = await (_db.select(
        _db.uomUom,
      )..where((t) => t.odooId.equals(fromUomId))).getSingleOrNull();
      final toUom = await (_db.select(
        _db.uomUom,
      )..where((t) => t.odooId.equals(toUomId))).getSingleOrNull();

      if (fromUom == null || toUom == null) {
        logger.w(
          '[PricelistCalculator]',
          'UoM not found: from=$fromUomId (${fromUom != null}), to=$toUomId (${toUom != null})',
        );
        return 1.0;
      }

      // In Odoo's uom.uom, factor is the ratio to the reference unit
      // factor = how many reference units are in this UoM
      // Units: factor=1.0 (reference)
      // Caja: factor=12.0 (1 Caja = 12 reference units)
      //
      // To convert price from Units to Caja:
      // price_per_caja = price_per_unit * (toUom.factor / fromUom.factor)
      // price_per_caja = 1.0 * (12.0 / 1.0) = 12.0
      final factor = toUom.factor / fromUom.factor;

      // Cache the result
      _uomFactorCache[cacheKey] = factor;

      logger.d(
        '[PricelistCalculator]',
        'UoM factors: from=${fromUom.factor}, to=${toUom.factor}, conversion=$factor (cached)',
      );

      return factor;
    } catch (e) {
      logger.e(
        '[PricelistCalculator]',
        'Error getting UoM conversion factor: $e',
      );
      return 1.0;
    }
  }

  /// Find the first applicable rule based on Odoo's rule ordering:
  /// ORDER BY applied_on, min_quantity DESC, categ_id DESC, id DESC
  ///
  /// applied_on values (lower = more specific):
  /// - 0_product_variant (most specific)
  /// - 1_product
  /// - 2_product_category
  /// - 3_global (least specific)
  ///
  /// Uses cached pricelist rules when available for better performance.
  ///
  /// IMPORTANT: min_quantity comparison is done in BASE UNITS.
  /// When selling qty=1 "Paquete de 6" (factor=6), the comparison is:
  /// - qty in base units = 1 * 6 = 6
  /// - if min_quantity=6, then 6 >= 6, rule applies
  Future<ProductPricelistItemData?> _findApplicableRule({
    required int productId,
    required int productTmplId,
    required int pricelistId,
    int? categId,
    required double quantity,
    int? uomId,
    int? productUomId,
  }) async {
    final now = DateTime.now();

    // Calculate quantity in BASE UNITS for min_quantity comparison
    // Odoo's min_quantity is in the reference UoM of the category (usually "Units")
    // We use the sale UoM's factor directly (factor = how many base units in 1 of this UoM)
    // Example: qty=1 "Paquete de 6" (factor=6) -> qtyInBaseUnits = 1 * 6 = 6 Units
    double qtyInBaseUnits = quantity;
    if (uomId != null) {
      // Get the sale UoM's factor (cached)
      double? uomFactor = _uomFactorByIdCache[uomId];
      String? uomName;

      if (uomFactor == null) {
        final saleUom = await (_db.select(
          _db.uomUom,
        )..where((t) => t.odooId.equals(uomId))).getSingleOrNull();

        if (saleUom != null && saleUom.factor > 0) {
          uomFactor = saleUom.factor;
          uomName = saleUom.name;
          _uomFactorByIdCache[uomId] = uomFactor;
        }
      }

      if (uomFactor != null && uomFactor > 0) {
        qtyInBaseUnits = quantity * uomFactor;
        logger.d(
          '[PricelistCalculator]',
          'Converting qty for min_quantity check: $quantity x ${uomName ?? 'UoM $uomId'} (factor=$uomFactor) = $qtyInBaseUnits base units',
        );
      }
    }

    // Get rules from cache or database
    List<ProductPricelistItemData> rules;
    if (_pricelistRulesCache.containsKey(pricelistId)) {
      // Use cached rules, filter by quantity IN BASE UNITS
      rules = _pricelistRulesCache[pricelistId]!
          .where((r) => r.minQuantity <= qtyInBaseUnits)
          .toList();
    } else {
      // Fetch from DB and cache
      final query = _db.select(_db.productPricelistItem)
        ..where((t) => t.pricelistId.equals(pricelistId))
        ..orderBy([
          (t) => OrderingTerm.asc(t.appliedOn),
          (t) => OrderingTerm.desc(t.minQuantity),
          (t) => OrderingTerm.desc(t.categId),
          (t) => OrderingTerm.desc(t.odooId),
        ]);

      final allRules = await query.get();
      _pricelistRulesCache[pricelistId] = allRules;
      rules = allRules.where((r) => r.minQuantity <= qtyInBaseUnits).toList();
      logger.d(
        '[PricelistCalculator]',
        'Cached ${allRules.length} rules for pricelist $pricelistId',
      );
    }

    logger.d(
      '[PricelistCalculator]',
      'Found ${rules.length} rules for pricelist $pricelistId with min_qty <= $qtyInBaseUnits base units (sale qty=$quantity, uomId=$uomId)',
    );

    // Log all rules for debugging
    for (final r in rules) {
      logger.d(
        '[PricelistCalculator]',
        '  Rule ${r.odooId}: applied_on=${r.appliedOn}, product_id=${r.productId}, tmpl_id=${r.productTmplId}, '
            'uom_id=${r.uomId}, compute_price=${r.computePrice}, percent=${r.percentPrice}%',
      );
    }

    for (final rule in rules) {
      // Check date validity
      if (rule.dateStart != null && rule.dateStart!.isAfter(now)) {
        logger.d(
          '[PricelistCalculator]',
          'Rule ${rule.odooId}: skipped - not started yet',
        );
        continue;
      }
      if (rule.dateEnd != null && rule.dateEnd!.isBefore(now)) {
        logger.d(
          '[PricelistCalculator]',
          'Rule ${rule.odooId}: skipped - expired',
        );
        continue;
      }

      // Check UoM filter (l10n_ec_sale_base extension)
      // If rule has uomId set, it only applies to that specific UoM
      if (rule.uomId != null) {
        if (uomId == null || rule.uomId != uomId) {
          logger.d(
            '[PricelistCalculator]',
            'Rule ${rule.odooId}: skipped - UoM mismatch (rule.uomId=${rule.uomId}, sale.uomId=$uomId)',
          );
          continue; // Rule requires specific UoM but sale UoM doesn't match
        }
      }

      // Check applied_on match
      bool matches = false;
      switch (rule.appliedOn) {
        case '0_product_variant':
          matches = rule.productId == productId;
          break;
        case '1_product':
          matches = rule.productTmplId == productTmplId;
          break;
        case '2_product_category':
          if (rule.categId != null && categId != null) {
            // Check category hierarchy (Odoo 19 compatible)
            // A rule for category "Electronics" should apply to "Electronics > Phones"
            matches = await _categoryMatchesWithHierarchy(
              ruleCategoryId: rule.categId!,
              productCategoryId: categId,
            );
          }
          break;
        case '3_global':
          matches = true; // Global rules apply to all
          break;
        default:
          matches = false;
      }

      if (matches) {
        logger.d(
          '[PricelistCalculator]',
          'Rule ${rule.odooId} MATCHED! applied_on=${rule.appliedOn}, uom_id=${rule.uomId}',
        );
        return rule;
      } else {
        logger.d(
          '[PricelistCalculator]',
          'Rule ${rule.odooId}: applied_on=${rule.appliedOn} did not match product/template/category',
        );
      }
    }

    logger.d(
      '[PricelistCalculator]',
      'No matching rule found for uomId=$uomId',
    );
    return null;
  }

  /// Compute price based on the rule's compute_price type
  /// Mimics Odoo's _compute_price method
  /// Returns both the final price AND the base price/discount for display
  ///
  /// [listPrice] - product's list_price in target UoM
  /// [standardPrice] - product's standard_price (cost) in target UoM
  _PriceWithDiscount _computePriceWithDiscount({
    required ProductPricelistItemData rule,
    required double listPrice,
    required double standardPrice,
    double productUomFactor = 1.0,
  }) {
    // Determine base price based on rule's base setting
    // This is what Odoo shows as price_unit before discount
    double basePrice;
    switch (rule.base) {
      case 'list_price':
        basePrice = listPrice;
        break;
      case 'standard_price':
        // Use product's cost price
        basePrice = standardPrice;
        logger.d(
          '[PricelistCalculator]',
          'Using standard_price (cost) as base: $standardPrice',
        );
        break;
      case 'pricelist':
        // This case is handled by the caller when rule.basePricelistId is set
        // Here we just use list price as fallback (the recursive calculation
        // happens in calculatePrice method before calling this)
        basePrice = listPrice;
        break;
      default:
        basePrice = listPrice;
    }

    double price;
    double discount = 0.0;

    switch (rule.computePrice) {
      case 'fixed':
        // Fixed prices are defined in product UoM, convert if needed
        // For fixed price, the base price IS the fixed price, no discount
        price = rule.fixedPrice * productUomFactor;
        basePrice = price; // Fixed price replaces base price
        discount = 0.0;
        break;

      case 'percentage':
        // percentage discount on base price
        // In Odoo: price_unit = basePrice, discount = percent_price
        discount = rule.percentPrice;
        price = basePrice - (basePrice * (discount / 100));
        break;

      case 'formula':
        // Full formula: base - discount% + surcharge, with rounding and margins
        // In Odoo:
        //   - For list_price base: discount = price_discount (positive = discount)
        //   - For standard_price base: discount = -price_markup (stored as price_discount)
        //     When user sets markup=105%, price_discount=-105 is stored
        //     Formula: price = cost - (cost * -105/100) = cost + cost*1.05 = cost*2.05
        discount = rule.priceDiscount;
        final priceLimit = basePrice; // Used for margin calculations

        logger.d(
          '[PricelistCalculator]',
          'Formula: base=${rule.base}, basePrice=$basePrice, priceDiscount=${rule.priceDiscount}',
        );

        price = basePrice - (basePrice * (discount / 100));

        logger.d(
          '[PricelistCalculator]',
          'Formula after discount: price=$price (basePrice - basePrice * $discount/100)',
        );

        // Apply rounding
        if (rule.priceRound > 0) {
          price = _roundPrice(price, rule.priceRound);
          logger.d('[PricelistCalculator]', 'After rounding: price=$price');
        }

        // Apply surcharge (surcharge is added to price, doesn't affect discount %)
        if (rule.priceSurcharge != 0) {
          price += rule.priceSurcharge * productUomFactor;
          logger.d(
            '[PricelistCalculator]',
            'After surcharge: price=$price (surcharge=${rule.priceSurcharge} * factor=$productUomFactor)',
          );
        }

        // Apply min/max margins (relative to price_limit, not basePrice after modifications)
        if (rule.priceMinMargin > 0) {
          final minPrice =
              priceLimit + (rule.priceMinMargin * productUomFactor);
          price = price.clamp(minPrice, double.infinity);
          logger.d(
            '[PricelistCalculator]',
            'After min margin: price=$price (min=$minPrice)',
          );
        }
        if (rule.priceMaxMargin > 0) {
          final maxPrice =
              priceLimit + (rule.priceMaxMargin * productUomFactor);
          price = price.clamp(0, maxPrice);
          logger.d(
            '[PricelistCalculator]',
            'After max margin: price=$price (max=$maxPrice)',
          );
        }

        // For display purposes, recalculate the effective discount
        // For cost-based markup: this will be negative (which is correct - it's a markup)
        // For list_price discount: this will be positive (discount)
        if (basePrice > 0) {
          discount = ((basePrice - price) / basePrice) * 100;
          // Don't clamp to 0 anymore - negative discount means markup
          // This is intentional for cost-based rules
        }
        break;

      default:
        price = basePrice;
        discount = 0.0;
    }

    return _PriceWithDiscount(
      price: price,
      basePrice: basePrice,
      discount: discount,
    );
  }

  /// Round price to multiple of rounding value
  double _roundPrice(double price, double rounding) {
    if (rounding <= 0) return price;
    return (price / rounding).round() * rounding;
  }

  /// Check if the product's category matches the rule's category
  /// considering the category hierarchy (Odoo 19 compatible)
  ///
  /// In Odoo, a rule for category "Electronics" should apply to products
  /// in "Electronics > Phones" or "Electronics > Computers > Laptops"
  ///
  /// [ruleCategoryId] - category ID in the pricelist rule
  /// [productCategoryId] - the product's category ID
  /// [maxDepth] - maximum depth to traverse (default 10 to prevent infinite loops)
  Future<bool> _categoryMatchesWithHierarchy({
    required int ruleCategoryId,
    required int productCategoryId,
    int maxDepth = 10,
  }) async {
    // Direct match
    if (ruleCategoryId == productCategoryId) {
      return true;
    }

    // Check if we have cached hierarchy for this category
    if (_categoryHierarchyCache.containsKey(productCategoryId)) {
      final hierarchy = _categoryHierarchyCache[productCategoryId]!;
      return hierarchy.contains(ruleCategoryId);
    }

    // Build and cache the hierarchy
    final hierarchy = <int>[];
    int? currentCategoryId = productCategoryId;
    int depth = 0;

    while (currentCategoryId != null && depth < maxDepth) {
      // Get the category from DB
      final category = await (_db.select(_db.productCategory)
            ..where((t) => t.odooId.equals(currentCategoryId!)))
          .getSingleOrNull();

      if (category == null) {
        break;
      }

      // Add parent to hierarchy
      if (category.parentId != null) {
        hierarchy.add(category.parentId!);
      }

      // Move up to parent
      currentCategoryId = category.parentId;
      depth++;
    }

    // Cache the hierarchy
    _categoryHierarchyCache[productCategoryId] = hierarchy;

    // Check if rule category is in hierarchy
    final matches = hierarchy.contains(ruleCategoryId);
    if (matches) {
      logger.d(
        '[PricelistCalculator]',
        'Category hierarchy match: product categ $productCategoryId is child of rule categ $ruleCategoryId (cached hierarchy)',
      );
    }

    return matches;
  }

  /// Recursively calculate price from a base pricelist
  /// Used when compute_price = 'formula' and base = 'pricelist'
  ///
  /// This allows chained pricelists: e.g., "Retail" based on "Wholesale"
  /// which is based on "Distributor" prices
  Future<double> _getBasePricelistPrice({
    required int basePricelistId,
    required int productId,
    required int productTmplId,
    required double quantity,
    int? uomId,
    int? productUomId,
    required double listPrice,
    double? standardPrice,
    int recursionDepth = 0,
    int maxRecursion = 5,
  }) async {
    // Prevent infinite recursion
    if (recursionDepth >= maxRecursion) {
      logger.w(
        '[PricelistCalculator]',
        'Max pricelist recursion depth reached ($maxRecursion), using list price',
      );
      return listPrice;
    }

    logger.d(
      '[PricelistCalculator]',
      'Recursively calculating price from base pricelist $basePricelistId (depth=$recursionDepth)',
    );

    // Get product category
    final product = await (_db.select(_db.productProduct)
          ..where((t) => t.odooId.equals(productId)))
        .getSingleOrNull();

    final int? categId = product?.categId;
    final effectiveProductUomId = productUomId ?? product?.uomId;
    final effectiveStandardPrice =
        standardPrice ?? product?.standardPrice ?? 0.0;

    // Calculate UoM conversion factor
    double uomConversionFactor = 1.0;
    if (uomId != null &&
        effectiveProductUomId != null &&
        uomId != effectiveProductUomId) {
      uomConversionFactor = await _getUomConversionFactor(
        fromUomId: effectiveProductUomId,
        toUomId: uomId,
      );
    }

    // Find applicable rule in the base pricelist
    final rule = await _findApplicableRule(
      productId: productId,
      productTmplId: productTmplId,
      pricelistId: basePricelistId,
      categId: categId,
      quantity: quantity,
      uomId: uomId,
      productUomId: effectiveProductUomId,
    );

    if (rule == null) {
      return listPrice * uomConversionFactor;
    }

    // Convert prices to sale UoM
    final listPriceInSaleUom = listPrice * uomConversionFactor;
    final standardPriceInSaleUom =
        effectiveStandardPrice * uomConversionFactor;

    // Handle recursive pricelist base
    if (rule.computePrice == 'formula' &&
        rule.base == 'pricelist' &&
        rule.basePricelistId != null) {
      final recursiveBasePrice = await _getBasePricelistPrice(
        basePricelistId: rule.basePricelistId!,
        productId: productId,
        productTmplId: productTmplId,
        quantity: quantity,
        uomId: uomId,
        productUomId: productUomId,
        listPrice: listPrice,
        standardPrice: standardPrice,
        recursionDepth: recursionDepth + 1,
        maxRecursion: maxRecursion,
      );

      // Apply the formula to the recursive base price
      return _applyFormulaToBasePrice(
        rule: rule,
        basePrice: recursiveBasePrice,
        productUomFactor: uomConversionFactor,
      );
    }

    // Calculate price using the rule
    final priceResult = _computePriceWithDiscount(
      rule: rule,
      listPrice: listPriceInSaleUom,
      standardPrice: standardPriceInSaleUom,
      productUomFactor: uomConversionFactor,
    );

    return priceResult.price;
  }

  /// Apply formula modifiers (discount, surcharge, rounding, margins) to a base price
  double _applyFormulaToBasePrice({
    required ProductPricelistItemData rule,
    required double basePrice,
    double productUomFactor = 1.0,
  }) {
    double price = basePrice;

    // Apply discount
    if (rule.priceDiscount != 0) {
      price = price - (price * (rule.priceDiscount / 100));
    }

    // Apply rounding
    if (rule.priceRound > 0) {
      price = _roundPrice(price, rule.priceRound);
    }

    // Apply surcharge
    if (rule.priceSurcharge != 0) {
      price += rule.priceSurcharge * productUomFactor;
    }

    // Apply min margin
    if (rule.priceMinMargin > 0) {
      final minPrice = basePrice + (rule.priceMinMargin * productUomFactor);
      price = price.clamp(minPrice, double.infinity);
    }

    // Apply max margin
    if (rule.priceMaxMargin > 0) {
      final maxPrice = basePrice + (rule.priceMaxMargin * productUomFactor);
      price = price.clamp(0, maxPrice);
    }

    return price;
  }

  // ===========================================================================
  // STATIC UTILITIES - COMMON PRICE CALCULATIONS
  // ===========================================================================

  /// Apply a discount percentage to a base price
  ///
  /// Example: applyDiscount(100.0, 10.0) => 90.0
  ///
  /// [basePrice] - Original price
  /// [discountPercent] - Discount percentage (0-100)
  static double applyDiscount(double basePrice, double discountPercent) {
    if (discountPercent <= 0) return basePrice;
    return basePrice * (1 - discountPercent / 100);
  }

  /// Calculate the discount amount
  ///
  /// Example: calculateDiscountAmount(100.0, 2.0, 10.0) => 20.0
  ///
  /// [priceUnit] - Unit price before discount
  /// [quantity] - Quantity
  /// [discountPercent] - Discount percentage (0-100)
  static double calculateDiscountAmount(
    double priceUnit,
    double quantity,
    double discountPercent,
  ) {
    if (discountPercent <= 0 || priceUnit <= 0 || quantity <= 0) return 0.0;
    return priceUnit * quantity * (discountPercent / 100);
  }

  /// Calculate subtotal (price * quantity - discount)
  ///
  /// Example: calculateSubtotal(100.0, 2.0, 10.0) => 180.0
  ///
  /// [priceUnit] - Unit price before discount
  /// [quantity] - Quantity
  /// [discountPercent] - Discount percentage (0-100)
  static double calculateSubtotal(
    double priceUnit,
    double quantity,
    double discountPercent,
  ) {
    final discountedPrice = applyDiscount(priceUnit, discountPercent);
    return discountedPrice * quantity;
  }

  /// Convert price between UoMs using a conversion factor
  ///
  /// Example: convertPriceByFactor(10.0, 12.0) => 120.0
  /// (Unit price 10, Caja factor 12 => Caja price 120)
  ///
  /// [price] - Price in source UoM
  /// [factor] - Conversion factor (target UoM factor / source UoM factor)
  static double convertPriceByFactor(double price, double factor) {
    if (factor <= 0) return price;
    return price * factor;
  }

  /// Calculate the effective discount percentage from two prices
  ///
  /// Example: calculateDiscountPercent(100.0, 90.0) => 10.0
  ///
  /// [originalPrice] - Original/list price
  /// [finalPrice] - Final price after discount
  static double calculateDiscountPercent(
    double originalPrice,
    double finalPrice,
  ) {
    if (originalPrice <= 0) return 0.0;
    final discount = ((originalPrice - finalPrice) / originalPrice) * 100;
    return discount.clamp(0, 100);
  }

  /// Round price to specified decimal places
  ///
  /// Example: roundPrice(10.1234, 2) => 10.12
  static double roundPrice(double price, int decimals) {
    final factor = _pow10(decimals);
    return (price * factor).round() / factor;
  }

  /// Helper for power of 10 calculation
  static double _pow10(int exponent) {
    double result = 1.0;
    for (int i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }
}

/// Internal helper class for price calculation with discount
class _PriceWithDiscount {
  final double price;
  final double basePrice;
  final double discount;

  _PriceWithDiscount({
    required this.price,
    required this.basePrice,
    required this.discount,
  });
}

/// Result of price calculation
class PriceCalculationResult {
  /// The final price after applying pricelist rules (already discounted for percentage/formula)
  final double price;

  /// The base price BEFORE any pricelist discount (used for display)
  /// In Odoo, this becomes price_unit and discount shows the percentage off
  final double basePrice;

  /// The discount percentage from the pricelist rule (0-100)
  /// Only set for percentage and formula rules with discount
  final double discount;

  final int? ruleId;
  final String computeType;

  PriceCalculationResult({
    required this.price,
    required this.basePrice,
    this.discount = 0.0,
    this.ruleId,
    required this.computeType,
  });

  @override
  String toString() =>
      'PriceCalculationResult(price: $price, basePrice: $basePrice, discount: $discount, ruleId: $ruleId, computeType: $computeType)';
}
