import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:theos_pos_core/theos_pos_core.dart' hide logger, TaxDetail;

import '../../../core/constants/app_constants.dart';
import '../../../core/database/repositories/repository_providers.dart';
import '../../../core/services/logger_service.dart';
import '../../../shared/utils/formatting_utils.dart';
import 'product_uom_pricing_table.dart';

/// Dialog showing product info and sales history
class ProductInfoDialog extends ConsumerStatefulWidget {
  final int productId;
  final int? partnerId;
  final String? partnerName;
  final int? pricelistId;

  const ProductInfoDialog({
    super.key,
    required this.productId,
    this.partnerId,
    this.partnerName,
    this.pricelistId,
  });

  @override
  ConsumerState<ProductInfoDialog> createState() => _ProductInfoDialogState();
}

class _ProductInfoDialogState extends ConsumerState<ProductInfoDialog> {
  bool _isLoading = true;
  Map<String, dynamic>? _productInfo;
  List<Map<String, dynamic>> _taxInfo = [];
  List<TaxDetail> _taxDetails = [];
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _stockByWarehouse = [];
  List<UomPriceData> _uomPriceData = [];
  Map<int, List<String>> _barcodesByUom = {}; // uomId -> list of barcodes
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProductInfo();
  }

  Future<void> _loadProductInfo() async {
    logger.i(
      '[ProductInfoDialog]',
      'Loading product info: productId=${widget.productId}, partnerId=${widget.partnerId}, pricelistId=${widget.pricelistId}',
    );

    try {
      final productRepo = ref.read(productRepositoryProvider);

      // Try to get product info - first from Odoo if available, then local
      Map<String, dynamic>? productInfo;

      if (productRepo != null) {
        logger.d('[ProductInfoDialog]', 'Trying to fetch product from Odoo...');
        productInfo = await productRepo.getDetailedInfo(
          widget.productId,
        );
        if (productInfo != null) {
          logger.i('[ProductInfoDialog]', 'Product info fetched from ODOO');
        }
      }

      // If no product info from productRepo, try local database directly
      if (productInfo == null) {
        logger.d('[ProductInfoDialog]', 'Falling back to LOCAL database...');
        productInfo = await _getProductFromLocalDb(widget.productId);
        if (productInfo != null) {
          logger.i('[ProductInfoDialog]', 'Product info fetched from LOCAL DB: ${productInfo['name']}');
        }
      }

      if (productInfo == null) {
        setState(() {
          _isLoading = false;
          _error = 'Producto no encontrado';
        });
        return;
      }

      // Fetch stock by warehouse (only if online)
      List<Map<String, dynamic>> stockByWarehouse = [];
      if (productRepo != null) {
        try {
          stockByWarehouse = await productRepo.getStockByWarehouse(
            widget.productId,
          );
        } catch (e) {
          logger.w(
            '[ProductInfoDialog]',
            'Could not load stock by warehouse: $e',
          );
        }
      }

      // Fetch history if we have a partner (only if online)
      List<Map<String, dynamic>> history = [];
      if (widget.partnerId != null && productRepo != null) {
        try {
          history = await productRepo.getHistoryForCustomer(
            productId: widget.productId,
            partnerId: widget.partnerId!,
          );
        } catch (e) {
          logger.w('[ProductInfoDialog]', 'Could not load history: $e');
        }
      }

      // Get tax info using shared loader
      List<Map<String, dynamic>> taxInfo = [];
      List<TaxDetail> taxDetails = [];
      final priceLoader = ProductUomPriceLoader(ref);

      taxDetails = await priceLoader.loadTaxInfo(widget.productId);
      // Also build legacy taxInfo for other parts of the dialog
      for (final tax in taxDetails) {
        taxInfo.add({
          'id': tax.id,
          'name': tax.name,
          'amount': tax.percent,
          'amount_type': tax.amountType,
        });
      }
      logger.d('[ProductInfoDialog]', 'Loaded ${taxDetails.length} taxes');

      // Extract product data needed for price calculation
      // product_tmpl_id can be int (local DB) or [id, name] (Odoo Many2one)
      int? productTmplId;
      final rawTmplId = productInfo['product_tmpl_id'];
      if (rawTmplId is int) {
        productTmplId = rawTmplId;
      } else if (rawTmplId is List && rawTmplId.isNotEmpty) {
        productTmplId = rawTmplId[0] as int?;
      }
      final basePrice = (productInfo['list_price'] as num?)?.toDouble() ?? 0.0;

      logger.d(
        '[ProductInfoDialog]',
        'Price calculation params: productId=${widget.productId}, '
        'productTmplId=$productTmplId, pricelistId=${widget.pricelistId}, '
        'basePrice=$basePrice',
      );

      // Load UoMs with prices using shared loader
      List<UomPriceData> uomPriceData = [];
      Map<int, List<String>> barcodesByUom = {};

      if (productInfo['uom_ids'] is List) {
        // Safely convert to List<int> (handles both int and dynamic)
        final uomIds = (productInfo['uom_ids'] as List)
            .map((e) => e is int ? e : int.tryParse(e.toString()))
            .whereType<int>()
            .toList();
        logger.d('[ProductInfoDialog]', 'UoM IDs to load: $uomIds');
        if (uomIds.isNotEmpty) {
          uomPriceData = await priceLoader.loadUomsWithPrices(
            productId: widget.productId,
            productTmplId: productTmplId,
            pricelistId: widget.pricelistId,
            listPrice: basePrice,
            allowedUomIds: uomIds,
            taxes: taxDetails,
          );
          logger.i('[ProductInfoDialog]', 'Loaded ${uomPriceData.length} UoMs with prices');

          // Load ALL barcodes grouped by UoM (one UoM can have multiple barcodes)
          barcodesByUom = await _loadBarcodesByUom(widget.productId);
          logger.i('[ProductInfoDialog]', 'Loaded barcodes for ${barcodesByUom.length} UoMs');
        }
      }

      if (mounted) {
        logger.i(
          '[ProductInfoDialog]',
          'Product info loaded successfully: '
          'taxes=${taxInfo.length}, stock=${stockByWarehouse.length} warehouses, '
          'uoms=${uomPriceData.length}, barcodes=${barcodesByUom.values.expand((b) => b).length}, '
          'history=${history.length} orders',
        );
        setState(() {
          _isLoading = false;
          _productInfo = productInfo;
          _taxInfo = taxInfo;
          _taxDetails = taxDetails;
          _history = history;
          _stockByWarehouse = stockByWarehouse;
          _uomPriceData = uomPriceData;
          _barcodesByUom = barcodesByUom;
        });
      }
    } catch (e, stack) {
      logger.e('[ProductInfoDialog]', 'Error loading product info', e, stack);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error al cargar informacion: $e';
        });
      }
    }
  }

  /// Get product info from local database via manager
  Future<Map<String, dynamic>?> _getProductFromLocalDb(int productId) async {
    try {
      final product = await productManager.readLocal(productId);
      if (product == null) return null;

      return {
        'id': product.id,
        'product_tmpl_id': product.productTmplId,
        'name': product.name,
        'display_name': product.displayName,
        'default_code': product.defaultCode,
        'barcode': product.barcode,
        'list_price': product.listPrice,
        'standard_price': product.standardPrice,
        'qty_available': product.qtyAvailable,
        'free_qty': product.virtualAvailable,
        'type': product.type.name,
        'tracking': product.tracking.name,
        'is_storable': product.isStorable,
        'uom_id': product.uomId != null ? [product.uomId, product.uomName] : null,
        'categ_id': product.categId != null
            ? [product.categId, product.categName]
            : null,
        'taxes_id': product.taxIdsList,
        'description_sale': product.descriptionSale,
        'image_128': product.image128,
        'uom_ids': product.allowedUomIds,
      };
    } catch (e) {
      logger.e('[ProductInfoDialog]', 'Error getting product from local: $e');
      return null;
    }
  }

  /// Load ALL barcodes for a product, grouped by UoM ID
  /// One UoM can have multiple barcodes
  Future<Map<int, List<String>>> _loadBarcodesByUom(int productId) async {
    try {
      final productUoms = await productUomManager.searchLocal(
        domain: [['product_id', '=', productId]],
      );

      final result = <int, List<String>>{};
      for (final pu in productUoms) {
        if (pu.barcode.isNotEmpty) {
          result.putIfAbsent(pu.uomId, () => []).add(pu.barcode);
        }
      }
      return result;
    } catch (e) {
      logger.w('[ProductInfoDialog]', 'Error loading barcodes: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ContentDialog(
        title: const Text('Cargando...'),
        content: const Center(
          child: Padding(padding: EdgeInsets.all(20), child: ProgressRing()),
        ),
      );
    }

    if (_error != null || _productInfo == null) {
      return ContentDialog(
        title: const Text('Error'),
        content: Text(
          _error ?? 'No se pudo cargar la informacion del producto',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      );
    }

    return _ProductInfoContent(
      productInfo: _productInfo!,
      taxInfo: _taxInfo,
      taxDetails: _taxDetails,
      history: _history,
      stockByWarehouse: _stockByWarehouse,
      uomPriceData: _uomPriceData,
      barcodesByUom: _barcodesByUom,
      partnerName: widget.partnerName,
    );
  }
}

/// Product info content widget - Redesigned with tabs
class _ProductInfoContent extends StatefulWidget {
  final Map<String, dynamic> productInfo;
  final List<Map<String, dynamic>> taxInfo;
  final List<TaxDetail> taxDetails;
  final List<Map<String, dynamic>> history;
  final List<Map<String, dynamic>> stockByWarehouse;
  final List<UomPriceData> uomPriceData;
  final Map<int, List<String>> barcodesByUom;
  final String? partnerName;

  const _ProductInfoContent({
    required this.productInfo,
    required this.taxInfo,
    required this.taxDetails,
    required this.history,
    required this.stockByWarehouse,
    required this.uomPriceData,
    required this.barcodesByUom,
    this.partnerName,
  });

  @override
  State<_ProductInfoContent> createState() => _ProductInfoContentState();
}

class _ProductInfoContentState extends State<_ProductInfoContent> {
  int _currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Extract product data
    final productName =
        widget.productInfo['display_name'] ?? widget.productInfo['name'] ?? '';
    final defaultCode = widget.productInfo['default_code'];
    final barcode = widget.productInfo['barcode'];
    final listPrice =
        (widget.productInfo['list_price'] as num?)?.toDouble() ?? 0.0;
    final image128 = widget.productInfo['image_128'];
    final descriptionSale = widget.productInfo['description_sale'];
    final productType = widget.productInfo['type'] as String? ?? 'consu';
    final tracking = widget.productInfo['tracking'] as String? ?? 'none';
    final isStorable = widget.productInfo['is_storable'] == true;

    // Get UoM name
    String uomName = 'Unidad';
    final uomData = widget.productInfo['uom_id'];
    if (uomData is List && uomData.length >= 2) {
      uomName = uomData[1] as String;
    }

    // Get category name
    String categName = '';
    final categData = widget.productInfo['categ_id'];
    if (categData is List && categData.length >= 2) {
      categName = categData[1] as String;
    }

    // Build tabs list
    final tabs = <Tab>[];

    // Tab 1: Stock + Precios (unified)
    if (widget.uomPriceData.isNotEmpty || widget.stockByWarehouse.isNotEmpty) {
      tabs.add(Tab(
        text: const Text('Stock / Precios'),
        icon: const Icon(FluentIcons.product, size: 14),
        body: _buildStockAndPricingTab(theme),
      ));
    }

    // Tab 2: History
    tabs.add(Tab(
      text: const Text('Historial'),
      icon: const Icon(FluentIcons.history, size: 14),
      body: _buildHistoryTab(theme, dateFormat),
    ));

    return ContentDialog(
      title: _buildHeader(
        theme,
        productName,
        defaultCode,
        barcode,
        listPrice,
        uomName,
        categName,
        image128,
        descriptionSale,
        productType,
        tracking,
        isStorable,
      ),
      constraints: const BoxConstraints(
        maxWidth: DialogSizes.largeWidth,
        maxHeight: DialogSizes.largeHeight,
      ),
      content: TabView(
        currentIndex: _currentTabIndex,
        onChanged: (index) => setState(() => _currentTabIndex = index),
        tabs: tabs,
        tabWidthBehavior: TabWidthBehavior.sizeToContent,
        closeButtonVisibility: CloseButtonVisibilityMode.never,
        header: const SizedBox.shrink(),
        footer: const SizedBox.shrink(),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  /// Build header with product image and basic info
  Widget _buildHeader(
    FluentThemeData theme,
    String productName,
    dynamic defaultCode,
    dynamic barcode,
    double listPrice,
    String uomName,
    String categName,
    dynamic image128,
    dynamic descriptionSale,
    String productType,
    String tracking,
    bool isStorable,
  ) {
    // Clean product name - remove [code] prefix
    String cleanName = productName;
    final codeRegex = RegExp(r'^\[.*?\]\s*');
    cleanName = cleanName.replaceFirst(codeRegex, '');

    // Map product type to display name (Odoo 19: consu=Bienes, service=Servicio, combo=Combo)
    String productTypeLabel;
    IconData productTypeIcon;
    Color productTypeColor;
    switch (productType) {
      case 'service':
        productTypeLabel = 'Servicio';
        productTypeIcon = FluentIcons.service_activity;
        productTypeColor = Colors.purple;
        break;
      case 'combo':
        productTypeLabel = 'Combo';
        productTypeIcon = FluentIcons.stack;
        productTypeColor = Colors.magenta;
        break;
      default: // 'consu' = Bienes (goods)
        productTypeLabel = 'Bienes';
        productTypeIcon = FluentIcons.product;
        productTypeColor = Colors.teal;
    }

    // Map tracking to display
    String? trackingLabel;
    if (tracking == 'serial') {
      trackingLabel = 'Control por Serie';
    } else if (tracking == 'lot') {
      trackingLabel = 'Control por Lote';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product image - 200px
        _buildImage(theme, image128, size: 200),
        const SizedBox(width: 16),
        // Product info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Product name - clean, 4 lines max
              Text(
                cleanName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Code and category
              if (defaultCode != null && defaultCode != false)
                _buildInfoChip(theme, FluentIcons.tag, defaultCode.toString()),
              if (categName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(FluentIcons.folder, size: 14, color: theme.inactiveColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        categName,
                        style: TextStyle(fontSize: 13, color: theme.inactiveColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 2),
              _buildInfoChip(theme, FluentIcons.quantity, uomName),
              const SizedBox(height: 6),
              // Product type, storable and tracking badges
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  // Product type badge
                  _buildBadge(productTypeLabel, productTypeIcon, productTypeColor),
                  // Storable badge
                  if (isStorable)
                    _buildBadge('Almacenable', FluentIcons.archive, Colors.blue),
                  // Tracking badge (if applicable)
                  if (trackingLabel != null)
                    _buildBadge(trackingLabel, FluentIcons.number_field, Colors.orange),
                ],
              ),
              const SizedBox(height: 6),
              // Base price with tax info - bigger PVP
              _buildCompactPriceInfo(theme, listPrice, uomName),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(FluentThemeData theme, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.inactiveColor),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(fontSize: 14, color: theme.inactiveColor),
        ),
      ],
    );
  }

  Widget _buildCompactPriceInfo(
    FluentThemeData theme,
    double listPrice,
    String uomName,
  ) {
    // Calculate total tax percent
    double totalTaxPercent = 0.0;
    for (final tax in widget.taxInfo) {
      final amountType = tax['amount_type'] as String? ?? 'percent';
      if (amountType == 'percent') {
        totalTaxPercent += (tax['amount'] as num?)?.toDouble() ?? 0.0;
      }
    }
    final totalWithTax = listPrice * (1 + totalTaxPercent / 100);

    // Get tax names
    final taxNames = widget.taxInfo
        .map((t) => t['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .map((n) {
      final parenIdx = n.indexOf('(');
      return parenIdx > 0 ? n.substring(0, parenIdx).trim() : n;
    }).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.accentColor.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.accentColor.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Precio base',
                style: TextStyle(fontSize: 12, color: theme.inactiveColor),
              ),
              Text(
                listPrice.toCurrency(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (taxNames.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Icon(FluentIcons.add, size: 14, color: theme.inactiveColor),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  taxNames.join(', '),
                  style: TextStyle(fontSize: 12, color: theme.inactiveColor),
                ),
                Text(
                  '${totalTaxPercent.toFixed(0)}%',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Icon(
                FluentIcons.calculator_equal_to,
                size: 14,
                color: theme.inactiveColor,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PVP',
                  style: TextStyle(fontSize: 13, color: theme.inactiveColor),
                ),
                Text(
                  totalWithTax.toCurrency(),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: theme.accentColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Build unified stock + pricing tab content
  Widget _buildStockAndPricingTab(FluentThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stock section first
          if (widget.stockByWarehouse.isNotEmpty) ...[
            _buildSectionHeader(
              theme,
              'Existencias por Bodega',
              FluentIcons.product,
            ),
            const SizedBox(height: 8),
            _buildStockTable(theme),
            const SizedBox(height: 16),
          ],

          // Pricing table
          if (widget.uomPriceData.isNotEmpty) ...[
            _buildSectionHeader(
              theme,
              'Precios por Empaque',
              FluentIcons.package,
            ),
            const SizedBox(height: 8),
            ProductUomPricingTable(
              uoms: widget.uomPriceData,
              taxes: widget.taxDetails,
              readOnly: true,
              showDiscount: true,
            ),
          ],

          // Barcodes section - always show with UoMs
          if (widget.uomPriceData.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionHeader(
              theme,
              'Codigos de Barra por Empaque',
              FluentIcons.contact_card,
            ),
            const SizedBox(height: 8),
            _buildBarcodesSection(theme),
          ],
        ],
      ),
    );
  }

  /// Build history tab content
  Widget _buildHistoryTab(FluentThemeData theme, DateFormat dateFormat) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            theme,
            widget.partnerName != null
                ? 'Historial con ${widget.partnerName}'
                : 'Historial de Ventas',
            FluentIcons.history,
          ),
          const SizedBox(height: 8),
          _buildHistoryContent(theme, dateFormat),
        ],
      ),
    );
  }

  Widget _buildHistoryContent(FluentThemeData theme, DateFormat dateFormat) {
    if (widget.history.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.resources.dividerStrokeColorDefault),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FluentIcons.history,
                size: 48,
                color: theme.inactiveColor.withAlpha(100),
              ),
              const SizedBox(height: 12),
              Text(
                'No hay historial de ventas',
                style: TextStyle(fontSize: 14, color: theme.inactiveColor),
              ),
              if (widget.partnerName == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Seleccione un cliente para ver historial',
                    style: TextStyle(fontSize: 12, color: theme.inactiveColor),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.accentColor.withAlpha(20),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    'Orden',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    'Fecha',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Cant.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  child: Text(
                    'P.Unit',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Dto.%',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Subtotal',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Data rows
          ...widget.history.map((h) {
            DateTime? date;
            if (h['date'] != null) {
              try {
                date = DateTime.parse(h['date'].toString());
              } catch (_) {}
            }
            final discount = ((h['discount'] as num?) ?? 0).toDouble();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.resources.dividerStrokeColorDefault,
                  ),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      h['order_name']?.toString() ?? '',
                      style: TextStyle(fontSize: 14, color: theme.accentColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      date != null ? dateFormat.format(date) : '-',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      ((h['qty'] as num?) ?? 0).toFixed(2),
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      ((h['price_unit'] as num?) ?? 0).toCurrency(),
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      discount > 0 ? '${discount.toFixed(1)}%' : '-',
                      style: TextStyle(
                        fontSize: 14,
                        color: discount > 0 ? Colors.green : null,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      ((h['subtotal'] as num?) ?? 0).toCurrency(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildImage(
    FluentThemeData theme,
    dynamic image128, {
    required double size,
  }) {
    if (image128 != null && image128 != false) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.resources.dividerStrokeColorDefault),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(
            base64Decode(image128 as String),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(
              FluentIcons.product,
              size: size * 0.5,
              color: theme.inactiveColor,
            ),
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.accentColor.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        FluentIcons.product,
        size: size * 0.5,
        color: theme.accentColor,
      ),
    );
  }

  Widget _buildSectionHeader(
    FluentThemeData theme,
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.accentColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.accentColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStockTable(FluentThemeData theme) {
    // Flatten warehouse -> locations into rows
    final List<Map<String, dynamic>> rows = [];

    for (final warehouse in widget.stockByWarehouse) {
      final warehouseName = warehouse['name'] as String? ?? '';
      final isMain = warehouse['is_main'] as bool? ?? false;
      final virtualAvailable =
          (warehouse['virtual_available'] as num?)?.toDouble() ?? 0.0;
      final locations = warehouse['locations'] as List?;

      if (locations != null && locations.isNotEmpty) {
        for (int i = 0; i < locations.length; i++) {
          final loc = locations[i] as Map<String, dynamic>;
          rows.add({
            'warehouse': i == 0
                ? (isMain ? '$warehouseName *' : warehouseName)
                : '',
            'location': loc['location_name'] as String? ?? '',
            'on_hand': (loc['total_stock'] as num?)?.toDouble() ?? 0.0,
            'reserved': (loc['reserved_stock'] as num?)?.toDouble() ?? 0.0,
            'available': (loc['stock'] as num?)?.toDouble() ?? 0.0,
            'forecast': i == 0 ? virtualAvailable : 0.0,
          });
        }
      } else {
        rows.add({
          'warehouse': isMain ? '$warehouseName *' : warehouseName,
          'location': 'Total',
          'on_hand': (warehouse['total_stock'] as num?)?.toDouble() ?? 0.0,
          'reserved': (warehouse['reserved_stock'] as num?)?.toDouble() ?? 0.0,
          'available': (warehouse['stock'] as num?)?.toDouble() ?? 0.0,
          'forecast': virtualAvailable,
        });
      }
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.accentColor.withAlpha(20),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Bodega',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Ubicacion',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Expanded(
                  child: Text(
                    'A Mano',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Reserv.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Disp.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Pron.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Data rows
          ...rows.map((item) {
            final warehouse = item['warehouse'] as String;
            final location = item['location'] as String;
            final onHand = item['on_hand'] as double;
            final reserved = item['reserved'] as double;
            final available = item['available'] as double;
            final forecast = item['forecast'] as double;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.resources.dividerStrokeColorDefault,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      warehouse,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      location,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      onHand.toFixed(0),
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      reserved.toFixed(0),
                      style: TextStyle(
                        fontSize: 14,
                        color: reserved > 0 ? Colors.orange : null,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      available.toFixed(0),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: available > 0 ? Colors.green : Colors.red,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      forecast > 0 ? forecast.toFixed(0) : '',
                      style: TextStyle(
                        fontSize: 14,
                        color: forecast > 0 ? Colors.teal : null,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Build barcodes section showing all UoMs with their barcodes
  Widget _buildBarcodesSection(FluentThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.accentColor.withAlpha(20),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Presentacion',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Codigo de Barra',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          // Data rows - one row per UoM
          ...widget.uomPriceData.map((uom) {
            // Get barcodes for this UoM (may have multiple or none)
            final barcodes = widget.barcodesByUom[uom.id] ?? [];
            final barcode = barcodes.isNotEmpty ? barcodes.join(', ') : '-';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.resources.dividerStrokeColorDefault,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      uom.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      barcode,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        color: barcode == '-' ? theme.inactiveColor : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
