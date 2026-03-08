import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/repositories/repository_providers.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show saleOrderManager, SaleOrderManagerBusiness;
import '../../../../../core/theme/spacing.dart';
import '../../../../../shared/providers/user_provider.dart';
import '../../../../../shared/utils/formatting_utils.dart';
import '../fast_sale_providers.dart';

/// Provider to check if an order has pending sync operations
final orderPendingSyncProvider = FutureProvider.family<int, int>((ref, orderId) async {
  final offlineQueue = ref.read(offlineQueueDataSourceProvider);
  if (offlineQueue == null) {
    return 0;
  }

  final operations = await offlineQueue.getOperationsForSaleOrder(orderId);
  return operations.length;
});

/// Provider to sync a specific order
final syncOrderProvider = FutureProvider.family<bool, int>((ref, orderId) async {
  final offlineSyncService = ref.read(offlineSyncServiceProvider);
  if (offlineSyncService == null) return false;

  final result = await offlineSyncService.processSaleOrderQueue(orderId);
  return result.synced > 0 && result.failed == 0;
});

/// Show the search orders dialog and load selected order into a new tab
///
/// This function can be called from outside the POSOrderTabs widget,
/// for example from the empty state screen.
Future<void> showSearchOrdersDialog(BuildContext context, WidgetRef ref) async {
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => const _SearchOrdersDialog(),
  );

  if (result != null) {
    final orderId = result['id'] as int;
    await ref.read(fastSaleProvider.notifier).loadOrderInNewTab(orderId);
  }
}

/// Order tabs for switching between multiple open orders
///
/// Shows tabs like: [Registrar] [Ordenes] [+] [1016] [Nueva]
/// Each tab represents an open sale order
class POSOrderTabs extends ConsumerWidget {
  const POSOrderTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final tabs = ref.watch(fastSaleProvider.select((s) => s.tabs));
    final activeIndex = ref.watch(
      fastSaleProvider.select((s) => s.activeTabIndex),
    );
    final hasMoreOrders = ref.watch(
      fastSaleProvider.select((s) => s.hasMoreOrders),
    );
    final totalOrdersCount = ref.watch(
      fastSaleProvider.select((s) => s.totalOrdersCount),
    );
    final notifier = ref.read(fastSaleProvider.notifier);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.menuColor,
        border: Border(
          bottom: BorderSide(color: theme.resources.dividerStrokeColorDefault),
        ),
      ),
      child: Row(
        children: [
          // "Ordenes" label
          Container(
            padding: EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
            child: Text(
              'Ordenes',
              style: theme.typography.body?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
          ),

          // Add new tab button (+) - clean icon button with accent color
          Tooltip(
            message: 'Nueva orden',
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: Spacing.xxs, vertical: Spacing.xxs),
              child: IconButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(
                    theme.accentColor.withValues(alpha: 0.15),
                  ),
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Spacing.xs),
                      side: BorderSide(
                        color: theme.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                icon: Icon(
                  FluentIcons.add,
                  size: 18,
                  color: theme.accentColor,
                ),
                onPressed: () => notifier.addNewTab(),
              ),
            ),
          ),

          // Vertical divider
          Container(
            width: 1,
            height: Spacing.lg,
            margin: EdgeInsets.symmetric(horizontal: Spacing.xs),
            color: theme.resources.dividerStrokeColorDefault,
          ),

          // Order tabs
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final isActive = index == activeIndex;

                return _OrderTab(
                  orderId: tab.orderId,
                  orderName: tab.orderName,
                  isActive: isActive,
                  hasChanges: tab.hasChanges,
                  onTap: () => notifier.switchToTab(index),
                  onClose: () => _confirmCloseTab(context, ref, index, tab.hasChanges),
                );
              },
            ),
          ),

          // Search more orders button (shown when there are more orders) - prominent
          if (hasMoreOrders) ...[
            Container(
              width: 1,
              height: Spacing.lg,
              margin: EdgeInsets.symmetric(horizontal: Spacing.xs),
              color: theme.resources.dividerStrokeColorDefault,
            ),
            Tooltip(
              message: 'Buscar en $totalOrdersCount órdenes',
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: Spacing.xxs, vertical: Spacing.xxs),
                child: Button(
                  style: ButtonStyle(
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
                    ),
                    backgroundColor: WidgetStatePropertyAll(
                      theme.accentColor.withValues(alpha: 0.1),
                    ),
                  ),
                  onPressed: () => _showSearchOrdersDialog(context, ref),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.search, size: 16, color: theme.accentColor),
                      SizedBox(width: Spacing.xs),
                      Text(
                        '+${totalOrdersCount - tabs.length}',
                        style: theme.typography.body?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          SizedBox(width: Spacing.xs),
        ],
      ),
    );
  }

  /// Confirm closing a tab with unsaved changes
  Future<void> _confirmCloseTab(
    BuildContext context,
    WidgetRef ref,
    int index,
    bool hasChanges,
  ) async {
    final notifier = ref.read(fastSaleProvider.notifier);

    if (!hasChanges) {
      // No changes, close directly
      notifier.closeTab(index);
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Cerrar orden'),
        content: const Text(
          'Esta orden tiene cambios sin guardar. ¿Está seguro que desea cerrarla?',
        ),
        actions: [
          Button(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FilledButton(
            child: const Text('Cerrar sin guardar'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      notifier.closeTab(index);
    }
  }

  Future<void> _showSearchOrdersDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _SearchOrdersDialog(),
    );

    if (result != null) {
      final orderId = result['id'] as int;
      await ref.read(fastSaleProvider.notifier).loadOrderInNewTab(orderId);
    }
  }
}

/// Dialog to search orders by number, customer, phone, VAT, etc.
class _SearchOrdersDialog extends ConsumerStatefulWidget {
  const _SearchOrdersDialog();

  @override
  ConsumerState<_SearchOrdersDialog> createState() => _SearchOrdersDialogState();
}

class _SearchOrdersDialogState extends ConsumerState<_SearchOrdersDialog> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  // Filter states (defaults: show only editable orders for current user)
  bool _includeConfirmed = false;
  bool _includeInvoiced = false;

  @override
  void initState() {
    super.initState();
    // Load pre-filtered results on dialog open
    _loadInitialResults();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Load pre-filtered orders for salespeople:
  /// - Orders NOT in 'sale' state (only editable: draft, sent, waiting_approval, approved)
  /// - Belonging to current user
  /// - Ordered by date_order DESC (newest first)
  Future<void> _loadInitialResults() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(userProvider);
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final results = await saleOrderManager.getEditableOrdersForPOS(
        // IMPORTANT: User.id is the Odoo user ID
        // SaleOrder.userId stores the Odoo user ID
        userId: currentUser.id,
        limit: 30,
        includeConfirmed: _includeConfirmed,
        includeInvoiced: _includeInvoiced,
      );

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  /// Get readable label for order state
  String _getStateLabel(String state) {
    switch (state) {
      case 'draft':
        return 'Borrador';
      case 'sent':
        return 'Enviado';
      case 'waiting_approval':
        return 'Esperando aprobación';
      case 'approved':
        return 'Aprobado';
      case 'sale':
        return 'Confirmada';
      case 'cancel':
        return 'Cancelada';
      default:
        return state;
    }
  }

  Future<void> _search([String? queryOverride]) async {
    final query = queryOverride ?? _searchController.text;
    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(userProvider);
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final results = await saleOrderManager.getEditableOrdersForPOS(
        // IMPORTANT: User.id is the Odoo user ID
        // SaleOrder.userId stores the Odoo user ID
        userId: currentUser.id,
        query: query.isEmpty ? null : query,
        limit: 30,
        includeConfirmed: _includeConfirmed,
        includeInvoiced: _includeInvoiced,
      );

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      title: const Text('Buscar Orden'),
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
      content: SizedBox(
        height: 400,
        child: Column(
          children: [
            TextBox(
              controller: _searchController,
              placeholder: 'Número, cliente, teléfono, RUC...',
              autofocus: true,
              onChanged: (value) => _search(value),
              prefix: Padding(
                padding: EdgeInsets.only(left: Spacing.xs),
                child: const Icon(FluentIcons.search, size: 16),
              ),
              suffix: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(FluentIcons.chrome_close, size: 12),
                      onPressed: () {
                        _searchController.clear();
                        _search('');
                      },
                    )
                  : null,
            ),
            SizedBox(height: Spacing.xs),
            // Filter toggles row
            Row(
              children: [
                Checkbox(
                  checked: _includeConfirmed,
                  onChanged: (value) {
                    setState(() => _includeConfirmed = value ?? false);
                    _search();
                  },
                  content: Text('Confirmadas', style: theme.typography.caption),
                ),
                SizedBox(width: Spacing.sm),
                Checkbox(
                  checked: _includeInvoiced,
                  onChanged: (value) {
                    setState(() => _includeInvoiced = value ?? false);
                    _search();
                  },
                  content: Text('Facturadas', style: theme.typography.caption),
                ),
              ],
            ),
            SizedBox(height: Spacing.xs),
            if (_isLoading)
              const Expanded(child: Center(child: ProgressRing()))
            else if (_results.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    _searchController.text.isEmpty
                        ? 'No hay órdenes pendientes'
                        : 'No se encontraron órdenes',
                    style: theme.typography.body?.copyWith(
                      color: theme.inactiveColor,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final order = _results[index];
                    final state = order['state'] ?? '';
                    final invoiceStatus = order['invoice_status'] ?? '';
                    final isInvoiced = invoiceStatus == 'invoiced';

                    // Build status text
                    String statusText = _getStateLabel(state);
                    if (isInvoiced) {
                      statusText += ' (Facturada)';
                    }

                    return ListTile.selectable(
                      title: Row(
                        children: [
                          Text(order['name'] ?? 'Sin nombre'),
                          if (isInvoiced) ...[
                            SizedBox(width: Spacing.xs),
                            Icon(FluentIcons.completed_solid, size: 12, color: Colors.green),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        '${order['partner_name'] ?? 'Sin cliente'} - $statusText',
                        style: theme.typography.caption?.copyWith(
                          color: isInvoiced ? Colors.green : null,
                        ),
                      ),
                      trailing: Text(
                        ((order['amount_total'] ?? 0) as num).toCurrency(),
                        style: theme.typography.body?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(order);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        Button(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Individual order tab widget with sync indicator (icon only)
class _OrderTab extends ConsumerWidget {
  final int orderId;
  final String orderName;
  final bool isActive;
  final bool hasChanges;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _OrderTab({
    required this.orderId,
    required this.orderName,
    required this.isActive,
    required this.hasChanges,
    required this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);

    // Watch pending sync count for this order
    final pendingSyncAsync = ref.watch(orderPendingSyncProvider(orderId));
    final pendingCount = pendingSyncAsync.when(
      data: (count) => count,
      loading: () => 0,
      error: (_, _) => 0,
    );
    final hasPendingSync = pendingCount > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: Spacing.xxs, vertical: Spacing.xxs),
        padding: EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xxs),
        decoration: BoxDecoration(
          color: isActive
              ? theme.accentColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(Spacing.xs),
          border: isActive
              ? Border.all(color: theme.accentColor, width: 1)
              : Border.all(color: theme.resources.dividerStrokeColorDefault),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Order name
            Text(
              orderName,
              style: theme.typography.body?.copyWith(
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? theme.accentColor : null,
                fontSize: 13,
              ),
            ),

            // Pending sync indicator (icon only, next to name)
            if (hasPendingSync) ...[
              SizedBox(width: Spacing.xxs),
              Tooltip(
                message: '$pendingCount pendientes',
                child: Icon(
                  FluentIcons.sync,
                  size: 11,
                  color: Colors.orange,
                ),
              ),
            ],

            // Unsaved changes indicator (only show if no pending sync)
            if (hasChanges && !hasPendingSync) ...[
              SizedBox(width: Spacing.xxs),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ],

            // Close button
            if (onClose != null) ...[
              SizedBox(width: Spacing.xs),
              GestureDetector(
                onTap: onClose,
                child: Icon(
                  FluentIcons.chrome_close,
                  size: 10,
                  color: theme.inactiveColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
