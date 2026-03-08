import 'package:drift/drift.dart' show Variable;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper, logger;

import '../../../core/database/providers.dart';
import '../../../core/managers/manager_providers.dart' show appDatabaseProvider;
import '../../../core/services/logger_service.dart';
import '../../../shared/utils/formatting_utils.dart';

// ============================================================================
// DATA MODELS
// ============================================================================

/// Represents a single tax with its details
class TaxDetail {
  final int id;
  final String name;
  final String shortName;
  final double percent;
  final String amountType;

  const TaxDetail({
    required this.id,
    required this.name,
    required this.shortName,
    required this.percent,
    required this.amountType,
  });
}

/// Represents a UoM with calculated pricing
class UomPriceData {
  final int id;
  final String name;
  final double factor;
  final double price;
  final String priceRuleType; // 'Precio Fijo', '% Descuento', 'Formula', ''
  final double discount;
  final Map<String, double> taxAmounts;
  final double totalTax;
  final double pvp;
  final String? barcode;

  const UomPriceData({
    required this.id,
    required this.name,
    required this.factor,
    required this.price,
    this.priceRuleType = '',
    this.discount = 0.0,
    this.taxAmounts = const {},
    this.totalTax = 0.0,
    required this.pvp,
    this.barcode,
  });
}

// ============================================================================
// PRICE LOADER SERVICE
// ============================================================================

/// Service to load UoMs and calculate prices with pricelist rules
class ProductUomPriceLoader {
  final WidgetRef ref;

  ProductUomPriceLoader(this.ref);

  /// Load tax info for a product
  Future<List<TaxDetail>> loadTaxInfo(int productId) async {
    try {
      final taxCalculator = ref.read(taxCalculatorProvider);
      final taxInfo = await taxCalculator.getProductTaxInfo(
        productId: productId,
      );

      return taxInfo.taxes.map((tax) {
        String shortName = tax.name;
        final parenIndex = tax.name.indexOf('(');
        if (parenIndex > 0) {
          shortName = tax.name.substring(0, parenIndex).trim();
        }

        return TaxDetail(
          id: tax.id,
          name: tax.name,
          shortName: shortName,
          percent: tax.amount,
          amountType: tax.amountType,
        );
      }).toList();
    } catch (e) {
      logger.w('[ProductUomPriceLoader]', 'Error loading tax info: $e');
      return [];
    }
  }

  /// Load UoMs for a product with calculated prices
  Future<List<UomPriceData>> loadUomsWithPrices({
    required int productId,
    int? productTmplId,
    int? pricelistId,
    double? listPrice,
    List<int>? allowedUomIds,
    List<TaxDetail> taxes = const [],
  }) async {
    List<Map<String, dynamic>> uomList = [];
    int? productBaseUomId;

    // Get product via manager
    final product = await productManager.readLocal(productId);
    productBaseUomId = product?.uomId;

    // Load UoMs based on allowedUomIds or product config
    if (allowedUomIds != null && allowedUomIds.isNotEmpty) {
      final uoms = await _loadUomsByIds(allowedUomIds);
      uomList = uoms;
    } else {
      if (product != null && product.allowedUomIds.isNotEmpty) {
        uomList = await _loadUomsByIds(product.allowedUomIds);
      }

      // Fallback to category UoMs
      if (uomList.isEmpty && product != null && product.uomId != null) {
        final baseUom = await uomManager.readLocal(product.uomId!);
        if (baseUom?.categoryId != null) {
          final categoryUoms = await uomManager.searchLocal(
            domain: [['category_id', '=', baseUom!.categoryId]],
            orderBy: 'factor asc',
          );
          uomList = categoryUoms
              .map((u) => <String, dynamic>{
                    'id': u.id,
                    'name': u.name,
                    'factor': u.factor,
                  })
              .toList();
        }
      }
    }

    // Load barcodes from product_uom via manager
    final productUoms = await productUomManager.searchLocal(
      domain: [['product_id', '=', productId]],
    );
    final barcodeMap = <int, String>{};
    for (final pu in productUoms) {
      if (pu.barcode.isNotEmpty) {
        barcodeMap[pu.uomId] = pu.barcode;
      }
    }

    // Calculate prices if pricelist provided
    if (pricelistId != null && listPrice != null) {
      return _calculatePricesForUoms(
        uoms: uomList,
        productBaseUomId: productBaseUomId,
        productId: productId,
        productTmplId: productTmplId,
        pricelistId: pricelistId,
        listPrice: listPrice,
        taxes: taxes,
        barcodeMap: barcodeMap,
        db: ref.read(appDatabaseProvider),
      );
    }

    // Return UoMs without price calculation
    return uomList.map((uom) {
      final uomId = uom['id'] as int;
      return UomPriceData(
        id: uomId,
        name: uom['name'] as String? ?? '',
        factor: (uom['factor'] as double?) ?? 1.0,
        price: 0,
        pvp: 0,
        barcode: barcodeMap[uomId],
      );
    }).toList();
  }

  /// Helper to load UoMs by list of IDs via manager
  Future<List<Map<String, dynamic>>> _loadUomsByIds(List<int> uomIds) async {
    final uoms = <Map<String, dynamic>>[];
    for (final id in uomIds) {
      final uom = await uomManager.readLocal(id);
      if (uom != null) {
        uoms.add({
          'id': uom.id,
          'name': uom.name,
          'factor': uom.factor,
        });
      }
    }
    // Sort by factor
    uoms.sort((a, b) => (a['factor'] as double).compareTo(b['factor'] as double));
    return uoms;
  }

  Future<List<UomPriceData>> _calculatePricesForUoms({
    required List<Map<String, dynamic>> uoms,
    required int? productBaseUomId,
    required int productId,
    required int? productTmplId,
    required int pricelistId,
    required double listPrice,
    required List<TaxDetail> taxes,
    required Map<int, String> barcodeMap,
    required dynamic db,
  }) async {
    logger.d(
      '[ProductUomPriceLoader]',
      'Calculating prices: productId=$productId, productTmplId=$productTmplId, '
      'pricelistId=$pricelistId, listPrice=$listPrice, uoms=${uoms.length}',
    );

    double baseUomFactor = 1.0;
    if (productBaseUomId != null) {
      final baseUom = await uomManager.readLocal(productBaseUomId);
      if (baseUom != null) {
        baseUomFactor = baseUom.factor;
      }
    }

    final result = <UomPriceData>[];

    for (final uom in uoms) {
      final uomId = uom['id'] as int;
      final uomFactor = (uom['factor'] as double?) ?? 1.0;
      final conversionFactor = uomFactor / baseUomFactor;

      double price = listPrice * conversionFactor;
      String priceRuleType = '';
      double discount = 0.0;

      final now = DateTime.now().toIso8601String();
      final query = '''
        SELECT * FROM product_pricelist_item
        WHERE pricelist_id = ?
          AND (date_start IS NULL OR date_start <= ?)
          AND (date_end IS NULL OR date_end >= ?)
          AND min_quantity <= ?
        ORDER BY applied_on ASC, min_quantity DESC, odoo_id DESC
      ''';

      final rules = await db
          .customSelect(
            query,
            variables: [
              Variable.withInt(pricelistId),
              Variable.withString(now),
              Variable.withString(now),
              Variable.withReal(uomFactor),
            ],
          )
          .get();

      logger.d(
        '[ProductUomPriceLoader]',
        'UoM $uomId (factor=$uomFactor): Found ${rules.length} potential rules',
      );

      for (final rule in rules) {
        final appliedOn = rule.read<String>('applied_on');
        final ruleProductId = rule.readNullable<int>('product_id');
        final ruleProductTmplId = rule.readNullable<int>('product_tmpl_id');
        final ruleUomId = rule.readNullable<int>('uom_id');

        if (ruleUomId != null && ruleUomId != uomId) continue;

        bool matches = false;
        switch (appliedOn) {
          case '0_product_variant':
            matches = ruleProductId == productId;
          case '1_product':
            matches = ruleProductTmplId == productTmplId;
          case '3_global':
            matches = true;
          default:
            matches = false;
        }

        if (matches) {
          final computePrice = rule.read<String>('compute_price');
          final fixedPrice = rule.read<double>('fixed_price');
          final percentPrice = rule.read<double>('percent_price');
          final priceDiscount = rule.read<double>('price_discount');
          final priceSurcharge = rule.read<double>('price_surcharge');

          logger.d(
            '[ProductUomPriceLoader]',
            'UoM $uomId: Rule matched! computePrice=$computePrice, '
            'fixedPrice=$fixedPrice, priceDiscount=$priceDiscount',
          );

          switch (computePrice) {
            case 'fixed':
              price = fixedPrice * conversionFactor;
              priceRuleType = 'Precio Fijo';
              break;
            case 'percentage':
              price = (listPrice * conversionFactor) * (1 - percentPrice / 100);
              priceRuleType = '% Descuento';
              discount = percentPrice;
              break;
            case 'formula':
              final basePrice = listPrice * conversionFactor;
              price = basePrice * (1 - priceDiscount / 100) +
                  (priceSurcharge * conversionFactor);
              priceRuleType = 'Formula';
              discount = priceDiscount;
              break;
          }
          break;
        }
      }

      logger.d(
        '[ProductUomPriceLoader]',
        'UoM $uomId final: price=$price, ruleType=$priceRuleType',
      );

      // Calculate individual tax amounts
      final taxAmounts = <String, double>{};
      double totalTaxAmount = 0.0;

      for (final tax in taxes) {
        if (tax.amountType == 'percent') {
          final amount = price * (tax.percent / 100);
          taxAmounts[tax.shortName] = amount;
          totalTaxAmount += amount;
        }
      }

      final pvp = price + totalTaxAmount;

      result.add(UomPriceData(
        id: uomId,
        name: uom['name'] as String? ?? '',
        factor: uomFactor,
        price: price,
        priceRuleType: priceRuleType,
        discount: discount,
        taxAmounts: taxAmounts,
        totalTax: totalTaxAmount,
        pvp: pvp,
        barcode: barcodeMap[uomId],
      ));
    }

    return result;
  }
}

// ============================================================================
// REUSABLE TABLE WIDGET
// ============================================================================

/// Reusable widget to display UoM pricing table
/// Can be used in read-only mode (ProductInfoDialog) or selectable mode (SelectUomDialog)
class ProductUomPricingTable extends StatelessWidget {
  final List<UomPriceData> uoms;
  final List<TaxDetail> taxes;
  final int? selectedUomId;
  final bool readOnly;
  final bool showBarcode;
  final bool showDiscount;
  final ValueChanged<UomPriceData>? onSelect;

  const ProductUomPricingTable({
    super.key,
    required this.uoms,
    this.taxes = const [],
    this.selectedUomId,
    this.readOnly = false,
    this.showBarcode = false,
    this.showDiscount = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(theme),
          ...uoms.map((uom) => _buildRow(theme, uom)),
        ],
      ),
    );
  }

  Widget _buildHeader(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.accentColor.withAlpha(20),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
      child: Row(
        children: [
          if (!readOnly) const SizedBox(width: 24),
          const Expanded(
            flex: 3,
            child: Text(
              'Nombre',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(
            width: 65,
            child: Text(
              'Factor',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          if (showDiscount)
            const SizedBox(
              width: 55,
              child: Text(
                'Dto.%',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.right,
              ),
            ),
          const SizedBox(
            width: 80,
            child: Text(
              'Precio',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.right,
            ),
          ),
          // Dynamic tax columns
          ...taxes.map((tax) => SizedBox(
                width: 80,
                child: Text(
                  tax.shortName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              )),
          if (taxes.isEmpty)
            const SizedBox(
              width: 80,
              child: Text(
                'Impuesto',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.right,
              ),
            ),
          const SizedBox(
            width: 80,
            child: Text(
              'c/IVA',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.right,
            ),
          ),
          if (showBarcode)
            const Expanded(
              child: Text(
                'Cod. Barras',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.right,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(FluentThemeData theme, UomPriceData uom) {
    final isSelected = uom.id == selectedUomId;

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? theme.accentColor.withAlpha(30) : null,
        border: Border(
          bottom: BorderSide(color: theme.resources.dividerStrokeColorDefault),
        ),
      ),
      child: Row(
        children: [
          if (!readOnly)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                isSelected ? FluentIcons.checkbox_composite : FluentIcons.quantity,
                size: 18,
                color: isSelected ? theme.accentColor : theme.inactiveColor,
              ),
            ),
          // Name
          Expanded(
            flex: 3,
            child: Text(
              uom.name,
              style: TextStyle(
                fontSize: 14,
                color: theme.accentColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Factor
          SizedBox(
            width: 65,
            child: Text(
              uom.factor == 1.0 ? '-' : uom.factor.toFixed(0),
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          // Discount
          if (showDiscount)
            SizedBox(
              width: 55,
              child: Text(
                uom.discount > 0 ? '${uom.discount.toFixed(1)}%' : '-',
                style: TextStyle(
                  fontSize: 14,
                  color: uom.discount > 0 ? Colors.green : null,
                  fontWeight: uom.discount > 0 ? FontWeight.w500 : null,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          // Price
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  uom.price.toCurrency(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: uom.priceRuleType.isNotEmpty ? Colors.green : null,
                  ),
                ),
                if (uom.priceRuleType.isNotEmpty)
                  Text(
                    uom.priceRuleType,
                    style: TextStyle(fontSize: 10, color: Colors.green),
                  ),
              ],
            ),
          ),
          // Dynamic tax columns
          ...taxes.map((tax) => SizedBox(
                width: 80,
                child: Text(
                  (uom.taxAmounts[tax.shortName] ?? 0.0).toCurrency(),
                  style: TextStyle(fontSize: 14, color: theme.inactiveColor),
                  textAlign: TextAlign.right,
                ),
              )),
          if (taxes.isEmpty)
            SizedBox(
              width: 80,
              child: Text(
                uom.totalTax.toCurrency(),
                style: TextStyle(fontSize: 14, color: theme.inactiveColor),
                textAlign: TextAlign.right,
              ),
            ),
          // PVP
          SizedBox(
            width: 80,
            child: Text(
              uom.pvp.toCurrency(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.accentColor,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // Barcode
          if (showBarcode)
            Expanded(
              child: Text(
                uom.barcode ?? '-',
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.right,
              ),
            ),
        ],
      ),
    );

    if (readOnly) {
      return content;
    }

    return GestureDetector(
      onTap: () => onSelect?.call(uom),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: content,
      ),
    );
  }
}
