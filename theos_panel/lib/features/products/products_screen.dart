import 'package:flutter/material.dart';

import '../../ui/components/fields/orbi_inline_catalog_picker.dart';
import '../../ui/components/orbi_components.dart';
import '../clients/catalog_contracts.dart';
import '../clients/entity_picker.dart';

class ProductsScreen<T> extends StatefulWidget {
  const ProductsScreen({super.key, this.repository, this.controller});
  final CatalogRepository<T>? repository;
  final CatalogController<T>? controller;
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
      return const OrbiPageShell(
        title: 'Productos',
        child: OrbiEmptyState(
          title: 'Catálogo no disponible',
          message: 'Conecta un catálogo local del ámbito activo.',
        ),
      );
    }
    return OrbiPageShell(
      title: 'Productos',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final picker = EntityPicker<T>(
            controller: controller,
            label: 'Buscar producto',
            entityName: 'productos',
            // Product search stays inline inside the grid area (the same
            // reusable overlay picker the sale line editor uses), instead of
            // an external search bar that would replace the record grid.
            searchBuilder: (context, controller) =>
                OrbiInlineCatalogPicker<T>(
                  controller: controller,
                  label: 'Buscar producto',
                  onSelected: (_) {},
                ),
          );
          final detail = StreamBuilder<CatalogSnapshot<T>>(
            stream: controller.changes,
            initialData: controller.snapshot,
            builder: (context, _) => _detail(context, controller),
          );
          // The side-by-side detail panel is desktop-shaped content: it must
          // not steal so much width that the record grid below 840px falls
          // back to a compressed list on tablet horizontal. Only split when
          // there is still room left over for a real grid after reserving
          // the panel and the gap between them; otherwise stack instead.
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
                Expanded(child: picker),
                const SizedBox(width: 16),
                SizedBox(width: detailWidth, child: detail),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: picker),
              detail,
            ],
          );
        },
      ),
    );
  }

  Widget _detail(BuildContext context, CatalogController<T> controller) {
    final selected = controller.selected;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: selected == null
            ? const Text('Selecciona un producto para ver precio y stock')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    selected.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
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
