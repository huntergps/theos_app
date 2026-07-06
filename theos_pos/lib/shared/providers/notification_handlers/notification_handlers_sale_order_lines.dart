part of '../notification_provider.dart';

// ============================================================
// SALE ORDER LINE — WebSocket Sync Handlers
// ============================================================
//
// Extraído de notification_provider.dart (refactor de descomposición,
// plan aprobado por software-architect). Cero cambio de comportamiento:
// los métodos se movieron tal cual, solo cambia su ubicación física.

mixin _SaleOrderLineNotificationHandlers {
  /// Provisto por [NotificationCounterNotifier] (via `Notifier<T>`).
  Ref get ref;

  /// Provisto por [NotificationCounterNotifier].
  AppDatabase get _db;

  /// Handle sale order line created notification from Odoo WebSocket
  /// Creates or updates the line in local Drift database
  Future<void> _handleSaleOrderLineCreated(Map<String, dynamic> payload) async {
    try {
      final salesRepo = ref.read(salesRepositoryProvider);
      if (salesRepo == null) {
        logger.d(
          '[NotificationProvider] ⚠️ SalesRepository not available for line create',
        );
        return;
      }

      final lineId = payload['id'] as int;
      final orderId = payload['order_id'] as int;
      final lineUuid = payload['x_uuid'] is String ? payload['x_uuid'] as String : null;

      // Check if this line was created by our app (has matching UUID)
      // If so, we already have it locally - just update with remote ID
      if (lineUuid != null && lineUuid.isNotEmpty) {
        // Line was created by Flutter app - update local record with remote ID
        logger.d(
          '[NotificationProvider] 📝 Line created by app, updating local with remote ID: $lineId',
        );
      }

      // Upsert line from WebSocket payload to local database
      await _upsertSaleOrderLineFromPayload(payload);

      // NOTA: ya NO llamamos directo a
      // saleOrderFormProvider.notifier.updateLineFromWebSocket aquí — el
      // Sale Order Form (si está abierto) se actualiza reactivamente vía su
      // stream de Drift (`saleOrderLinesStreamProvider`) apenas el upsert de
      // arriba se completa (mismo fix que en _handleSaleOrderUpdated).

      // También actualizar FastSale (POS) si la orden está abierta
      final newLine = _buildSaleOrderLineFromPayload(payload);
      if (newLine != null) {
        ref.read(fastSaleProvider.notifier).updateLineFromWebSocket(newLine);
      }

      logger.d(
        '[NotificationProvider] ✅ Sale order line created: lineId=$lineId, orderId=$orderId',
      );
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling sale order line created: $e',
      );
    }
  }

  /// Handle sale order line updated notification from Odoo WebSocket
  /// Updates the line in local Drift database and form provider (granularly)
  Future<void> _handleSaleOrderLineUpdated(Map<String, dynamic> payload) async {
    try {
      final salesRepo = ref.read(salesRepositoryProvider);
      if (salesRepo == null) {
        logger.d(
          '[NotificationProvider] ⚠️ SalesRepository not available for line update',
        );
        return;
      }

      final lineId = payload['id'] as int;
      final orderId = payload['order_id'] as int;

      // Guard: ¿la línea local tiene cambios sin sincronizar (isSynced==false)?
      // Reemplaza el guard anterior basado en `dirty_fields` (ver nota
      // completa en `_handleSaleOrderUpdated`) — esa tabla nunca se poblaba
      // en producción, así que la protección era inerte. `isSynced` sí
      // refleja fielmente si hay cambios locales pendientes.
      final localLine = await (_db.select(_db.saleOrderLine)
            ..where((t) => t.odooId.equals(lineId)))
          .getSingleOrNull();

      if (localLine != null && !localLine.isSynced) {
        logger.d(
          '[NotificationProvider] ⚠️ Line $lineId has unsynced local '
          'changes — skipping WebSocket overwrite to protect local changes',
        );
        // No sobrescribir la línea. Se sincronizará cuando el usuario
        // confirme o la offline queue la envíe.
        return;
      }

      // Update line from WebSocket payload to local database
      await _upsertSaleOrderLineFromPayload(payload);

      // NOTA: ya NO llamamos directo a
      // saleOrderFormProvider.notifier.updateLineFromWebSocket aquí — el
      // Sale Order Form (si está abierto) se actualiza reactivamente vía su
      // stream de Drift (`saleOrderLinesStreamProvider`) apenas el upsert de
      // arriba se completa (mismo fix que en _handleSaleOrderUpdated).

      // También actualizar FastSale (POS) si la orden está abierta
      final updatedLine = _buildSaleOrderLineFromPayload(payload);
      if (updatedLine != null) {
        ref.read(fastSaleProvider.notifier).updateLineFromWebSocket(updatedLine);
      }

      logger.d(
        '[NotificationProvider] ✅ Sale order line updated: lineId=$lineId, orderId=$orderId',
      );
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling sale order line updated: $e',
      );
    }
  }

  /// Handle sale order line deleted notification from Odoo WebSocket
  /// Removes the line from local Drift database and form provider (granularly)
  Future<void> _handleSaleOrderLineDeleted(Map<String, dynamic> payload) async {
    try {
      final lineId = payload['id'] as int;
      final orderId = payload['order_id'] as int?;

      // Delete line from local database
      await saleOrderLineManager.deleteLocal(lineId);

      // NOTA: ya NO llamamos directo a
      // saleOrderFormProvider.notifier.removeLineFromWebSocket aquí — el
      // Sale Order Form (si está abierto) se actualiza reactivamente vía su
      // stream de Drift (`saleOrderLinesStreamProvider`) apenas el delete de
      // arriba se completa (mismo fix que en _handleSaleOrderUpdated).
      if (orderId != null) {
        // También actualizar FastSale (POS) si la orden está abierta
        ref.read(fastSaleProvider.notifier).removeLineFromWebSocket(orderId, lineId);
      }

      logger.d(
        '[NotificationProvider] ✅ Sale order line deleted: lineId=$lineId, orderId=$orderId',
      );
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling sale order line deleted: $e',
      );
    }
  }

  /// Build a SaleOrderLine model from WebSocket payload
  /// Returns null if payload is invalid
  SaleOrderLine? _buildSaleOrderLineFromPayload(Map<String, dynamic> payload) {
    try {
      final lineId = payload['id'] as int;
      final orderId = payload['order_id'] as int;
      final lineUuid = payload['x_uuid'] is String ? payload['x_uuid'] as String : null;
      final sequence = payload['sequence'] as int? ?? 10;
      final productId = payload['product_id'] as int?;
      final productName = payload['product_name'] as String?;
      final productCode = payload['product_code'] as String?;
      final name = payload['name'] as String? ?? '';
      final productUomQty =
          (payload['product_uom_qty'] as num?)?.toDouble() ?? 1.0;
      final productUomId = payload['product_uom_id'] as int?;
      final productUomName = payload['product_uom_name'] as String?;
      final priceUnit = (payload['price_unit'] as num?)?.toDouble() ?? 0.0;
      final discount = (payload['discount'] as num?)?.toDouble() ?? 0.0;
      final priceSubtotal =
          (payload['price_subtotal'] as num?)?.toDouble() ?? 0.0;
      final priceTax = (payload['price_tax'] as num?)?.toDouble() ?? 0.0;
      final priceTotal = (payload['price_total'] as num?)?.toDouble() ?? 0.0;
      final qtyDelivered =
          (payload['qty_delivered'] as num?)?.toDouble() ?? 0.0;
      final qtyInvoiced = (payload['qty_invoiced'] as num?)?.toDouble() ?? 0.0;
      final orderState = toStringOrNull(payload['state']);
      final displayTypeStr = toStringOrNull(payload['display_type']);
      final writeDateStr = toStringOrNull(payload['write_date']);

      DateTime? writeDate;
      if (writeDateStr != null) {
        writeDate = DateTime.tryParse(writeDateStr);
      }

      // Convert display_type string to enum
      LineDisplayType displayType = LineDisplayType.product;
      if (displayTypeStr != null && displayTypeStr.isNotEmpty) {
        switch (displayTypeStr) {
          case 'line_section':
            displayType = LineDisplayType.lineSection;
            break;
          case 'line_subsection':
            displayType = LineDisplayType.lineSubsection;
            break;
          case 'line_note':
            displayType = LineDisplayType.lineNote;
            break;
        }
      }

      return SaleOrderLine(
        id: lineId,
        orderId: orderId,
        lineUuid: lineUuid,
        sequence: sequence,
        productId: productId,
        productName: productName,
        productCode: productCode,
        name: name,
        productUomQty: productUomQty,
        productUomId: productUomId,
        productUomName: productUomName,
        priceUnit: priceUnit,
        discount: discount,
        priceSubtotal: priceSubtotal,
        priceTax: priceTax,
        priceTotal: priceTotal,
        qtyDelivered: qtyDelivered,
        qtyInvoiced: qtyInvoiced,
        orderState: orderState,
        displayType: displayType,
        writeDate: writeDate,
        isSynced: true,
      );
    } catch (e) {
      logger.d(
        '[NotificationProvider] Error building SaleOrderLine from payload: $e',
      );
      return null;
    }
  }

  /// Helper to upsert a sale order line from WebSocket payload to local database
  Future<void> _upsertSaleOrderLineFromPayload(
    Map<String, dynamic> payload,
  ) async {
    // Extract data from WebSocket payload (matches Odoo's _get_notification_data)
    final lineId = payload['id'] as int;
    final orderId = payload['order_id'] as int;
    final lineUuid = payload['x_uuid'] is String ? payload['x_uuid'] as String : null;
    final sequence = payload['sequence'] as int? ?? 10;
    final productId = payload['product_id'] as int?;
    final productName = payload['product_name'] as String?;
    final name = payload['name'] as String? ?? '';
    final productUomQty =
        (payload['product_uom_qty'] as num?)?.toDouble() ?? 1.0;
    final productUomId = payload['product_uom_id'] as int?;
    final productUomName = payload['product_uom_name'] as String?;
    final priceUnit = (payload['price_unit'] as num?)?.toDouble() ?? 0.0;
    final discount = (payload['discount'] as num?)?.toDouble() ?? 0.0;
    final priceSubtotal =
        (payload['price_subtotal'] as num?)?.toDouble() ?? 0.0;
    final priceTax = (payload['price_tax'] as num?)?.toDouble() ?? 0.0;
    final priceTotal = (payload['price_total'] as num?)?.toDouble() ?? 0.0;
    final qtyDelivered = (payload['qty_delivered'] as num?)?.toDouble() ?? 0.0;
    final qtyInvoiced = (payload['qty_invoiced'] as num?)?.toDouble() ?? 0.0;
    final state = toStringOrNull(payload['state']);
    final displayType = toStringOrNull(payload['display_type']);
    final writeDateStr = toStringOrNull(payload['write_date']);

    DateTime? writeDate;
    if (writeDateStr != null) {
      writeDate = DateTime.tryParse(writeDateStr);
    }

    // Use SaleOrderLineManager to upsert the line
    await saleOrderLineManager.upsertSaleOrderLineFromWebSocket(
      odooId: lineId,
      orderId: orderId,
      lineUuid: lineUuid,
      sequence: sequence,
      productId: productId,
      productName: productName,
      name: name,
      productUomQty: productUomQty,
      productUomId: productUomId,
      productUomName: productUomName,
      priceUnit: priceUnit,
      discount: discount,
      priceSubtotal: priceSubtotal,
      priceTax: priceTax,
      priceTotal: priceTotal,
      qtyDelivered: qtyDelivered,
      qtyInvoiced: qtyInvoiced,
      orderState: state,
      displayType: displayType,
      writeDate: writeDate,
    );
  }
}
