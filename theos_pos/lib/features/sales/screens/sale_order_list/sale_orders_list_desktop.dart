import 'package:fluent_ui/fluent_ui.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../../../../shared/widgets/common_grid_widgets.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

class SaleOrdersDesktop extends StatelessWidget {
  final GlobalKey<SfDataGridState> gridKey;
  final TheosDataGridSource<SaleOrder> dataSource;
  final int rowsPerPage;
  final VoidCallback onExport;
  final Function(SaleOrder) onOrderTap;

  const SaleOrdersDesktop({
    super.key,
    required this.gridKey,
    required this.dataSource,
    required this.rowsPerPage,
    required this.onExport,
    required this.onOrderTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(0),
      child: TheosDataGrid(
        gridKey: gridKey,
        source: dataSource,
        showPager: true,
        rowsPerPage: rowsPerPage,
        onExport: () async => onExport(),
        storageKey: 'sale_orders',
        onCellTap: (details) {
          if (details.rowColumnIndex.rowIndex > 0) {
            final rowIndex = details.rowColumnIndex.rowIndex - 1;
            // Check bounds
            final order = dataSource.getItem(rowIndex);
            if (order != null) {
              onOrderTap(order);
            }
          }
        },
        columns: <GridColumn>[
          GridColumn(
            columnName: 'reference',
            width: 120,
            label: TheosDataGrid.buildHeaderLabel('Referencia', context),
          ),
          GridColumn(
            columnName: 'customer',
            columnWidthMode: ColumnWidthMode.fill,
            label: TheosDataGrid.buildHeaderLabel('Cliente', context),
          ),
          GridColumn(
            columnName: 'date',
            width: 160,
            label: TheosDataGrid.buildHeaderLabel('Fecha de la orden', context),
          ),
          GridColumn(
            columnName: 'subtotal',
            width: 110,
            label: TheosDataGrid.buildHeaderLabel(
              'Subtotal',
              context,
              alignment: Alignment.centerRight,
            ),
          ),
          GridColumn(
            columnName: 'taxes',
            width: 100,
            label: TheosDataGrid.buildHeaderLabel(
              'Impuestos',
              context,
              alignment: Alignment.centerRight,
            ),
          ),
          GridColumn(
            columnName: 'total',
            width: 110,
            label: TheosDataGrid.buildHeaderLabel(
              'Total',
              context,
              alignment: Alignment.centerRight,
            ),
          ),
          GridColumn(
            columnName: 'state',
            width: 130,
            allowSorting: false,
            label: TheosDataGrid.buildHeaderLabel(
              'Estado',
              context,
              alignment: Alignment.center,
            ),
          ),
          GridColumn(
            columnName: 'salesperson',
            width: 140,
            label: TheosDataGrid.buildHeaderLabel('Vendedor', context),
          ),
        ],
      ),
    );
  }
}
