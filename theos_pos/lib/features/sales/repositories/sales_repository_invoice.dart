part of 'sales_repository.dart';

/// Invoice-related operations: offline invoice creation, sequencing,
/// syncing invoices from Odoo, queueing, deletion, and regeneration.
extension SalesRepositoryInvoice on SalesRepository {
  /// Create a complete offline invoice with AccountMove and lines
  ///
  /// Called by `queueInvoiceWithPayments` after resolving the cashier's point.
  ///
  /// Returns the created invoice data or null if creation failed.
  Future<OfflineInvoiceData?> _createOfflineInvoiceWithAccountMove({
    required int orderId,
    required SaleOrder order,
    required int? collectionSessionId,
    required List<Map<String, dynamic>> paymentLines,
    String? existingInvoiceName,
    String? existingAccessKey,
  }) async {
    final appDb = _db;
    return appDb.transaction(() async {
      // Reuse a pending local invoice for this order. This prevents repeated
      // queue attempts from generating a second sequence/access key.
      final pending =
          await (appDb.select(appDb.offlineInvoice)
                ..where((t) => t.orderId.equals(orderId))
                ..where((t) => t.status.equals('pending'))
                ..limit(1))
              .getSingleOrNull();
      if (pending != null && existingInvoiceName == null) return pending;

      // The offline emission point belongs to this exact cashier session.
      // Never fall back to an arbitrary journal (or a recently synced session).
      if (collectionSessionId == null || collectionSessionId == 0) {
        throw StateError('Seleccione la sesión de caja para emitir offline.');
      }
      final session = await (appDb.select(
        appDb.collectionSession,
      )..where((t) => t.odooId.equals(collectionSessionId))).getSingleOrNull();
      if (session == null || session.companyId != order.companyId) {
        throw StateError(
          'La sesión local no corresponde a la empresa del pedido.',
        );
      }
      final config = await (appDb.select(
        appDb.collectionConfig,
      )..where((t) => t.odooId.equals(session.configId))).getSingleOrNull();
      if (config == null ||
          !config.active ||
          config.journalId == null ||
          config.companyId != order.companyId) {
        throw StateError(
          'La caja no tiene un diario de emisión offline configurado.',
        );
      }
      final journal =
          await (appDb.select(appDb.accountJournal)
                ..where((t) => t.odooId.equals(config.journalId!))
                ..where((t) => t.type.equals('sale'))
                ..where((t) => t.active.equals(true))
                ..where((t) => t.l10nEcEntity.isNotNull())
                ..where((t) => t.l10nEcEmission.isNotNull()))
              .getSingleOrNull();

      if (journal == null ||
          journal.companyId != order.companyId ||
          !journal.numberedByClient ||
          !RegExp(r'^\d{3}$').hasMatch(journal.l10nEcEntity!) ||
          !RegExp(r'^\d{3}$').hasMatch(journal.l10nEcEmission!)) {
        throw StateError(
          'Falta la configuración fiscal local del diario de esta caja.',
        );
      }

      final entity = journal.l10nEcEntity!;
      final emission = journal.l10nEcEmission!;

      // Variables for invoice name and access key
      String invoiceName;
      String accessKey;
      int? sequenceToUpdate;
      final now = DateTime.now();
      var invoiceDate = DateTime(now.year, now.month, now.day);

      // If existing invoice name provided (regeneration), reuse it
      if (existingInvoiceName != null && existingAccessKey != null) {
        invoiceName = existingInvoiceName;
        accessKey = existingAccessKey;
        // Reprinting/rebuilding must retain the original fiscal date, not the
        // date on which the device retries the operation.
        if (!RegExp(r'^\d{49}$').hasMatch(accessKey)) {
          throw StateError('La clave de acceso existente no es válida.');
        }
        final day = int.parse(accessKey.substring(0, 2));
        final month = int.parse(accessKey.substring(2, 4));
        final year = int.parse(accessKey.substring(4, 8));
        invoiceDate = DateTime(year, month, day);
        if (invoiceDate.year != year ||
            invoiceDate.month != month ||
            invoiceDate.day != day) {
          throw StateError('La fecha de la clave de acceso no es válida.');
        }
        logger.d(
          '[SalesRepository]',
          'Reusing existing invoice name: $invoiceName',
        );
      } else {
        // 2. Get correct sequence considering existing Odoo invoices
        final nextSequence = await _getNextInvoiceSequence(journal);
        sequenceToUpdate = nextSequence;

        // 3. Generate invoice name and access key
        invoiceName = SRIKeyGenerator.generateInvoiceName(
          entity: entity,
          emission: emission,
          sequence: nextSequence,
        );

        // Match l10n_ec_edi.account.move._l10n_ec_set_authorization_number:
        // issuer VAT (res.company.vat mirrors company.partner_id.vat), company
        // environment and the persisted invoice date. All are local data.
        final companyId = order.companyId;
        final company = companyId == null
            ? null
            : await companyManager.readLocal(companyId);
        final ruc = company?.vat;
        if (company == null ||
            ruc == null ||
            !RegExp(r'^\d{13}$').hasMatch(ruc)) {
          throw StateError(
            'Falta la configuración fiscal local de la empresa emisora. '
            'No se puede emitir una factura con un RUC o ambiente supuesto.',
          );
        }
        final sriEnvironment = company.l10nEcProductionEnv ? '2' : '1';

        accessKey = SRIKeyGenerator.generateAccessKey(
          date: invoiceDate,
          documentType: '01', // Factura
          ruc: ruc,
          environment: sriEnvironment,
          emissionType: '1',
          invoiceName: invoiceName,
        );
      }

      final invoiceUuid = _uuid.v4();

      // PaymentLine.amount is the applied amount, including advances and
      // credit notes, not cash tendered. Withholdings are persisted separately.
      var appliedAmount = 0.0;
      for (final line in paymentLines) {
        final amount = line['amount'];
        if (amount is! num || !amount.isFinite || amount < 0) {
          throw StateError('El importe aplicado de un pago no es válido.');
        }
        appliedAmount += amount.toDouble();
      }
      final withholds = await (appDb.select(
        appDb.saleOrderWithholdLine,
      )..where((t) => t.orderId.equals(orderId))).get();
      for (final line in withholds) {
        if (!line.amount.isFinite || line.amount < 0) {
          throw StateError('El importe de una retención no es válido.');
        }
        appliedAmount += line.amount;
      }
      final currencyId = order.currencyId ?? journal.currencyId;
      final currency = currencyId == null
          ? null
          : await (appDb.select(
              appDb.resCurrency,
            )..where((t) => t.odooId.equals(currencyId))).getSingleOrNull();
      final rounding = MoneyRounding(precision: currency?.rounding ?? 0.01);
      final remaining = rounding.round(order.amountTotal - appliedAmount);
      final residual = remaining < 0 ? 0.0 : remaining;
      final paymentState = rounding.isZero(residual)
          ? 'paid'
          : appliedAmount > 0
          ? 'partial'
          : 'not_paid';

      // Extract sequence number from invoice name (format: 001-001-000000123)
      final sequenceNumber =
          sequenceToUpdate ?? int.tryParse(invoiceName.split('-').last) ?? 0;

      // 4. Store Offline Invoice record
      await appDb
          .into(appDb.offlineInvoice)
          .insert(
            OfflineInvoiceCompanion(
              uuid: drift.Value(invoiceUuid),
              orderId: drift.Value(orderId),
              orderName: drift.Value(order.name),
              invoiceName: drift.Value(invoiceName),
              accessKey: drift.Value(accessKey),
              sequenceNumber: drift.Value(sequenceNumber),
              documentType: const drift.Value('01'),
              invoiceDate: drift.Value(invoiceDate),
              partnerId: drift.Value(order.partnerId ?? 0),
              amountTotal: drift.Value(order.amountTotal),
              status: const drift.Value('pending'),
              invoiceType: const drift.Value('out_invoice'),
              invoiceData: drift.Value(
                jsonEncode({
                  'order_uuid': order.orderUuid,
                  'invoice_name': invoiceName,
                  'access_key': accessKey,
                  'amount_total': order.amountTotal,
                }),
              ),
              createdAt: drift.Value(now),
            ),
          );

      // 5. Create AccountMove for printing (negative odooId indicates offline)
      final offlineMoveOdooId = InvoiceRepository.offlineMoveIdForOrder(
        orderId,
      );
      await appDb
          .into(appDb.accountMove)
          .insert(
            AccountMoveCompanion(
              odooId: drift.Value(offlineMoveOdooId),
              name: drift.Value(invoiceName),
              moveType: const drift.Value('out_invoice'),
              l10nEcAuthorizationNumber: drift.Value(accessKey),
              l10nLatamDocumentNumber: drift.Value(invoiceName),
              l10nLatamDocumentTypeId: const drift.Value(1),
              l10nLatamDocumentTypeName: const drift.Value('Factura'),
              l10nEcSriPaymentName: const drift.Value(
                'Sin utilización del sistema financiero',
              ),
              state: const drift.Value('posted'),
              paymentState: drift.Value(paymentState),
              invoiceDate: drift.Value(invoiceDate),
              invoiceDateDue: drift.Value(now),
              date: drift.Value(now),
              partnerId: drift.Value(order.partnerId),
              partnerName: drift.Value(order.partnerName),
              partnerVat: drift.Value(order.partnerVat),
              journalId: drift.Value(journal.odooId),
              journalName: drift.Value(journal.name),
              amountUntaxed: drift.Value(order.amountUntaxed),
              amountTax: drift.Value(order.amountTax),
              amountTotal: drift.Value(order.amountTotal),
              amountResidual: drift.Value(residual),
              companyId: drift.Value(order.companyId),
              currencyId: drift.Value(order.currencyId),
              invoiceOrigin: drift.Value(order.name),
              saleOrderId: drift.Value(orderId),
              lastSyncDate: drift.Value(now),
            ),
          );

      // 6. Create AccountMoveLines from order lines
      final orderLines = await _lineManager.getSaleOrderLines(orderId);
      int lineSequence = 10;
      for (final line in orderLines) {
        if (line.displayType != LineDisplayType.product) continue;

        String? barcode;
        if (line.productId != null) {
          final product = await _productRepository?.getById(line.productId!);
          barcode = product?.barcode;
        }

        await appDb
            .into(appDb.accountMoveLine)
            .insert(
              AccountMoveLineCompanion(
                odooId: drift.Value(-line.id),
                moveId: drift.Value(offlineMoveOdooId),
                name: drift.Value(line.name),
                displayType: const drift.Value('product'),
                sequence: drift.Value(lineSequence),
                productId: drift.Value(line.productId),
                productName: drift.Value(line.productName),
                productCode: drift.Value(line.productCode),
                productBarcode: drift.Value(barcode),
                quantity: drift.Value(line.productUomQty),
                productUomId: drift.Value(line.productUomId),
                productUomName: drift.Value(line.productUomName),
                priceUnit: drift.Value(line.priceUnit),
                discount: drift.Value(line.discount),
                priceSubtotal: drift.Value(line.priceSubtotal),
                priceTotal: drift.Value(line.priceTotal),
                taxIds: drift.Value(line.taxIds),
                taxNames: drift.Value(line.taxNames),
                lastSyncDate: drift.Value(now),
              ),
            );
        lineSequence += 10;
      }

      // 7. Update journal sequence (only for new invoices, not regeneration)
      if (sequenceToUpdate != null) {
        await (appDb.update(
          appDb.accountJournal,
        )..where((t) => t.id.equals(journal.id))).write(
          AccountJournalCompanion(
            lastInvoiceSequence: drift.Value(sequenceToUpdate),
          ),
        );
      }

      logger.i(
        '[SalesRepository]',
        'Created offline invoice $invoiceName with ${orderLines.where((l) => l.displayType == LineDisplayType.product).length} lines',
      );

      // AccountMove records are created above; OfflineInvoiceData is read
      // separately via InvoiceRepository.getOfflineInvoice() when needed.
      final created = await (appDb.select(
        appDb.offlineInvoice,
      )..where((t) => t.uuid.equals(invoiceUuid))).getSingleOrNull();
      return created;
    });
  }

  /// Get the next invoice sequence number for a given entity/emission
  ///
  /// This considers BOTH:
  /// 1. The journal's lastInvoiceSequence
  /// 2. The MAX sequence from existing account_move records (synced from Odoo)
  ///
  /// This local high-water mark does not replace exclusive emission ownership.
  Future<int> _getNextInvoiceSequence(AccountJournalData journal) async {
    final appDb = _db;
    final journalSequence = journal.lastInvoiceSequence;

    // 2. Get MAX sequence from existing invoices in account_move
    // Invoice names follow pattern: "Fact 001-001-000000007" or "001-001-000000007"
    final prefix = '${journal.l10nEcEntity}-${journal.l10nEcEmission}-';
    final invoices =
        await (appDb.select(appDb.accountMove)
              ..where((t) => t.moveType.equals('out_invoice'))
              ..where((t) => t.journalId.equals(journal.odooId))
              ..where((t) => t.name.contains(prefix)))
            .get();

    int maxExistingSequence = 0;
    for (final invoice in invoices) {
      final name = invoice.name;
      if (name == null) continue;
      // Extract sequence number from name like "Fact 001-001-000000007" or "001-001-000000007"
      final match = RegExp(r'(\d{3})-(\d{3})-(\d+)$').firstMatch(name);
      if (match != null) {
        final seq = int.tryParse(match.group(3) ?? '0') ?? 0;
        if (seq > maxExistingSequence) {
          maxExistingSequence = seq;
        }
      }
    }

    // 3. Return MAX of both + 1
    final baseSequence = journalSequence > maxExistingSequence
        ? journalSequence
        : maxExistingSequence;

    logger.d(
      '[SalesRepository]',
      'Next sequence for $prefix: journal=$journalSequence, '
          'maxExisting=$maxExistingSequence, next=${baseSequence + 1}',
    );

    return baseSequence + 1;
  }

  /// Sync invoices and their lines for a specific order
  ///
  /// This fetches invoices linked to the order from Odoo and saves them to local DB
  /// with their lines. Similar to how payment lines are synced.
  /// PUBLIC for use by providers (like syncPaymentLinesFromOdoo)
  ///
  /// [forceRefresh]: If true, always fetch from Odoo. If false (default), only fetch
  /// if data is not available locally (incremental sync).
  Future<void> syncInvoicesForOrder(
    int orderId, {
    bool forceRefresh = false,
  }) async {
    if (!_orderManager.isOnline) return;

    try {
      // Get order data from local DB to check invoice_ids
      final appDb = _db;
      final orderData = await (appDb.select(
        appDb.saleOrder,
      )..where((t) => t.odooId.equals(orderId))).getSingleOrNull();

      if (orderData == null) {
        logger.d(
          '[SalesRepository] Order $orderId not found locally, skipping invoice sync',
        );
        return;
      }

      // Note: invoiceIds field removed from SaleOrder table
      // Get invoices from Odoo
      List<int>? invoiceIds;
      {
        try {
          final orderDataFromOdoo = await _orderManager.client.searchRead(
            model: 'sale.order',
            fields: ['invoice_ids'],
            domain: [
              ['id', '=', orderId],
            ],
            limit: 1,
          );

          if (orderDataFromOdoo.isNotEmpty) {
            final invoiceIdsFromOdoo =
                orderDataFromOdoo.first['invoice_ids'] as List<dynamic>?;
            if (invoiceIdsFromOdoo != null && invoiceIdsFromOdoo.isNotEmpty) {
              invoiceIds = invoiceIdsFromOdoo.cast<int>();
            }
          }
        } catch (e) {
          logger.w(
            '[SalesRepository] Failed to fetch invoice_ids from Odoo for order $orderId: $e',
          );
        }
      }

      if (invoiceIds == null || invoiceIds.isEmpty) {
        logger.d('[SalesRepository] No invoices found for order $orderId');
        return;
      }

      // Use InvoiceRepository to sync invoices with their lines
      // F5: InvoiceRepository ya no recibe OdooClient (usa managers
      // internamente).
      final invoiceRepository = InvoiceRepository(
        productRepository: _productRepository,
        appDb: _db,
      );

      // Fetch invoices by IDs (uses forceRefresh parameter for incremental vs full sync)
      // forceRefresh=false: only fetch from Odoo if not in local cache (incremental)
      // forceRefresh=true: always fetch from Odoo (manual refresh)
      await invoiceRepository.getInvoicesByIds(
        invoiceIds,
        forceRefresh: forceRefresh,
        saleOrderId: orderId,
      );

      logger.i(
        '[SalesRepository] ${forceRefresh ? "Synced" : "Loaded"} ${invoiceIds.length} invoices for order $orderId',
      );
    } catch (e) {
      logger.w(
        '[SalesRepository] Error syncing invoices for order $orderId: $e',
      );
      // Don't throw - invoice sync failure shouldn't break order loading
    }
  }

  /// Queue invoice creation with payments for offline processing
  ///
  /// This is used when the user tries to create an invoice while offline.
  /// Creates an offline invoice with SRI access key and queues for sync.
  /// The operation will be processed when connection is restored.
  ///
  /// Returns the offline invoice data if created, null otherwise.
  ///
  /// [existingInvoiceName] and [existingAccessKey] can be provided when
  /// regenerating an invoice to preserve the original invoice number.
  Future<OfflineInvoiceData?> queueInvoiceWithPayments({
    required int saleOrderId,
    required List<Map<String, dynamic>> paymentLines,
    int? collectionSessionId,
    String? existingInvoiceName,
    String? existingAccessKey,
  }) => _db.transaction(
    () => _queueInvoiceWithPayments(
      saleOrderId: saleOrderId,
      paymentLines: paymentLines,
      collectionSessionId: collectionSessionId,
      existingInvoiceName: existingInvoiceName,
      existingAccessKey: existingAccessKey,
    ),
  );

  // The invoice, sequence and outbox must survive together or roll back
  // together. A disk failure must never leave a printed-number candidate
  // without the command that will synchronize it.
  Future<OfflineInvoiceData?> _queueInvoiceWithPayments({
    required int saleOrderId,
    required List<Map<String, dynamic>> paymentLines,
    int? collectionSessionId,
    String? existingInvoiceName,
    String? existingAccessKey,
  }) async {
    if (_offlineQueue == null) {
      logger.e('[SalesRepository]', 'Offline queue not available');
      return null;
    }

    // 1. Get order data for invoice generation
    final order = await _orderManager.getSaleOrder(saleOrderId);
    if (order == null) {
      logger.e('[SalesRepository]', 'Order $saleOrderId not found locally');
      return null;
    }
    if (order.orderUuid == null || order.orderUuid!.isEmpty) {
      logger.e(
        '[SalesRepository]',
        'Order $saleOrderId has no durable UUID; refusing unsafe invoice queue',
      );
      return null;
    }

    // 2. Generate offline invoice with SRI access key (Ecuador)
    // Uses unified method for consistent invoice creation
    // If existingInvoiceName is provided, reuse it (for regeneration)
    OfflineInvoiceData? offlineInvoice;
    try {
      offlineInvoice = await _createOfflineInvoiceWithAccountMove(
        orderId: saleOrderId,
        order: order,
        collectionSessionId: collectionSessionId,
        paymentLines: paymentLines,
        existingInvoiceName: existingInvoiceName,
        existingAccessKey: existingAccessKey,
      );
    } catch (e) {
      logger.e('[SalesRepository]', 'SRI invoice generation failed: $e');
      return null;
    }

    if (offlineInvoice == null ||
        offlineInvoice.accessKey == null ||
        offlineInvoice.accessKey!.isEmpty ||
        offlineInvoice.invoiceName == null ||
        offlineInvoice.invoiceDate == null) {
      logger.e(
        '[SalesRepository]',
        'Offline invoice has no durable fiscal identity; refusing unsafe queue',
      );
      return null;
    }

    final appDb = _db;

    final existingQueued = await _offlineQueue.getOperationsForSaleOrder(
      saleOrderId,
    );
    if (existingQueued.any(
      (op) => op.method == 'invoice_create_with_payments',
    )) {
      logger.d(
        '[SalesRepository]',
        'Invoice operation already queued for sale $saleOrderId',
      );
      return offlineInvoice;
    }

    // 3. Queue the operation for sync
    await _offlineQueue.queueCommand(
      model: 'sale.order',
      command: OfflineLocalCommand.invoiceCreateWithPayments,
      values: {
        'sale_id': saleOrderId,
        'order_uuid': order.orderUuid!,
        'collection_session_id': collectionSessionId,
        'payment_lines': paymentLines,
        'offline_access_key': offlineInvoice.accessKey!,
        'client_op_uuid': offlineInvoice.uuid,
        'offline_invoice_name': offlineInvoice.invoiceName!,
        'sequential': offlineInvoice.sequenceNumber,
        'emission_date': offlineInvoice.invoiceDate!
            .toIso8601String()
            .split('T')
            .first,
      },
      parentOrderId: saleOrderId,
    );

    // 4. Mark order as having a queued invoice - prevents modifying payments/withholds
    await (appDb.update(appDb.saleOrder)
          ..where((t) => t.odooId.equals(saleOrderId)))
        .write(const SaleOrderCompanion(hasQueuedInvoice: drift.Value(true)));

    logger.i(
      '[SalesRepository] Invoice creation queued for sale $saleOrderId with ${paymentLines.length} payments'
      ' (offline invoice: ${offlineInvoice.invoiceName})',
    );

    return offlineInvoice;
  }
}
