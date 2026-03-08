import 'package:fluent_ui/fluent_ui.dart';

import '../../providers/sale_order_form_state.dart';

/// Banner de notificacion de conflicto de edicion
///
/// Muestra cuando hay un conflicto entre los cambios locales y los del servidor.
/// Permite al usuario elegir entre aceptar cambios del servidor o mantener los locales.
class ConflictBanner extends StatelessWidget {
  final String message;
  final Map<String, ConflictDetail>? conflicts;
  final VoidCallback onAcceptServer;
  final VoidCallback onKeepLocal;

  const ConflictBanner({
    super.key,
    required this.message,
    this.conflicts,
    required this.onAcceptServer,
    required this.onKeepLocal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(20),
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.warning, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Conflicto de Edicion',
                  style: theme.typography.subtitle?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(message, style: theme.typography.body),
          if (conflicts != null && conflicts!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Campos en conflicto:', style: theme.typography.bodyStrong),
            const SizedBox(height: 8),
            ...conflicts!.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      FluentIcons.circle_fill,
                      size: 6,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${_getFieldLabel(entry.key)}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: 'Tu valor: ${entry.value.localValue}',
                              style: TextStyle(color: theme.inactiveColor),
                            ),
                            const TextSpan(text: ' -> '),
                            TextSpan(
                              text: 'Servidor: ${entry.value.serverValue}',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Button(
                onPressed: onKeepLocal,
                child: const Text('Mantener mis cambios'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onAcceptServer,
                child: const Text('Aceptar del servidor'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getFieldLabel(String fieldName) {
    const labels = {
      'state': 'Estado',
      'partner_id': 'Cliente',
      'amount_total': 'Total',
      'amount_untaxed': 'Subtotal',
      'amount_tax': 'Impuestos',
      'date_order': 'Fecha',
      'validity_date': 'Vencimiento',
      'commitment_date': 'Fecha de Entrega',
      'user_id': 'Vendedor',
      'team_id': 'Equipo',
      'pricelist_id': 'Lista de Precios',
      'payment_term_id': 'Termino de Pago',
      'note': 'Notas',
      'client_order_ref': 'Ref. Cliente',
      'invoice_status': 'Estado de Facturacion',
      'locked': 'Bloqueado',
      'collection_session_id': 'Sesion de Cobro',
    };
    return labels[fieldName] ?? fieldName;
  }
}
