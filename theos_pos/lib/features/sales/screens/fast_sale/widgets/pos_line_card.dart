part of 'pos_order_lines_panel.dart';

/// Card-based line widget for POS (similar to normal order form)
///
/// Shows complete line information:
/// - Product code and custom description (or product name)
/// - Quantity with +/- buttons, UoM selector, unit price
/// - Discount (percentage and amount)
/// - Tax badge with tax amount
/// - Subtotal, Tax, Total
///
/// Features:
/// - Clickable UoM to change unit of measure
/// - Large +/- buttons for quick quantity adjustment
/// - Custom description field (shows instead of product name)
/// - Expanded view shows real product name and details
/// - Delete action requires confirmation dialog
class _POSLineCard extends ConsumerStatefulWidget {
  final SaleOrderLine line;
  final bool isSelected;
  final int lineIndex;
  final VoidCallback onTap;
  final Future<bool> Function()? onDelete;
  final Future<void> Function()? onIncrement;
  final Future<void> Function()? onDecrement;
  final Future<void> Function(int uomId, String uomName, double? price)?
  onUpdateUom;
  final void Function(String description)? onUpdateDescription;
  final VoidCallback? onShowProductInfo;

  /// Whether this line can be edited (order in draft/sent state)
  final bool canEdit;

  /// Pricelist ID for price calculation in UoM dialog
  final int? pricelistId;

  const _POSLineCard({
    required this.line,
    required this.isSelected,
    required this.lineIndex,
    required this.onTap,
    this.onDelete,
    this.onIncrement,
    this.onDecrement,
    this.onUpdateUom,
    this.onUpdateDescription,
    this.onShowProductInfo,
    this.canEdit = true,
    this.pricelistId,
  });

  @override
  ConsumerState<_POSLineCard> createState() => _POSLineCardState();
}

class _POSLineCardState extends ConsumerState<_POSLineCard> {
  bool _isExpanded = false;
  bool _isEditingDescription = false;
  late TextEditingController _descriptionController;
  String? _productBarcode;

  @override
  void initState() {
    super.initState();
    // Only pre-fill if there's a custom description (different from product name)
    final hasCustom =
        widget.line.name != (widget.line.productName ?? '') &&
        (widget.line.productName ?? '').isNotEmpty;
    _descriptionController = TextEditingController(
      text: hasCustom ? widget.line.name : '',
    );
    _loadProductBarcode();
  }

  /// Load barcode from product_uom table (packaging barcodes) or product table
  Future<void> _loadProductBarcode() async {
    if (widget.line.productId == null) return;

    // First, try to get barcode from product_uom table (packaging barcode)
    if (widget.line.productUomId != null) {
      final productUoms = await productUomManager.getForProduct(
        widget.line.productId!,
      );

      // Find barcode for the specific UoM
      for (final pu in productUoms) {
        if (pu.uomId == widget.line.productUomId && pu.barcode.isNotEmpty) {
          if (mounted) {
            setState(() {
              _productBarcode = pu.barcode;
            });
          }
          return;
        }
      }
    }

    // Fallback: try product's main barcode
    final product = await productManager.readLocal(widget.line.productId!);

    if (product?.barcode != null && product!.barcode!.isNotEmpty && mounted) {
      setState(() {
        _productBarcode = product.barcode;
      });
    }
  }

  @override
  void didUpdateWidget(covariant _POSLineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line.name != widget.line.name && !_isEditingDescription) {
      // Only show custom description if different from product name
      final hasCustom =
          widget.line.name != (widget.line.productName ?? '') &&
          (widget.line.productName ?? '').isNotEmpty;
      _descriptionController.text = hasCustom ? widget.line.name : '';
    }
    // Reload barcode if product or UoM changed
    if (oldWidget.line.productId != widget.line.productId ||
        oldWidget.line.productUomId != widget.line.productUomId) {
      _productBarcode = null;
      _loadProductBarcode();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  /// Check if the line has a custom description (different from product name)
  bool get _hasCustomDescription {
    final productName = widget.line.productName ?? '';
    return widget.line.name != productName && productName.isNotEmpty;
  }

  /// Get display name (custom description or product name)
  String get _displayName {
    // If there's a custom description that's different from product name, show it
    if (_hasCustomDescription) {
      return widget.line.name;
    }
    // Otherwise show product name
    return widget.line.productName ?? widget.line.name;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final line = widget.line;

    // Get tax names from cache (lookup from taxIds if taxNames is empty)
    final taxNamesCache = ref.watch(taxNamesCacheProvider);
    String effectiveTaxNames = line.taxNames ?? '';
    if (effectiveTaxNames.isEmpty &&
        line.taxIds != null &&
        line.taxIds!.isNotEmpty) {
      taxNamesCache.whenData((cache) {
        effectiveTaxNames = getTaxNamesFromIds(line.taxIds, cache);
      });
    }

    // Handle non-product lines (sections, notes)
    if (!line.isProductLine) {
      return _buildInfoLine(theme);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: GestureDetector(
        onTap: () {
          setState(() => _isExpanded = !_isExpanded);
          widget.onTap();
        },
        onDoubleTap: widget.onShowProductInfo,
        child: Card(
          padding: EdgeInsets.zero,
          backgroundColor: widget.isSelected
              ? theme.accentColor.withValues(alpha: 0.08)
              : null,
          child: Column(
            children: [
              // Main card content
              Container(
                padding: const EdgeInsets.all(Spacing.sm),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: widget.isSelected
                          ? theme.accentColor
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Line index, codes, description/name, delete button and total
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Line index
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.resources.subtleFillColorSecondary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${widget.lineIndex + 1}',
                            style: theme.typography.caption?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: Spacing.xs),

                        // Codes column (code + barcode)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product code badge (always visible if exists)
                            if (line.productCode != null &&
                                line.productCode!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.accentColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  line.productCode!,
                                  style: theme.typography.body?.copyWith(
                                    color: theme.accentColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            // Barcode badge (if different from code)
                            if (_productBarcode != null &&
                                _productBarcode != line.productCode) ...[
                              const SizedBox(height: Spacing.xxs),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.inactiveColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      FluentIcons.bar_chart4,
                                      size: 12,
                                      color: theme.inactiveColor,
                                    ),
                                    const SizedBox(width: Spacing.xxs),
                                    Text(
                                      _productBarcode!,
                                      style: theme.typography.body?.copyWith(
                                        color: theme.inactiveColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(width: Spacing.xs),

                        // Expand icon
                        Icon(
                          _isExpanded
                              ? FluentIcons.chevron_down
                              : FluentIcons.chevron_right,
                          size: 12,
                          color: theme.inactiveColor,
                        ),
                        const SizedBox(width: Spacing.xxs),

                        // Display name (custom description or product name)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayName,
                                style: theme.typography.body?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // Show "personalized" indicator if custom description
                              if (_hasCustomDescription)
                                Text(
                                  'Descripción personalizada',
                                  style: theme.typography.caption?.copyWith(
                                    color: theme.accentColor,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(width: Spacing.xs),

                        // Total price
                        Text(
                          line.priceTotal.toCurrency(),
                          style: theme.typography.bodyStrong?.copyWith(
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(width: Spacing.sm),

                        // Info button - show product details
                        if (widget.onShowProductInfo != null)
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: Tooltip(
                              message: 'Ver detalle del producto',
                              child: IconButton(
                                icon: Icon(
                                  FluentIcons.info,
                                  size: 18,
                                  color: theme.accentColor,
                                ),
                                onPressed: widget.onShowProductInfo,
                              ),
                            ),
                          ),

                        // Delete button (at the end, bigger) - only if can edit
                        if (widget.canEdit)
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: Tooltip(
                              message: 'Eliminar línea',
                              child: IconButton(
                                icon: Icon(
                                  FluentIcons.delete,
                                  size: 20,
                                  color: AppColors.danger,
                                ),
                                onPressed: widget.onDelete != null
                                    ? () => _confirmDelete(context)
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Row 2: +/- buttons, Qty, UoM (clickable), Price, Discount, Tax
                    Row(
                      children: [
                        // Large - button (only if can edit)
                        if (widget.canEdit)
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: Button(
                              onPressed: widget.onDecrement,
                              child: const Icon(FluentIcons.remove, size: 16),
                            ),
                          ),
                        if (widget.canEdit) const SizedBox(width: Spacing.xs),

                        // Quantity display
                        Container(
                          constraints: const BoxConstraints(minWidth: 50),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.resources.subtleFillColorSecondary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatQuantity(line.productUomQty),
                            style: theme.typography.bodyStrong?.copyWith(
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(width: Spacing.xs),

                        // Large + button (only if can edit)
                        if (widget.canEdit)
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: FilledButton(
                              onPressed: widget.onIncrement,
                              child: const Icon(FluentIcons.add, size: 16),
                            ),
                          ),

                        const SizedBox(width: Spacing.sm),

                        // UoM badge (clickable only if can edit)
                        GestureDetector(
                          onTap: widget.canEdit
                              ? () => _showUomSelector(context)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: widget.canEdit
                                  ? theme.accentColor.withValues(alpha: 0.1)
                                  : theme.resources.subtleFillColorSecondary,
                              borderRadius: BorderRadius.circular(4),
                              border: widget.canEdit
                                  ? Border.all(
                                      color: theme.accentColor.withValues(
                                        alpha: 0.3,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  line.productUomName ?? 'Unid',
                                  style: theme.typography.caption?.copyWith(
                                    color: widget.canEdit
                                        ? theme.accentColor
                                        : theme.inactiveColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (widget.canEdit) ...[
                                  const SizedBox(width: Spacing.xxs),
                                  Icon(
                                    FluentIcons.chevron_down,
                                    size: 10,
                                    color: theme.accentColor,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: Spacing.xs),

                        // "x" separator and unit price
                        Text(
                          'x ${line.priceUnit.toCurrency()}',
                          style: theme.typography.body?.copyWith(
                            color: theme.inactiveColor,
                          ),
                        ),

                        // Discount badge (if any)
                        if (line.discount > 0) ...[
                          const SizedBox(width: Spacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '-${line.discount.toFixed(0)}%',
                              style: theme.typography.caption?.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],

                        const Spacer(),

                        // Tax badge with amount
                        if (line.priceTax > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TaxBadge(
                                  taxNames: effectiveTaxNames.isNotEmpty
                                      ? effectiveTaxNames
                                      : line.taxNames,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  line.priceTax.toCurrency(),
                                  style: theme.typography.caption?.copyWith(
                                    color: AppColors.info,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else
                          TaxBadge(
                            taxNames: effectiveTaxNames.isNotEmpty
                                ? effectiveTaxNames
                                : line.taxNames,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Expanded details section
              if (_isExpanded) _buildExpandedDetails(theme, effectiveTaxNames),
            ],
          ),
        ),
      ),
    );
  }

  /// Show UoM selector dialog with pricelist info for price display
  Future<void> _showUomSelector(BuildContext context) async {
    final line = widget.line;
    if (line.productId == null) return;

    // Get allowed UoMs from product (Odoo 19 compatible)
    List<int>? allowedUomIds;
    final product = await productManager.readLocal(line.productId!);

    if (product != null) {
      final uomIds = <int>{};
      if (product.uomId != null) {
        uomIds.add(product.uomId!);
      }
      if (product.uomIds != null && product.uomIds!.isNotEmpty) {
        uomIds.addAll(product.uomIds!);
      }
      if (uomIds.isNotEmpty) {
        allowedUomIds = uomIds.toList();
      }
    }

    if (!context.mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SelectUomDialog(
        currentUomId: line.productUomId,
        currentUomName: line.productUomName,
        productId: line.productId,
        productTmplId: product?.productTmplId,
        pricelistId: widget.pricelistId,
        listPrice: product?.listPrice,
        allowedUomIds: allowedUomIds,
      ),
    );

    if (result != null && context.mounted) {
      final uomId = result['id'] as int;
      final uomName = result['name'] as String;
      final price = result['price'] as double?;
      await widget.onUpdateUom?.call(uomId, uomName, price);
    }
  }

  Widget _buildInfoLine(FluentThemeData theme) {
    final line = widget.line;

    if (line.isSection) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Spacing.xs),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.xs,
          ),
          decoration: BoxDecoration(
            color: theme.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(FluentIcons.section, size: 14, color: theme.accentColor),
              const SizedBox(width: Spacing.xs),
              Text(
                line.name,
                style: theme.typography.bodyStrong?.copyWith(
                  color: theme.accentColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (line.isNote) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Spacing.xs),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.xs,
          ),
          decoration: BoxDecoration(
            color: theme.resources.subtleFillColorSecondary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(FluentIcons.edit_note, size: 14, color: theme.inactiveColor),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: Text(
                  line.name,
                  style: theme.typography.caption?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.inactiveColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildExpandedDetails(
    FluentThemeData theme,
    String effectiveTaxNames,
  ) {
    final line = widget.line;

    return Container(
      padding: const EdgeInsets.fromLTRB(Spacing.sm, 0, Spacing.sm, Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: Spacing.sm),
            color: theme.resources.dividerStrokeColorDefault,
          ),

          // Real product name (shown when there's a custom description)
          if (_hasCustomDescription) ...[
            Container(
              padding: const EdgeInsets.all(Spacing.xs),
              margin: const EdgeInsets.only(bottom: Spacing.sm),
              decoration: BoxDecoration(
                color: theme.resources.subtleFillColorSecondary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    FluentIcons.product,
                    size: 14,
                    color: theme.inactiveColor,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Producto original:',
                          style: theme.typography.caption?.copyWith(
                            color: theme.inactiveColor,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          line.productName ?? '',
                          style: theme.typography.body?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Custom description field (only if can edit)
          if (widget.canEdit)
            Container(
              margin: const EdgeInsets.only(bottom: Spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        FluentIcons.edit,
                        size: 12,
                        color: theme.inactiveColor,
                      ),
                      const SizedBox(width: Spacing.xxs),
                      Text(
                        'Descripción personalizada:',
                        style: theme.typography.caption?.copyWith(
                          color: theme.inactiveColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xxs),
                  TextBox(
                    controller: _descriptionController,
                    placeholder: line.productName ?? 'Descripción del producto',
                    maxLines: 2,
                    onTap: () {
                      setState(() => _isEditingDescription = true);
                    },
                    onChanged: (value) {
                      // Real-time update as user types
                    },
                    onSubmitted: (value) {
                      setState(() => _isEditingDescription = false);
                      if (value.trim().isNotEmpty) {
                        widget.onUpdateDescription?.call(value.trim());
                      } else {
                        // If empty, reset to product name
                        widget.onUpdateDescription?.call(
                          line.productName ?? '',
                        );
                        _descriptionController.text = line.productName ?? '';
                      }
                    },
                    suffix: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Save button
                        Tooltip(
                          message: 'Guardar descripción',
                          child: IconButton(
                            icon: Icon(
                              FluentIcons.check_mark,
                              size: 14,
                              color: AppColors.success,
                            ),
                            onPressed: () {
                              final value = _descriptionController.text.trim();
                              setState(() => _isEditingDescription = false);
                              if (value.isNotEmpty) {
                                widget.onUpdateDescription?.call(value);
                              } else {
                                widget.onUpdateDescription?.call(
                                  line.productName ?? '',
                                );
                                _descriptionController.text =
                                    line.productName ?? '';
                              }
                            },
                          ),
                        ),
                        // Reset button (show only if different from product name)
                        if (_hasCustomDescription)
                          Tooltip(
                            message: 'Restablecer al nombre del producto',
                            child: IconButton(
                              icon: Icon(
                                FluentIcons.undo,
                                size: 14,
                                color: theme.inactiveColor,
                              ),
                              onPressed: () {
                                final productName = line.productName ?? '';
                                _descriptionController.text = productName;
                                widget.onUpdateDescription?.call(productName);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Discount info (if any)
          if (line.discount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.xs,
                  vertical: Spacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Descuento ${line.discount.toFixed(1)}% = -${line.discountAmount.toCurrency()}',
                  style: theme.typography.caption?.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ),
            ),

          // Price breakdown row
          Row(
            children: [
              // Subtotal
              _buildDetailColumn(
                theme,
                'Subtotal',
                line.priceSubtotal.toCurrency(),
              ),
              const SizedBox(width: 16),

              // Tax
              _buildDetailColumn(
                theme,
                effectiveTaxNames.isNotEmpty
                    ? effectiveTaxNames
                    : (line.taxNames ?? 'IVA'),
                line.priceTax.toCurrency(),
              ),
              const SizedBox(width: 16),

              // Total
              _buildDetailColumn(
                theme,
                'Total',
                line.priceTotal.toCurrency(),
                isBold: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Shows confirmation dialog before deleting the line
  Future<void> _confirmDelete(BuildContext context) async {
    final line = widget.line;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Eliminar linea'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Desea eliminar esta linea?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: FluentTheme.of(context)
                    .resources
                    .subtleFillColorSecondary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (line.productCode != null &&
                            line.productCode!.isNotEmpty)
                          Text(
                            '[${line.productCode}]',
                            style: FluentTheme.of(context).typography.caption
                                ?.copyWith(
                                  color: FluentTheme.of(context).accentColor,
                                ),
                          ),
                        Text(
                          line.productName ?? line.name,
                          style: FluentTheme.of(context).typography.body,
                        ),
                        const SizedBox(height: Spacing.xxs),
                        Text(
                          '${_formatQuantity(line.productUomQty)} ${line.productUomName ?? 'Unid'} x ${line.priceUnit.toCurrency()}',
                          style: FluentTheme.of(context).typography.caption
                              ?.copyWith(
                                color: FluentTheme.of(context).inactiveColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    line.priceTotal.toCurrency(),
                    style: FluentTheme.of(context).typography.bodyStrong,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AppColors.danger),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.onDelete != null) {
      await widget.onDelete!();
    }
  }

  Widget _buildDetailColumn(
    FluentThemeData theme,
    String label,
    String value, {
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.typography.caption?.copyWith(color: theme.inactiveColor),
        ),
        Text(
          value,
          style: theme.typography.body?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  String _formatQuantity(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toFixed(2);
  }
}
