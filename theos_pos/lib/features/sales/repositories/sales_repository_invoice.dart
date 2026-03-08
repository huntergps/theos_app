part of 'sales_repository.dart';

/// Invoice-related operations: offline invoice creation, sequencing,
/// syncing invoices from Odoo, queueing, deletion, and regeneration.
extension SalesRepositoryInvoice on SalesRepository {
  /// Create a complete offline invoice with AccountMove and lines
  ///
  /// This unified method is used by both `confirmOffline` and `queueInvoiceWithPayments`
  /// to ensure consistent invoice creation.
  ///
  /// Returns the created invoice data or null if creation failed.
  Future<OfflineInvoiceData?> _createOfflineInvoiceWithAccountMove({
    required int orderId,
    required SaleOrder order,
    String? existingInvoiceName,
    String? existingAccessKey,
  }) async {
    final appDb = _db;

    // 1. Get SRI-configured journal
    final journal = await (appDb.select(appDb.accountJournal)
          ..where((t) => t.l10nEcEntity.isNotNull())
          ..where((t) => t.l10nEcEmission.isNotNull())
          ..limit(1))
        .getSingleOrNull();

    if (journal == null) {
      logger.w('[SalesRepository]', 'No SRI-configured journal found');
      return null;
    }

    final entity = journal.l10nEcEntity!;
    final emission = journal.l10nEcEmission!;

    // Variables for invoice name and access key
    String invoiceName;
    String accessKey;
    int? sequenceToUpdate;

    // If existing invoice name provided (regeneration), reuse it
    if (existingInvoiceName != null && existingAccessKey != null) {
      invoiceName = existingInvoiceName;
      accessKey = existingAccessKey;
      logger.d('[SalesRepository]', 'Reusing existing invoice name: $invoiceName');
    } else {
      // 2. Get correct sequence considering existing Odoo invoices
      final nextSequence = await _getNextInvoiceSequence(entity, emission);
      sequenceToUpdate = nextSequence;

      // 3. Generate invoice name and access key
      invoiceName = SRIKeyGenerator.generateInvoiceName(
        entity: entity,
        emission: emission,
        sequence: nextSequence,
      );

      final ruc = order.partnerVat ?? '9999999999999';

      // SRI environment: '2' = production, '1' = test
      // Read from res.company.l10n_ec_production_env via companyManager
      String sriEnvironment = '1'; // default to test
      try {
        final companyId = order.companyId;
        if (companyId != null) {
          final company = await companyManager.readLocal(companyId);
          if (company != null) {
            sriEnvironment = company.l10nEcProductionEnv ? '2' : '1';
          }
        }
      } catch (e) {
        logger.w('[SalesRepository]', 'Could not read company SRI env, defaulting to test: $e');
      }

      accessKey = SRIKeyGenerator.generateAccessKey(
        date: DateTime.now(),
        documentType: '01', // Factura
        ruc: ruc,
        environment: sriEnvironment,
        emissionType: '1',
        invoiceName: invoiceName,
      );
    }

    final invoiceUuid = _uuid.v4();
    final now = DateTime.now();

    // Extract sequence number from invoice name (format: 001-001-000000123)
    final sequenceNumber = sequenceToUpdate ??
        int.tryParse(invoiceName.split('-').last) ??
        0;

    // 4. Store Offline Invoice record
    await appDb.into(appDb.offlineInvoice).insert(
          OfflineInvoiceCompanion(
            uuid: drift.Value(invoiceUuid),
            orderId: drift.Value(orderId),
            invoiceName: drift.Value(invoiceName),
            accessKey: drift.Value(accessKey),
            sequenceNumber: drift.Value(sequenceNumber),
            documentType: const drift.Value('01'),
            invoiceDate: drift.Value(now),
            partnerId: drift.Value(order.partnerId ?? 0),
            amountTotal: drift.Value(order.amountTotal),
            status: const drift.Value('pending'),
            createdAt: drift.Value(now),
          ),
        );

    // 5. Create AccountMove for printing (negative odooId indicates offline)
    final offlineMoveOdooId = -orderId;
    await appDb.into(appDb.accountMove).insert(
          AccountMoveCompanion(
            odooId: drift.Value(offlineMoveOdooId),
            name: drift.Value(invoiceName),
            moveType: const drift.Value('out_invoice'),
            l10nEcAuthorizationNumber: drift.Value(accessKey),
            l10nLatamDocumentNumber: drift.Value(invoiceName),
            l10nLatamDocumentTypeId: const drift.Value(1),
            l10nLatamDocumentTypeName: const drift.Value('Factura'),
            l10nEcSriPaymentName:
                const drift.Value('Sin utilización del sistema financiero'),
            state: const drift.Value('posted'),
            paymentState: const drift.Value('paid'),
            invoiceDate: drift.Value(now),
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
            amountResidual: const drift.Value(0.0),
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

      await appDb.into(appDb.accountMoveLine).insert(
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
      await (appDb.update(appDb.accountJournal)
            ..where((t) => t.id.equals(journal.id)))
          .write(
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
    return null;
  }

  /// Get the next invoice sequence number for a given entity/emission
  ///
  /// This considers BOTH:
  /// 1. The journal's lastInvoiceSequence
  /// 2. The MAX sequence from existing account_move records (synced from Odoo)
  ///
  /// This ensures offline invoices don't duplicate numbers from Odoo-created invoices.
  Future<int> _getNextInvoiceSequence(String entity, String emission) async {
    final appDb = _db;

    // 1. Get journal's stored sequence
    final journal = await (appDb.select(appDb.accountJournal)
          ..where((t) => t.l10nEcEntity.equals(entity))
          ..where((t) => t.l10nEcEmission.equals(emission))
          ..limit(1))
        .getSingleOrNull();

    final journalSequence = journal?.lastInvoiceSequence ?? 0;

    // 2. Get MAX sequence from existing invoices in account_move
    // Invoice names follow pattern: "Fact 001-001-000000007" or "001-001-000000007"
    final prefix = '$entity-$emission-';
    final invoices = await (appDb.select(appDb.accountMove)
          ..where((t) => t.moveType.equals('out_invoice'))
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
      'Next sequence for $entity-$emission: journal=$journalSequence, '
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
  Future<void> syncInvoicesForOrder(int orderId, {bool forceRefresh = false}) async {
    if (_odooClient == null) return;

    try {
      // Get order data from local DB to check invoice_ids
      final appDb = _db;
      final orderData = await (appDb.select(appDb.saleOrder)
            ..where((t) => t.odooId.equals(orderId)))
          .getSingleOrNull();

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
          final orderDataFromOdoo = await _odooClient.searchRead(
            model: 'sale.order',
            fields: ['invoice_ids'],
            domain: [
              ['id', '=', orderId],
            ],
            limit: 1,
          );

          if (orderDataFromOdoo.isNotEmpty) {
            final invoiceIdsFromOdoo = orderDataFromOdoo.first['invoice_ids'] as List<dynamic>?;
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
        logger.d(
          '[SalesRepository] No invoices found for order $orderId',
        );
        return;
      }

      // Use InvoiceRepository to sync invoices with their lines
      final invoiceRepository = InvoiceRepository(
        odooClient: _odooClient,
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

    // 2. Generate offline invoice with SRI access key (Ecuador)
    // Uses unified method for consistent invoice creation
    // If existingInvoiceName is provided, reuse it (for regeneration)
    OfflineInvoiceData? offlineInvoice;
    try {
      offlineInvoice = await _createOfflineInvoiceWithAccountMove(
        orderId: saleOrderId,
        order: order,
        existingInvoiceName: existingInvoiceName,
        existingAccessKey: existingAccessKey,
      );
    } catch (e) {
      logger.w('[SalesRepository]', 'SRI invoice generation skipped: $e');
      // Continue with queueing - invoice will be created on sync
    }

    final appDb = _db;

    // 3. Queue the operation for sync
    await _offlineQueue.queueOperation(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'invoice_create_with_payments',
      values: {
        'sale_id': saleOrderId,
        'collection_session_id': collectionSessionId,
        'payment_lines': paymentLines,
        // Include offline invoice data for server-side matching
        if (offlineInvoice != null) ...{
          'offline_access_key': offlineInvoice.accessKey,
          'offline_invoice_name': offlineInvoice.invoiceName,
        },
      },
      parentOrderId: saleOrderId,
    );

    // 4. Mark order as having a queued invoice - prevents modifying payments/withholds
    await (appDb.update(appDb.saleOrder)
          ..where(
            (t) => t.id.equals(saleOrderId) | t.odooId.equals(saleOrderId),
          ))
        .write(const SaleOrderCompanion(hasQueuedInvoice: drift.Value(true)));

    logger.i(
      '[SalesRepository] Invoice creation queued for sale $saleOrderId with ${paymentLines.length} payments'
      '${offlineInvoice != null ? " (offline invoice: ${offlineInvoice.invoiceName})" : ""}',
    );

    return offlineInvoice;
  }

}
