import 'package:fluent_ui/fluent_ui.dart';
import 'package:odoo_widgets/odoo_widgets.dart';

import '../../ui/components/orbi_components.dart';
import '../../ui/export/export_listing.dart';
import '../../ui/fluent/orbi_page.dart';
import '../clients/catalog_contracts.dart';

/// Pantalla de navegación «Productos». Por orden del dueño (11-sep-2026) usa
/// el listado estándar `OrbiListing` (filtro, paginación, ocultar columnas)
/// en vez de fabricar el suyo propio: el buscador inline (`EntityPicker` +
/// `OrbiInlineCatalogPicker`) sigue existiendo, pero sólo dentro del editor
/// de ventas, donde se busca un producto para añadirlo a una línea; aquí la
/// pantalla es de navegación y ya trae su propio filtro de serie.
class ProductsScreen<T> extends StatefulWidget {
  const ProductsScreen({
    super.key,
    this.repository,
    this.controller,
    this.onExport,
  });
  final CatalogRepository<T>? repository;
  final CatalogController<T>? controller;

  /// Cómo guardar el Excel. Lo pone la ruta, que sí tiene con qué leer
  /// la preferencia de duración del aviso. Nulo esconde el botón.
  final ListingExporter? onExport;

  @override
  State<ProductsScreen<T>> createState() => _ProductsScreenState<T>();
}

class _ProductsScreenState<T> extends State<ProductsScreen<T>> {
  late final CatalogController<T>? _controller =
      widget.controller ??
      (widget.repository == null
          ? null
          : CatalogController<T>(repository: widget.repository!));
  @override
  void dispose() {
    if (widget.controller == null) _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const OrbiPage(
        title: 'Productos',
        subtitle: 'Catálogo de productos del ámbito activo',
        child: OrbiEmptyState(
          title: 'Catálogo no disponible',
          message: 'Conecta un catálogo local del ámbito activo.',
        ),
      );
    }
    return OrbiPage(
      title: 'Productos',
      subtitle: 'Busca, filtra y revisa precio y stock de cada producto',
      child: StreamBuilder<CatalogSnapshot<T>>(
        stream: controller.changes,
        initialData: controller.snapshot,
        builder: (context, snapshot) {
          final state = snapshot.data ?? controller.snapshot;
          if (state.status == CatalogLoadStatus.error) {
            return OrbiErrorState(
              message: 'No se pudo cargar el catálogo de productos.',
              onRetry: controller.refresh,
            );
          }
          if (state.status == CatalogLoadStatus.initial ||
              state.status == CatalogLoadStatus.loading) {
            return const Center(child: ProgressRing());
          }
          return LayoutBuilder(
            builder: (context, constraints) =>
                _body(context, constraints, controller, state),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    BoxConstraints constraints,
    CatalogController<T> controller,
    CatalogSnapshot<T> state,
  ) {
    final listing = OrbiListing<CatalogEntity<T>>(
      rows: state.items,
      columns: _columns(),
      storageKey: 'products-screen',
      exportFileName: 'productos',
      onExport: widget.onExport == null
          ? null
          : (bytes, name) => widget.onExport!(context, bytes, name),
      filterText: controller.query.search,
      onFilterChanged: controller.setSearch,
      filterPlaceholder: 'Buscar producto',
      pageIndex: controller.pageIndex,
      rowsPerPage: controller.query.pageSize,
      totalCount: state.totalCount ?? state.items.length,
      onPageChanged: controller.setPage,
      onRowTap: controller.select,
      emptyMessage: 'No hay productos en este catálogo todavía',
    );
    final detail = _detail(context, controller);
    // The side-by-side detail panel is desktop-shaped content: it must not
    // steal so much width that the listing below 840px falls back to a
    // compressed table. Only split when there is still room left over for a
    // real table after reserving the panel and the gap between them;
    // otherwise stack instead.
    const detailReserve = 320.0 + 16.0;
    final canConsiderSplit = constraints.maxWidth >= 840 + detailReserve;
    double detailWidth = 320;
    var canSplit = false;
    if (canConsiderSplit) {
      detailWidth = (320 * MediaQuery.textScalerOf(context).scale(1))
          .clamp(320.0, constraints.maxWidth * .45)
          .toDouble();
      canSplit = constraints.maxWidth - detailWidth - 16 >= 840;
    }
    if (canSplit) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: listing),
          const SizedBox(width: 16),
          SizedBox(width: detailWidth, child: detail),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: listing),
        detail,
      ],
    );
  }

  List<OrbiColumn<CatalogEntity<T>>> _columns() => [
    OrbiColumn(
      key: 'title',
      label: 'Producto',
      value: (entity) => entity.title,
      alwaysVisible: true,
    ),
    OrbiColumn(
      key: 'subtitle',
      label: 'Precio / stock',
      value: (entity) => entity.subtitle ?? '—',
    ),
  ];

  Widget _detail(BuildContext context, CatalogController<T> controller) {
    final typography = FluentTheme.of(context).typography;
    final selected = controller.selected;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: selected == null
            ? const Text('Selecciona un producto para ver precio y stock')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(selected.title, style: typography.subtitle),
                  if (selected.subtitle != null) Text(selected.subtitle!),
                  const SizedBox(height: 12),
                  Text('Identidad local: ${selected.uuid}'),
                  const OrbiStatusChip(
                    label: 'Precio/stock provistos por catálogo',
                  ),
                ],
              ),
      ),
    );
  }
}
