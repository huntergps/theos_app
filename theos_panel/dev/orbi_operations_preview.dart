import 'package:flutter/material.dart';

/// Simulation-only Caja, Bodega and Aprobaciones surface for the Orbi shell.
/// No remote calls, persistence or business rules are performed here.
class OrbiOperationsPreview extends StatefulWidget {
  const OrbiOperationsPreview({super.key, required this.area});

  final String area;

  @override
  State<OrbiOperationsPreview> createState() => _OrbiOperationsPreviewState();
}

class _OrbiOperationsPreviewState extends State<OrbiOperationsPreview> {
  String? _selectedOrder;
  bool _cashRegistered = false;
  bool _receiptVisible = false;
  final Set<String> _picked = <String>{};
  final Set<String> _approved = <String>{};

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      final medium = constraints.maxWidth >= 600 && constraints.maxWidth < 840;
      return Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 28,
              compact ? 16 : 24,
              compact ? 16 : 28,
              24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1420),
              child: _content(context, compact: compact, medium: medium),
            ),
          ),
          if (_receiptVisible) _receiptOverlay(context),
        ],
      );
    },
  );

  Widget _content(
    BuildContext context, {
    required bool compact,
    required bool medium,
  }) {
    final title = widget.area == 'Caja'
        ? 'Caja'
        : widget.area == 'Bodega'
        ? 'Bodega'
        : 'Aprobaciones';
    final subtitle = widget.area == 'Caja'
        ? 'Cobros pendientes · Turno mañana · Jacqueline Rizo'
        : widget.area == 'Bodega'
        ? 'Preparación y despacho · Matriz Quito'
        : 'Revisión comercial · 3 solicitudes requieren decisión';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const _SimulationBadge(),
          ],
        ),
        const SizedBox(height: 18),
        if (widget.area == 'Caja')
          _caja(context, compact: compact, medium: medium),
        if (widget.area == 'Bodega')
          _bodega(context, compact: compact, medium: medium),
        if (widget.area == 'Aprobaciones')
          _approvals(context, compact: compact),
      ],
    );
  }

  Widget _caja(
    BuildContext context, {
    required bool compact,
    required bool medium,
  }) {
    final list = _Panel(
      title: 'Pendientes por cobrar',
      icon: Icons.payments_outlined,
      subtitle: '4 documentos · ordenados por próxima acción',
      child: Column(
        children: [
          _orderRow(
            context,
            'SO-1048',
            'Laura Méndez',
            'Factura F-001948',
            42.56,
            'Esperando cobro',
            Icons.schedule,
          ),
          _orderRow(
            context,
            'SO-1043',
            'Comercial Andina',
            'Factura F-001943',
            118.40,
            'Pago parcial disponible',
            Icons.account_balance_wallet_outlined,
          ),
          _orderRow(
            context,
            'SO-1039',
            'Diego Paredes',
            'Factura F-001939',
            76.80,
            'Listo para cobrar',
            Icons.check_circle_outline,
          ),
          _orderRow(
            context,
            'SO-1037',
            'Restaurante La Plaza',
            'Factura F-001937',
            214.00,
            'Anticipo registrado',
            Icons.receipt_long_outlined,
          ),
        ],
      ),
    );
    final detail = _Panel(
      title: _selectedOrder == null
          ? 'Selecciona un documento'
          : 'Cobrar · $_selectedOrder',
      icon: Icons.point_of_sale_outlined,
      subtitle: 'El borrador de cobro queda aislado por documento y cajera',
      child: _cashDetail(context),
    );
    if (compact)
      return Column(children: [list, const SizedBox(height: 12), detail]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: medium ? 5 : 4, child: list),
        const SizedBox(width: 16),
        Expanded(flex: medium ? 5 : 6, child: detail),
      ],
    );
  }

  Widget _orderRow(
    BuildContext context,
    String ref,
    String customer,
    String invoice,
    double amount,
    String status,
    IconData icon,
  ) => InkWell(
    onTap: () => setState(() {
      _selectedOrder = ref;
      _cashRegistered = false;
    }),
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$ref · $customer',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '$invoice · $status',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    ),
  );

  Widget _cashDetail(BuildContext context) {
    if (_selectedOrder == null)
      return Center(
        child: Text(
          'Elige un pendiente para ver cliente, documento y medios de pago.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    final total = _selectedOrder == 'SO-1043' ? 118.40 : 42.56;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoLine(
          'Cliente',
          _selectedOrder == 'SO-1043'
              ? 'Comercial Andina · RUC 09901234001'
              : 'Laura Méndez · RUC 0912345678001',
        ),
        _infoLine(
          'Documento',
          'Factura · ${_selectedOrder == 'SO-1043' ? 'F-001943' : 'F-001948'}',
        ),
        _infoLine('Saldo pendiente', '\$${total.toStringAsFixed(2)}'),
        const Divider(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Efectivo recibido',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '\$${(total + 7.44).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: .82,
          minHeight: 7,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 8),
        _infoLine('Vuelto a entregar', '\$7.44'),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Pago mixto simulado · efectivo + saldo a favor'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (_cashRegistered) _savedMessage(context),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: _cashRegistered
                ? null
                : () => setState(() => _cashRegistered = true),
            icon: const Icon(Icons.lock_outline),
            label: Text(
              _cashRegistered
                  ? 'Cobro registrado'
                  : 'Cobrar \$${total.toStringAsFixed(2)}',
            ),
          ),
        ),
        if (_cashRegistered)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => _receiptVisible = true),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Ver comprobante persistente'),
            ),
          ),
      ],
    );
  }

  Widget _savedMessage(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Row(
      children: [
        Icon(Icons.cloud_upload_outlined, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text('Cobro guardado en este equipo · pendiente de enviar'),
        ),
      ],
    ),
  );

  Widget _bodega(
    BuildContext context, {
    required bool compact,
    required bool medium,
  }) {
    final prep = _Panel(
      title: 'Por preparar',
      icon: Icons.inventory_2_outlined,
      subtitle: 'Preparar sigue permitido aunque falte el pago',
      child: Column(
        children: [
          _warehouseRow(
            context,
            'SO-1048',
            'Laura Méndez',
            '3 líneas · estante A-04',
            'Pago pendiente',
            false,
          ),
          _warehouseRow(
            context,
            'SO-1043',
            'Comercial Andina',
            '6 líneas · estante B-02',
            'Pagado',
            true,
          ),
          _warehouseRow(
            context,
            'SO-1035',
            'Hotel Mirador',
            '2 líneas · estante C-01',
            'Pago pendiente',
            false,
          ),
        ],
      ),
    );
    final ready = _Panel(
      title: 'Preparado / listo para entregar',
      icon: Icons.local_shipping_outlined,
      subtitle: 'Entrega al cliente respeta el candado de pago',
      child: Column(
        children: [
          _warehouseRow(
            context,
            'SO-1032',
            'Panadería Sol',
            '4 bultos · muelle 2',
            'Listo · pagado',
            true,
          ),
          _warehouseRow(
            context,
            'SO-1029',
            'Óptica Central',
            '1 caja · mostrador',
            'Bloqueado por pago',
            false,
          ),
        ],
      ),
    );
    if (compact)
      return Column(children: [prep, const SizedBox(height: 12), ready]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: prep),
        const SizedBox(width: 16),
        Expanded(child: ready),
      ],
    );
  }

  Widget _warehouseRow(
    BuildContext context,
    String ref,
    String customer,
    String location,
    String status,
    bool enabled,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Icon(
          enabled ? Icons.check_circle_outline : Icons.pending_outlined,
          size: 20,
          color: enabled
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$ref · $customer',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '$location · $status',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: () => _showPicking(context, ref, enabled),
          child: Text(enabled ? 'Revisar' : 'Preparar'),
        ),
      ],
    ),
  );

  void _showPicking(BuildContext context, String ref, bool paymentReady) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final complete = _picked.where((e) => e.startsWith(ref)).length == 3;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checklist · $ref',
                  style: Theme.of(sheetContext).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Preparación simulada: marcar productos y ubicación.',
                ),
                for (final item in [
                  '3 unidades verificadas',
                  'Empaque y sello colocados',
                  'Ubicación confirmada',
                ])
                  CheckboxListTile(
                    value: _picked.contains('$ref$item'),
                    onChanged: (_) {
                      setState(() => _picked.add('$ref$item'));
                      setSheetState(() {});
                    },
                    title: Text(item),
                    contentPadding: EdgeInsets.zero,
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: complete
                        ? () {
                            Navigator.pop(sheetContext);
                            _snack(
                              context,
                              '$ref preparado · guardado localmente',
                            );
                          }
                        : null,
                    child: const Text('Marcar preparado'),
                  ),
                ),
                if (paymentReady)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Pago listo: la acción Entregar quedará habilitada.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _approvals(BuildContext context, {required bool compact}) => Column(
    children: [
      _approvalCard(
        context,
        'SO-1048',
        'Descuento excepcional · 18%',
        'Laura Méndez · Total afectado: \$42.56',
        'El descuento supera la política de mostrador.',
        'Ana Morales',
        Icons.local_offer_outlined,
      ),
      const SizedBox(height: 10),
      _approvalCard(
        context,
        'SO-1041',
        'Venta a crédito · 30 días',
        'Comercial Andina · \$1,840.00',
        'Cliente con saldo vencido de \$240.00.',
        'Erik Salazar',
        Icons.credit_score_outlined,
      ),
    ],
  );

  Widget _approvalCard(
    BuildContext context,
    String ref,
    String title,
    String summary,
    String reason,
    String owner,
    IconData icon,
  ) {
    final done = _approved.contains(ref);
    return _Panel(
      title: '$ref · $title',
      icon: icon,
      subtitle: done
          ? 'Resuelta en esta simulación · siguiente acción: volver al pedido'
          : 'Pendiente · responsable sugerido: $owner',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Motivo y consecuencia: $reason')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (!done)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _snack(
                      context,
                      'Solicitud devuelta al pedido $ref · simulación',
                    ),
                    child: const Text('Solicitar ajuste'),
                  ),
                ),
              if (!done) const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: done
                      ? null
                      : () => setState(() => _approved.add(ref)),
                  icon: Icon(done ? Icons.check : Icons.verified_outlined),
                  label: Text(done ? 'Aprobada' : 'Aprobar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _receiptOverlay(BuildContext context) {
    final content = Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Comprobante de cobro',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _receiptVisible = false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            const Text(
              'ORBI ERP · COPIA DEL CLIENTE',
              style: TextStyle(fontSize: 11, letterSpacing: 1.1),
            ),
            const SizedBox(height: 14),
            _infoLine('Documento', 'F-001948 · SO-1048'),
            _infoLine('Cliente', 'Laura Méndez'),
            _infoLine('Fecha', '09 sep 2026 · 10:42'),
            _infoLine('Total cobrado', '\$42.56'),
            _infoLine('Medio', 'Efectivo + saldo a favor'),
            const SizedBox(height: 12),
            const Text(
              'Resultado guardado y recuperable. Imprimir o compartir no registra otro pago.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _snack(
                      context,
                      'Impresión simulada · el cobro no se duplica',
                    ),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Imprimir'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _snack(
                      context,
                      'Comprobante listo para compartir · simulación',
                    ),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Compartir'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _infoLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ],
    ),
  );
  void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
}

class _SimulationBadge extends StatelessWidget {
  const _SimulationBadge();
  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      Icons.science_outlined,
      size: 16,
      color: Theme.of(context).colorScheme.primary,
    ),
    label: const Text('Simulación · datos locales'),
    visualDensity: VisualDensity.compact,
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });
  final String title, subtitle;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}
