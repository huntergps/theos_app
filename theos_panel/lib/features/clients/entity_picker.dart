import 'package:flutter/material.dart';

import '../../ui/components/orbi_components.dart';
import 'catalog_contracts.dart';

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
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.controller.query.search);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CatalogSnapshot<T>>(
      stream: widget.controller.changes,
      initialData: widget.controller.snapshot,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.controller.snapshot;
        return LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
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
              ),
              const SizedBox(height: 12),
              Expanded(child: _body(context, constraints.maxWidth, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, double width, CatalogSnapshot<T> state) {
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
      CatalogLoadStatus.data => _list(context, width, state),
    };
  }

  Widget _list(BuildContext context, double width, CatalogSnapshot<T> state) {
    final wide = width >= 840;
    final children = [
      for (final entity in state.items)
        MergeSemantics(
          child: Semantics(
            selected: widget.controller.selected?.uuid == entity.uuid,
            label:
                '${entity.title}${entity.subtitle == null ? '' : '. ${entity.subtitle}'}',
            child: Card(
              child: ListTile(
                title: Text(entity.title),
                subtitle: entity.subtitle == null
                    ? null
                    : Text(entity.subtitle!),
                selected: widget.controller.selected?.uuid == entity.uuid,
                onTap: () {
                  setState(() => widget.controller.select(entity));
                  widget.onSelected?.call(entity);
                },
              ),
            ),
          ),
        ),
    ];
    final content = wide
        ? GridView.extent(
            maxCrossAxisExtent: 360,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: children,
          )
        : ListView(children: children);
    return Column(
      children: [
        Expanded(child: content),
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
}
