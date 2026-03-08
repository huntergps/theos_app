import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repositories/repository_providers.dart'
    show salesRepositoryProvider;
import '../repositories/sales_repository.dart'; // Extension methods (getWithLines, etc.)
import '../../../core/services/logger_service.dart';
import '../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../../clients/clients.dart'
    show
        CreditInfoCard,
        clientWithCreditProvider,
        clientCreditServiceProvider,
        clientRepositoryProvider;

/// Credit info card wrapper for sales interfaces
///
/// Takes a `partnerId` and optionally an `orderId` to sync all related data.
/// When the sync button is pressed, it refreshes:
/// - Partner/client data and credit info
/// - Sale order data (if orderId provided)
/// - Sale order lines
/// - Related products
///
/// Usage:
/// ```dart
/// PartnerCreditInfoCard(
///   partnerId: order.partnerId,
///   orderId: order.id,
///   isCompact: !isExpanded,
/// )
/// ```
class PartnerCreditInfoCard extends ConsumerStatefulWidget {
  final int? partnerId;
  final int? orderId;
  final bool isCompact;

  /// Optional callback when sync completes
  final VoidCallback? onSyncComplete;

  /// Hide the sync button (for fast_sale where sync is in action panel)
  final bool hideSyncButton;

  const PartnerCreditInfoCard({
    super.key,
    required this.partnerId,
    this.orderId,
    this.isCompact = false,
    this.onSyncComplete,
    this.hideSyncButton = false,
  });

  @override
  ConsumerState<PartnerCreditInfoCard> createState() =>
      _PartnerCreditInfoCardState();
}

class _PartnerCreditInfoCardState extends ConsumerState<PartnerCreditInfoCard> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    if (widget.partnerId == null || widget.partnerId! <= 0) {
      return _buildNoPartnerState(context);
    }

    final clientAsync =
        ref.watch(clientWithCreditProvider(widget.partnerId!));

    return clientAsync.when(
      loading: () => _buildLoadingState(context),
      error: (error, stack) => const SizedBox.shrink(),
      data: (client) {
        if (client == null) return const SizedBox.shrink();
        return CreditInfoCard(
          client: client,
          isCompact: widget.isCompact,
          showActions: false,
          // Hide sync button when hideSyncButton is true (fast_sale uses POSActionsPanel)
          onRefresh: widget.hideSyncButton ? null : (_isSyncing ? null : _syncAllData),
        );
      },
    );
  }

  /// Sync ALL data related to the sale order from Odoo
  Future<void> _syncAllData() async {
    if (widget.partnerId == null) return;

    setState(() => _isSyncing = true);

    final syncedItems = <String>[];
    final errors = <String>[];

    try {
      logger.i('[PartnerCreditInfoCard]', 'Starting full sync for partner ${widget.partnerId}, order ${widget.orderId}');

      // 1. Sync partner/client data
      try {
        await _syncPartnerData();
        syncedItems.add('Cliente');
      } catch (e) {
        errors.add('Cliente: $e');
      }

      // 2. Sync sale order, lines, payments, withholds, invoices (if orderId provided)
      if (widget.orderId != null && widget.orderId! > 0) {
        try {
          await _syncSaleOrderData();
          syncedItems.addAll(['Orden', 'Líneas', 'Pagos', 'Retenciones', 'Facturas']);
        } catch (e) {
          errors.add('Orden: $e');
        }
      }

      // 3. Refresh credit info
      try {
        await _syncCreditInfo();
        syncedItems.add('Crédito');
      } catch (e) {
        errors.add('Crédito: $e');
      }

      logger.i('[PartnerCreditInfoCard]', 'Sync completed. Items: ${syncedItems.join(", ")}. Errors: ${errors.length}');

      // Show result message
      if (mounted) {
        if (errors.isEmpty) {
          CopyableInfoBar.showSuccess(
            context,
            title: 'Sincronizado',
            message: 'Actualizado: ${syncedItems.join(", ")}',
          );
        } else {
          // Build detailed error message
          final errorDetails = errors.join('\n');
          CopyableInfoBar.showWarning(
            context,
            title: 'Sincronización parcial',
            message: 'OK: ${syncedItems.join(", ")}\n\nErrores:\n$errorDetails',
          );
        }
      }

      // Call optional callback
      widget.onSyncComplete?.call();
    } catch (e, st) {
      logger.e('[PartnerCreditInfoCard]', 'Sync failed', e, st);

      if (mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error de sincronización',
          message: 'No se pudieron actualizar los datos:\n$e\n\nStack trace:\n$st',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  /// Sync partner/client data from Odoo
  Future<void> _syncPartnerData() async {
    final clientRepo = ref.read(clientRepositoryProvider);
    if (clientRepo == null) throw Exception('Sin conexión');

    logger.d('[PartnerCreditInfoCard]', 'Syncing partner ${widget.partnerId}');

    // Force refresh partner data from Odoo
    await clientRepo.refreshCreditData(widget.partnerId!);
  }

  /// Sync sale order and ALL related data from Odoo:
  /// - Order header
  /// - Order lines
  /// - Payment lines (sale.order.payment.line)
  /// - Withhold lines (sale.order.withhold.line)
  /// - Related invoices (account.move) and their lines
  Future<void> _syncSaleOrderData() async {
    final salesRepo = ref.read(salesRepositoryProvider);
    if (salesRepo == null) throw Exception('Sin conexión');

    logger.d('[PartnerCreditInfoCard]', 'Syncing sale order ${widget.orderId} with all related data');

    // getWithLines with forceRefresh=true syncs:
    // - Order and lines from Odoo
    // - Withhold lines (syncWithholdLinesFromOdoo)
    // - Payment lines (syncPaymentLinesFromOdoo)
    // - Invoices and invoice lines (syncInvoicesForOrder)
    await salesRepo.getWithLines(widget.orderId!, forceRefresh: true);
  }

  /// Sync credit info from Odoo
  Future<void> _syncCreditInfo() async {
    final creditService = ref.read(clientCreditServiceProvider);
    if (creditService == null) throw Exception('Sin conexión');

    logger.d('[PartnerCreditInfoCard]', 'Syncing credit info for partner ${widget.partnerId}');

    // Force refresh credit data from Odoo
    await creditService.getClientWithCredit(widget.partnerId!, forceRefresh: true);

    // Invalidate the provider to reload UI
    ref.invalidate(clientWithCreditProvider(widget.partnerId!));
  }

  Widget _buildNoPartnerState(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (widget.isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withAlpha(25),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FluentIcons.contact, size: 12, color: theme.inactiveColor),
            const SizedBox(width: 4),
            Text(
              'Seleccione cliente',
              style: theme.typography.caption?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      backgroundColor: Colors.grey.withAlpha(12),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(FluentIcons.contact, size: 16, color: theme.inactiveColor),
          const SizedBox(width: 8),
          Text(
            'Crédito',
            style: theme.typography.bodyStrong?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
          const Spacer(),
          Text(
            'Seleccione un cliente',
            style: theme.typography.caption?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (widget.isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withAlpha(25),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: ProgressRing(strokeWidth: 2),
            ),
            const SizedBox(width: 4),
            Text(
              _isSyncing ? 'Sincronizando...' : 'Cargando...',
              style: theme.typography.caption?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      backgroundColor: Colors.grey.withAlpha(12),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: ProgressRing(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'Crédito',
            style: theme.typography.bodyStrong?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
          const Spacer(),
          Text(
            _isSyncing ? 'Sincronizando...' : 'Cargando...',
            style: theme.typography.caption?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}
