import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/providers.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../shared/utils/formatting_utils.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show Uom, productManager, uomManager;

// ============================================================================
// DIALOGO DE SELECCION DE UOM
// ============================================================================

/// Dialog for selecting a unit of measure (UoM)
/// If productId is provided, shows only UoMs allowed for that product
/// Shows: name, package code (factor), price, taxes, tax amount, and PVP
///
/// [allowedUomIds] - Odoo 19 compatible: only these UoM IDs will be shown
/// This matches Odoo's allowed_uom_ids computed field (product.uom_id | product.uom_ids)
class SelectUomDialog extends ConsumerStatefulWidget {
  final int? currentUomId;
  final String? currentUomName;
  final int? productId;
  final int? productTmplId;
  final int? pricelistId;
  final double? listPrice;

  /// Odoo 19: allowed_uom_ids - only show these UoMs
  final List<int>? allowedUomIds;

  const SelectUomDialog({
    super.key,
    this.currentUomId,
    this.currentUomName,
    this.productId,
    this.productTmplId,
    this.pricelistId,
    this.listPrice,
    this.allowedUomIds,
  });

  @override
  ConsumerState<SelectUomDialog> createState() => _SelectUomDialogState();
}

/// Represents a single tax with its details
class _TaxDetail {
  final String name;
  final String shortName;
  final double percent;
  final String amountType;

  const _TaxDetail({
    required this.name,
    required this.shortName,
    required this.percent,
    required this.amountType,
  });
}

class _SelectUomDialogState extends ConsumerState<SelectUomDialog> {
  List<Map<String, dynamic>> _uoms = [];
  bool _isLoading = true;
  String? _error;

  // Tax info for the product - list of individual taxes
  List<_TaxDetail> _taxes = [];
  double _totalTaxPercent = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      logger.d(
        '[SelectUomDialog]',
        'Loading UoMs from local DB (offline-first) for productId=${widget.productId}',
      );

      // Load tax info first
      await _loadTaxInfo();

      // Load UoMs
      final localUoms = await _loadUomsFromLocalDb();
      logger.d(
        '[SelectUomDialog]',
        'Loaded ${localUoms.length} UoMs from local DB',
      );

      if (mounted) {
        setState(() {
          _uoms = localUoms;
          _isLoading = false;
        });
      }
    } catch (e) {
      logger.e('[SelectUomDialog]', 'Error loading UoMs from local DB', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error al cargar unidades: $e';
        });
      }
    }
  }

  /// Load tax info for the product using TaxCalculatorService
  Future<void> _loadTaxInfo() async {
    if (widget.productId == null) return;

    try {
      final taxCalculator = ref.read(taxCalculatorProvider);
      final taxInfo = await taxCalculator.getProductTaxInfo(
        productId: widget.productId!,
      );

      _totalTaxPercent = taxInfo.taxPercent;

      // Build list of individual taxes
      _taxes = taxInfo.taxes.map((tax) {
        // Create short name (e.g., "IVA 15%" from "IVA 15% (411, B)")
        String shortName = tax.name;
        final parenIndex = tax.name.indexOf('(');
        if (parenIndex > 0) {
          shortName = tax.name.substring(0, parenIndex).trim();
        }

        return _TaxDetail(
          name: tax.name,
          shortName: shortName,
          percent: tax.amount,
          amountType: tax.amountType,
        );
      }).toList();

      logger.d(
        '[SelectUomDialog]',
        'Tax info loaded: ${_taxes.map((t) => '${t.shortName} (${t.percent}%)').join(', ')} - Total: $_totalTaxPercent%',
      );
    } catch (e) {
      logger.w('[SelectUomDialog]', 'Error loading tax info: $e');
    }
  }

  /// Convert a [Uom] model to the map format used by the dialog.
  Map<String, dynamic> _uomToMap(Uom uom) => {
        'id': uom.id,
        'name': uom.name,
        'factor': uom.factor,
        'uom_type': uom.uomType.name,
      };

  Future<List<Map<String, dynamic>>> _loadUomsFromLocalDb() async {
    List<Map<String, dynamic>> uomList = [];
    int? productBaseUomId;

    // Odoo 19: If allowedUomIds is provided, use it strictly (matches allowed_uom_ids)
    if (widget.allowedUomIds != null && widget.allowedUomIds!.isNotEmpty) {
      logger.d(
        '[SelectUomDialog]',
        'Using strict allowedUomIds filter (Odoo 19 compatible): ${widget.allowedUomIds}',
      );
      final uoms = await uomManager.searchLocal(
        domain: [['id', 'in', widget.allowedUomIds]],
        orderBy: 'factor asc',
      );
      uomList = uoms.map(_uomToMap).toList();

      // Get product base UoM for price calculation
      if (widget.productId != null) {
        final product = await productManager.readLocal(widget.productId!);
        productBaseUomId = product?.uomId;
      }
    } else if (widget.productId != null) {
      // Fallback: load from product's uom_ids field
      final product = await productManager.readLocal(widget.productId!);

      productBaseUomId = product?.uomId;

      if (product != null &&
          product.uomIds != null &&
          product.uomIds!.isNotEmpty) {
        final uomIdsList = product.uomIds!;

        if (uomIdsList.isNotEmpty) {
          logger.d(
            '[SelectUomDialog]',
            'Product has allowed UoMs: $uomIdsList',
          );
          final uoms = await uomManager.searchLocal(
            domain: [['id', 'in', uomIdsList]],
            orderBy: 'factor asc',
          );
          uomList = uoms.map(_uomToMap).toList();
        }
      }

      if (uomList.isEmpty && product != null && product.uomId != null) {
        logger.d(
          '[SelectUomDialog]',
          'Using product base UoM: ${product.uomId}',
        );
        final baseUom = await uomManager.readLocal(product.uomId!);

        if (baseUom != null && baseUom.categoryId != null) {
          final uoms = await uomManager.searchLocal(
            domain: [['category_id', '=', baseUom.categoryId]],
            orderBy: 'factor asc',
          );
          uomList = uoms.map(_uomToMap).toList();
        }
      }
    }

    if (uomList.isEmpty) {
      logger.d('[SelectUomDialog]', 'Loading all UoMs from local DB');
      final uoms = await uomManager.searchLocal(orderBy: 'factor asc');
      uomList = uoms.map(_uomToMap).toList();
    }

    if (widget.pricelistId != null && widget.listPrice != null) {
      uomList = await _calculatePricesForUoms(uomList, productBaseUomId);
    }

    return uomList;
  }

  Future<List<Map<String, dynamic>>> _calculatePricesForUoms(
    List<Map<String, dynamic>> uoms,
    int? productBaseUomId,
  ) async {
    final calculator = ref.read(pricelistCalculatorProvider);
    final listPrice = widget.listPrice ?? 0.0;
    final pricelistId = widget.pricelistId!;
    final productId = widget.productId;
    final productTmplId = widget.productTmplId;

    // Preload pricelist rules once before iterating UoMs
    await calculator.preloadPricelistRules([pricelistId]);

    double baseUomFactor = 1.0;
    if (productBaseUomId != null) {
      final baseUom = await uomManager.readLocal(productBaseUomId);
      if (baseUom != null) {
        baseUomFactor = baseUom.factor;
      }
    }

    final result = <Map<String, dynamic>>[];

    for (final uom in uoms) {
      final uomId = uom['id'] as int;
      final uomFactor = (uom['factor'] as double?) ?? 1.0;
      final conversionFactor = uomFactor / baseUomFactor;

      double price = listPrice * conversionFactor;
      String hasSpecificRule = '';

      if (productId != null && productTmplId != null) {
        final priceResult = await calculator.calculatePrice(
          productId: productId,
          productTmplId: productTmplId,
          pricelistId: pricelistId,
          quantity: 1.0,
          uomId: uomId,
          productUomId: productBaseUomId,
          listPrice: listPrice,
        );

        price = priceResult.price;

        // Determine if a specific rule was applied
        if (priceResult.ruleId != null) {
          switch (priceResult.computeType) {
            case 'fixed':
              hasSpecificRule = 'Precio Fijo';
            case 'percentage':
              hasSpecificRule = '% Descuento';
            case 'formula':
              hasSpecificRule = 'Formula';
            default:
              hasSpecificRule = '';
          }
        }
      }

      // Calculate individual tax amounts
      final taxAmounts = <String, double>{};
      double totalTaxAmount = 0.0;

      for (final tax in _taxes) {
        if (tax.amountType == 'percent') {
          final amount = price * (tax.percent / 100);
          taxAmounts[tax.shortName] = amount;
          totalTaxAmount += amount;
        }
      }

      final pvp = price + totalTaxAmount;

      result.add({
        ...uom,
        'price': price,
        'has_specific_rule': hasSpecificRule,
        'tax_amounts': taxAmounts, // Map of tax name -> amount
        'total_tax': totalTaxAmount,
        'pvp': pvp,
      });
    }

    return result;
  }

  String _formatFactorAsCode(double factor) {
    if (factor == 1.0) return 'Base';
    final intFactor = factor.round();
    if ((factor - intFactor).abs() < 0.001) return 'x$intFactor';
    return 'x${factor.toFixed(2)}';
  }

  /// Calculate dialog width based on number of taxes
  double _calculateDialogWidth(bool hasPrice) {
    if (!hasPrice) return 400;
    // Base: 400 + 70 per tax column + 70 for PVP
    final taxColumns = _taxes.length;
    return 400 + (taxColumns * 70) + 70;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final hasPrice = widget.pricelistId != null && widget.listPrice != null;

    return ContentDialog(
      title: const Text('Seleccionar Unidad de Medida'),
      constraints: BoxConstraints(
        maxWidth: _calculateDialogWidth(hasPrice),
        maxHeight: 500,
      ),
      content: _isLoading
          ? const Center(child: ProgressRing())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: TextStyle(color: theme.inactiveColor),
              ),
            )
          : _uoms.isEmpty
          ? Center(
              child: Text(
                'No hay unidades disponibles',
                style: TextStyle(color: theme.inactiveColor),
              ),
            )
          : Column(
              children: [
                if (hasPrice) _buildHeader(theme),
                if (hasPrice) const SizedBox(height: 8),
                Expanded(child: _buildUomList(theme, hasPrice)),
              ],
            ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Widget _buildHeader(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.accentColor.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const SizedBox(width: 24),
          const Expanded(
            flex: 3,
            child: Text(
              'Unidad',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(
            width: 60,
            child: Text(
              'Empaque',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(
            width: 70,
            child: Text(
              'Precio',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
          // Dynamic tax columns
          ..._taxes.map((tax) => SizedBox(
                width: 70,
                child: Text(
                  tax.shortName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              )),
          // If no taxes, show placeholder
          if (_taxes.isEmpty)
            const SizedBox(
              width: 70,
              child: Text(
                'Impuesto',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                textAlign: TextAlign.right,
              ),
            ),
          const SizedBox(
            width: 70,
            child: Text(
              'PVP',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUomList(FluentThemeData theme, bool hasPrice) {
    return ListView.builder(
      itemCount: _uoms.length,
      itemBuilder: (context, index) {
        final uom = _uoms[index];
        final id = uom['id'] as int;
        final name = uom['name'] as String? ?? 'Sin nombre';
        final factor = (uom['factor'] as double?) ?? 1.0;
        final price = uom['price'] as double?;
        // Get individual tax amounts map
        final taxAmountsRaw = uom['tax_amounts'];
        final taxAmounts = taxAmountsRaw is Map<String, dynamic>
            ? taxAmountsRaw.map((k, v) => MapEntry(k, (v as num).toDouble()))
            : <String, double>{};
        final totalTax = (uom['total_tax'] as num?)?.toDouble() ?? 0.0;
        final pvp = uom['pvp'] as double?;
        final hasSpecificRule = uom['has_specific_rule'] as String? ?? '';
        final isSelected = id == widget.currentUomId;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? theme.accentColor.withAlpha(30) : null,
            borderRadius: BorderRadius.circular(4),
            border: isSelected
                ? Border.all(color: theme.accentColor, width: 1)
                : null,
          ),
          child: ListTile(
            onPressed: () => Navigator.of(
              context,
            ).pop({'id': id, 'name': name, 'factor': factor, 'price': price}),
            leading: Icon(
              isSelected
                  ? FluentIcons.checkbox_composite
                  : FluentIcons.quantity,
              size: 16,
              color: isSelected ? theme.accentColor : theme.inactiveColor,
            ),
            title: hasPrice
                ? _buildUomRowWithPrice(
                    theme: theme,
                    name: name,
                    factor: factor,
                    price: price,
                    taxAmounts: taxAmounts,
                    totalTax: totalTax,
                    pvp: pvp,
                    hasSpecificRule: hasSpecificRule,
                    isSelected: isSelected,
                  )
                : Text(
                    name,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildUomRowWithPrice({
    required FluentThemeData theme,
    required String name,
    required double factor,
    required double? price,
    required Map<String, double> taxAmounts,
    required double totalTax,
    required double? pvp,
    required String hasSpecificRule,
    required bool isSelected,
  }) {
    return Row(
      children: [
        // Unidad (nombre)
        Expanded(
          flex: 3,
          child: Text(
            name,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Empaque (factor)
        SizedBox(
          width: 60,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: factor > 1
                  ? Colors.blue.withAlpha(30)
                  : theme.inactiveColor.withAlpha(20),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _formatFactorAsCode(factor),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: factor > 1 ? Colors.blue : theme.inactiveColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // Precio (sin impuesto)
        SizedBox(
          width: 70,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                price?.toCurrency() ?? '-',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: hasSpecificRule.isNotEmpty ? Colors.green : null,
                ),
              ),
              if (hasSpecificRule.isNotEmpty)
                Text(
                  hasSpecificRule,
                  style: TextStyle(fontSize: 10, color: Colors.green),
                ),
            ],
          ),
        ),
        // Dynamic tax amount columns - one per tax
        ..._taxes.map((tax) => SizedBox(
              width: 70,
              child: Text(
                (taxAmounts[tax.shortName] ?? 0.0).toCurrency(),
                style: TextStyle(
                  fontSize: 12,
                  color: theme.inactiveColor,
                ),
                textAlign: TextAlign.right,
              ),
            )),
        // If no taxes defined, show placeholder with total
        if (_taxes.isEmpty)
          SizedBox(
            width: 70,
            child: Text(
              totalTax.toCurrency(),
              style: TextStyle(
                fontSize: 12,
                color: theme.inactiveColor,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        // PVP (precio + impuesto)
        SizedBox(
          width: 70,
          child: Text(
            pvp?.toCurrency() ?? '-',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.accentColor,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
