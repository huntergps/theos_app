import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

import '../repositories/sales_repository.dart';
import '../repositories/sales_repository_models.dart' show CreditIssue;
import 'order_validation_types.dart';
import 'credit_validation_ui_service.dart';
import 'sale_order_logic_engine.dart';

/// Result of order confirmation
class OrderConfirmationResult {
  final bool success;
  final String? error;
  final bool hasCreditIssue;
  final UnifiedCreditResult? creditResult;
  final CreditIssue? serverCreditIssue;
  final SaleOrder? confirmedOrder;
  final List<SaleOrderLine>? confirmedLines;

  const OrderConfirmationResult._({
    required this.success,
    this.error,
    this.hasCreditIssue = false,
    this.creditResult,
    this.serverCreditIssue,
    this.confirmedOrder,
    this.confirmedLines,
  });

  /// Confirmation succeeded
  factory OrderConfirmationResult.success({
    SaleOrder? order,
    List<SaleOrderLine>? lines,
  }) => OrderConfirmationResult._(
    success: true,
    confirmedOrder: order,
    confirmedLines: lines,
  );

  /// Validation failed before confirmation
  factory OrderConfirmationResult.validationFailed(String error) =>
      OrderConfirmationResult._(success: false, error: error);

  /// Credit issue detected - need to show dialog
  factory OrderConfirmationResult.creditIssue(UnifiedCreditResult result) =>
      OrderConfirmationResult._(
        success: false,
        hasCreditIssue: true,
        creditResult: result,
        error: result.validationResult?.message ?? 'Problema de crédito',
      );

  factory OrderConfirmationResult.serverApproval(CreditIssue issue) =>
      OrderConfirmationResult._(
        success: false,
        hasCreditIssue: true,
        serverCreditIssue: issue,
        error: issue.message,
      );

  /// General error during confirmation
  factory OrderConfirmationResult.error(String error) =>
      OrderConfirmationResult._(success: false, error: error);

  /// Order queued for offline confirmation
  /// Preserves order and lines for UI to display
  factory OrderConfirmationResult.queued({
    SaleOrder? order,
    List<SaleOrderLine>? lines,
  }) => OrderConfirmationResult._(
    success: true,
    error: 'Orden en cola para confirmación cuando haya conexión',
    confirmedOrder: order,
    confirmedLines: lines,
  );
}

/// Unified service for confirming sale orders
///
/// This service consolidates the confirmation logic from both
/// Fast Sale POS and Sale Order Form screens.
///
/// Features:
/// - Order validation (partner, lines, state)
/// - Credit validation with dialog support
/// - Online confirmation via Odoo
/// - Offline confirmation via queue
/// - Order reload after confirmation
///
/// Usage:
/// ```dart
/// final service = ref.read(orderConfirmationServiceProvider);
/// final result = await service.confirmOrder(
///   order: order,
///   lines: lines,
/// );
/// if (result.hasCreditIssue) {
///   // Show credit dialog
/// } else if (result.success) {
///   // Order confirmed
/// }
/// ```
class OrderConfirmationService {
  static const _tag = '[OrderConfirmation]';

  final SalesRepository? salesRepository;
  final SaleOrderLogicEngine logicEngine;
  final CreditValidationUIService? creditValidationService;

  OrderConfirmationService({
    required this.salesRepository,
    required this.logicEngine,
    required this.creditValidationService,
  });

  /// Confirm a sale order with full validation
  ///
  /// Steps:
  /// 1. Validate order structure (partner, lines, state)
  /// 2. Validate credit limits (unless bypassed)
  /// 3. Sync unsynced order to Odoo (if local-only)
  /// 4. Call action_confirm or action_pos_confirm
  /// 5. Reload order with new state
  ///
  /// [order] - The order to confirm
  /// [lines] - Order lines
  /// [skipCreditCheck] - Skip credit validation (after user approval)
  /// [usePosConfirm] - Use POS-specific confirmation (with credit handling)
  /// [creditBypassed] - Credit check already bypassed by user
  Future<OrderConfirmationResult> confirmOrder({
    required SaleOrder order,
    required List<SaleOrderLine> lines,
    bool skipCreditCheck = false,
    bool usePosConfirm = false,
    bool creditBypassed = false,
  }) async {
    try {
      logger.d(_tag, 'Confirming order ${order.id} (${order.name})');

      final salesRepo = salesRepository;
      if (salesRepo == null) {
        return OrderConfirmationResult.error('Repositorio no disponible');
      }

      // 1. Validate order structure using LogicEngine
      final validationResult = await logicEngine.validateAction(
        order: order,
        lines: lines,
        action: OrderAction.confirm,
        context: {'skipCreditCheck': skipCreditCheck || creditBypassed},
      );

      if (!validationResult.isValid) {
        logger.w(
          _tag,
          'Validation failed: ${validationResult.firstErrorMessage}',
        );
        return OrderConfirmationResult.validationFailed(
          validationResult.firstErrorMessage ?? 'Validación fallida',
        );
      }

      // 2. Validate credit (unless bypassed)
      if (!salesRepo.isOnline &&
          !skipCreditCheck &&
          !creditBypassed &&
          order.partnerId != null) {
        if (creditValidationService != null) {
          final creditResult = await creditValidationService!.validateCredit(
            clientId: order.partnerId,
            orderAmount: _calculateOrderTotal(lines),
            skipIfBypassed: false,
            isBypassed: false,
            logTag: _tag,
          );

          if (creditResult.requiresDialog) {
            logger.i(_tag, 'Credit issue detected, requires dialog');
            return OrderConfirmationResult.creditIssue(creditResult);
          }
        }
      }

      // 3. Handle unsynced orders (local-only with negative ID)
      var orderId = order.id;
      logger.d(
        _tag,
        '=== CONFIRM STEP 3: orderId=$orderId (negative means local-only) ===',
      );
      if (orderId < 0) {
        // A local-only order cannot be uploaded without a connection. Queue
        // confirmation against the original order instead of calling create(),
        // which used to create a second local header and duplicate every line.
        if (!salesRepo.isOnline) {
          final queued = await salesRepo.confirmOffline(orderId);
          if (!queued) {
            return OrderConfirmationResult.error(
              'No se pudo guardar la confirmación offline',
            );
          }
          return OrderConfirmationResult.queued(
            order: order.copyWith(state: SaleOrderState.sale),
            lines: lines,
          );
        }
        logger.i(_tag, 'Order has local ID $orderId, syncing to Odoo first...');

        final syncResult = await _syncLocalOrder(order, salesRepo);
        if (!syncResult.success) {
          logger.e(_tag, 'Sync failed: ${syncResult.error}');
          return OrderConfirmationResult.error(
            syncResult.error ?? 'Error al sincronizar orden',
          );
        }
        orderId = syncResult.odooId!;
        logger.i(_tag, 'Order synced with Odoo ID: $orderId');
      } else {
        // 3.5. For existing orders, sync header changes (especially partner) before confirming
        // This ensures Odoo has the latest partner_id before validation
        // Pattern: Save local -> Sync to Odoo/Queue -> Read from local
        logger.d(
          _tag,
          'CONFIRM STEP 3.5: Syncing header changes for existing order $orderId',
        );

        final headerValues = _confirmationHeaderValues(order);

        if (headerValues.isNotEmpty) {
          logger.d(_tag, 'Syncing header changes: $headerValues');
          // salesRepo.update() follows the pattern:
          // 1. Save to local DB first
          // 2. Try to sync to Odoo (or queue if offline)
          // 3. Returns true if successful (either synced or queued)
          final syncSuccess = await salesRepo.update(orderId, headerValues);
          if (!syncSuccess) {
            // If update failed completely (not even queued), return error
            logger.e(_tag, 'Header sync failed completely');
            return OrderConfirmationResult.error(
              'Error al sincronizar cambios de cabecera con el servidor',
            );
          }
          logger.i(_tag, 'Header changes synced/queued successfully');
        }
      }

      // 3.6 Sync lines to Odoo (required before confirmation)
      // Lines with negative IDs are local-only and need to be created in Odoo
      final unsyncedLines = lines.where((line) => !line.isSynced).toList();
      if (unsyncedLines.isNotEmpty) {
        logger.d(
          _tag,
          '=== CONFIRM STEP 3.6: Syncing ${unsyncedLines.length} unsynced lines to Odoo ===',
        );
        final linesSynced = await salesRepo.syncOrderLinesToOdoo(
          orderId,
          lines,
        );
        if (!linesSynced) {
          // If online and sync failed, we should not proceed with confirmation
          // The order would have no lines in Odoo
          if (salesRepo.isOnline) {
            logger.e(
              _tag,
              'Failed to sync lines to Odoo - cannot confirm online',
            );
            return OrderConfirmationResult.error(
              'Error al sincronizar líneas con el servidor. Intente nuevamente.',
            );
          }
          // If offline, we can proceed with offline confirmation
          logger.d(
            _tag,
            'Lines not synced (offline) - will use offline confirmation',
          );
        } else {
          logger.d(_tag, 'Lines synced successfully to Odoo');
        }
      }

      // 4. Confirm order
      logger.d(
        _tag,
        '=== CONFIRM STEP 4: usePosConfirm=$usePosConfirm, orderId=$orderId ===',
      );
      if (usePosConfirm) {
        // Use POS-specific confirmation (handles credit on server side)
        try {
          logger.d(_tag, 'Attempting posConfirm for order $orderId...');
          final confirmResult = await salesRepo.posConfirm(
            orderId,
            skipCreditCheck: skipCreditCheck || creditBypassed,
          );
          logger.d(
            _tag,
            'posConfirm returned: success=${confirmResult.success}, error=${confirmResult.error}',
          );

          if (!confirmResult.success) {
            // Check if this is a connection error - fall back to offline
            final errorMsg = confirmResult.error ?? '';
            final isConnectionError =
                errorMsg.contains('Connection refused') ||
                errorMsg.contains('Connection errored') ||
                errorMsg.contains('SocketException') ||
                errorMsg.contains('Failed host lookup');

            if (isConnectionError) {
              logger.d(
                _tag,
                'Connection error detected, trying offline confirmation...',
              );
              final offlineSuccess = await salesRepo.confirmOffline(orderId);
              logger.d(_tag, 'confirmOffline returned: $offlineSuccess');
              if (offlineSuccess) {
                logger.d(
                  _tag,
                  'Order $orderId queued for offline confirmation - SUCCESS',
                );
                // Return order with updated state for UI
                final updatedOrder = order.copyWith(state: SaleOrderState.sale);
                return OrderConfirmationResult.queued(
                  order: updatedOrder,
                  lines: lines,
                );
              }
              // If offline also fails, return the original error
              logger.d(_tag, 'confirmOffline FAILED, returning original error');
            }

            if (confirmResult.hasCreditIssue &&
                confirmResult.creditIssue != null) {
              logger.d(
                _tag,
                'Server credit issue: ${confirmResult.creditIssue!.type}',
              );
              return OrderConfirmationResult.serverApproval(
                confirmResult.creditIssue!,
              );
            }
            return OrderConfirmationResult.error(
              confirmResult.error ?? 'Error al confirmar',
            );
          }
        } catch (e) {
          if (_isConfirmationTransportFailure(e)) {
            logger.d(_tag, '=== POS CONFIRM TRANSPORT EXCEPTION: $e ===');
            logger.d(_tag, 'Trying offline confirmation for order $orderId...');
            final offlineSuccess = await salesRepo.confirmOffline(orderId);
            logger.d(_tag, 'confirmOffline returned: $offlineSuccess');
            if (!offlineSuccess) {
              logger.d(_tag, 'confirmOffline FAILED for order $orderId');
              return OrderConfirmationResult.error(
                'Error al confirmar offline',
              );
            }
            logger.d(
              _tag,
              'Order $orderId queued for offline confirmation - SUCCESS',
            );
            final updatedOrder = order.copyWith(state: SaleOrderState.sale);
            return OrderConfirmationResult.queued(
              order: updatedOrder,
              lines: lines,
            );
          }
          return OrderConfirmationResult.error('Error al confirmar: $e');
        }
      } else {
        // Standard confirmation
        try {
          await salesRepo.confirm(orderId);
        } catch (e) {
          if (_isConfirmationTransportFailure(e)) {
            logger.w(_tag, 'Confirmation transport failed, queuing: $e');
            final offlineSuccess = await salesRepo.confirmOffline(orderId);
            if (!offlineSuccess) {
              return OrderConfirmationResult.error('Error al confirmar: $e');
            }
            final updatedOrder = order.copyWith(state: SaleOrderState.sale);
            return OrderConfirmationResult.queued(
              order: updatedOrder,
              lines: lines,
            );
          }
          return OrderConfirmationResult.error('Error al confirmar: $e');
        }
      }

      logger.i(_tag, 'Order $orderId confirmed successfully');

      // 5. Reload order with new state
      final (confirmedOrder, confirmedLines) = await salesRepo.getWithLines(
        orderId,
        forceRefresh: false,
      );

      return OrderConfirmationResult.success(
        order:
            confirmedOrder ??
            order.copyWith(id: orderId, state: SaleOrderState.sale),
        lines: confirmedLines.isNotEmpty ? confirmedLines : lines,
      );
    } catch (e, stack) {
      logger.e(_tag, 'Error confirming order', e, stack);
      return OrderConfirmationResult.error('Error al confirmar: $e');
    }
  }

  /// Quick validation without confirmation
  ///
  /// Use this to check if an order can be confirmed before showing
  /// confirmation dialog.
  Future<ValidationResult> validateForConfirmation({
    required SaleOrder order,
    required List<SaleOrderLine> lines,
  }) async {
    return logicEngine.validateAction(
      order: order,
      lines: lines,
      action: OrderAction.confirm,
      context: {'skipCreditCheck': true}, // Separate check for credit
    );
  }

  /// Check credit without confirming
  ///
  /// Use this to show credit dialog before attempting confirmation.
  Future<UnifiedCreditResult> checkCredit({
    required int? partnerId,
    required double orderAmount,
    bool isBypassed = false,
  }) async {
    if (creditValidationService == null) {
      return UnifiedCreditResult.notRequired();
    }
    return creditValidationService!.validateCredit(
      clientId: partnerId,
      orderAmount: orderAmount,
      skipIfBypassed: true,
      isBypassed: isBypassed,
      logTag: _tag,
    );
  }

  // Dedup: delega en orderTotalsCalculator (mismo resultado numérico).
  double _calculateOrderTotal(List<SaleOrderLine> lines) {
    return orderTotalsCalculator.calculate(lines: lines).total;
  }

  Future<_SyncResult> _syncLocalOrder(
    SaleOrder order,
    SalesRepository salesRepo,
  ) async {
    try {
      // Validate Final Consumer requirements before creating
      if (order.isFinalConsumer &&
          (order.endCustomerName == null ||
              order.endCustomerName!.trim().isEmpty)) {
        return _SyncResult(
          success: false,
          error: 'El nombre del consumidor final es obligatorio',
        );
      }

      final newOrderId = await salesRepo.syncLocalOrderToOdoo(order.id);

      if (newOrderId == null) {
        return _SyncResult(
          success: false,
          error: 'No se pudo crear la orden en el servidor',
        );
      }

      return _SyncResult(success: true, odooId: newOrderId);
    } catch (e) {
      return _SyncResult(success: false, error: 'Error al sincronizar: $e');
    }
  }
}

class _SyncResult {
  final bool success;
  final int? odooId;
  final String? error;

  _SyncResult({required this.success, this.odooId, this.error});
}

bool _isConfirmationTransportFailure(Object error) {
  return error is OdooConnectionException ||
      error is OdooTimeoutException ||
      error is OdooOfflineException;
}

Map<String, dynamic> _confirmationHeaderValues(SaleOrder order) {
  return {
    if (order.partnerId != null) 'partner_id': order.partnerId,
    if (order.paymentTermId != null) 'payment_term_id': order.paymentTermId,
    if (order.pricelistId != null) 'pricelist_id': order.pricelistId,
    if (order.warehouseId != null) 'warehouse_id': order.warehouseId,
    if (order.userId != null) 'user_id': order.userId,
    if (order.teamId != null) 'team_id': order.teamId,
    if (order.fiscalPositionId != null)
      'fiscal_position_id': order.fiscalPositionId,
    if (order.dateOrder != null)
      'date_order': formatOdooDateTime(order.dateOrder!),
    if (order.validityDate != null)
      'validity_date': formatOdooDate(order.validityDate!),
    if (order.commitmentDate != null)
      'commitment_date': formatOdooDateTime(order.commitmentDate!),
    if (order.note != null) 'note': order.note,
    if (order.clientOrderRef != null) 'client_order_ref': order.clientOrderRef,
    'is_final_consumer': order.isFinalConsumer,
    if (order.endCustomerName?.isNotEmpty == true)
      'end_customer_name': order.endCustomerName,
    if (order.endCustomerPhone?.isNotEmpty == true)
      'end_customer_phone': order.endCustomerPhone,
    if (order.endCustomerEmail?.isNotEmpty == true)
      'end_customer_email': order.endCustomerEmail,
    'emitir_factura_fecha_posterior': order.emitirFacturaFechaPosterior,
    if (order.fechaFacturar != null)
      'fecha_facturar': formatOdooDate(order.fechaFacturar!),
    if (order.referrerId != null) 'referrer_id': order.referrerId,
    if (order.tipoCliente?.isNotEmpty == true)
      'tipo_cliente': order.tipoCliente,
    if (order.canalCliente?.isNotEmpty == true)
      'canal_cliente': order.canalCliente,
  };
}
