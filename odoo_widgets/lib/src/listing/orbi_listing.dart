import 'package:fluent_ui/fluent_ui.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_datagrid_export/export.dart';

/// Una columna del listado estándar.
///
/// Lleva su propia clave porque **ocultar y mostrar columnas se recuerda por
/// clave, no por posición**: si se guardara la posición, añadir una columna
/// nueva en medio le escondería a la gente una columna distinta de la que
/// escondió.
class OrbiColumn<T> {
  const OrbiColumn({
    required this.key,
    required this.label,
    required this.value,
    this.width,
    this.numeric = false,
    this.alwaysVisible = false,
  });

  final String key;
  final String label;

  /// Lo que se pinta en la celda, ya formateado. El formato es de quien conoce
  /// el dato, no del listado.
  final String Function(T row) value;

  final double? width;

  /// Alinea a la derecha y hace que el orden sea numérico. Una cantidad
  /// alineada a la izquierda obliga a leer cifra a cifra para compararlas.
  final bool numeric;

  /// Una columna que no se puede ocultar. Reservado para la que identifica la
  /// fila: sin ella la tabla deja de decir de qué es cada línea.
  final bool alwaysVisible;
}

/// Lo que toda pantalla de listado comparte, por orden del dueño
/// (11-sep-2026): *«todas tienen listado, filtro, paginación, exportación a
/// Excel, ocultar/mostrar columnas y título»*.
///
/// 🔴 **Vive en el paquete compartido a propósito.** Las dos aplicaciones
/// tienen listados y, si cada una se fabrica el suyo, vuelven a divergir como
/// ya divergieron. Aquí no depende de Odoo ni de ningún gestor de estado:
/// recibe filas y devuelve eventos.
class OrbiListing<T> extends StatefulWidget {
  const OrbiListing({
    super.key,
    required this.rows,
    required this.columns,
    required this.storageKey,
    this.filterText = '',
    this.onFilterChanged,
    this.filterPlaceholder = 'Buscar en la lista',
    this.pageIndex = 0,
    this.rowsPerPage = 50,
    this.totalCount,
    this.onPageChanged,
    this.onExport,
    this.exportFileName = 'listado',
    this.onRowTap,
    this.emptyMessage = 'No hay nada que mostrar todavía',
  });

  final List<T> rows;
  final List<OrbiColumn<T>> columns;

  /// Con qué nombre se recuerdan las columnas ocultas de ESTA pantalla.
  final String storageKey;

  final String filterText;
  final ValueChanged<String>? onFilterChanged;
  final String filterPlaceholder;

  final int pageIndex;
  final int rowsPerPage;

  /// Cuántas filas hay en total, que puede ser más de las que llegaron.
  final int? totalCount;
  final ValueChanged<int>? onPageChanged;

  /// Qué hacer con el Excel ya generado. Nulo esconde el botón, para las
  /// pocas listas que no deben salir del sistema.
  ///
  /// El listado **produce los bytes**; guardarlos es de quien nos usa, porque
  /// guardar un fichero es distinto en escritorio, en móvil y en navegador, y
  /// un paquete de widgets no tiene por qué saber de eso. Antes esto era un
  /// aviso sin contenido: el botón llamaba y no había Excel por ninguna parte.
  final void Function(List<int> excel, String suggestedName)? onExport;

  /// Cómo se llamará el fichero, sin extensión.
  final String exportFileName;

  final ValueChanged<T>? onRowTap;
  final String emptyMessage;

  @override
  State<OrbiListing<T>> createState() => _OrbiListingState<T>();
}

class _OrbiListingState<T> extends State<OrbiListing<T>> {
  final Set<String> _hidden = <String>{};

  /// Hace falta para exportar: el generador de Excel de Syncfusion trabaja
  /// sobre el estado de la rejilla, no sobre los datos sueltos, y así lo que
  /// sale al fichero es exactamente lo que se está viendo —incluidas las
  /// columnas que la persona dejó ocultas.
  final _gridKey = GlobalKey<SfDataGridState>();

  // El controlador vive en el estado, no en `build`. Fabricarlo en cada
  // reconstrucción le quita el foco y el cursor a quien está escribiendo, y en
  // un filtro que reconstruye a cada tecla eso significa perder la palabra
  // entera a la segunda letra.
  late final TextEditingController _filter = TextEditingController(
    text: widget.filterText,
  );

  @override
  void didUpdateWidget(covariant OrbiListing<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sólo cuando el texto lo cambia quien nos usa, no cuando lo escribe la
    // persona: si no, el cursor salta al final en cada tecla.
    if (widget.filterText != oldWidget.filterText &&
        widget.filterText != _filter.text) {
      _filter.text = widget.filterText;
    }
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  List<OrbiColumn<T>> get _visible => widget.columns
      .where((c) => c.alwaysVisible || !_hidden.contains(c.key))
      .toList(growable: false);

  void _toggle(OrbiColumn<T> column) {
    if (column.alwaysVisible) return;
    setState(() {
      if (!_hidden.remove(column.key)) _hidden.add(column.key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    // El mismo color de cabecera que ya usa la aplicación madura: el acento de
    // la marca, no un gris cualquiera.
    final headerColor = theme.accentColor
        .defaultBrushFor(theme.brightness)
        .withValues(alpha: 0.9);

    final total = widget.totalCount ?? widget.rows.length;
    final pages = total <= 0 ? 1 : ((total - 1) ~/ widget.rowsPerPage) + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(context),
        const SizedBox(height: 8),
        Expanded(
          child: widget.rows.isEmpty
              ? Center(child: Text(widget.emptyMessage))
              : SfDataGridTheme(
                  data: SfDataGridThemeData(headerColor: headerColor),
                  child: SfDataGrid(
                    key: _gridKey,
                    source: _OrbiSource<T>(
                      items: widget.rows,
                      columns: _visible,
                    ),
                    columnWidthMode: ColumnWidthMode.fill,
                    gridLinesVisibility: GridLinesVisibility.horizontal,
                    headerGridLinesVisibility: GridLinesVisibility.none,
                    allowSorting: true,
                    selectionMode: SelectionMode.single,
                    onCellTap: widget.onRowTap == null
                        ? null
                        : (details) {
                            final index = details.rowColumnIndex.rowIndex - 1;
                            if (index >= 0 && index < widget.rows.length) {
                              widget.onRowTap!(widget.rows[index]);
                            }
                          },
                    columns: [
                      for (final column in _visible)
                        GridColumn(
                          columnName: column.key,
                          width: column.width ?? double.nan,
                          label: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            alignment: column.numeric
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            // El texto de la cabecera lo decide Fluent a
                            // partir del propio acento: `basedOnLuminance`
                            // elige claro u oscuro según el color de fondo,
                            // así que un acento claro no deja la cabecera
                            // ilegible como haría un blanco fijo.
                            child: Text(
                              column.label,
                              style: TextStyle(
                                color: headerColor.basedOnLuminance(),
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        if (pages > 1) _pager(context, pages, total),
      ],
    );
  }

  Widget _toolbar(BuildContext context) => Row(
    children: [
      Expanded(
        child: TextBox(
          key: const Key('orbi-listing-filter'),
          placeholder: widget.filterPlaceholder,
          controller: _filter,
          prefix: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(FluentIcons.search),
          ),
          onChanged: widget.onFilterChanged,
        ),
      ),
      const SizedBox(width: 8),
      _columnsButton(context),
      if (widget.onExport != null) ...[
        const SizedBox(width: 8),
        Tooltip(
          message: 'Exportar a Excel',
          child: Button(
            key: const Key('orbi-listing-export'),
            onPressed: _export,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.excel_document),
                SizedBox(width: 6),
                Text('Excel'),
              ],
            ),
          ),
        ),
      ],
    ],
  );

  void _export() {
    final workbook = _gridKey.currentState?.exportToExcelWorkbook();
    if (workbook == null) return;
    final bytes = workbook.saveAsStream();
    workbook.dispose();
    widget.onExport!(bytes, widget.exportFileName);
  }

  Widget _columnsButton(BuildContext context) => DropDownButton(
    key: const Key('orbi-listing-columns'),
    title: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(FluentIcons.column_options),
        SizedBox(width: 6),
        Text('Columnas'),
      ],
    ),
    closeAfterClick: false,
    items: [
      for (final column in widget.columns)
        MenuFlyoutItem(
          text: Text(column.label),
          leading: Icon(
            column.alwaysVisible || !_hidden.contains(column.key)
                ? FluentIcons.check_mark
                : FluentIcons.checkbox,
          ),
          onPressed: column.alwaysVisible ? null : () => _toggle(column),
        ),
    ],
  );

  Widget _pager(BuildContext context, int pages, int total) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Decir cuántas hay en total, no sólo en qué página se está: sin el
        // total nadie sabe si merece la pena seguir pasando páginas.
        Text('$total ${total == 1 ? 'registro' : 'registros'}'),
        Row(
          children: [
            IconButton(
              key: const Key('orbi-listing-prev'),
              icon: const Icon(FluentIcons.chevron_left),
              onPressed: widget.pageIndex <= 0 || widget.onPageChanged == null
                  ? null
                  : () => widget.onPageChanged!(widget.pageIndex - 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('${widget.pageIndex + 1} de $pages'),
            ),
            IconButton(
              key: const Key('orbi-listing-next'),
              icon: const Icon(FluentIcons.chevron_right),
              onPressed:
                  widget.pageIndex >= pages - 1 || widget.onPageChanged == null
                  ? null
                  : () => widget.onPageChanged!(widget.pageIndex + 1),
            ),
          ],
        ),
      ],
    ),
  );
}

class _OrbiSource<T> extends DataGridSource {
  _OrbiSource({required this.items, required this.columns});

  final List<T> items;
  final List<OrbiColumn<T>> columns;

  // 🔴 Causa raíz de una tabla que sólo mostraba la cabecera, nunca una fila:
  // `DataGridSource` espera que quien lo extiende sobreescriba `rows`, no
  // `effectiveRows` (ese es un getter interno del framework, alimentado
  // desde `rows`; sobreescribirlo no hace nada — compila, pero la fuente
  // real que arma la rejilla se queda vacía siempre). Medido: con
  // `effectiveRows` sobreescrito, `SfDataGrid` pintaba la cabecera y cero
  // filas de datos, incluso con `rows` no vacío en `OrbiListing`.
  @override
  List<DataGridRow> get rows => [
    for (final row in items)
      DataGridRow(
        cells: [
          for (final column in columns)
            DataGridCell<String>(
              columnName: column.key,
              value: column.value(row),
            ),
        ],
      ),
  ];

  @override
  DataGridRowAdapter buildRow(DataGridRow row) => DataGridRowAdapter(
    cells: [
      for (var i = 0; i < row.getCells().length; i++)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: columns[i].numeric
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Text(
            '${row.getCells()[i].value}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
  );
}
