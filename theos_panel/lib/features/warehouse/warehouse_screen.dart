import 'package:fluent_ui/fluent_ui.dart';

import '../../ui/components/orbi_components.dart';
import '../../ui/fluent/orbi_page.dart';
import '../orders/orders_contracts.dart';

import 'package:orbi_runtime/orbi_runtime.dart';

/// Read-only warehouse queue. The actual picking mutation remains owned by the
/// runtime command port; this surface only exposes the native-first gate and
/// never bypasses it with an ad-hoc RPC.
class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({
    super.key,
    required this.repository,
    required this.policy,
    required this.operations,
    this.scopeKey = 'unscoped',
  });

  final OrderRepository repository;
  final OrderFilterPolicy policy;
  final WarehouseOperationPort operations;
  final String scopeKey;

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  late final OrderController _controller = OrderController(
    repository: widget.repository,
    policy: widget.policy,
    scopeKey: widget.scopeKey,
  );
  String? _busyPicking;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OrbiPage(
    title: 'Bodega',
    commands: [
      CommandBarButton(
        key: const Key('warehouse-refresh-button'),
        icon: const Icon(FluentIcons.refresh),
        label: const Text('Actualizar'),
        tooltip: 'Actualizar despachos',
        onPressed: _controller.refresh,
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_message!, key: const Key('warehouse-result')),
          ),
        Expanded(
          child: StreamBuilder<OrderSnapshot>(
            stream: _controller.changes,
            initialData: _controller.snapshot,
            builder: (context, snapshot) {
              final state = snapshot.data ?? _controller.snapshot;
              final content = switch (state.status) {
                OrderLoadStatus.initial || OrderLoadStatus.loading =>
                  const Center(child: ProgressRing()),
                OrderLoadStatus.empty => const OrbiEmptyState(
                  title: 'Sin despachos',
                  message: 'No hay órdenes listas para revisar en bodega.',
                ),
                OrderLoadStatus.error => OrbiErrorState(
                  message: 'No se pudieron cargar los despachos.',
                  onRetry: _controller.refresh,
                ),
                OrderLoadStatus.data => _list(state.items),
              };
              final refreshError = state.refreshError;
              // El refresco en línea falló pero la copia local sí se pudo
              // leer: se sigue mostrando (`content`), y esto SÓLO añade el
              // aviso. Antes (`ScopeOrderRepository` con `catch (_) {}`) el
              // fallo se tragaba entero y Bodega quedaba vacía sin decir
              // por qué — el defecto medido en Mepriga el 14-sep.
              if (refreshError == null) return content;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InfoBar(
                      key: const Key('warehouse-refresh-error'),
                      title: const Text('No se pudo actualizar desde Odoo'),
                      content: Text(
                        'No se pudo actualizar desde Odoo: $refreshError. '
                        'Se muestra lo guardado en el equipo.',
                      ),
                      severity: InfoBarSeverity.warning,
                    ),
                  ),
                  Expanded(child: content),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _list(List<OrderListItem> items) => ListView.separated(
    itemCount: items.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final item = items[index];
      final locked = item.pendingCollection;
      return Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.title,
              style: FluentTheme.of(context).typography.bodyStrong,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OrbiStatusChip(label: 'Negocio: ${item.businessState.code}'),
                OrbiStatusChip(
                  label: locked ? 'Cobro pendiente' : 'Cobro completo',
                  icon: locked ? FluentIcons.lock : FluentIcons.unlock,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (locked)
              const Text(
                'Entrega bloqueada: se requiere cobro completo.',
                key: Key('delivery-payment-lock'),
              )
            else if (item.pickingIds.isEmpty)
              const Text('Sin picking pendiente en el alcance local.')
            else
              const Text(
                'Entrega habilitada; ejecutar flujo oficial de picking.',
              ),
            const SizedBox(height: 8),
            Semantics(
              button: true,
              enabled: !locked && item.pickingIds.isNotEmpty,
              label: locked
                  ? 'Validar entrega bloqueada por cobro pendiente'
                  : item.pickingIds.isEmpty
                  ? 'Validar entrega sin picking disponible'
                  : 'Validar entrega mediante flujo oficial',
              child: FilledButton(
                onPressed:
                    locked || item.pickingIds.isEmpty || _busyPicking != null
                    ? null
                    : () => _validate(item),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.delivery_truck),
                    SizedBox(width: 8),
                    Text('Validar entrega'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _validate(OrderListItem item) async {
    final pickingId = item.pickingIds.first;
    setState(() {
      _busyPicking = item.localId;
      _message = null;
    });
    final result = await widget.operations.validatePicking(
      pickingId: pickingId,
    );
    if (!mounted) return;
    if (result.state == WarehouseValidationState.backorderRequired) {
      setState(() {
        _busyPicking = null;
        _message = result.message;
      });
      await _showBackorderDialog(result);
      return;
    }
    setState(() {
      _busyPicking = null;
      _message = result.message;
    });
    if (result.accepted) await _controller.refresh();
  }

  Future<void> _showBackorderDialog(WarehouseValidationResult pending) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ContentDialog(
        title: const Text('Backorder requerido'),
        content: Text(pending.message),
        actions: [
          Button(
            key: const Key('backorder-cancel-button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cerrar sin backorder'),
          ),
          FilledButton(
            key: const Key('backorder-confirm-button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar backorder'),
          ),
        ],
      ),
    );
    if (!mounted || confirm == null) return;
    setState(() => _busyPicking = 'backorder');
    final result = await widget.operations.resolveBackorder(
      pending: pending,
      confirm: confirm,
    );
    if (!mounted) return;
    setState(() {
      _busyPicking = null;
      _message = result.message;
    });
    if (result.accepted) await _controller.refresh();
  }
}
