import 'package:fluent_ui/fluent_ui.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show SaleCatalogProduct;

import '../clients/catalog_contracts.dart';
import '../../ui/components/fields/orbi_inline_catalog_picker.dart';
import 'sale_editor.dart';

String _priceLabel(SaleDraftLine line) =>
    line.amountsCalculated ? 'Precio' : 'Precio catálogo';

String _discountLabel(SaleDraftLine line) =>
    line.amountsCalculated ? '${line.discount}%' : 'Por validar';

String _taxLabel(SaleDraftLine line) =>
    line.amountsCalculated ? '${line.tax}%' : 'Por validar';

String _totalLabel(SaleDraftLine line) => line.amountsCalculated
    ? line.total.toStringAsFixed(2)
    : 'Pendiente de cálculo';

/// Shared line presentation for sale forms. The runtime/controller remains the
/// owner of the draft; this widget only forwards typed edits and catalog picks.
///
/// 🔴 No usa `OrbiListing`: esto no es un catálogo para navegar, es una tabla
/// editable con cantidades, descuentos, impuestos y un total por línea — el
/// dinero de la venta. `OrbiListing` no soporta edición de celdas, así que
/// cambiarla habría significado perder la edición de cantidades, no ganarla.
class SaleLinesEditor extends StatefulWidget {
  const SaleLinesEditor({
    super.key,
    required this.draft,
    this.products,
    required this.onAddProduct,
    required this.onRemoveLine,
    required this.onQuantityChanged,
  });

  final SaleDraftSnapshot draft;
  final CatalogController<SaleCatalogProduct>? products;
  final ValueChanged<CatalogEntity<SaleCatalogProduct>> onAddProduct;
  final ValueChanged<String> onRemoveLine;
  final void Function(String uuid, double quantity) onQuantityChanged;

  @override
  State<SaleLinesEditor> createState() => _SaleLinesEditorState();
}

class _SaleLinesEditorState extends State<SaleLinesEditor> {
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, FocusNode> _quantityFocusNodes = {};
  final Set<String> _dirtyQuantities = {};
  final Map<String, String?> _quantityErrors = {};

  @override
  void dispose() {
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (final node in _quantityFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(SaleDraftLine line) {
    final controller = _quantityControllers.putIfAbsent(
      line.uuid,
      () => TextEditingController(text: _format(line.quantity)),
    );
    final focus = _quantityFocusNodes.putIfAbsent(line.uuid, FocusNode.new);
    if (!_dirtyQuantities.contains(line.uuid) &&
        !focus.hasFocus &&
        controller.text != _format(line.quantity)) {
      controller.text = _format(line.quantity);
    }
    return controller;
  }

  FocusNode _focusFor(SaleDraftLine line) =>
      _quantityFocusNodes.putIfAbsent(line.uuid, FocusNode.new);

  void _reconcileControllers() {
    final ids = widget.draft.lines.map((line) => line.uuid).toSet();
    for (final id in _quantityControllers.keys.toList()) {
      if (ids.contains(id)) continue;
      _quantityControllers.remove(id)?.dispose();
      _quantityFocusNodes.remove(id)?.dispose();
      _dirtyQuantities.remove(id);
      _quantityErrors.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final window = MediaQuery.sizeOf(context);
      _reconcileControllers();
      final wide = window.width >= 840 && window.width >= window.height;
      return wide ? _grid(context) : _cards(context);
    },
  );

  Widget _grid(BuildContext context) {
    final theme = FluentTheme.of(context);
    final source = _SaleLinesDataSource(
      lines: widget.draft.lines,
      quantityController: _controllerFor,
      quantityFocusNode: _focusFor,
      quantityError: (uuid) => _quantityErrors[uuid],
      onQuantityTextChanged: _editQuantity,
      onRemoveLine: widget.onRemoveLine,
      products: widget.products,
      onAddProduct: widget.onAddProduct,
      // El color por significado sí está fijado por contrato (rojo =
      // error); el resto del estilo lo hereda del tema, nunca a mano. Se
      // captura aquí porque `DataGridSource.buildRow` no recibe contexto.
      errorTextStyle: theme.typography.caption?.copyWith(
        color: theme.resources.systemFillColorCritical,
      ),
    );
    return Column(
      children: [
        Expanded(
          child: SfDataGrid(
            source: source,
            rowHeight: 56,
            onQueryRowHeight: (details) =>
                details.rowIndex == widget.draft.lines.length + 1
                ? 172
                : details.rowHeight,
            columns: [
              GridColumn(width: 60, columnName: 'code', label: Text('ID')),
              GridColumn(
                width: 420,
                columnName: 'product',
                label: Text('Producto'),
              ),
              GridColumn(
                width: 110,
                columnName: 'quantity',
                label: Text('Cantidad'),
              ),
              GridColumn(width: 90, columnName: 'unit', label: Text('Unidad')),
              GridColumn(
                width: 110,
                columnName: 'price',
                label: Text('Precio'),
              ),
              GridColumn(
                width: 100,
                columnName: 'discount',
                label: Text('Descuento'),
              ),
              GridColumn(width: 80, columnName: 'tax', label: Text('IVA')),
              GridColumn(width: 110, columnName: 'total', label: Text('Total')),
              GridColumn(width: 70, columnName: 'actions', label: Text('')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cards(BuildContext context) => Column(
    children: [
      for (final line in widget.draft.lines) _lineCard(context, line),
      if (widget.products != null) _productSearch(context),
      if (widget.draft.lines.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Sin productos'),
        ),
    ],
  );

  Widget _lineCard(BuildContext context, SaleDraftLine line) {
    final quantity = _controllerFor(line);
    final typography = FluentTheme.of(context).typography;
    return Card(
      key: ValueKey('sale-line-${line.uuid}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(line.name, style: typography.bodyStrong),
            Text(
              '${line.uomName ?? 'Unidad'} · ${_priceLabel(line)} '
              '${line.unitPrice} · Descuento ${_discountLabel(line)} · '
              'Impuesto ${_taxLabel(line)} · Total ${_totalLabel(line)}',
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                const Text('Cantidad'),
                SizedBox(width: 96, child: _quantityField(context, line, quantity)),
                Tooltip(
                  message: 'Quitar',
                  child: IconButton(
                    onPressed: () => widget.onRemoveLine(line.uuid),
                    icon: const Icon(FluentIcons.delete),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quantityField(
    BuildContext context,
    SaleDraftLine line,
    TextEditingController controller,
  ) {
    final error = _quantityErrors[line.uuid];
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextBox(
          key: ValueKey('sale-quantity-${line.uuid}'),
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          focusNode: _focusFor(line),
          placeholder: 'Cantidad · ${line.name}',
          onChanged: (value) => _editQuantity(line.uuid, value),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              error,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.systemFillColorCritical,
              ),
            ),
          ),
      ],
    );
  }

  Widget _productSearch(BuildContext context) {
    final products = widget.products;
    if (products == null) return const SizedBox.shrink();
    return OrbiInlineCatalogPicker<SaleCatalogProduct>(
      key: const Key('sale-inline-product-search'),
      controller: products,
      label: 'Buscar producto para nueva línea',
      onSelected: widget.onAddProduct,
    );
  }

  void _editQuantity(String uuid, String value) {
    final quantity = double.tryParse(value.replaceAll(',', '.'));
    final valid = quantity != null && quantity.isFinite && quantity > 0;
    setState(() {
      _dirtyQuantities.add(uuid);
      _quantityErrors[uuid] = valid ? null : 'Cantidad inválida';
    });
    if (valid) widget.onQuantityChanged(uuid, quantity);
  }
}

final class _SaleLinesDataSource extends DataGridSource {
  _SaleLinesDataSource({
    required this._lines,
    required this.quantityController,
    required this.quantityFocusNode,
    required this.quantityError,
    required this.onQuantityTextChanged,
    required this.onRemoveLine,
    required this.products,
    required this.onAddProduct,
    required this.errorTextStyle,
  });

  final List<SaleDraftLine> _lines;
  final TextEditingController Function(SaleDraftLine) quantityController;
  final FocusNode Function(SaleDraftLine) quantityFocusNode;
  final String? Function(String uuid) quantityError;
  final void Function(String uuid, String value) onQuantityTextChanged;
  final ValueChanged<String> onRemoveLine;
  final CatalogController<SaleCatalogProduct>? products;
  final ValueChanged<CatalogEntity<SaleCatalogProduct>> onAddProduct;
  final TextStyle? errorTextStyle;

  @override
  List<DataGridRow> get rows => [
    for (final line in _lines)
      DataGridRow(
        cells: [
          DataGridCell<String>(
            columnName: 'code',
            value: line.remoteId?.toString() ?? line.uuid,
          ),
          DataGridCell<String>(columnName: 'product', value: line.name),
          DataGridCell<String>(columnName: 'quantity', value: line.uuid),
          DataGridCell<String>(
            columnName: 'unit',
            value: line.uomName ?? 'Unidad',
          ),
          DataGridCell<String>(
            columnName: 'price',
            value: line.unitPrice.toStringAsFixed(2),
          ),
          DataGridCell<String>(
            columnName: 'discount',
            value: _discountLabel(line),
          ),
          DataGridCell<String>(columnName: 'tax', value: _taxLabel(line)),
          DataGridCell<String>(columnName: 'total', value: _totalLabel(line)),
          DataGridCell<String>(columnName: 'actions', value: line.uuid),
        ],
      ),
    DataGridRow(
      cells: [
        for (final column in const [
          'code',
          'product',
          'quantity',
          'unit',
          'price',
          'discount',
          'tax',
          'total',
          'actions',
        ])
          DataGridCell<String>(columnName: column, value: '__add__'),
      ],
    ),
  ];

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final uuid =
        row.getCells().firstWhere((cell) => cell.columnName == 'quantity').value
            as String;
    if (uuid == '__add__') {
      return DataGridRowAdapter(
        cells: [
          for (final cell in row.getCells())
            cell.columnName == 'product'
                ? products == null
                      ? const SizedBox.shrink()
                      : OrbiInlineCatalogPicker<SaleCatalogProduct>(
                          key: const Key('sale-inline-product-search'),
                          controller: products!,
                          label: 'Buscar producto para nueva línea',
                          onSelected: onAddProduct,
                        )
                : const SizedBox.shrink(),
        ],
      );
    }
    final line = _lines.firstWhere((item) => item.uuid == uuid);
    return DataGridRowAdapter(
      cells: [
        for (final cell in row.getCells())
          if (cell.columnName == 'quantity')
            SizedBox(width: 110, child: _quantity(line))
          else if (cell.columnName == 'actions')
            Tooltip(
              message: 'Quitar',
              child: IconButton(
                onPressed: () => onRemoveLine(line.uuid),
                icon: const Icon(FluentIcons.delete),
              ),
            )
          else
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(cell.value?.toString() ?? ''),
            ),
      ],
    );
  }

  Widget _quantity(SaleDraftLine line) {
    final error = quantityError(line.uuid);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextBox(
          key: ValueKey('sale-quantity-${line.uuid}'),
          controller: quantityController(line),
          focusNode: quantityFocusNode(line),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          placeholder: 'Cantidad · ${line.name}',
          onChanged: (value) => onQuantityTextChanged(line.uuid, value),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(error, style: errorTextStyle),
          ),
      ],
    );
  }
}

String _format(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
