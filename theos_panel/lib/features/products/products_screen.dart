import 'package:flutter/material.dart';

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
          );
          final detail = StreamBuilder<CatalogSnapshot<T>>(
            stream: controller.changes,
            initialData: controller.snapshot,
            builder: (context, _) => _detail(context, controller),
          );
          if (constraints.maxWidth >= 840) {
            final detailWidth =
                (320 * MediaQuery.textScalerOf(context).scale(1))
                    .clamp(320.0, constraints.maxWidth * .45)
                    .toDouble();
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
