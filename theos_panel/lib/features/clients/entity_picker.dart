import 'package:fluent_ui/fluent_ui.dart';
import 'package:odoo_widgets/odoo_widgets.dart';

import '../../ui/components/orbi_components.dart';
import 'catalog_contracts.dart';

/// Search + listing picker shared by narrower dialogs (e.g. the sale
/// editor's client picker) that need to pick one entity.
///
/// Por orden del dueño (11-sep-2026) — *«todos los listados deben tener el
/// mismo aspecto»* — esta pantalla usa el mismo `OrbiListing` que
/// `ClientsScreen`/`ProductsScreen`, en vez de la rejilla adaptativa propia
/// (`OrbiRecordGrid`/`OrbiRecordList`) que usaba antes. `OrbiListing` trae su
/// propio filtro, así que ya no hace falta un campo de búsqueda aparte por
/// encima: el filtro que antes escribía en el `TextBox` de esta pantalla
/// ahora escribe directamente en el de `OrbiListing`.
class EntityPicker<T> extends StatefulWidget {
  const EntityPicker({
    super.key,
    required this.controller,
    required this.label,
    this.entityName,
    this.onSelected,
  });

  final CatalogController<T> controller;
  final String label;
  final String? entityName;
  final ValueChanged<CatalogEntity<T>>? onSelected;

  @override
  State<EntityPicker<T>> createState() => _EntityPickerState<T>();
}

class _EntityPickerState<T> extends State<EntityPicker<T>> {
  void _onRowTap(CatalogEntity<T> entity) {
    widget.controller.select(entity);
    widget.onSelected?.call(entity);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CatalogSnapshot<T>>(
      stream: widget.controller.changes,
      initialData: widget.controller.snapshot,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.controller.snapshot;
        return switch (state.status) {
          CatalogLoadStatus.initial ||
          CatalogLoadStatus.loading => const Center(child: ProgressRing()),
          CatalogLoadStatus.error => OrbiErrorState(
            message:
                'No se pudo cargar ${widget.entityName ?? widget.label.toLowerCase()}.',
            onRetry: widget.controller.refresh,
          ),
          CatalogLoadStatus.empty => const OrbiEmptyState(
            title: 'Sin resultados',
            message: 'Prueba otra búsqueda o actualiza el catálogo.',
          ),
          CatalogLoadStatus.data => _listing(context, state),
        };
      },
    );
  }

  Widget _listing(BuildContext context, CatalogSnapshot<T> state) =>
      OrbiListing<CatalogEntity<T>>(
        rows: state.items,
        columns: _columns(),
        storageKey: 'entity-picker',
        filterText: widget.controller.query.search,
        onFilterChanged: widget.controller.setSearch,
        filterPlaceholder: widget.label,
        pageIndex: widget.controller.pageIndex,
        rowsPerPage: widget.controller.query.pageSize,
        totalCount: state.totalCount ?? state.items.length,
        onPageChanged: widget.controller.setPage,
        onRowTap: _onRowTap,
        emptyMessage: 'Sin resultados',
      );

  List<OrbiColumn<CatalogEntity<T>>> _columns() => [
    OrbiColumn(
      key: 'title',
      label: widget.label,
      value: (entity) => entity.title,
      alwaysVisible: true,
    ),
    OrbiColumn(
      key: 'subtitle',
      label: 'Detalle',
      value: (entity) => entity.subtitle ?? '—',
    ),
  ];
}
