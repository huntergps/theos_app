import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/offline_queue_provider.dart';
import '../providers/sync_provider.dart';

/// Numero de horas que se considera el sync reciente y valido para salir a campo
const int _maxSyncAgeHours = 24;

/// Definicion de un item del checklist de disponibilidad offline
class _ChecklistItemDef {
  final String label;
  final IconData icon;
  final String Function(SyncScreenState syncState, OfflineQueueState queueState)
  detail;
  final bool Function(SyncScreenState syncState, OfflineQueueState queueState)
  isOk;

  const _ChecklistItemDef({
    required this.label,
    required this.icon,
    required this.detail,
    required this.isOk,
  });
}

/// Checklist visual "Listo para salir a campo".
///
/// Muestra semaforo verde/rojo para cada item critico que el vendedor
/// necesita antes de ir a una zona sin internet. Usa exclusivamente los
/// providers existentes [syncProvider] y [offlineQueueProvider].
class SyncReadinessChecklist extends ConsumerStatefulWidget {
  const SyncReadinessChecklist({super.key});

  @override
  ConsumerState<SyncReadinessChecklist> createState() =>
      _SyncReadinessChecklistState();
}

class _SyncReadinessChecklistState
    extends ConsumerState<SyncReadinessChecklist> {
  bool _isExpanded = true;

  /// Items del checklist con su logica de evaluacion
  static final List<_ChecklistItemDef> _items = [
    _ChecklistItemDef(
      label: 'Productos',
      icon: FluentIcons.product,
      isOk: (sync, _) => sync.getItemState('products').localCount > 0,
      detail: (sync, _) {
        final count = sync.getItemState('products').localCount;
        if (count == 0) {
          return 'Sin productos locales — sincronizar antes de salir';
        }
        return '$count productos disponibles offline';
      },
    ),
    _ChecklistItemDef(
      label: 'Clientes',
      icon: FluentIcons.people,
      isOk: (sync, _) => sync.getItemState('partners').localCount > 0,
      detail: (sync, _) {
        final count = sync.getItemState('partners').localCount;
        if (count == 0) {
          return 'Sin clientes locales — sincronizar antes de salir';
        }
        return '$count clientes disponibles offline';
      },
    ),
    _ChecklistItemDef(
      label: 'Impuestos',
      icon: FluentIcons.money,
      isOk: (sync, _) => sync.getItemState('taxes').localCount > 0,
      detail: (sync, _) {
        final count = sync.getItemState('taxes').localCount;
        if (count == 0) {
          return 'Sin impuestos — los calculos de precio fallaran';
        }
        return '$count impuestos cargados';
      },
    ),
    _ChecklistItemDef(
      label: 'Listas de precios',
      icon: FluentIcons.tag,
      isOk: (sync, _) => sync.getItemState('pricelists').localCount > 0,
      detail: (sync, _) {
        final count = sync.getItemState('pricelists').localCount;
        if (count == 0) {
          return 'Sin listas de precio — sincronizar antes de salir';
        }
        return '$count listas de precio disponibles';
      },
    ),
    _ChecklistItemDef(
      label: 'Metodos de pago',
      icon: FluentIcons.payment_card,
      isOk: (sync, _) =>
          sync.getItemState('payment_method_lines').localCount > 0,
      detail: (sync, _) {
        final count = sync.getItemState('payment_method_lines').localCount;
        if (count == 0) {
          return 'Sin metodos de pago — no podra registrar cobros';
        }
        return '$count metodos de pago disponibles';
      },
    ),
    _ChecklistItemDef(
      label: 'Cola offline vacia',
      icon: FluentIcons.send,
      isOk: (_, queue) => queue.totalCount == 0,
      detail: (_, queue) {
        if (queue.totalCount == 0) {
          return 'No hay operaciones pendientes de enviar';
        }
        return '${queue.totalCount} operacion(es) pendiente(s) — sincronizar antes de salir';
      },
    ),
    _ChecklistItemDef(
      label: 'Sync reciente (< ${_maxSyncAgeHours}h)',
      icon: FluentIcons.history,
      isOk: (sync, _) => _isProductsSyncRecent(sync),
      detail: (sync, _) {
        final lastSync = sync.getItemState('products').lastSyncDate;
        if (lastSync == null) return 'Nunca sincronizado — hacer sync completo';
        final age = DateTime.now().difference(lastSync);
        if (age.inHours >= _maxSyncAgeHours) {
          return 'Ultima sync hace ${_formatAge(age)} — recomendable actualizar';
        }
        return 'Ultima sync hace ${_formatAge(age)}';
      },
    ),
  ];

  static bool _isProductsSyncRecent(SyncScreenState sync) {
    final lastSync = sync.getItemState('products').lastSyncDate;
    if (lastSync == null) return false;
    return DateTime.now().difference(lastSync).inHours < _maxSyncAgeHours;
  }

  static String _formatAge(Duration age) {
    if (age.inMinutes < 60) return '${age.inMinutes} min';
    if (age.inHours < 24) return '${age.inHours}h';
    return '${age.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final syncState = ref.watch(syncProvider);
    final queueState = ref.watch(offlineQueueProvider);

    final failingItems = _items
        .where((item) => !item.isOk(syncState, queueState))
        .toList();
    final allOk = failingItems.isEmpty;

    return Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera siempre visible — muestra resumen y toggle
          _ChecklistHeader(
            allOk: allOk,
            failingCount: failingItems.length,
            isExpanded: _isExpanded,
            onToggle: () => setState(() => _isExpanded = !_isExpanded),
          ),

          // Contenido expandible
          if (_isExpanded) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lista de items del checklist
                  ..._items.map(
                    (item) => _ChecklistRow(
                      item: item,
                      syncState: syncState,
                      queueState: queueState,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Pie: resumen o boton de accion
                  _ChecklistFooter(
                    allOk: allOk,
                    failingCount: failingItems.length,
                    theme: theme,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Cabecera colapsable del checklist
class _ChecklistHeader extends StatelessWidget {
  final bool allOk;
  final int failingCount;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _ChecklistHeader({
    required this.allOk,
    required this.failingCount,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    final Color headerColor = allOk
        ? const Color(0xFF107C10) // verde exito
        : const Color(0xFFC50F1F); // rojo error

    return GestureDetector(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icono de estado grande
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: headerColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                allOk ? FluentIcons.completed : FluentIcons.warning,
                color: headerColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Texto de estado
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allOk
                        ? 'Listo para salir a campo'
                        : '$failingCount item(s) pendiente(s)',
                    style: theme.typography.bodyStrong?.copyWith(
                      color: headerColor,
                    ),
                  ),
                  Text(
                    allOk
                        ? 'Todos los datos estan disponibles offline'
                        : 'Resuelva los items en rojo antes de salir',
                    style: theme.typography.caption?.copyWith(
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Flecha de toggle
            Icon(
              isExpanded
                  ? FluentIcons.chevron_up_small
                  : FluentIcons.chevron_down_small,
              size: 16,
              color: theme.resources.textFillColorSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila individual del checklist
class _ChecklistRow extends StatelessWidget {
  final _ChecklistItemDef item;
  final SyncScreenState syncState;
  final OfflineQueueState queueState;

  const _ChecklistRow({
    required this.item,
    required this.syncState,
    required this.queueState,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final ok = item.isOk(syncState, queueState);
    final detail = item.detail(syncState, queueState);

    final Color dotColor = ok
        ? const Color(0xFF107C10)
        : const Color(0xFFC50F1F);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Semaforo: circulo de color
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.35),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Icono del catalogo
          Icon(
            item.icon,
            size: 16,
            color: theme.resources.textFillColorSecondary,
          ),
          const SizedBox(width: 10),

          // Etiqueta
          SizedBox(
            width: 140,
            child: Text(
              item.label,
              style: theme.typography.body?.copyWith(
                fontWeight: ok ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ),

          // Detalle
          Expanded(
            child: Text(
              detail,
              style: theme.typography.caption?.copyWith(
                color: ok
                    ? theme.resources.textFillColorSecondary
                    : const Color(0xFFC50F1F),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Icono OK/error al final
          const SizedBox(width: 8),
          Icon(
            ok
                ? FluentIcons.skype_circle_check
                : FluentIcons.status_circle_error_x,
            size: 16,
            color: dotColor,
          ),
        ],
      ),
    );
  }
}

/// Pie del checklist con resumen final
class _ChecklistFooter extends StatelessWidget {
  final bool allOk;
  final int failingCount;
  final FluentThemeData theme;

  const _ChecklistFooter({
    required this.allOk,
    required this.failingCount,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (allOk) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF107C10).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF107C10).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              FluentIcons.airplane,
              size: 16,
              color: Color(0xFF107C10),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Puede salir a campo con confianza. Los datos estan listos para uso offline.',
                style: theme.typography.caption?.copyWith(
                  color: const Color(0xFF107C10),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4CE).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFF7630C).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(FluentIcons.warning, size: 16, color: Color(0xFFF7630C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$failingCount item(s) requieren atencion. Use "Sincronizar Todo" en la barra superior antes de salir.',
              style: theme.typography.caption?.copyWith(
                color: const Color(0xFF8A4B00),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
