import 'package:theos_pos_core/theos_pos_core.dart';
import '../../../core/database/datasources/datasources.dart';
import '../repositories/sales_repository.dart';
import 'order_validation_types.dart';
import 'credit_validation_ui_service.dart';
import 'sale_order_logic_engine.dart';

/// Result of order confirmation
class OrderConfirmationResult {
  final bool success;
  final String? error;
  final bool hasCreditIssue;
  final UnifiedCreditResult? creditResult;
  final SaleOrder? confirmedOrder;
  final List<SaleOrderLine>? confirmedLines;

  const OrderConfirmationResult._({
    required this.success,
    this.error,
    this.hasCreditIssue = false,
    this.creditResult,
    this.confirmedOrder,
    this.confirmedLines,
  });

  /// Confirmation succeeded
  factory OrderConfirmationResult.success({
    SaleOrder? order,
    List<SaleOrderLine>? lines,
  }) =>
      OrderConfirmationResult._(
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

  /// General error during confirmation
  factory OrderConfirmationResult.error(String error) =>
      OrderConfirmationResult._(success: false, error: error);

  /// Order queued for offline confirmation
  /// Preserves order and lines for UI to display
  factory OrderConfirmationResult.queued({
    SaleOrder? order,
    List<SaleOrderLine>? lines,
  }) =>
      OrderConfirmationResult._(
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

  final SalesRepository? _salesRepo;
  final SaleOrderLogicEngine _logicEngine;
  final CreditValidationUIService? _creditValidationService;
  final OfflineQueueDataSource? _offlineQueue;

  OrderConfirmationService({
    required SalesRepository? salesRepo,
    required SaleOrderLogicEngine logicEngine,
    required CreditValidationUIService? creditValidationService,
    OfflineQueueDataSource? offlineQueue,
  })  : _salesRepo = salesRepo,
        _logicEngine = logicEngine,
        _creditValidationService = creditValidationService,
        _offlineQueue = offlineQueue;

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

      final salesRepo = _salesRepo;
      if (salesRepo == null) {
        return OrderConfirmationResult.error('Repositorio no disponible');
      }

      // 1. Validate order structure using LogicEngine
      final validationResult = await _logicEngine.validateAction(
        order: order,
        lines: lines,
        action: OrderAction.confirm,
        context: {'skipCreditCheck': skipCreditCheck || creditBypassed},
      );

      if (!validationResult.isValid) {
        logger.w(_tag, 'Validation failed: ${validationResult.firstErrorMessage}');
        return OrderConfirmationResult.validationFailed(
          validationResult.firstErrorMessage ?? 'Validación fallida',
        );
      }

      // 2. Validate credit (unless bypassed)
      if (!skipCreditCheck && !creditBypassed && order.partnerId != null) {
        if (_creditValidationService != null) {
          final creditResult = await _creditValidationService.validateCredit(
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
      logger.d(_tag, '=== CONFIRM STEP 3: orderId=$orderId (negative means local-only) ===');
      if (orderId < 0) {
        logger.i(_tag, 'Order has local ID $orderId, syncing to Odoo first...');

        final syncResult = await _syncLocalOrder(order, lines, salesRepo);
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
        logger.d(_tag, 'CONFIRM STEP 3.5: Syncing header changes for existing order $orderId');

        final headerValues = <String, dynamic>{};

        // Always sync partner_id to ensure Odoo has the correct client
        if (order.partnerId != null) {
          headerValues['partner_id'] = order.partnerId;
        }

        // Sync other important header fields that may have changed
        if (order.paymentTermId != null) {
          headerValues['payment_term_id'] = order.paymentTermId;
        }
        if (order.pricelistId != null) {
          headerValues['pricelist_id'] = order.pricelistId;
        }
        if (order.warehouseId != null) {
          headerValues['warehouse_id'] = order.warehouseId;
        }

        // Sync final consumer fields
        if (order.isFinalConsumer) {
          headerValues['is_final_consumer'] = true;
          if (order.endCustomerName != null) {
            headerValues['end_customer_name'] = order.endCustomerName;
          }
        }

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
      final unsyncedLines = lines.where((l) => l.id < 0).toList();
      if (unsyncedLines.isNotEmpty) {
        logger.d(_tag, '=== CONFIRM STEP 3.6: Syncing ${unsyncedLines.length} unsynced lines to Odoo ===');
        final linesSynced = await salesRepo.syncOrderLinesToOdoo(orderId, lines);
        if (!linesSynced) {
          // If online and sync failed, we should not proceed with confirmation
          // The order would have no lines in Odoo
          if (salesRepo.isOnline) {
            logger.e(_tag, 'Failed to sync lines to Odoo - cannot confirm online');
            return OrderConfirmationResult.error(
              'Error al sincronizar líneas con el servidor. Intente nuevamente.',
            );
          }
          // If offline, we can proceed with offline confirmation
          logger.d(_tag, 'Lines not synced (offline) - will use offline confirmation');
        } else {
          logger.d(_tag, 'Lines synced successfully to Odoo');
        }
      }

      // 4. Confirm order
      logger.d(_tag, '=== CONFIRM STEP 4: usePosConfirm=$usePosConfirm, orderId=$orderId ===');
      if (usePosConfirm) {
        // Use POS-specific confirmation (handles credit on server side)
        try {
          logger.d(_tag, 'Attempting posConfirm for order $orderId...');
          final confirmResult = await salesRepo.posConfirm(
            orderId,
            skipCreditCheck: skipCreditCheck || creditBypassed,
          );
          logger.d(_tag, 'posConfirm returned: success=${confirmResult.success}, error=${confirmResult.error}');

          if (!confirmResult.success) {
            // Check if this is a connection error - fall back to offline
            final errorMsg = confirmResult.error ?? '';
            final isConnectionError = errorMsg.contains('Connection refused') ||
                errorMsg.contains('Connection errored') ||
                errorMsg.contains('SocketException') ||
                errorMsg.contains('Failed host lookup');

            if (isConnectionError) {
              logger.d(_tag, 'Connection error detected, trying offline confirmation...');
              final offlineSuccess = await salesRepo.confirmOffline(orderId);
              logger.d(_tag, 'confirmOffline returned: $offlineSuccess');
              if (offlineSuccess) {
                logger.d(_tag, 'Order $orderId queued for offline confirmation - SUCCESS');
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

            if (confirmResult.hasCreditIssue && confirmResult.creditIssue != null) {
              logger.d(_tag, 'Server credit issue: ${confirmResult.creditIssue!.type}');
              return OrderConfirmationResult.error(
                confirmResult.creditIssue!.message,
              );
            }
            return OrderConfirmationResult.error(
              confirmResult.error ?? 'Error al confirmar',
            );
          }
        } catch (e) {
          // Offline fallback for POS confirmation (exception case)
          logger.d(_tag, '=== POS CONFIRM EXCEPTION: $e ===');
          logger.d(_tag, 'Trying offline confirmation for order $orderId...');
          final offlineSuccess = await salesRepo.confirmOffline(orderId);
          logger.d(_tag, 'confirmOffline returned: $offlineSuccess');
          if (!offlineSuccess) {
            logger.d(_tag, 'confirmOffline FAILED for order $orderId');
            return OrderConfirmationResult.error('Error al confirmar offline');
          }
          logger.d(_tag, 'Order $orderId queued for offline confirmation - SUCCESS');
          final updatedOrder = order.copyWith(state: SaleOrderState.sale);
          return OrderConfirmationResult.queued(
            order: updatedOrder,
            lines: lines,
          );
        }
      } else {
        // Standard confirmation
        try {
          await salesRepo.confirm(orderId);
        } catch (e) {
          // Try offline confirmation if online fails
          logger.w(_tag, 'Online confirmation failed, trying offline: $e');
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
      }

      logger.i(_tag, 'Order $orderId confirmed successfully');

      // 5. Reload order with new state
      final (confirmedOrder, confirmedLines) = await salesRepo.getWithLines(
        orderId,
        forceRefresh: true,
      );

      return OrderConfirmationResult.success(
        order: confirmedOrder,
        lines: confirmedLines,
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
    return _logicEngine.validateAction(
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
    if (_creditValidationService == null) {
      return UnifiedCreditResult.notRequired();
    }
    return _creditValidationService.validateCredit(
      clientId: partnerId,
      orderAmount: orderAmount,
      skipIfBypassed: true,
      isBypassed: isBypassed,
      logTag: _tag,
    );
  }

  double _calculateOrderTotal(List<SaleOrderLine> lines) {
    return lines
        .where((l) => l.isProductLine)
        .fold(0.0, (sum, line) => sum + line.priceTotal);
  }

  Future<_SyncResult> _syncLocalOrder(
    SaleOrder order,
    List<SaleOrderLine> lines,
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

      // Check if the offline queue already synced this order.
      // If the queue processed the create, the local record would have been
      // updated with a positive Odoo ID. Since we're here with a negative ID,
      // the queue hasn't processed it yet. Remove the pending create operation
      // to avoid duplication — we'll create directly now for immediate confirmation.
      if (_offlineQueue != null) {
        final removedCount = await _offlineQueue.removeOperationsForRecord(
          'sale.order',
          order.id,
        );
        if (removedCount > 0) {
          logger.i(
            _tag,
            'Removed $removedCount pending queue operations for order ${order.id} '
            '(confirmation will create directly)',
          );
        }
      }

      // Create order in Odoo with all required fields
      final newOrderId = await salesRepo.create(
        partnerId: order.partnerId!,
        warehouseId: order.warehouseId,
        userId: order.userId,
        pricelistId: order.pricelistId,
        paymentTermId: order.paymentTermId,
        isFinalConsumer: order.isFinalConsumer,
        endCustomerName: order.endCustomerName,
      );

      if (newOrderId == null) {
        return _SyncResult(
          success: false,
          error: 'No se pudo crear la orden en el servidor',
        );
      }

      // Create lines in Odoo
      for (final line in lines) {
        if (line.isProductLine) {
          try {
            await salesRepo.addLine(
              newOrderId,
              line.copyWith(orderId: newOrderId),
            );
          } catch (e) {
            logger.w(_tag, 'Error creating line in Odoo: $e');
            // Continue with other lines
          }
        }
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
