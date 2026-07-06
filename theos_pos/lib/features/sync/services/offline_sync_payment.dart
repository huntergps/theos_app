part of 'offline_sync_service.dart';

/// Sync de pagos: account.payment, wizard de pago con factura,
/// facturas SRI offline, líneas de pago/retención/anticipo.
///
/// Comparte el estado mutable [OfflineSyncService._lastInvoiceCreated]
/// (se setea en [_processPaymentWizard] y se lee desde el resultado final
/// de `_processSaleOrderQueueInternal` en offline_sync_sale_order.dart).
extension _OfflineSyncPayment on OfflineSyncService {
  // =========================================================================
  // ACCOUNT PAYMENT SYNC HANDLERS
  // =========================================================================

  /// Process account.payment CREATE operation
  ///
  /// Values expected:
  /// - local_id: int (negative ID)
  /// - payment_uuid: String (SOLO correlación local — NUNCA se envía a Odoo,
  ///   ver nota abajo)
  /// - collection_session_id: int
  /// - partner_id: int
  /// - journal_id: int
  /// - payment_method_line_id: int
  /// - amount: double
  /// - payment_type: String
  /// - payment_origin_type: String
  /// - date: String (ISO format)
  /// - memo: String? (antes 'ref' — ver nota de compatibilidad 19.5 abajo)
  ///
  /// ## Compatibilidad Odoo 19.5 (hallazgo verificado en vivo, julio 2026)
  ///
  /// Contra `erp1.tecnosmart.com.ec` (19.5a1+e), `fields_get` confirmó que
  /// `account.payment.ref` YA NO EXISTE en el servidor — el campo real es
  /// `memo` (mismo dato, otro nombre). También se confirmó que
  /// `payment_uuid` NUNCA existió como campo de `account.payment` (ni en
  /// 19.2 ni en 19.5, y no está definido en
  /// `l10n_ec_collection_box/models/account_payment.py`) — es un campo
  /// puramente local (`@OdooLocalOnly()` en `AccountPayment.paymentUuid`,
  /// ver `account_payment.model.dart`) usado sólo para correlacionar el
  /// registro local con su ID remoto después del create
  /// ([_updatePaymentIdByUuid]). Antes de este fix se enviaba igual dentro
  /// de `odooValues`, lo que habría producido "Invalid field 'payment_uuid'
  /// on model 'account.payment'" en el create() contra Odoo.
  ///
  /// Los campos de tarjeta (`card_holder_name`, `card_last_4`,
  /// `authorization_code`) y `is_cash_payment` NO se envían aquí (nunca se
  /// construyeron en este payload) — ya están marcados `@OdooLocalOnly()`
  /// en el modelo por el mismo hallazgo de compatibilidad 19.5.
  Future<void> _processPaymentCreate(OfflineOperation op) async {
    final localId = op.values['local_id'] as int?;
    final paymentUuid = op.values['payment_uuid'] as String?;

    // Build Odoo values
    final odooValues = <String, dynamic>{
      'collection_session_id': op.values['collection_session_id'],
      'partner_id': op.values['partner_id'],
      'journal_id': op.values['journal_id'],
      'payment_method_line_id': op.values['payment_method_line_id'],
      'amount': op.values['amount'],
      'payment_type': op.values['payment_type'] ?? 'inbound',
      'payment_origin_type': op.values['payment_origin_type'],
      'date': op.values['date'],
    };

    // 'memo' reemplaza a 'ref' en account.payment (eliminado en Odoo 19.5,
    // ver nota de compatibilidad arriba). El valor viene bajo la clave
    // 'memo' desde collection_repository.dart::createPaymentOffline. Se
    // acepta también la clave legacy 'ref' como fallback — operaciones
    // encoladas ANTES de este fix (ya persistidas en el OfflineQueue local
    // de un usuario, pendientes de retry) todavía traen esa clave; sin este
    // fallback esos pagos pendientes perderían silenciosamente su
    // referencia al reprocesarse tras actualizar la app.
    final memo = op.values['memo'] ?? op.values['ref'];
    if (memo != null) {
      odooValues['memo'] = memo;
    }

    // payment_uuid NUNCA se manda a Odoo — ver nota de compatibilidad
    // arriba. Sólo se usa después del create (más abajo) para actualizar el
    // registro local vía _updatePaymentIdByUuid.

    logger.d(
      '[OfflineSyncService]',
      'Creating account.payment: uuid=$paymentUuid, localId=$localId',
    );

    final remoteId = await _odooClient!.create(
      model: 'account.payment',
      values: odooValues,
    );

    if (remoteId == null) {
      throw Exception('Failed to create account.payment - returned null');
    }

    logger.d('[OfflineSyncService]', 'Payment created: $remoteId');

    // Update local payment with remote ID
    if (localId != null && paymentUuid != null) {
      await _updatePaymentIdByUuid(paymentUuid, remoteId);
      logger.d(
        '[OfflineSyncService]',
        'Updated local payment $localId -> $remoteId',
      );
    }
  }

  /// Process invoice creation with payments (offline-first)
  ///
  /// Creates a payment wizard and executes action_apply_and_create_invoice.
  /// This is used when the user saves and creates invoice while offline.
  ///
  /// Values expected:
  /// - sale_id: int (sale order ID)
  /// - collection_session_id: int? (optional)
  /// - payment_lines: List<Map> with payment line data
  ///
  /// Returns the created invoice ID if successful.
  Future<int?> _processInvoiceWithPayments(OfflineOperation op) async {
    final saleId = op.values['sale_id'] as int?;
    final collectionSessionId = op.values['collection_session_id'] as int?;
    final paymentLines = op.values['payment_lines'] as List?;

    if (saleId == null) {
      throw Exception('sale_id is required for invoice_create_with_payments');
    }

    logger.d(
      '[OfflineSyncService]',
      'Creating invoice with payments for sale $saleId',
    );

    // Prepare line values for wizard
    final lineVals = (paymentLines ?? []).map((line) {
      final lineMap = line as Map<String, dynamic>;
      return [0, 0, lineMap];
    }).toList();

    // Create the payment wizard
    final wizardId = await _odooClient!.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'create',
      kwargs: {
        'vals_list': [
          {
            'sale_id': saleId,
            'collection_session_id': ?collectionSessionId,
            'line_ids': lineVals,
          },
        ],
      },
    );

    if (wizardId == null) {
      throw Exception('Failed to create payment wizard');
    }

    // Execute action_apply_and_create_invoice
    final actualId = wizardId is List ? wizardId[0] : wizardId;
    final result = await _odooClient.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'action_apply_and_create_invoice',
      kwargs: {
        'ids': [actualId],
      },
    );

    logger.i(
      '[OfflineSyncService]',
      'Invoice created for sale $saleId: $result',
    );

    // Update local order state if needed
    int? invoiceId;
    if (result is Map && result.containsKey('res_id')) {
      invoiceId = result['res_id'] as int?;
      if (invoiceId != null) {
        // Mark local payments as synced
        await _markOrderPaymentsAsSynced(saleId);
        // Store for result feedback
        _lastInvoiceCreated = invoiceId;
        logger.d(
          '[OfflineSyncService]',
          'Marked payments as synced for sale $saleId, invoice $invoiceId',
        );
      }
    }
    return invoiceId;
  }

  /// Process SRI Offline Invoice Sync
  ///
  /// Sends the pre-generated offline invoice data (Access Key, Name, etc.) to Odoo.
  /// Requires the order to be already synced (to have a remote ID).
  ///
  /// Values expected:
  /// - order_local_id: int
  /// - order_uuid: String
  /// - access_key: String
  /// - invoice_name: String
  /// - invoice_date: String
  /// - amount_total: double
  Future<void> _processSyncOfflineInvoice(OfflineOperation op) async {
    final orderLocalId = op.values['order_local_id'] as int?;
    final orderUuid = op.values['order_uuid'] as String?;
    final accessKey = op.values['access_key'] as String?;
    final invoiceName = op.values['invoice_name'] as String?;

    if (orderLocalId == null || accessKey == null) {
      throw Exception('Missing required fields for offline invoice sync');
    }

    logger.d(
      '[OfflineSyncService]',
      'Syncing offline invoice $invoiceName (Key: $accessKey) for order $orderLocalId',
    );

    // 1. Resolve Remote Order ID
    int? remoteOrderId;
    // Check if local order has been updated with remote ID
    final order = await _orderManager.getSaleOrder(orderLocalId);
    if (order != null && order.isSynced) {
      remoteOrderId = order.id;
    } else if (orderUuid != null) {
      // Try to find by UUID in case ID link is missing
      final syncedOrder = await _orderManager.getSaleOrderByUuid(orderUuid);
      if (syncedOrder != null && syncedOrder.id > 0) {
        remoteOrderId = syncedOrder.id;
      }
    }

    if (remoteOrderId == null || remoteOrderId <= 0) {
      // Order not synced yet. Throw exception to retry later.
      // Since FIFO applies, this should happen rarely if queued after order sync.
      throw Exception(
        'Order $orderLocalId not yet synced to Odoo. Cannot sync invoice.',
      );
    }

    // 2. Call Odoo Method
    // We assume 'account.move' has a method 'action_sync_offline_invoice'
    // Payload:
    // - order_id: Remote Order ID
    // - access_key: SRI Access Key
    // - invoice_number: '001-001-000000001'
    // - invoice_date: '2023-10-25'
    // - amount_total: 100.0 (optional validation)
    final result = await _odooClient!.call(
      model: 'account.move',
      method: 'action_sync_offline_invoice',
      kwargs: {
        'vals': {
          'order_id': remoteOrderId,
          'access_key': accessKey,
          'invoice_number': invoiceName,
          'invoice_date': op.values['invoice_date'],
          'amount_total': op.values['amount_total'],
        },
      },
    );

    if (result == null || result == false) {
      throw Exception(
        'Failed to sync offline invoice (Odoo returned false/null)',
      );
    }

    logger.i(
      '[OfflineSyncService]',
      'Successfully synced offline invoice $invoiceName. Result: $result',
    );

    // Optional: Update OfflineInvoice table status to 'synced' here if needed.
    // For now, removing from queue is sufficient.
  }

  /// Process payment wizard operation (l10n_ec_collection_box.sale.order.payment.wizard)
  Future<void> _processPaymentWizard(OfflineOperation op) async {
    final saleId = op.values['sale_id'] as int?;
    final collectionSessionId = op.values['collection_session_id'] as int?;
    final paymentLines = op.values['line_ids'] ?? op.values['payment_lines'];

    if (saleId == null) {
      throw Exception('sale_id is required for payment wizard');
    }

    // Resolve local sale_id to remote if needed
    int actualSaleId = saleId;
    if (saleId < 0) {
      // Look up by parent order ID or UUID
      final order = await _orderManager.getSaleOrder(saleId);
      if (order != null && order.id > 0) {
        actualSaleId = order.id;
      } else {
        throw Exception('Cannot resolve local sale_id $saleId to remote ID');
      }
    }

    logger.d(
      '[OfflineSyncService]',
      'Processing payment wizard for sale $actualSaleId (original: $saleId)',
    );

    // Prepare line values for wizard
    List<dynamic> lineVals = [];
    if (paymentLines is List) {
      lineVals = paymentLines.map((line) {
        if (line is Map<String, dynamic>) {
          return [0, 0, line];
        }
        return line;
      }).toList();
    }

    // Create the payment wizard
    final wizardId = await _odooClient!.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'create',
      kwargs: {
        'vals_list': [
          {
            'sale_id': actualSaleId,
            'collection_session_id': ?collectionSessionId,
            if (lineVals.isNotEmpty) 'line_ids': lineVals,
          },
        ],
      },
    );

    if (wizardId == null) {
      throw Exception('Failed to create payment wizard');
    }

    // Execute the action based on method
    final actualId = wizardId is List ? wizardId[0] : wizardId;

    if (op.method == 'action_apply_and_create_invoice') {
      final result = await _odooClient.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'action_apply_and_create_invoice',
        kwargs: {
          'ids': [actualId],
        },
      );
      // Capture invoice ID from result
      if (result is Map && result.containsKey('res_id')) {
        _lastInvoiceCreated = result['res_id'] as int?;
        // Mark local payments as synced
        await _markOrderPaymentsAsSynced(actualSaleId);
      }
      logger.i(
        '[OfflineSyncService]',
        'Payment wizard: invoice created for sale $actualSaleId (invoice: $_lastInvoiceCreated)',
      );
    } else if (op.method == 'action_apply') {
      await _odooClient.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'action_apply',
        kwargs: {
          'ids': [actualId],
        },
      );
      logger.i(
        '[OfflineSyncService]',
        'Payment wizard: payments applied for sale $actualSaleId',
      );
    } else {
      // Just create was enough
      logger.i(
        '[OfflineSyncService]',
        'Payment wizard created for sale $actualSaleId (id=$actualId)',
      );
    }
  }

  /// Process individual payment line
  Future<void> _processPaymentLine(OfflineOperation op) async {
    final values = Map<String, dynamic>.from(op.values);

    // Remove local-only fields
    values.remove('local_id');
    values.remove('uuid');
    values.remove('_uuid');

    // Resolve local IDs to remote IDs if needed
    if (values['sale_id'] != null && (values['sale_id'] as int) < 0) {
      final localSaleId = values['sale_id'] as int;
      final order = await _orderManager.getSaleOrder(localSaleId);
      if (order != null && order.id > 0) {
        values['sale_id'] = order.id;
      }
    }

    if (op.method == 'create') {
      final remoteId = await _odooClient!.create(
        model: op.model,
        values: values,
      );
      logger.d('[OfflineSyncService]', 'Payment line created: $remoteId');
    } else if (op.method == 'write' && op.recordId != null) {
      await _odooClient!.write(
        model: op.model,
        ids: [op.recordId!],
        values: values,
      );
      logger.d('[OfflineSyncService]', 'Payment line updated: ${op.recordId}');
    } else if (op.method == 'unlink' && op.recordId != null) {
      try {
        await _odooClient!.unlink(model: op.model, ids: [op.recordId!]);
        logger.d(
          '[OfflineSyncService]',
          'Payment line deleted: ${op.recordId}',
        );
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('does not exist') ||
            errorStr.contains('has been deleted') ||
            errorStr.contains('missing record')) {
          throw OperationSkippedException(
            'Payment line ${op.recordId} ya no existe en Odoo',
          );
        }
        rethrow;
      }
    }
  }

  /// Process withhold line
  Future<void> _processWithholdLine(OfflineOperation op) async {
    final values = Map<String, dynamic>.from(op.values);

    // Remove local-only fields
    values.remove('local_id');
    values.remove('uuid');
    values.remove('_uuid');

    // Resolve local sale_id to remote if needed
    if (values['sale_id'] != null && (values['sale_id'] as int) < 0) {
      final localSaleId = values['sale_id'] as int;
      final order = await _orderManager.getSaleOrder(localSaleId);
      if (order != null && order.id > 0) {
        values['sale_id'] = order.id;
      }
    }

    if (op.method == 'create') {
      final remoteId = await _odooClient!.create(
        model: op.model,
        values: values,
      );
      logger.d('[OfflineSyncService]', 'Withhold line created: $remoteId');
    } else if (op.method == 'write' && op.recordId != null) {
      await _odooClient!.write(
        model: op.model,
        ids: [op.recordId!],
        values: values,
      );
      logger.d('[OfflineSyncService]', 'Withhold line updated: ${op.recordId}');
    } else if (op.method == 'unlink' && op.recordId != null) {
      try {
        await _odooClient!.unlink(model: op.model, ids: [op.recordId!]);
        logger.d(
          '[OfflineSyncService]',
          'Withhold line deleted: ${op.recordId}',
        );
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('does not exist') ||
            errorStr.contains('has been deleted') ||
            errorStr.contains('missing record')) {
          throw OperationSkippedException(
            'Withhold line ${op.recordId} ya no existe en Odoo',
          );
        }
        rethrow;
      }
    }
  }

  /// Process advance line
  Future<void> _processAdvanceLine(OfflineOperation op) async {
    final values = Map<String, dynamic>.from(op.values);

    // Remove local-only fields
    values.remove('local_id');
    values.remove('uuid');
    values.remove('_uuid');

    // Resolve local sale_id to remote if needed
    if (values['sale_id'] != null && (values['sale_id'] as int) < 0) {
      final localSaleId = values['sale_id'] as int;
      final order = await _orderManager.getSaleOrder(localSaleId);
      if (order != null && order.id > 0) {
        values['sale_id'] = order.id;
      }
    }

    if (op.method == 'create') {
      final remoteId = await _odooClient!.create(
        model: op.model,
        values: values,
      );
      logger.d('[OfflineSyncService]', 'Advance line created: $remoteId');
    } else if (op.method == 'write' && op.recordId != null) {
      await _odooClient!.write(
        model: op.model,
        ids: [op.recordId!],
        values: values,
      );
      logger.d('[OfflineSyncService]', 'Advance line updated: ${op.recordId}');
    } else if (op.method == 'unlink' && op.recordId != null) {
      try {
        await _odooClient!.unlink(model: op.model, ids: [op.recordId!]);
        logger.d(
          '[OfflineSyncService]',
          'Advance line deleted: ${op.recordId}',
        );
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('does not exist') ||
            errorStr.contains('has been deleted') ||
            errorStr.contains('missing record')) {
          throw OperationSkippedException(
            'Advance line ${op.recordId} ya no existe en Odoo',
          );
        }
        rethrow;
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Private helpers (migrated from CollectionPaymentDataSource)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Update local payment with Odoo ID after sync (by UUID)
  Future<void> _updatePaymentIdByUuid(String paymentUuid, int newOdooId) async {
    final existing = (await _paymentManager.searchLocal(
      domain: [['payment_uuid', '=', paymentUuid]],
      limit: 1,
    )).firstOrNull;
    if (existing == null) {
      logger.w('[OfflineSyncService]', 'No payment found with UUID=$paymentUuid');
      return;
    }
    final updated = existing.copyWith(
      id: newOdooId,
      isSynced: true,
      lastSyncDate: DateTime.now(),
    );
    await _paymentManager.upsertLocal(updated);
  }

  /// Mark all SaleOrderPaymentLine records for an order as synced.
  ///
  /// This operates on the SaleOrderPaymentLine table (not AccountPayment),
  /// so it uses direct Drift access rather than a manager.
  Future<void> _markOrderPaymentsAsSynced(int orderId) async {
    final db = _appDb;
    await (db.update(db.saleOrderPaymentLine)
          ..where((tbl) => tbl.orderId.equals(orderId)))
        .write(
      const SaleOrderPaymentLineCompanion(
        isSynced: drift.Value(true),
      ),
    );
    logger.d(
      '[OfflineSyncService]',
      'Payments marked as synced for order $orderId',
    );
  }
}
