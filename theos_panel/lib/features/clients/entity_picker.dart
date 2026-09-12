import 'dart:async';

import 'package:flutter/material.dart';

import '../../ui/bindings/record_view_controller.dart';
import '../../ui/components/orbi_components.dart';
import '../../ui/components/records/orbi_record_grid.dart';
import 'catalog_contracts.dart';

/// Search + grid/list picker shared by the catalog screens (clients,
/// products) and by narrower dialogs (e.g. the sale editor's client picker).
///
/// The results surface reuses [OrbiRecordGrid]: a real Syncfusion grid on
/// desktop/tablet-landscape and [OrbiRecordList] cards on tablet-portrait/
/// phone, the same adaptive component `OrdersScreen` uses. It intentionally
/// does not reimplement a grid with `GridView.extent`, which produced fixed
/// square cells that did not resize to the actual content.
class EntityPicker<T> extends StatefulWidget {
  const EntityPicker({
    super.key,
    required this.controller,
    required this.label,
    this.entityName,
    this.onSelected,
    this.searchBuilder,
  });

  final CatalogController<T> controller;
  final String label;
  final String? entityName;
  final ValueChanged<CatalogEntity<T>>? onSelected;

  /// Builds the search control shown above the grid/list. Defaults to a
  /// plain search field with a refresh action. Pass a builder returning
  /// `OrbiInlineCatalogPicker` to search inline instead of a separate bar
  /// that would replace the grid with a bare results list
  /// (REACTIVE_COMPONENTS_SPEC.md §5: product search stays inside the grid).
  final Widget Function(BuildContext context, CatalogController<T> controller)?
  searchBuilder;

  @override
  State<EntityPicker<T>> createState() => _EntityPickerState<T>();
}

class _EntityPickerState<T> extends State<EntityPicker<T>> {
  late final TextEditingController _search = TextEditingController(
    text: widget.controller.query.search,
  );
  late final OrbiRecordViewController<CatalogEntity<T>> _records =
      OrbiRecordViewController<CatalogEntity<T>>(
        idOf: (record) => record.value.uuid,
      );
  StreamSubscription<CatalogSnapshot<T>>? _subscription;

  @override
  void initState() {
    super.initState();
    // Seed synchronously from the current snapshot (mirrors the
    // StreamBuilder's `initialData`), so the very first synchronous publish
    // from the controller's constructor is never missed by this late
    // subscription on its broadcast stream.
    _syncRecords(widget.controller.snapshot);
    _subscription = widget.controller.changes.listen(_syncRecords);
  }

  void _syncRecords(CatalogSnapshot<T> snapshot) {
    _records.replaceRecords([
      for (final entity in snapshot.items)
        OrbiRecord<CatalogEntity<T>>(id: entity.uuid, value: entity),
    ]);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _records.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onRecordTap(OrbiRecord<CatalogEntity<T>> record) {
    widget.controller.select(record.value);
    widget.onSelected?.call(record.value);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CatalogSnapshot<T>>(
      stream: widget.controller.changes,
      initialData: widget.controller.snapshot,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.controller.snapshot;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.searchBuilder?.call(context, widget.controller) ??
                _defaultSearch(),
            const SizedBox(height: 12),
            Expanded(child: _body(context, state)),
          ],
        );
      },
    );
  }

  Widget _defaultSearch() {
    return TextField(
      controller: _search,
      onChanged: widget.controller.setSearch,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          tooltip: 'Actualizar',
          onPressed: widget.controller.refresh,
          icon: const Icon(Icons.refresh),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, CatalogSnapshot<T> state) {
    return switch (state.status) {
      CatalogLoadStatus.initial || CatalogLoadStatus.loading => const Center(
        child: CircularProgressIndicator(),
      ),
      CatalogLoadStatus.error => OrbiErrorState(
        message:
            'No se pudo cargar ${widget.entityName ?? widget.label.toLowerCase()}.',
        onRetry: widget.controller.refresh,
      ),
      CatalogLoadStatus.empty => const OrbiEmptyState(
        title: 'Sin resultados',
        message: 'Prueba otra búsqueda o actualiza el catálogo.',
      ),
      CatalogLoadStatus.data => _grid(context, state),
    };
  }

  Widget _grid(BuildContext context, CatalogSnapshot<T> state) {
    return Column(
      children: [
        Expanded(
          child: OrbiRecordGrid<CatalogEntity<T>>(
            controller: _records,
            columns: _columns(),
            onRecordTap: _onRecordTap,
          ),
        ),
        if (state.nextCursor != null)
          TextButton.icon(
            onPressed: widget.controller.loadNext,
            icon: const Icon(Icons.expand_more),
            label: const Text('Cargar más'),
          ),
        Semantics(
          liveRegion: true,
          label: '${state.items.length} resultados',
          child: Text(
            '${state.items.length} resultados',
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  List<OrbiRecordColumn<CatalogEntity<T>>> _columns() => [
    OrbiRecordColumn(
      id: 'title',
      label: widget.label,
      value: (entity) => entity.title,
    ),
    OrbiRecordColumn(
      id: 'subtitle',
      label: 'Detalle',
      value: (entity) => entity.subtitle ?? '—',
    ),
  ];
}
