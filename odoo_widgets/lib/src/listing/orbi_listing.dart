import 'package:fluent_ui/fluent_ui.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_datagrid_export/export.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

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
    this.subtitle = false,
    this.metric = false,
    this.emphasis = false,
    this.badgeColor,
    this.leadingIcon,
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

  /// En ficha, va pegada debajo del título en vez de como un campo más. Para
  /// lo que califica al título y no se lee solo: la unidad de medida, el
  /// código, la referencia.
  final bool subtitle;

  /// En ficha, se dibuja como una cifra en su propio recuadro dentro de una
  /// cuadrícula, no como una línea «etiqueta: valor».
  ///
  /// 🔴 Está aquí, y no en cada pantalla, por lo que pidió el dueño: *«todos
  /// los listados deben tener el mismo aspecto»*. Cinco cifras leídas como
  /// cinco renglones seguidos se confunden entre sí; en recuadros se comparan
  /// de un vistazo. Antes esto lo resolvía cada pantalla con su propia
  /// función de ficha, que es justo lo que hacía que dos listados no se
  /// parecieran.
  final bool metric;

  /// Resalta el valor (negrita), sin cambiar cómo se alinea. Para el total de
  /// una fila: la cifra que manda se lee de un vistazo entre las demás.
  final bool emphasis;

  /// Cuando no es nula, la celda se pinta como una insignia de color en vez
  /// de texto plano. El color lo decide quien conoce el significado del
  /// estado — el listado no sabe qué es «aprobado» ni de qué color va.
  final Color Function(T row)? badgeColor;

  /// Un icono que antecede al valor — por ejemplo, el aviso de que la fila
  /// todavía no ha subido al servidor. Nulo si esta fila no lo necesita.
  final ({IconData icon, Color color})? Function(T row)? leadingIcon;
}

/// Una insignia de color, para la celda que la pida y para su misma columna
/// en ficha: el mismo aspecto en los dos, porque son la misma información.
Widget _orbiPill(String text, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.16),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text(
    text,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: color,
      fontWeight: FontWeight.w600,
      fontSize: 12,
    ),
  ),
);

/// Antepone el icono de aviso al valor de la celda, cuando la columna lo pide.
Widget _orbiWithLeading(
  Widget child,
  ({IconData icon, Color color})? leading,
) {
  if (leading == null) return child;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(leading.icon, size: 14, color: leading.color),
      const SizedBox(width: 4),
      Flexible(child: child),
    ],
  );
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
    this.showFilterBox = true,
    this.pageIndex = 0,
    this.rowsPerPage = 50,
    this.totalCount,
    this.onPageChanged,
    this.onExport,
    this.exportFileName = 'listado',
    this.onRowTap,
    this.emptyMessage = 'No hay nada que mostrar todavía',
    this.cardBadge,
  });

  /// Por debajo de este ancho la rejilla deja paso a tarjetas. Medido, no
  /// elegido: es el mismo corte que ya usaba la rejilla adaptativa anterior
  /// de Orbi, y coincide con el que reparte el panel de navegación.
  static const double cardBreakpoint = 840;

  /// Una tableta en vertical supera el corte de ancho y aun así necesita
  /// leer hacia abajo en vez de columnas comprimidas.
  static const double portraitCardBreakpoint = 1200;

  final List<T> rows;
  final List<OrbiColumn<T>> columns;

  /// Con qué nombre se recuerdan las columnas ocultas de ESTA pantalla.
  final String storageKey;

  final String filterText;
  final ValueChanged<String>? onFilterChanged;
  final String filterPlaceholder;

  /// Falso cuando quien nos usa ya tiene su propia caja de búsqueda arriba
  /// del listado y filtra `rows` antes de pasárselas — sin esto, `OrbiListing`
  /// siempre pinta la suya y el resultado son DOS cajas de búsqueda en la
  /// misma pantalla, una de ellas sin ningún `onFilterChanged` que la
  /// conecte (defecto medido el 14-sep-2026 en «Envases por recibir»). Las
  /// demás piezas de la barra (columnas, exportar) se siguen mostrando.
  final bool showFilterBox;

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

  /// El dato que resume la fila, en la esquina del título de la ficha.
  ///
  /// Devuelve **texto**, no un widget, a propósito: quien nos usa decide QUÉ
  /// resume la fila, y el listado decide CÓMO se ve. Aceptar un widget aquí
  /// sería abrir otra vez la puerta a que cada pantalla se pinte el suyo.
  final String Function(T row)? cardBadge;

  @override
  State<OrbiListing<T>> createState() => _OrbiListingState<T>();
}

class _OrbiListingState<T> extends State<OrbiListing<T>> {
  final Set<String> _hidden = <String>{};

  /// Qué se está viendo ahora mismo. Lo necesita la exportación: en tarjetas
  /// no hay rejilla montada de la que sacar el libro de Excel.
  bool _narrow = false;

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

  // La fuente vive en el estado. Fabricarla dentro de `build` la reiniciaba en
  // cada reconstrucción —o sea, en cada tecla del filtro—, y con ella se
  // perdía el orden que la persona acababa de elegir en una cabecera.
  late final _OrbiSource<T> _source = _OrbiSource<T>(
    items: widget.rows,
    columns: _visible,
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
    _source.dispose();
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
    // Un tinte suave del acento, no el acento sólido: una cabecera a color
    // plano se lee pesada (orden del dueño, 13-sep-2026, al ver la de
    // Clientes). El acento sigue reconociéndose — sólo que como fondo, no
    // como bloque de color.
    final headerColor = Color.alphaBlend(
      theme.accentColor.normal.withValues(alpha: 0.14),
      theme.resources.layerFillColorDefault,
    );

    final total = widget.totalCount ?? widget.rows.length;
    final pages = total <= 0 ? 1 : ((total - 1) ~/ widget.rowsPerPage) + 1;

    // Mantener la fuente al día en vez de fabricar otra: así el orden que la
    // persona eligió en una cabecera sobrevive a que lleguen filas nuevas.
    _source.update(items: widget.rows, columns: _visible);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(context),
        const SizedBox(height: 8),
        Expanded(
          child: widget.rows.isEmpty
              ? Center(child: Text(widget.emptyMessage))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final window = MediaQuery.sizeOf(context);
                    final portrait =
                        window.height > window.width &&
                        constraints.maxWidth <
                            OrbiListing.portraitCardBreakpoint;
                    _narrow =
                        constraints.maxWidth < OrbiListing.cardBreakpoint ||
                        portrait;
                    return _narrow
                        ? _cards(context)
                        : _grid(context, headerColor);
                  },
                ),
        ),
        if (pages > 1) _pager(context, pages, total),
      ],
    );
  }

  Widget _grid(BuildContext context, Color headerColor) => SfDataGridTheme(
    data: SfDataGridThemeData(headerColor: headerColor),
    child: SfDataGrid(
      key: _gridKey,
      source: _source,
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
              // El texto de la cabecera lo decide Fluent a partir del propio
              // acento: `basedOnLuminance` elige claro u oscuro según el color
              // de fondo, así que un acento claro no deja la cabecera
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
  );

  /// La misma lista, leída hacia abajo.
  ///
  /// 🔴 No es un adorno para móvil: a 390 px una rejilla con seis columnas y
  /// `ColumnWidthMode.fill` reparte 65 px por columna y **no se lee ninguna**.
  /// Cada fila pasa a ser una ficha con su identificador arriba y el resto de
  /// campos debajo, con tres papeles posibles: subtítulo pegado al título,
  /// cifra en recuadro dentro de una cuadrícula, o línea «etiqueta: valor».
  Widget _cards(BuildContext context) {
    final columns = _visible;
    if (columns.isEmpty) return Center(child: Text(widget.emptyMessage));
    // La que identifica la fila hace de título; si nadie se declaró como tal,
    // la primera, que es donde todo el mundo pone el nombre o el código.
    final title = columns.firstWhere(
      (c) => c.alwaysVisible,
      orElse: () => columns.first,
    );
    final subtitles = columns.where((c) => c.subtitle && c.key != title.key);
    final metrics = columns
        .where((c) => c.metric && c.key != title.key && !c.subtitle)
        .toList(growable: false);
    final plain = columns
        .where((c) => c.key != title.key && !c.subtitle && !c.metric)
        .toList(growable: false);

    return ListView.separated(
      key: const Key('orbi-listing-cards'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: widget.rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = widget.rows[index];
        final card = Card(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cardTitle(context, row, title, subtitles),
                for (final column in plain) ...[
                  const SizedBox(height: 6),
                  _cardLine(context, row, column),
                ],
                if (metrics.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _cardMetrics(context, row, metrics, constraints.maxWidth),
                ],
              ],
            ),
          ),
        );
        if (widget.onRowTap == null) return card;
        return GestureDetector(onTap: () => widget.onRowTap!(row), child: card);
      },
    );
  }

  Widget _cardTitle(
    BuildContext context,
    T row,
    OrbiColumn<T> title,
    Iterable<OrbiColumn<T>> subtitles,
  ) {
    final theme = FluentTheme.of(context);
    final leading = title.leadingIcon?.call(row);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _orbiWithLeading(
                Text(
                  title.value(row),
                  style: theme.typography.bodyStrong,
                  overflow: TextOverflow.ellipsis,
                ),
                leading,
              ),
              for (final column in subtitles)
                Text(column.value(row), style: theme.typography.caption),
            ],
          ),
        ),
        if (widget.cardBadge != null) ...[
          const SizedBox(width: 8),
          _badge(context, widget.cardBadge!(row)),
        ],
      ],
    );
  }

  /// El distintivo lo dibuja el listado, con colores del tema. Ninguna
  /// pantalla elige aquí su color: el dueño lo dijo expreso.
  Widget _badge(BuildContext context, String text) {
    final theme = FluentTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.resources.subtleFillColorSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.resources.controlStrokeColorDefault),
      ),
      child: Text(text, style: theme.typography.caption),
    );
  }

  Widget _cardLine(BuildContext context, T row, OrbiColumn<T> column) {
    final theme = FluentTheme.of(context);
    final badge = column.badgeColor?.call(row);
    final leading = column.leadingIcon?.call(row);
    final value = badge != null
        ? _orbiPill(column.value(row), badge)
        : Text(
            column.value(row),
            textAlign: column.numeric ? TextAlign.right : TextAlign.start,
            style: column.emphasis ? theme.typography.bodyStrong : null,
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(column.label, style: theme.typography.caption),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Align(
            alignment: column.numeric
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: _orbiWithLeading(value, leading),
          ),
        ),
      ],
    );
  }

  /// Las cifras en cuadrícula: dos por fila cuando cabe, una cuando no.
  Widget _cardMetrics(
    BuildContext context,
    T row,
    List<OrbiColumn<T>> metrics,
    double width,
  ) {
    final perRow = width >= 600 ? 2 : 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < metrics.length; index += perRow)
          Padding(
            padding: EdgeInsets.only(
              bottom: index + perRow < metrics.length ? 8 : 0,
            ),
            // `IntrinsicHeight` para que los dos recuadros de una fila midan
            // lo mismo aunque una etiqueta parta en dos líneas. Sin él, un
            // `stretch` dentro de una lista vertical no tiene altura contra la
            // que estirarse y la maquetación revienta.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var offset = 0; offset < perRow; offset++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          end: offset == perRow - 1 ? 0 : 8,
                        ),
                        child: index + offset < metrics.length
                            ? _metricBox(context, row, metrics[index + offset])
                            : const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _metricBox(BuildContext context, T row, OrbiColumn<T> column) {
    final theme = FluentTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.resources.subtleFillColorSecondary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(column.label, style: theme.typography.caption),
          const SizedBox(height: 2),
          Text(column.value(row), style: theme.typography.bodyStrong),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context) => Row(
    children: [
      if (widget.showFilterBox)
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
        )
      else
        const Spacer(),
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
    // En rejilla se exporta LA REJILLA, para que el fichero salga con el orden
    // que la persona acaba de elegir en una cabecera. En tarjetas no hay
    // rejilla montada, así que el libro se arma con los mismos datos y las
    // mismas columnas visibles: en los dos casos sale lo que se está viendo.
    //
    // 🔴 Antes esto era `if (workbook == null) return;`. Cuando la rejilla no
    // estaba montada el botón no hacía nada y no lo decía — la segunda promesa
    // vacía de este mismo botón. Ahora siempre hay un camino que produce el
    // fichero.
    final workbook = _narrow
        ? null
        : _gridKey.currentState?.exportToExcelWorkbook();
    final bytes = workbook != null
        ? _bytesOf(workbook)
        : _bytesOf(_workbookFromData());
    widget.onExport!(bytes, widget.exportFileName);
  }

  List<int> _bytesOf(xlsio.Workbook workbook) {
    final bytes = workbook.saveAsStream();
    workbook.dispose();
    return bytes;
  }

  xlsio.Workbook _workbookFromData() {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    final columns = _visible;
    for (var c = 0; c < columns.length; c++) {
      final cell = sheet.getRangeByIndex(1, c + 1);
      cell.setText(columns[c].label);
      cell.cellStyle.bold = true;
    }
    for (var r = 0; r < widget.rows.length; r++) {
      for (var c = 0; c < columns.length; c++) {
        sheet
            .getRangeByIndex(r + 2, c + 1)
            .setText(columns[c].value(widget.rows[r]));
      }
    }
    return workbook;
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

  /// Hasta cinco números consecutivos alrededor de la página actual (tres en
  /// estrecho, para no desbordar). Ir al principio o al final se resuelve con
  /// los botones de doble flecha, no forzando que su número siempre aparezca.
  List<int> _visiblePageNumbers(int current, int pages, int windowSize) {
    if (pages <= windowSize) return List.generate(pages, (i) => i);
    var start = current - windowSize ~/ 2;
    if (start < 0) start = 0;
    if (start > pages - windowSize) start = pages - windowSize;
    return List.generate(windowSize, (i) => start + i);
  }

  Widget _pageNumberButton(FluentThemeData theme, int page, bool selected) {
    final background = selected
        ? theme.accentColor.normal
        : Colors.transparent;
    return SizedBox(
      key: Key('orbi-listing-page-${page + 1}'),
      width: 30,
      height: 30,
      child: Button(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(EdgeInsets.zero),
          backgroundColor: WidgetStateProperty.all(background),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        onPressed: selected || widget.onPageChanged == null
            ? null
            : () => widget.onPageChanged!(page),
        child: Text(
          '${page + 1}',
          style: TextStyle(
            color: selected ? background.basedOnLuminance() : null,
            fontWeight: selected ? FontWeight.bold : null,
          ),
        ),
      ),
    );
  }

  Widget _pager(BuildContext context, int pages, int total) {
    final theme = FluentTheme.of(context);
    final current = widget.pageIndex;
    final visible = _visiblePageNumbers(current, pages, _narrow ? 3 : 5);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          // Decir cuántas hay en total, no sólo en qué página se está: sin el
          // total nadie sabe si merece la pena seguir pasando páginas.
          Text('$total ${total == 1 ? 'registro' : 'registros'}'),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                key: const Key('orbi-listing-first'),
                icon: const Icon(FluentIcons.double_chevron_left8),
                onPressed: current <= 0 || widget.onPageChanged == null
                    ? null
                    : () => widget.onPageChanged!(0),
              ),
              IconButton(
                key: const Key('orbi-listing-prev'),
                icon: const Icon(FluentIcons.chevron_left),
                onPressed: current <= 0 || widget.onPageChanged == null
                    ? null
                    : () => widget.onPageChanged!(current - 1),
              ),
              for (final page in visible)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _pageNumberButton(theme, page, page == current),
                ),
              IconButton(
                key: const Key('orbi-listing-next'),
                icon: const Icon(FluentIcons.chevron_right),
                onPressed: current >= pages - 1 || widget.onPageChanged == null
                    ? null
                    : () => widget.onPageChanged!(current + 1),
              ),
              IconButton(
                key: const Key('orbi-listing-last'),
                icon: const Icon(FluentIcons.double_chevron_right8),
                onPressed: current >= pages - 1 || widget.onPageChanged == null
                    ? null
                    : () => widget.onPageChanged!(pages - 1),
              ),
            ],
          ),
          Text('${current + 1} de $pages'),
        ],
      ),
    );
  }
}

class _OrbiSource<T> extends DataGridSource {
  _OrbiSource({required this.items, required this.columns});

  List<T> items;
  List<OrbiColumn<T>> columns;

  /// De qué fila original viene cada [DataGridRow], para poder pedirle a la
  /// columna su insignia o su icono — que son funciones de `T`, no del texto
  /// ya formateado que lleva la celda. Se reconstruye en cada lectura de
  /// [rows]; la igualdad de `DataGridRow` es por identidad, así que sigue
  /// sirviendo aunque la rejilla reordene la lista al ordenar por columna.
  final _rowOwners = <DataGridRow, T>{};

  /// Refrescar en vez de reemplazar. `notifyListeners` hace que la rejilla
  /// vuelva a leer `rows`, y la fuente conserva el orden que tenía.
  void update({required List<T> items, required List<OrbiColumn<T>> columns}) {
    if (identical(items, this.items) &&
        columns.length == this.columns.length &&
        List.generate(
          columns.length,
          (i) => columns[i].key == this.columns[i].key,
        ).every((same) => same)) {
      return;
    }
    this.items = items;
    this.columns = columns;
    notifyListeners();
  }

  // 🔴 Causa raíz de una tabla que sólo mostraba la cabecera, nunca una fila:
  // `DataGridSource` espera que quien lo extiende sobreescriba `rows`, no
  // `effectiveRows` (ese es un getter interno del framework, alimentado
  // desde `rows`; sobreescribirlo no hace nada — compila, pero la fuente
  // real que arma la rejilla se queda vacía siempre). Medido: con
  // `effectiveRows` sobreescrito, `SfDataGrid` pintaba la cabecera y cero
  // filas de datos, incluso con `rows` no vacío en `OrbiListing`.
  @override
  List<DataGridRow> get rows {
    _rowOwners.clear();
    final built = <DataGridRow>[];
    for (final row in items) {
      final dataRow = DataGridRow(
        cells: [
          for (final column in columns)
            DataGridCell<String>(
              columnName: column.key,
              value: column.value(row),
            ),
        ],
      );
      _rowOwners[dataRow] = row;
      built.add(dataRow);
    }
    return built;
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final owner = _rowOwners[row];
    return DataGridRowAdapter(
      cells: [
        for (var i = 0; i < row.getCells().length; i++)
          _buildCell(columns[i], '${row.getCells()[i].value}', owner),
      ],
    );
  }

  Widget _buildCell(OrbiColumn<T> column, String text, T? owner) {
    final badge = owner == null ? null : column.badgeColor?.call(owner);
    final leading = owner == null ? null : column.leadingIcon?.call(owner);
    final content = badge != null
        ? _orbiPill(text, badge)
        : Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: column.emphasis
                ? const TextStyle(fontWeight: FontWeight.w700)
                : null,
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: column.numeric ? Alignment.centerRight : Alignment.centerLeft,
      child: _orbiWithLeading(content, leading),
    );
  }
}
