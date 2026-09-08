import 'package:flutter/material.dart';

import '../../ui/components/orbi_components.dart';
import 'catalog_contracts.dart';
import 'entity_picker.dart';

class ClientsScreen<T> extends StatefulWidget {
  const ClientsScreen({super.key, this.repository, this.controller});
  final CatalogRepository<T>? repository;
  final CatalogController<T>? controller;
  @override
  State<ClientsScreen<T>> createState() => _ClientsScreenState<T>();
}

class _ClientsScreenState<T> extends State<ClientsScreen<T>> {
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
        title: 'Clientes',
        child: OrbiEmptyState(
          title: 'Catálogo no disponible',
          message: 'Conecta un catálogo local del ámbito activo.',
        ),
      );
    }
    return OrbiPageShell(
      title: 'Clientes',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final picker = EntityPicker<T>(
            controller: controller,
            label: 'Buscar cliente',
            entityName: 'clientes',
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
            ? const Text('Selecciona un cliente para ver su contexto')
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
                ],
              ),
      ),
    );
  }
}
