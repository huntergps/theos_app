import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import '../providers/credit_approval_provider.dart';
import 'dialogs/copyable_info_bar.dart';

/// Widget que observa las órdenes en estado waitingApproval y
/// dispara una InfoBar por cada nueva orden que aparezca.
///
/// Debe colocarse en el árbol de widgets una sola vez (MainScreen) para
/// que las notificaciones se muestren en toda la app.
/// Solo actúa cuando el usuario tiene permisos de supervisor.
class CreditApprovalNotificationListener extends ConsumerStatefulWidget {
  const CreditApprovalNotificationListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CreditApprovalNotificationListener> createState() =>
      _CreditApprovalNotificationListenerState();
}

class _CreditApprovalNotificationListenerState
    extends ConsumerState<CreditApprovalNotificationListener> {
  // IDs de órdenes que ya han sido notificadas en esta sesión
  final Set<int> _notifiedIds = {};
  bool _isFirstLoad = true;

  @override
  Widget build(BuildContext context) {
    final isSupervisor = ref.watch(isSupervisorUserProvider);

    // Solo escuchar si es supervisor
    if (isSupervisor) {
      ref.listen<List<SaleOrder>>(
        pendingApprovalOrdersProvider,
        (previous, next) {
          // En la primera carga, registrar las órdenes existentes sin notificar
          // para evitar spam al iniciar la app.
          if (_isFirstLoad) {
            _isFirstLoad = false;
            for (final order in next) {
              _notifiedIds.add(order.id);
            }
            return;
          }

          // Detectar órdenes nuevas que no han sido notificadas
          for (final order in next) {
            if (!_notifiedIds.contains(order.id)) {
              _notifiedIds.add(order.id);
              _showApprovalNotification(context, order);
            }
          }

          // Limpiar IDs de órdenes que ya no están en waitingApproval
          final currentIds = next.map((o) => o.id).toSet();
          _notifiedIds.removeWhere((id) => !currentIds.contains(id));
        },
      );
    }

    return widget.child;
  }

  void _showApprovalNotification(BuildContext context, SaleOrder order) {
    if (!mounted) return;

    final currencySymbol = order.currencySymbol ?? '\$';
    final amount = _formatCurrency(order.amountTotal, currencySymbol);
    final client = order.partnerName ?? 'Cliente desconocido';
    final seller = order.userName ?? 'Vendedor desconocido';
    final orderName = order.name;

    // Usar CopyableInfoBar segun convencion del proyecto (no displayInfoBar directo)
    // Duracion larga (30s) porque requiere respuesta activa del supervisor
    CopyableInfoBar.showWarning(
      context,
      title: 'Solicitud de aprobacion de credito',
      message: '$orderName — $client por $amount\nVendedor: $seller',
      duration: const Duration(seconds: 30),
      action: Button(
        onPressed: () => context.go('/sales'),
        child: const Text('Ver solicitud'),
      ),
    );
  }

  String _formatCurrency(double amount, String symbol) {
    final formatter = NumberFormat('#,##0.00', 'es_EC');
    return '$symbol ${formatter.format(amount)}';
  }
}

/// Badge numérico para el ícono de ventas en el NavigationPane.
///
/// Muestra un punto rojo con el conteo cuando hay órdenes pendientes
/// de aprobación. Solo visible para supervisores.
class SalesBadgeIcon extends ConsumerWidget {
  const SalesBadgeIcon({super.key, required this.baseIcon});

  final IconData baseIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingApprovalCountProvider);

    if (count == 0) {
      return Icon(baseIcon);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(baseIcon),
        Positioned(
          top: -4,
          right: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
