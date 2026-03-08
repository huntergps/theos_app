import 'package:fluent_ui/fluent_ui.dart';
import '../product_description_cell.dart';
import '../editable_number_cell.dart';
import '../uom_cell.dart';
import '../../../../shared/utils/formatting_utils.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Card for displaying a sale order line (mobile view)
///
/// Supports editing if [isEditable] is true.
class SalesOrderLineCard extends StatelessWidget {
  final SaleOrderLine line;
  final int index;
  final List<SaleOrderLine> allLines;
  final bool isEditable;
  final bool showPrice;

  // Callbacks
  // onUpdateQty uses Function to support async recalculation with pricelist rules
  final Function(SaleOrderLine line, double qty)? onUpdateQty;
  final void Function(SaleOrderLine line, double price)? onUpdatePrice;
  final void Function(SaleOrderLine line, double discount)? onUpdateDiscount;
  final void Function(SaleOrderLine line)? onSelectUom;
  final void Function(SaleOrderLine line)? onSelectProduct;
  final void Function(SaleOrderLine line, String newDescription)?
  onUpdateDescription;
  final void Function(SaleOrderLine line)? onShowProductInfo;
  final void Function(SaleOrderLine line)? onDelete;
  final void Function(SaleOrderLine line)? onDuplicate;

  const SalesOrderLineCard({
    super.key,
    required this.line,
    required this.index,
    required this.allLines,
    this.isEditable = false,
    this.showPrice = true,
    this.onUpdateQty,
    this.onUpdatePrice,
    this.onUpdateDiscount,
    this.onSelectUom,
    this.onSelectProduct,
    this.onUpdateDescription,
    this.onShowProductInfo,
    this.onDelete,
    this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    // Section
    if (line.displayType == LineDisplayType.lineSection) {
      return _buildSectionCard(theme);
    }

    // Subsection
    if (line.displayType == LineDisplayType.lineSubsection) {
      return _buildSubsectionCard(theme);
    }

    // Note
    if (line.displayType == LineDisplayType.lineNote) {
      return _buildNoteCard(theme);
    }

    // Regular product line
    return _buildProductCard(context, theme);
  }

  Widget _buildSectionCard(FluentThemeData theme) {
    final sectionSubtotal = allLines.getSectionSubtotal(line);
    final sectionTotal = allLines.getSectionTotal(line);
    final accentColor = theme.accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: accentColor
            .defaultBrushFor(theme.brightness)
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.section, size: 14, color: accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              line.name,
              style: theme.typography.bodyStrong?.copyWith(color: accentColor),
            ),
          ),
          if (!isEditable) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Subtotal: ${sectionSubtotal.toCurrency()}',
                  style: theme.typography.caption,
                ),
                Text(
                  'Total: ${sectionTotal.toCurrency()}',
                  style: theme.typography.body?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ] else
            _buildCardActions(theme),
        ],
      ),
    );
  }

  Widget _buildSubsectionCard(FluentThemeData theme) {
    final sectionSubtotal = allLines.getSectionSubtotal(line);
    final sectionTotal = allLines.getSectionTotal(line);

    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardColor.withAlpha(200),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              line.name,
              style: theme.typography.body?.copyWith(
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          if (!isEditable && !line.collapsePrices) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  sectionSubtotal.toCurrency(),
                  style: theme.typography.caption,
                ),
                Text(
                  sectionTotal.toCurrency(),
                  style: theme.typography.body?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ] else if (isEditable)
            _buildCardActions(theme),
        ],
      ),
    );
  }

  Widget _buildNoteCard(FluentThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[150] : Colors.grey[30],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(FluentIcons.edit_note, size: 14, color: theme.inactiveColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              line.name,
              style: theme.typography.caption?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.inactiveColor,
              ),
            ),
          ),
          if (isEditable) _buildCardActions(theme),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, FluentThemeData theme) {
    final accentColor = theme.accentColor;
    final isDark = theme.brightness == Brightness.dark;
    final hasParent = allLines.getParentSection(line) != null;

    return Card(
      margin: EdgeInsets.only(bottom: 8, left: hasParent ? 16 : 0),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
            decoration: BoxDecoration(
              color: accentColor
                  .defaultBrushFor(theme.brightness)
                  .withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                // Index
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accentColor
                        .defaultBrushFor(theme.brightness)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Product code
                if (line.productCode != null &&
                    line.productCode!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[140] : Colors.grey[40],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      line.productCode!,
                      style: theme.typography.caption?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Product name
                Expanded(
                  child: GestureDetector(
                    onTap: isEditable
                        ? () => onSelectProduct?.call(line)
                        : null,
                    child: ProductDescriptionCell(
                      productName:
                          line.productName ?? line.name.split('\n').first,
                      fullDescription: line.name,
                      isEditable: isEditable,
                      onDescriptionChanged: (newDesc) =>
                          onUpdateDescription?.call(line, newDesc),
                      onShowProductInfo: () => onShowProductInfo?.call(line),
                    ),
                  ),
                ),
                // Actions
                if (isEditable) _buildCardActions(theme),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: [
                // Row 1: Quantity and UoM
                Row(
                  children: [
                    Expanded(
                      child: _buildCardField(
                        theme,
                        label: 'Cantidad',
                        child: _buildQuantityInput(theme),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCardField(
                        theme,
                        label: 'Unidad',
                        child: isEditable
                            ? GestureDetector(
                                onTap: () => onSelectUom?.call(line),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: theme
                                          .resources
                                          .dividerStrokeColorDefault,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: UomCell(
                                    name: line.productUomName ?? 'Unidades',
                                    isEditable: true,
                                    onTap: () => onSelectUom?.call(line),
                                    style: theme.typography.body,
                                    iconColor: theme.inactiveColor,
                                  ),
                                ),
                              )
                            : Text(line.productUomName ?? 'Unid.'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 2: Price and Discount (if price shown)
                if (showPrice) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildCardField(
                          theme,
                          label: 'Precio Unit.',
                          child: _buildPriceInput(theme),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCardField(
                          theme,
                          label: '% Descuento',
                          child: _buildDiscountInput(theme),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Row 3: Subtotal and Total
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[150] : Colors.grey[20],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subtotal',
                            style: theme.typography.caption?.copyWith(
                              color: theme.inactiveColor,
                            ),
                          ),
                          Text(
                            line.priceSubtotal.toCurrency(),
                            style: theme.typography.body,
                          ),
                        ],
                      ),
                      if (line.priceTax > 0)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'IVA',
                              style: theme.typography.caption?.copyWith(
                                color: theme.inactiveColor,
                              ),
                            ),
                            Text(
                              line.priceTax.toCurrency(),
                              style: theme.typography.body,
                            ),
                          ],
                        ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Total',
                            style: theme.typography.caption?.copyWith(
                              color: accentColor,
                            ),
                          ),
                          Text(
                            line.priceTotal.toCurrency(),
                            style: theme.typography.bodyStrong?.copyWith(
                              color: accentColor,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Delivered/Invoiced info (read only)
                if (line.qtyDelivered > 0 || line.qtyInvoiced > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (line.qtyDelivered > 0) ...[
                        _buildStatusBadge(
                          theme,
                          FluentIcons.delivery_truck,
                          'Entregado: ${line.qtyDelivered}',
                          theme.accentColor,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (line.qtyInvoiced > 0)
                        _buildStatusBadge(
                          theme,
                          FluentIcons.receipt_check,
                          'Facturado: ${line.qtyInvoiced}',
                          Colors.green,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
    FluentThemeData theme,
    IconData icon,
    String text,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: theme.typography.caption),
        ],
      ),
    );
  }

  Widget _buildCardField(
    FluentThemeData theme, {
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.typography.caption?.copyWith(
            color: theme.inactiveColor,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _buildQuantityInput(FluentThemeData theme) {
    // Si es producto unitario, solo permitir enteros (0 decimales)
    // Si no es producto unitario, permitir decimales (2 decimales)
    final decimalPlaces = line.isUnitProduct ? 0 : 2;
    final step = line.isUnitProduct ? 1.0 : 0.01;

    return EditableNumberCell(
      value: line.productUomQty,
      isEditable: isEditable,
      min: 0,
      decimals: decimalPlaces,
      step: step,
      width: double.infinity,
      height: 32,
      textAlign: TextAlign.left,
      onChanged: (value) {
        onUpdateQty?.call(line, value);
      },
    );
  }

  Widget _buildPriceInput(FluentThemeData theme) {
    return EditableNumberCell(
      value: line.priceUnit,
      isEditable: isEditable,
      min: 0,
      decimals: 2,
      step: 0.01,
      width: double.infinity,
      height: 32,
      textAlign: TextAlign.left,
      suffix: '\$', // Add suffix for read-only view context? Or pre-pend?
      // EditableNumberCell supports suffix which is usually appended.
      // For price, we usually prepend $.
      // Let's rely on EditableNumberCell standard formatting or standard Input.
      // Wait, EditableNumberCell suffix is appended.
      // For Price, we want '$' prefix maybe?
      // NumberInputBase doesn't support prefix logic easily for text mode.
      // Let's use simple formatting for now.
      onChanged: (value) {
        onUpdatePrice?.call(line, value);
      },
    );
  }

  Widget _buildDiscountInput(FluentThemeData theme) {
    return EditableNumberCell(
      value: line.discount,
      isEditable: isEditable,
      min: 0,
      max: 100,
      decimals: 1,
      step: 0.1,
      width: double.infinity,
      height: 32,
      textAlign: TextAlign.left,
      suffix: '%',
      style: !isEditable && line.discount > 0
          ? TextStyle(color: Colors.green)
          : null,
      onChanged: (value) {
        onUpdateDiscount?.call(line, value);
      },
    );
  }

  Widget _buildCardActions(FluentThemeData theme) {
    return DropDownButton(
      leading: Icon(FluentIcons.more_vertical, size: 14),
      items: [
        if (line.productId != null && onShowProductInfo != null)
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.info, size: 14),
            text: const Text('Ver info del producto'),
            onPressed: () => onShowProductInfo?.call(line),
          ),
        if (onDuplicate != null)
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.copy, size: 14),
            text: const Text('Duplicar'),
            onPressed: () => onDuplicate?.call(line),
          ),
        if (onDelete != null)
          MenuFlyoutItem(
            leading: Icon(FluentIcons.delete, size: 14, color: Colors.red),
            text: Text('Eliminar', style: TextStyle(color: Colors.red)),
            onPressed: () => onDelete?.call(line),
          ),
      ],
    );
  }
}
