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
  /// Contra Odoo 19.5a1+e, `fields_get` confirmó que
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
    if (paymentUuid != null && paymentUuid.isNotEmpty) {
      odooValues['payment_reference'] = 'THEOS:$paymentUuid';
    }

    // Odoo JSON-2 account.payment uses `memo`; `ref` is not accepted.
    final memo = op.values['memo'];
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

    int? remoteId;
    if (paymentUuid != null && paymentUuid.isNotEmpty) {
      final existing = await _odooClient!.searchRead(
        model: 'account.payment',
        domain: [
          ['payment_reference', '=', 'THEOS:$paymentUuid'],
        ],
        fields: ['id'],
        limit: 1,
      );
      if (existing.isNotEmpty) remoteId = existing.first['id'] as int?;
    }
    remoteId ??= await _odooClient!.create(
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
  Future<ConflictInfo?> _processInvoiceWithPayments(OfflineOperation op) async {
    if (_odooClient == null) {
      throw StateError('No hay conexión Odoo configurada para sincronizar.');
    }
    final saleId = op.values['sale_id'] as int?;
    final collectionSessionId = op.values['collection_session_id'] as int?;
    final paymentLines = op.values['payment_lines'] as List?;

    if (saleId == null) {
      throw Exception('sale_id is required for invoice_create_with_payments');
    }
    var remoteSaleId = saleId;
    if (saleId < 0) {
      final orderUuid = op.values['order_uuid'] as String?;
      final order = orderUuid == null
          ? await _orderManager.getSaleOrder(saleId)
          : await _orderManager.getSaleOrderByUuid(orderUuid);
      if (order == null || order.id <= 0) {
        throw StateError(
          'Cannot invoice until local sale $saleId has a remote ID',
        );
      }
      remoteSaleId = order.id;
    }
    final orderUuid = op.values['order_uuid'] as String?;
    final accessKey =
        (op.values['offline_access_key'] ?? op.values['access_key']) as String?;
    if (orderUuid == null || accessKey == null || accessKey.isEmpty) {
      throw StateError(
        'invoice_create_with_payments is non-retryable without '
        'order_uuid and offline_access_key idempotency marker',
      );
    }
    if (!RegExp(r'^[0-9]{49}$').hasMatch(accessKey)) {
      throw StateError('La clave fiscal offline debe contener 49 dígitos.');
    }
    final day = int.parse(accessKey.substring(0, 2));
    final month = int.parse(accessKey.substring(2, 4));
    final year = int.parse(accessKey.substring(4, 8));
    final fiscalDate = DateTime(year, month, day);
    final emissionDate =
        '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
    final sequence = int.parse(accessKey.substring(30, 39));
    if (fiscalDate.year != year ||
        fiscalDate.month != month ||
        fiscalDate.day != day ||
        sequence == 0 ||
        (op.values['sequential'] != null &&
            op.values['sequential'] != sequence) ||
        (op.values['emission_date'] != null &&
            op.values['emission_date'] != emissionDate)) {
      throw StateError(
        'La fecha o secuencia no coincide con la clave offline.',
      );
    }
    final operationUuid = op.values['client_op_uuid'] ?? orderUuid;
    if (operationUuid is! String || operationUuid.trim().isEmpty) {
      throw StateError('Falta la identidad de la operación fiscal offline.');
    }
    // A linked invoice is not proof of a completed payment. The canonical
    // wizard verifies its durable operation identity and committed retries.

    // A supervisor choosing "Mantener local" on an overpayment conflict is
    // explicit approval to continue the intermediate advance wizard. Resume
    // the stored action instead of creating a second payment wizard.
    final approvedInvoiceId = await _resumeApprovedOverpayment(
      op,
      fallbackSaleId: remoteSaleId,
    );
    if (approvedInvoiceId != null) {
      _lastInvoiceCreated = approvedInvoiceId;
      await _markOrderPaymentsAsSynced(saleId);
      return null;
    }

    logger.d(
      '[OfflineSyncService]',
      'Creating invoice with payments for sale $saleId',
    );

    final lineCommands = await adaptPaymentWizardCommands(
      _odooClient,
      _paymentWizardLineCommands(paymentLines),
    );
    final wizardResult = await _odooClient.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'create',
      kwargs: {
        'vals_list': [
          {
            'sale_id': remoteSaleId,
            'collection_session_id': ?collectionSessionId,
            'pos_client_sequential': sequence,
            'pos_emission_date': emissionDate,
            'pos_access_key': accessKey,
            'pos_client_op_uuid': operationUuid,
            if (lineCommands.isNotEmpty) 'line_ids': lineCommands,
          },
        ],
      },
    );
    final wizardId = wizardResult is List && wizardResult.isNotEmpty
        ? wizardResult.first
        : wizardResult;
    if (wizardId is! int) {
      throw StateError('Odoo did not return the payment wizard ID');
    }

    final result = await _odooClient.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'action_apply_and_create_invoice',
      ids: [wizardId],
    );

    logger.i(
      '[OfflineSyncService]',
      'Invoice created for sale $saleId: $result',
    );

    // Update local order state if needed
    if (result is! Map) {
      throw StateError('Odoo returned an invalid invoice action');
    }
    final action = Map<String, dynamic>.from(result);
    if (action['res_model'] ==
        'l10n_ec_collection_box.confirm.advance.wizard') {
      final now = DateTime.now().toUtc();
      return ConflictInfo(
        operationId: op.id,
        model: op.model,
        recordId: remoteSaleId,
        localWriteDate: op.createdAt.toUtc(),
        serverWriteDate: now,
        localValues: {
          ...op.values,
          'resolution_required': 'confirm_overpayment_advance',
        },
        serverValues: action,
      );
    }

    final invoiceId = _invoiceIdFromAction(action);
    if (invoiceId == null) {
      throw StateError('Odoo invoice action returned no account.move ID');
    }
    await _markOrderPaymentsAsSynced(saleId);
    _lastInvoiceCreated = invoiceId;
    logger.d(
      '[OfflineSyncService]',
      'Marked payments as synced for sale $saleId, invoice $invoiceId',
    );
    return null;
  }

  /// Process payment wizard operation (l10n_ec_collection_box.sale.order.payment.wizard)
  Future<ConflictInfo?> _processPaymentWizard(OfflineOperation op) async {
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

    // Wizard records are transient and have no durable idempotency key. If
    // this operation carries the same invoice marker used by the invoice
    // path, resolve an already-created invoice and do not recreate the
    // transient wizard after an indeterminate timeout.
    final wizardMarker = op.values['l10n_ec_pos_client_op_uuid'] as String?;
    if (op.method == 'action_apply_and_create_invoice' &&
        wizardMarker != null &&
        wizardMarker.isNotEmpty) {
      final existingInvoice = await _odooClient!.searchRead(
        model: 'account.move',
        domain: [
          ['l10n_ec_pos_client_op_uuid', '=', wizardMarker],
        ],
        fields: ['id'],
        limit: 1,
      );
      if (existingInvoice.isNotEmpty) {
        _lastInvoiceCreated = existingInvoice.first['id'] as int?;
        await _markOrderPaymentsAsSynced(actualSaleId);
        return null;
      }
    }

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

    lineVals = await adaptPaymentWizardCommands(_odooClient!, lineVals);

    // Create the payment wizard
    final wizardId = await _odooClient.call(
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
        ids: [actualId],
      );
      if (result is! Map) {
        throw StateError('Odoo returned an invalid payment wizard action');
      }
      final action = Map<String, dynamic>.from(result);
      if (action['res_model'] ==
          'l10n_ec_collection_box.confirm.advance.wizard') {
        final now = DateTime.now().toUtc();
        return ConflictInfo(
          operationId: op.id,
          model: op.model,
          recordId: actualSaleId,
          localWriteDate: op.createdAt.toUtc(),
          serverWriteDate: now,
          localValues: {
            ...op.values,
            'resolution_required': 'confirm_overpayment_advance',
          },
          serverValues: action,
        );
      }
      _lastInvoiceCreated = _invoiceIdFromAction(action);
      if (_lastInvoiceCreated == null) {
        throw StateError('Odoo invoice action returned no account.move ID');
      }
      await _markOrderPaymentsAsSynced(actualSaleId);
      logger.i(
        '[OfflineSyncService]',
        'Payment wizard: invoice created for sale $actualSaleId (invoice: $_lastInvoiceCreated)',
      );
    } else if (op.method == 'action_apply' ||
        op.method == OfflineLocalCommand.paymentWizardApply.storageName) {
      await _odooClient.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'action_apply',
        ids: [actualId],
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
    return null;
  }

  List<dynamic> _paymentWizardLineCommands(List? paymentLines) {
    if (paymentLines == null) return const [];
    return paymentLines
        .map((raw) {
          if (raw is List) return raw;
          if (raw is! Map) {
            throw StateError('Invalid offline payment line payload');
          }
          final values = Map<String, dynamic>.from(raw);
          values.removeWhere((_, value) => value == null);
          for (final localField in const [
            'id',
            'uuid',
            'line_uuid',
            'is_synced',
            'order_id',
            'state',
          ]) {
            values.remove(localField);
          }
          values.putIfAbsent(
            'line_type',
            () => values.containsKey('advance_id')
                ? 'advance'
                : values.containsKey('credit_note_id')
                ? 'credit_note'
                : 'payment',
          );
          return [0, 0, values];
        })
        .toList(growable: false);
  }

  int? _invoiceIdFromAction(Map<String, dynamic> action) {
    // Caja can return a print action whose continuation opens the invoice.
    // Follow only that explicit native continuation, with a bounded depth.
    for (var depth = 0; depth < 8; depth++) {
      if (action['type'] != 'ir.actions.client') break;
      final params = action['params'];
      final next = params is Map ? params['next_action'] : null;
      if (next is! Map) return null;
      action = Map<String, dynamic>.from(next);
    }
    if (action['res_model'] != 'account.move') return null;
    final resId = action['res_id'];
    if (resId is int) return resId;
    final invoiceId = action['invoice_id'];
    if (invoiceId is int) return invoiceId;
    final domain = action['domain'];
    if (domain is List) {
      for (final term in domain) {
        if (term is List &&
            term.length >= 3 &&
            term[0] == 'id' &&
            term[1] == 'in') {
          final ids = term[2];
          if (ids is List && ids.length == 1 && ids.first is int) {
            return ids.first as int;
          }
        }
      }
    }
    return null;
  }

  Future<ConflictInfo?> _processExistingInvoiceCollection(
    OfflineOperation op,
  ) async {
    final client = _odooClient;
    if (client == null) throw StateError('No hay conexión Odoo configurada.');
    final saleId = op.values['sale_id'];
    final invoiceId = op.values['invoice_id'];
    final sessionId = op.values['collection_session_id'];
    final operationUuid = op.values['collection_op_uuid'];
    final paymentLines = op.values['payment_lines'];
    final lineUuids = op.values['payment_line_uuids'];
    if (saleId is! int ||
        saleId <= 0 ||
        invoiceId is! int ||
        invoiceId <= 0 ||
        sessionId is! int ||
        sessionId <= 0 ||
        operationUuid is! String ||
        operationUuid.trim().isEmpty ||
        paymentLines is! List ||
        paymentLines.isEmpty ||
        lineUuids is! List ||
        lineUuids.length != paymentLines.length ||
        lineUuids.any((uuid) => uuid is! String || uuid.isEmpty)) {
      throw StateError(
        'El cobro requiere factura, venta y turno sincronizados e identidad durable.',
      );
    }
    final rawCommands = _paymentWizardLineCommands(paymentLines);
    for (var index = 0; index < rawCommands.length; index++) {
      final command = rawCommands[index] as List;
      final values = Map<String, dynamic>.from(command[2] as Map);
      values['pos_collection_line_uuid'] = lineUuids[index] as String;
      rawCommands[index] = [command[0], command[1], values];
    }
    final commands = await adaptPaymentWizardCommands(client, rawCommands);
    final created = await client.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'create',
      kwargs: {
        'vals_list': [
          {
            'sale_id': saleId,
            'collection_session_id': sessionId,
            'pos_existing_invoice_id': invoiceId,
            'pos_collection_op_uuid': operationUuid,
            'line_ids': commands,
          },
        ],
      },
    );
    final wizardId = created is List && created.length == 1
        ? created.single
        : created;
    if (wizardId is! int || wizardId <= 0) {
      throw StateError('Odoo no devolvió el asistente de cobro.');
    }
    final result = await client.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'action_apply_existing_invoice',
      ids: [wizardId],
    );
    if (result is! Map ||
        result['success'] != true ||
        result['operation_uuid'] != operationUuid ||
        result['invoice_id'] != invoiceId) {
      throw StateError('Odoo no acreditó la operación completa de este cobro.');
    }
    final remoteLines = result['payment_line_ids'];
    if (remoteLines is! List ||
        remoteLines.length != lineUuids.length ||
        remoteLines.any((id) => id is! int || id <= 0) ||
        remoteLines.toSet().length != remoteLines.length) {
      throw StateError('La operación no identifica todas las líneas del cobro.');
    }
    final remotePayments = result['payments'];
    if (remotePayments is! List ||
        remotePayments.length != lineUuids.length ||
        remotePayments.any(
          (item) =>
              item is! Map ||
              item['line_uuid'] is! String ||
              (item['line_uuid'] as String).isEmpty ||
              item['payment_line_id'] is! int ||
              (item['payment_line_id'] as int) <= 0 ||
              item['payment_id'] is! int ||
              (item['payment_id'] as int) <= 0 ||
              item['move_id'] is! int ||
              (item['move_id'] as int) <= 0,
        )) {
      throw StateError(
        'La operación no devuelve la contabilidad completa del cobro.',
      );
    }
    final paymentsByLineUuid = <String, Map>{};
    for (final item in remotePayments.cast<Map>()) {
      final uuid = item['line_uuid'] as String;
      if (paymentsByLineUuid.containsKey(uuid)) {
        throw StateError('Odoo devolvió una línea de cobro duplicada.');
      }
      paymentsByLineUuid[uuid] = item;
    }
    final expectedUuids = lineUuids.cast<String>().toSet();
    final metadataLineIds = remotePayments
        .cast<Map>()
        .map((item) => item['payment_line_id'] as int)
        .toSet();
    final returnedLineIds = remoteLines.cast<int>().toSet();
    if (paymentsByLineUuid.length != expectedUuids.length ||
        !paymentsByLineUuid.keys.toSet().containsAll(expectedUuids) ||
        returnedLineIds.length != metadataLineIds.length ||
        !returnedLineIds.containsAll(metadataLineIds)) {
      throw StateError('Odoo devolvió identidades ajenas a este cobro.');
    }
    final remoteResidual = result['amount_residual'];
    if (remoteResidual is! num ||
        !remoteResidual.toDouble().isFinite ||
        remoteResidual.toDouble() < 0) {
      throw StateError('Odoo devolvió un saldo de factura inválido.');
    }
    await _appDb.transaction(() async {
      for (var i = 0; i < lineUuids.length; i++) {
        final localLine =
            await (_appDb.select(_appDb.saleOrderPaymentLine)..where(
                  (row) =>
                      row.orderId.equals(saleId) &
                      row.lineUuid.equals(lineUuids[i] as String),
                ))
                .getSingleOrNull();
        if (localLine == null) {
          throw StateError('Falta la línea local del cobro.');
        }
        final paymentUuid = '$operationUuid:${lineUuids[i]}';
        final localPayment =
            await (_appDb.select(_appDb.accountPaymentTable)..where(
                  (row) =>
                      row.paymentUuid.equals(paymentUuid) &
                      row.saleId.equals(saleId) &
                      row.invoiceId.equals(invoiceId),
                ))
                .getSingleOrNull();
        if (localPayment == null) {
          throw StateError('Falta el pago local correlacionado del cobro.');
        }
        final remote = paymentsByLineUuid[lineUuids[i] as String]!;
        await (_appDb.update(_appDb.saleOrderPaymentLine)..where(
              (row) =>
                  row.orderId.equals(saleId) &
                  row.lineUuid.equals(lineUuids[i] as String),
            ))
            .write(
              SaleOrderPaymentLineCompanion(
                odooId: drift.Value(remote['payment_line_id'] as int),
                state: const drift.Value('posted'),
                isSynced: const drift.Value(true),
              ),
            );
        final paymentId = remote['payment_id'] as int;
        final updated =
            await (_appDb.update(
              _appDb.accountPaymentTable,
            )..where((row) => row.paymentUuid.equals(paymentUuid))).write(
              AccountPaymentCompanion(
                odooId: drift.Value(paymentId),
                state: const drift.Value('posted'),
                isSynced: const drift.Value(true),
                invoiceId: drift.Value(invoiceId),
              ),
            );
        if (updated != 1) {
          throw StateError('El pago local no pudo reconciliarse exactamente.');
        }
      }
    });
    return null;
  }

  Future<int?> _resumeApprovedOverpayment(
    OfflineOperation op, {
    required int fallbackSaleId,
  }) async {
    final approved =
        await (_appDb.select(_appDb.syncConflict)
              ..where(
                (row) =>
                    row.operationId.equals(op.id) &
                    row.isResolved.equals(true) &
                    row.resolution.equals('local_wins'),
              )
              ..orderBy([(row) => drift.OrderingTerm.desc(row.resolvedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (approved == null) return null;

    final wrapper = jsonDecode(approved.remoteData);
    if (wrapper is! Map) return null;
    final encodedAction = wrapper['value'];
    final decodedAction = encodedAction is String
        ? jsonDecode(encodedAction)
        : encodedAction;
    if (decodedAction is! Map) return null;
    final action = Map<String, dynamic>.from(decodedAction);
    if (action['res_model'] !=
        'l10n_ec_collection_box.confirm.advance.wizard') {
      return null;
    }
    final context = action['context'] is Map
        ? Map<String, dynamic>.from(action['context'] as Map)
        : const <String, dynamic>{};
    final paymentWizardId = context['default_payment_wizard_id'];
    if (paymentWizardId is! int) {
      throw StateError('Approved overpayment has no payment wizard ID');
    }
    final saleId = context['default_sale_id'] is int
        ? context['default_sale_id'] as int
        : fallbackSaleId;
    final rawAmount = context['default_overpayment_amount'];
    final overpaymentAmount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '');
    if (overpaymentAmount == null) {
      throw StateError('Approved overpayment has no valid amount');
    }

    final createResult = await _odooClient!.call(
      model: 'l10n_ec_collection_box.confirm.advance.wizard',
      method: 'create',
      kwargs: {
        'vals_list': [
          {
            'payment_wizard_id': paymentWizardId,
            'sale_id': saleId,
            'overpayment_amount': overpaymentAmount,
          },
        ],
      },
    );
    final confirmationId = createResult is List && createResult.isNotEmpty
        ? createResult.first
        : createResult;
    if (confirmationId is! int) {
      throw StateError('Odoo did not return the advance confirmation ID');
    }

    final result = await _odooClient.call(
      model: 'l10n_ec_collection_box.confirm.advance.wizard',
      method: 'action_create_advance',
      ids: [confirmationId],
    );
    if (result is! Map) {
      throw StateError('Odoo returned an invalid advance confirmation action');
    }
    final invoiceId = _invoiceIdFromAction(Map<String, dynamic>.from(result));
    if (invoiceId == null) {
      throw StateError('Advance confirmation returned no account.move ID');
    }
    return invoiceId;
  }

  /// Process individual payment line
  Future<void> _processPaymentLine(OfflineOperation op) async {
    final values = Map<String, dynamic>.from(op.values);
    final localId = values['local_id'] as int?;

    // Remove local-only fields
    values.remove('local_id');
    values.remove('uuid');
    values.remove('_uuid');
    values.remove(OfflineQueueDataSource.remoteCreateIdKey);

    // Resolve local IDs to remote IDs if needed
    if (values['sale_id'] != null && (values['sale_id'] as int) < 0) {
      final localSaleId = values['sale_id'] as int;
      final order = await _orderManager.getSaleOrder(localSaleId);
      if (order != null && order.id > 0) {
        values['sale_id'] = order.id;
      }
    }

    if (op.method == 'create') {
      var remoteId =
          op.values[OfflineQueueDataSource.remoteCreateIdKey] as int?;
      remoteId ??= await _findExistingSaleChildCreate(op.model, values);
      remoteId ??= await _odooClient!.create(model: op.model, values: values);
      if (remoteId == null || localId == null) {
        throw StateError(
          'Payment create has no durable local/remote ID (local=$localId, remote=$remoteId)',
        );
      }
      await _offlineQueue.persistRemoteCreateId(op.id, remoteId);
      await _reconcileSaleChildCreate(
        model: op.model,
        localId: localId,
        remoteId: remoteId,
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
    final localId = values['local_id'] as int?;

    // Remove local-only fields
    values.remove('local_id');
    values.remove('uuid');
    values.remove('_uuid');
    values.remove(OfflineQueueDataSource.remoteCreateIdKey);

    // Resolve local sale_id to remote if needed
    if (values['sale_id'] != null && (values['sale_id'] as int) < 0) {
      final localSaleId = values['sale_id'] as int;
      final order = await _orderManager.getSaleOrder(localSaleId);
      if (order != null && order.id > 0) {
        values['sale_id'] = order.id;
      }
    }

    if (op.method == 'create') {
      var remoteId =
          op.values[OfflineQueueDataSource.remoteCreateIdKey] as int?;
      remoteId ??= await _findExistingSaleChildCreate(op.model, values);
      remoteId ??= await _odooClient!.create(model: op.model, values: values);
      if (remoteId == null || localId == null) {
        throw StateError(
          'Withhold create has no durable local/remote ID (local=$localId, remote=$remoteId)',
        );
      }
      await _offlineQueue.persistRemoteCreateId(op.id, remoteId);
      await _reconcileSaleChildCreate(
        model: op.model,
        localId: localId,
        remoteId: remoteId,
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

  /// Finds the remote result of an interrupted child create before retrying.
  ///
  /// These two Odoo models do not expose the local UUID. Their complete
  /// business signature is therefore queued and used as a natural key. The UI
  /// stores one line per signature; exact duplicates are collapsed locally.
  Future<int?> _findExistingSaleChildCreate(
    String model,
    Map<String, dynamic> values,
  ) async {
    final identityFields = switch (model) {
      'sale.order.withhold.line' => const [
        'sale_id',
        'tax_id',
        'base',
        'amount',
        'taxsupport_code',
        'notes',
      ],
      'l10n_ec_collection_box.sale.order.payment' => const [
        'sale_id',
        'amount',
        'date',
        'journal_id',
        'payment_method_line_id',
        'payment_reference',
        'credit_note_id',
        'advance_id',
        'card_type',
        'card_brand_id',
        'card_deadline_id',
        'lote_id',
        'l10n_ec_bank_id',
        'bank_name_ec',
        'bank_reference_date',
        'partner_bank_id',
        'effective_date',
        'collection_session_id',
      ],
      _ => const <String>[],
    };
    if (identityFields.isEmpty || values['sale_id'] is! int) return null;

    final domain = <dynamic>[];
    for (final field in identityFields) {
      if (values.containsKey(field)) {
        domain.add([field, '=', values[field]]);
      }
    }
    final existing = await _odooClient!.searchRead(
      model: model,
      domain: domain,
      fields: const ['id'],
      order: 'id desc',
      limit: 1,
    );
    return existing.isEmpty ? null : existing.first['id'] as int?;
  }

  /// Finishes the local ID hand-off without exposing a half-synchronized row.
  Future<void> _reconcileSaleChildCreate({
    required String model,
    required int localId,
    required int remoteId,
  }) async {
    final syncedAt = DateTime.now().toUtc();
    await _appDb.transaction(() async {
      if (model == 'sale.order.withhold.line') {
        final local = await (_appDb.select(
          _appDb.saleOrderWithholdLine,
        )..where((table) => table.id.equals(localId))).getSingleOrNull();
        final remote = await (_appDb.select(
          _appDb.saleOrderWithholdLine,
        )..where((table) => table.odooId.equals(remoteId))).getSingleOrNull();
        if (local != null && remote != null && local.id != remote.id) {
          await (_appDb.delete(
            _appDb.saleOrderWithholdLine,
          )..where((table) => table.id.equals(local.id))).go();
        } else if (local != null) {
          await (_appDb.update(
            _appDb.saleOrderWithholdLine,
          )..where((table) => table.id.equals(local.id))).write(
            SaleOrderWithholdLineCompanion(
              odooId: drift.Value(remoteId),
              isSynced: const drift.Value(true),
              lastSyncDate: drift.Value(syncedAt),
            ),
          );
        }
      } else if (model == 'l10n_ec_collection_box.sale.order.payment') {
        final local = await (_appDb.select(
          _appDb.saleOrderPaymentLine,
        )..where((table) => table.id.equals(localId))).getSingleOrNull();
        final remote = await (_appDb.select(
          _appDb.saleOrderPaymentLine,
        )..where((table) => table.odooId.equals(remoteId))).getSingleOrNull();
        if (local != null && remote != null && local.id != remote.id) {
          await (_appDb.delete(
            _appDb.saleOrderPaymentLine,
          )..where((table) => table.id.equals(local.id))).go();
        } else if (local != null) {
          await (_appDb.update(
            _appDb.saleOrderPaymentLine,
          )..where((table) => table.id.equals(local.id))).write(
            SaleOrderPaymentLineCompanion(
              odooId: drift.Value(remoteId),
              isSynced: const drift.Value(true),
              lastSyncDate: drift.Value(syncedAt),
            ),
          );
        }
      }
    });
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
      domain: [
        ['payment_uuid', '=', paymentUuid],
      ],
      limit: 1,
    )).firstOrNull;
    if (existing == null) {
      logger.w(
        '[OfflineSyncService]',
        'No payment found with UUID=$paymentUuid',
      );
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
    await (db.update(
      db.saleOrderPaymentLine,
    )..where((tbl) => tbl.orderId.equals(orderId))).write(
      const SaleOrderPaymentLineCompanion(isSynced: drift.Value(true)),
    );
    logger.d(
      '[OfflineSyncService]',
      'Payments marked as synced for order $orderId',
    );
  }
}
