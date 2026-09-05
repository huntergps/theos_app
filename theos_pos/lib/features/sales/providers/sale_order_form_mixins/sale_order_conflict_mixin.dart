import 'package:theos_pos_core/theos_pos_core.dart';

import '../../services/conflict_detection_service.dart';
import '../sale_order_form_state.dart';

/// Stages changes observed through the local Drift streams while an order is
/// being edited and resolves conflicts without discarding unrelated edits.
///
/// Remote refreshes write to the local database first. The form then receives
/// the new order through `saleOrderStreamProvider` and either applies it
/// directly in view mode or stores it until editing finishes.
mixin SaleOrderConflictMixin {
  /// Estado actual del formulario - debe ser implementado por el notifier
  SaleOrderFormState get state;

  /// Metodo para actualizar estado - debe ser implementado por el notifier
  set state(SaleOrderFormState newState);

  /// Implementado por [SaleOrderUtilityMixin]
  void updateOrderFromSync(SaleOrder order, List<SaleOrderLine> lines);

  /// Implementado por [SaleOrderUtilityMixin]
  Future<void> refreshOrder();

  /// Implementado por [SaleOrderLoaderMixin]
  Future<void> loadOrder(int orderId, {bool forceRefresh = false});

  // ===========================================================================
  // Canal A: staging de updates pendientes (streams de Drift)
  // ===========================================================================

  /// Mark that a server update arrived while in edit mode.
  ///
  /// Stores the pending data so it can be applied later (when the user
  /// clicks the sync indicator or exits edit mode).
  void setServerUpdatePending(SaleOrder order, List<SaleOrderLine>? lines) {
    logger.i(
      '[SaleOrderForm]',
      'Server update pending for order ${order.id} (user is editing)',
    );
    state = state.copyWith(
      serverUpdatePending: true,
      pendingServerOrder: order,
      pendingServerLines: lines,
    );
  }

  /// Apply the pending server update with fine-grained field merging.
  ///
  /// Called when the user clicks the pending-update indicator, or
  /// automatically when exiting edit mode.
  ///
  /// **Merge strategy:**
  /// - View mode (not editing): full overwrite via [updateOrderFromSync]
  /// - Edit mode, no conflicts: auto-merge server-changed fields that the
  ///   user did NOT touch
  /// - Edit mode, conflicts: set conflict state for UI resolution AND
  ///   auto-merge the non-conflicting fields
  void applyPendingServerUpdate() {
    final pendingOrder = state.pendingServerOrder;
    if (pendingOrder == null) {
      clearServerUpdatePending();
      return;
    }

    logger.i(
      '[SaleOrderForm]',
      'Applying pending server update for order ${pendingOrder.id}',
    );

    final pendingLines = state.pendingServerLines ?? state.lines;

    if (!state.isEditing) {
      // View mode: full overwrite (no conflicts possible)
      updateOrderFromSync(pendingOrder, pendingLines);
      clearServerUpdatePending();
      return;
    }

    // ---- Edit mode: detect conflicts on order header ----
    final result = conflictDetectionService.detectOrderConflicts(
      localOrder: state.order!,
      serverOrder: pendingOrder,
      changedFields: state.changedFields,
    );

    if (result.hasConflicts) {
      // Both the conflict service and form state use the canonical
      // ConflictDetail from base_order_state.dart.
      final stateConflicts = <String, ConflictDetail>{
        for (final conflict in result.conflicts) conflict.fieldName: conflict,
      };
      state = state.copyWith(
        hasConflict: true,
        conflicts: stateConflicts,
        conflictMessage: result.conflictMessage,
      );
      logger.w(
        '[SaleOrderForm]',
        'Conflicts detected: ${result.conflictingFieldNames}',
      );
    }

    // Auto-merge non-conflicting header fields
    if (result.mergeableFields.isNotEmpty) {
      _applyMergeableFields(result.mergeableFields);
    }

    // ---- Line merging ----
    _applyPendingLinesMerge(pendingLines);

    clearServerUpdatePending();
  }

  /// Apply mergeable (non-conflicting) server field values to local state.
  ///
  /// Each key is the snake_case Odoo field name; the value comes straight
  /// from the server order via [ConflictDetectionService].
  void _applyMergeableFields(Map<String, dynamic> fields) {
    if (fields.isEmpty) return;

    logger.d(
      '[SaleOrderForm]',
      'Auto-merging ${fields.length} server fields: ${fields.keys}',
    );

    // Build a partial copyWith with only the mergeable fields.
    int? partnerId = state.partnerId;
    int? pricelistId = state.pricelistId;
    String? pricelistName = state.pricelistName;
    int? paymentTermId = state.paymentTermId;
    String? paymentTermName = state.paymentTermName;
    int? warehouseId = state.warehouseId;
    String? warehouseName = state.warehouseName;
    int? userId = state.userId;
    String? userName = state.userName;
    DateTime? dateOrder = state.dateOrder;
    DateTime? commitmentDate = state.commitmentDate;
    String? note = state.note;
    String? partnerPhone = state.partnerPhone;
    String? partnerEmail = state.partnerEmail;
    String? endCustomerName = state.endCustomerName;
    String? endCustomerPhone = state.endCustomerPhone;
    String? endCustomerEmail = state.endCustomerEmail;

    for (final entry in fields.entries) {
      switch (entry.key) {
        case 'partner_id':
          partnerId = entry.value as int?;
          break;
        case 'pricelist_id':
          pricelistId = entry.value as int?;
          // Try to resolve name from selection data
          if (pricelistId != null && state.pricelists.isNotEmpty) {
            final found = state.pricelists.firstWhere(
              (pl) => pl['id'] == pricelistId,
              orElse: () => <String, dynamic>{},
            );
            if (found.isNotEmpty) pricelistName = found['name'] as String?;
          }
          break;
        case 'payment_term_id':
          paymentTermId = entry.value as int?;
          if (paymentTermId != null && state.paymentTerms.isNotEmpty) {
            final found = state.paymentTerms.firstWhere(
              (pt) => pt['id'] == paymentTermId,
              orElse: () => <String, dynamic>{},
            );
            if (found.isNotEmpty) paymentTermName = found['name'] as String?;
          }
          break;
        case 'warehouse_id':
          warehouseId = entry.value as int?;
          if (warehouseId != null && state.warehouses.isNotEmpty) {
            final found = state.warehouses.firstWhere(
              (w) => w['id'] == warehouseId,
              orElse: () => <String, dynamic>{},
            );
            if (found.isNotEmpty) warehouseName = found['name'] as String?;
          }
          break;
        case 'user_id':
          userId = entry.value as int?;
          if (userId != null && state.salespeople.isNotEmpty) {
            final found = state.salespeople.firstWhere(
              (s) => s['id'] == userId,
              orElse: () => <String, dynamic>{},
            );
            if (found.isNotEmpty) userName = found['name'] as String?;
          }
          break;
        case 'date_order':
          dateOrder = entry.value as DateTime?;
          break;
        case 'commitment_date':
          commitmentDate = entry.value as DateTime?;
          break;
        case 'note':
          note = entry.value as String?;
          break;
        case 'partner_phone':
          partnerPhone = entry.value as String?;
          break;
        case 'partner_email':
          partnerEmail = entry.value as String?;
          break;
        case 'end_customer_name':
          endCustomerName = entry.value as String?;
          break;
        case 'end_customer_phone':
          endCustomerPhone = entry.value as String?;
          break;
        case 'end_customer_email':
          endCustomerEmail = entry.value as String?;
          break;
      }
    }

    state = state.copyWith(
      partnerId: partnerId,
      pricelistId: pricelistId,
      pricelistName: pricelistName,
      paymentTermId: paymentTermId,
      paymentTermName: paymentTermName,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      userId: userId,
      userName: userName,
      dateOrder: dateOrder,
      commitmentDate: commitmentDate,
      note: note,
      partnerPhone: partnerPhone,
      partnerEmail: partnerEmail,
      endCustomerName: endCustomerName,
      endCustomerPhone: endCustomerPhone,
      endCustomerEmail: endCustomerEmail,
    );
  }

  /// Merge pending server lines into local state.
  ///
  /// - If user has NOT modified any lines, apply server lines directly.
  /// - If user HAS modified lines, use [ConflictDetectionService] to detect
  ///   line-level conflicts and only flag those that actually conflict.
  void _applyPendingLinesMerge(List<SaleOrderLine> serverLines) {
    final hasLocalLineChanges =
        state.updatedLines.isNotEmpty ||
        state.deletedLineIds.isNotEmpty ||
        state.newLines.isNotEmpty;

    if (!hasLocalLineChanges) {
      // No local line modifications — safe to apply server lines directly
      logger.d(
        '[SaleOrderForm]',
        'No local line changes, applying ${serverLines.length} server lines',
      );
      state = state.copyWith(lines: serverLines);
      return;
    }

    // User has modified lines — detect per-line conflicts
    final modifiedLineIds = <int>{
      ...state.updatedLines.map((l) => l.id),
      ...state.deletedLineIds,
    };

    final lineResults = conflictDetectionService.detectLineConflicts(
      localLines: state.lines,
      serverLines: serverLines,
      modifiedLineIds: modifiedLineIds,
    );

    // Check if any line has conflicts
    final hasLineConflicts = lineResults.values.any((r) => r.hasConflicts);

    if (hasLineConflicts) {
      // Add line conflicts to the existing conflict state
      final conflictMessages = <String>[];
      for (final entry in lineResults.entries) {
        if (entry.value.hasConflicts) {
          conflictMessages.add(
            'Línea ${entry.key}: ${entry.value.conflictMessage}',
          );
        }
      }

      final existingMessage = state.conflictMessage ?? '';
      final lineMessage = conflictMessages.join('; ');
      final combinedMessage = existingMessage.isEmpty
          ? lineMessage
          : '$existingMessage\n$lineMessage';

      state = state.copyWith(
        hasConflict: true,
        conflictMessage: combinedMessage,
      );

      logger.w(
        '[SaleOrderForm]',
        'Line conflicts detected: ${conflictMessages.length} lines',
      );
    } else {
      // No line conflicts — apply non-modified server lines
      // Keep locally modified lines, update the rest from server
      final serverLineMap = {for (var l in serverLines) l.id: l};
      final mergedLines = <SaleOrderLine>[];

      for (final line in state.lines) {
        if (modifiedLineIds.contains(line.id)) {
          // Keep local version of modified lines
          mergedLines.add(line);
        } else if (serverLineMap.containsKey(line.id)) {
          // Use server version of non-modified lines
          mergedLines.add(serverLineMap[line.id]!);
        } else {
          // Line exists locally but not on server (deleted on server)
          // Keep it — user didn't delete it locally
          mergedLines.add(line);
        }
      }

      // Add new server lines that don't exist locally
      for (final serverLine in serverLines) {
        if (!state.lines.any((l) => l.id == serverLine.id)) {
          mergedLines.add(serverLine);
        }
      }

      state = state.copyWith(lines: mergedLines);
      logger.d('[SaleOrderForm]', 'Lines merged: ${mergedLines.length} total');
    }
  }

  /// Clear the pending flag without applying (e.g., user dismissed it).
  ///
  /// FASE F2: antes existían DOS métodos con el cuerpo idéntico —
  /// `clearServerUpdatePending()` (público, usado por el botón de cerrar en
  /// `sale_order_form_screen.dart`) y `_clearPendingState()` (privado, usado
  /// 2x dentro de `applyPendingServerUpdate`). Se fusionaron en este único
  /// método — `applyPendingServerUpdate()` ahora llama directo acá.
  void clearServerUpdatePending() {
    state = state.copyWith(
      serverUpdatePending: false,
      pendingServerOrder: null,
      pendingServerLines: null,
    );
  }

  /// Resolver conflicto aceptando cambios del servidor
  ///
  /// Consumido directamente por `ConflictBanner.onAcceptServer` en
  /// `sale_order_form_screen.dart`.
  Future<void> acceptServerChanges() async {
    if (state.order == null) return;

    logger.d('[SaleOrderForm]', 'Accepting server changes');

    // Limpiar cambios locales en los campos en conflicto
    final newChangedFields = Map<String, dynamic>.from(state.changedFields);
    for (final conflictField in state.conflicts?.keys ?? <String>[]) {
      newChangedFields.remove(conflictField);
    }

    // Refrescar desde servidor
    await loadOrder(state.order!.id, forceRefresh: true);

    state = state.copyWith(
      changedFields: newChangedFields,
      hasConflict: false,
      conflicts: null,
      conflictMessage: null,
      hasChanges: newChangedFields.isNotEmpty,
    );
  }

  /// Resolver conflicto manteniendo cambios locales (para volver a guardar)
  ///
  /// Consumido directamente por `ConflictBanner.onKeepLocal` en
  /// `sale_order_form_screen.dart`.
  void keepLocalChanges() {
    logger.d('[SaleOrderForm]', 'Keeping local changes, user will re-save');
    state = state.copyWith(
      hasConflict: false,
      conflicts: null,
      conflictMessage: null,
    );
  }

  /// Limpiar estado de conflicto
  ///
  /// Consumido directamente desde `form_header.dart`.
  void clearConflict() {
    state = state.copyWith(
      hasConflict: false,
      conflicts: null,
      conflictMessage: null,
    );
  }

  // ===========================================================================
  // Utilidades varias (agrupadas acá desde la Fase E2b original)
  // ===========================================================================

  /// Limpiar error
  ///
  /// Consumido directamente desde `sale_order_form_screen.dart`.
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
