import 'package:flutter/material.dart';

import '../../ui/components/orbi_components.dart';
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
  Widget build(BuildContext context) => OrbiPageShell(
    title: 'Bodega',
    actions: [
      IconButton(
        key: const Key('warehouse-refresh-button'),
        tooltip: 'Actualizar despachos',
        onPressed: _controller.refresh,
        icon: const Icon(Icons.refresh),
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
              return switch (state.status) {
                OrderLoadStatus.initial || OrderLoadStatus.loading =>
                  const Center(child: CircularProgressIndicator()),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(item.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OrbiStatusChip(label: 'Negocio: ${item.businessState.code}'),
                  OrbiStatusChip(
                    label: locked ? 'Cobro pendiente' : 'Cobro completo',
                    icon: locked ? Icons.lock_outline : Icons.lock_open,
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
                child: FilledButton.icon(
                  onPressed:
                      locked || item.pickingIds.isEmpty || _busyPicking != null
                      ? null
                      : () => _validate(item),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Validar entrega'),
                ),
              ),
            ],
          ),
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
      builder: (context) => AlertDialog(
        title: const Text('Backorder requerido'),
        content: Text(pending.message),
        actions: [
          TextButton(
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
