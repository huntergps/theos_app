import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show AppDatabase, AccountMove, AccountMoveLine, accountMoveManager, accountMoveLineManager, clientManager, SaleOrderCompanion, AccountMoveLineCompanion;

import '../../products/repositories/product_repository.dart';

/// Repository for invoice (account.move) operations
///
/// Follows offline-first pattern:
/// 1. Check local database first
/// 2. If not found or force refresh, fetch from Odoo
/// 3. Store in local database
/// 4. Return from local database
///
/// Uses generated managers (accountMoveManager, accountMoveLineManager) for
/// standard CRUD and direct Drift access for complex operations (line upsert
/// with parent-derived required columns, search with LIKE, offline cascades).
class InvoiceRepository {
  final OdooClient? odooClient;
  final ProductRepository? _productRepository;
  final AppDatabase _appDb;

  InvoiceRepository({
    this.odooClient,
    ProductRepository? productRepository,
    required AppDatabase appDb,
  })  : _productRepository = productRepository,
        _appDb = appDb;

  // ============ Local Data Access (via Managers) ============

  /// Get all invoices for a sale order (by sale order odoo_id)
  Future<List<AccountMove>> getInvoicesForSaleOrderLocal(int saleOrderOdooId) async {
    return accountMoveManager.searchLocal(
      domain: [['sale_order_id', '=', saleOrderOdooId]],
    );
  }

  /// Get invoice by Odoo ID from local database
  Future<AccountMove?> getInvoiceByOdooIdLocal(int odooId) async {
    return accountMoveManager.readLocal(odooId);
  }

  /// Get invoices by list of Odoo IDs from local database
  Future<List<AccountMove>> getInvoicesByOdooIdsLocal(List<int> odooIds) async {
    if (odooIds.isEmpty) return [];
    return accountMoveManager.readLocalBatch(odooIds);
  }

  /// Upsert a single invoice with its lines to local database
  Future<void> upsertInvoiceLocal(AccountMove invoice) async {
    // Save invoice header via manager
    await accountMoveManager.upsertLocal(invoice);

    // Save invoice lines if present (needs direct DB access for required columns)
    if (invoice.lines.isNotEmpty) {
      await _upsertInvoiceLines(invoice.id, invoice.lines);
    }
  }

  /// Upsert multiple invoices to local database
  Future<void> upsertInvoicesLocal(List<AccountMove> invoices) async {
    for (final invoice in invoices) {
      await upsertInvoiceLocal(invoice);
    }
  }

  /// Delete invoice and its lines by Odoo ID from local database
  Future<void> deleteInvoiceLocal(int odooId) async {
    // Delete lines first via manager search + delete
    final lines = await accountMoveLineManager.searchLocal(
      domain: [['move_id', '=', odooId]],
    );
    for (final line in lines) {
      await accountMoveLineManager.deleteLocal(line.id);
    }
    // Delete invoice header via manager
    await accountMoveManager.deleteLocal(odooId);
  }

  /// Get invoice with lines from local database
  Future<AccountMove?> getInvoiceWithLinesLocal(int odooId) async {
    final invoice = await accountMoveManager.readLocal(odooId);
    if (invoice == null) return null;

    final lines = await getInvoiceLinesForMoveLocal(odooId);
    return invoice.copyWith(lines: lines);
  }

  /// Get invoice lines for a specific invoice by move_id from local database
  Future<List<AccountMoveLine>> getInvoiceLinesForMoveLocal(int moveOdooId) async {
    return accountMoveLineManager.searchLocal(
      domain: [['move_id', '=', moveOdooId]],
      orderBy: 'sequence asc',
    );
  }

  /// Check if invoice has lines cached locally
  Future<bool> hasInvoiceLinesLocally(int moveOdooId) async {
    final count = await accountMoveLineManager.countLocal(
      domain: [['move_id', '=', moveOdooId]],
    );
    return count > 0;
  }

  /// Search invoices by name or partner name in local database
  ///
  /// Uses direct Drift query for LIKE + moveType + ordering + limit
  /// which cannot be expressed through the standard manager domain filters.
  Future<List<AccountMove>> searchInvoicesLocal(
    String query, {
    int limit = 20,
    List<String> moveTypes = const ['out_invoice'],
  }) async {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    final db = _appDb;

    final results = await (db.select(db.accountMove)
          ..where((tbl) =>
              tbl.moveType.isIn(moveTypes) &
              (tbl.name.lower().like('%$lowerQuery%') |
                  tbl.partnerName.lower().like('%$lowerQuery%')))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.invoiceDate)])
          ..limit(limit))
        .get();

    return results.map((r) => accountMoveManager.fromDrift(r)).toList();
  }

  /// Get offline invoice data for an order (returns the most recent one as AccountMove)
  Future<AccountMove?> getOfflineInvoice(int orderId) async {
    final db = _appDb;
    final invoices = await (db.select(db.offlineInvoice)
          ..where((tbl) => tbl.orderId.equals(orderId))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)])
          ..limit(1))
        .get();

    if (invoices.isEmpty) return null;

    // Convert OfflineInvoiceData to AccountMove
    // Note: Offline invoice is a temporary record, we return the associated AccountMove
    final negativeOdooId = -orderId;
    return await getInvoiceByOdooIdLocal(negativeOdooId);
  }

  /// Delete offline invoice and related data for an order
  ///
  /// Removes:
  /// - OfflineInvoice record
  /// - Associated AccountMove (negative odooId = -orderId)
  /// - Associated AccountMoveLines
  /// - Resets hasQueuedInvoice flag on the order
  ///
  /// Returns true if invoice was deleted, false if not found
  Future<bool> deleteOfflineInvoice(int orderId) async {
    final offlineInvoice = await getOfflineInvoice(orderId);
    if (offlineInvoice == null) {
      return false;
    }

    final db = _appDb;

    // Delete offline invoice record
    await (db.delete(db.offlineInvoice)
          ..where((tbl) => tbl.orderId.equals(orderId)))
        .go();

    // Delete associated AccountMove and its lines (has negative odooId = -orderId)
    final offlineMoveOdooId = -orderId;
    await deleteInvoiceLocal(offlineMoveOdooId);

    // Reset hasQueuedInvoice flag on the order
    await (db.update(db.saleOrder)
          ..where((t) => t.id.equals(orderId) | t.odooId.equals(orderId)))
        .write(const SaleOrderCompanion(hasQueuedInvoice: drift.Value(false)));

    // Delete related offline queue operations (invoice creation, payments)
    await (db.delete(db.offlineQueue)
          ..where((tbl) =>
              tbl.parentOrderId.equals(orderId) &
              (tbl.model.equals('l10n_ec_collection_box.sale.order.payment.wizard') |
               tbl.model.equals('l10n_ec_collection_box.sale.order.payment'))))
        .go();

    return true;
  }

  // ============ Get Invoices for Sale Order ============

  /// Get invoices linked to a sale order
  ///
  /// Uses the invoice_ids stored in the sale order to fetch specific invoices.
  /// Offline-first: Check local DB with lines -> Fetch from Odoo if needed -> Save locally
  Future<List<AccountMove>> getInvoicesForSaleOrder(
    int saleOrderOdooId, {
    bool forceRefresh = false,
  }) async {
    // 1. Check local first - get invoices WITH lines
    if (!forceRefresh) {
      final cachedInvoices = await getInvoicesForSaleOrderLocal(saleOrderOdooId);
      if (cachedInvoices.isNotEmpty) {
        // Load lines for each invoice
        final invoicesWithLines = <AccountMove>[];
        for (final invoice in cachedInvoices) {
          final lines = await getInvoiceLinesForMoveLocal(invoice.id);
          if (lines.isNotEmpty) {
            invoicesWithLines.add(invoice.copyWith(lines: lines));
          } else {
            invoicesWithLines.add(invoice);
          }
        }
        // If all invoices have lines, return from cache
        if (invoicesWithLines.every((inv) => inv.lines.isNotEmpty)) {
          logger.d('[InvoiceRepository]', 'Returning ${invoicesWithLines.length} invoices from local cache with lines');
          return invoicesWithLines;
        }
      }
    }

    // 2. Fetch invoice_ids from sale order and load invoices
    // This is more efficient than searching by invoice_origin
    if (odooClient == null) {
      // Offline: return local data with lines
      final cachedInvoices = await getInvoicesForSaleOrderLocal(saleOrderOdooId);
      final invoicesWithLines = <AccountMove>[];
      for (final invoice in cachedInvoices) {
        final lines = await getInvoiceLinesForMoveLocal(invoice.id);
        invoicesWithLines.add(invoice.copyWith(lines: lines));
      }
      return invoicesWithLines;
    }

    try {
      // Get sale order to read invoice_ids
      final orderData = await odooClient!.searchRead(
        model: 'sale.order',
        fields: ['invoice_ids'],
        domain: [
          ['id', '=', saleOrderOdooId],
        ],
        limit: 1,
      );

      if (orderData.isEmpty) return [];

      // Parse invoice_ids
      final invoiceIds = orderData.first['invoice_ids'] as List<dynamic>?;
      if (invoiceIds == null || invoiceIds.isEmpty) return [];

      // Fetch invoices by IDs
      return await _fetchAndLinkInvoices(
        invoiceIds.cast<int>(),
        saleOrderOdooId,
      );
    } catch (e) {
      // Fallback to local cache on error - return with lines if available
      logger.w('[InvoiceRepository]', 'Error fetching invoices from Odoo, falling back to cache: $e');
      final cachedInvoices = await getInvoicesForSaleOrderLocal(saleOrderOdooId);
      final invoicesWithLines = <AccountMove>[];
      for (final invoice in cachedInvoices) {
        final lines = await getInvoiceLinesForMoveLocal(invoice.id);
        invoicesWithLines.add(invoice.copyWith(lines: lines));
      }
      return invoicesWithLines;
    }
  }

  /// Fetch invoices by IDs and link them to a sale order
  /// Also cleans up local invoices that no longer exist in Odoo
  Future<List<AccountMove>> _fetchAndLinkInvoices(
    List<int> invoiceIds,
    int saleOrderOdooId,
  ) async {
    if (invoiceIds.isEmpty) {
      // If Odoo returns no invoices, clean up any local invoices for this order
      await _cleanupObsoleteInvoices(saleOrderOdooId, []);
      return [];
    }

    logger.d('[InvoiceRepository]', 'Fetching ${invoiceIds.length} invoices for order $saleOrderOdooId');

    // Clean up local invoices that are no longer linked in Odoo
    await _cleanupObsoleteInvoices(saleOrderOdooId, invoiceIds);

    // 1. Fetch invoice headers
    final data = await odooClient!.searchRead(
      model: accountMoveManager.odooModel,
      fields: accountMoveManager.odooFields,
      domain: [
        ['id', 'in', invoiceIds],
      ],
    );

    final invoices = <AccountMove>[];

    for (final invoiceData in data) {
      var invoice = accountMoveManager.fromOdoo(invoiceData);

      // 2. Load partner address from local database (already synced)
      if (invoice.partnerId != null) {
        try {
          final partner = await clientManager.readLocal(invoice.partnerId!);
          if (partner != null) {
            invoice = invoice.copyWithPartnerData(
              partnerStreet: partner.street,
              partnerCity: partner.city,
              partnerPhone: partner.phone,
              partnerEmail: partner.email,
            );
          }
        } catch (e) {
          logger.w('[InvoiceRepository]', 'Failed to load partner from local DB: $e');
        }
      }

      // 3. Fetch ALL invoice lines, then filter in code
      try {
        final linesData = await odooClient!.searchRead(
          model: accountMoveLineManager.odooModel,
          fields: accountMoveLineManager.odooFields,
          domain: [
            ['move_id', '=', invoice.id],
          ],
        );

        logger.d('[InvoiceRepository]', 'Invoice ${invoice.name}: ${linesData.length} raw lines');

        // Filter to report-relevant lines only
        var lines = linesData
            .map((e) => accountMoveLineManager.fromOdoo(e))
            .where((line) => line.isReportLine)
            .toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence));

        // Enrich lines with product data (barcode, l10n_ec_auxiliary_code)
        lines = await _enrichLinesWithProductData(lines);

        logger.d('[InvoiceRepository]', 'Invoice ${invoice.name}: ${lines.length} report lines (enriched)');

        invoice = invoice.copyWith(
          saleOrderId: saleOrderOdooId,
          lines: lines,
        );
      } catch (e) {
        logger.w('[InvoiceRepository]', 'Failed to load lines for ${invoice.name}: $e');
        // If lines fail, continue with header only
        invoice = invoice.copyWith(saleOrderId: saleOrderOdooId);
      }

      invoices.add(invoice);

      // Save to local DB
      await upsertInvoiceLocal(invoice);
    }

    return invoices;
  }

  // ============ Get Invoice by ID ============

  /// Get a single invoice by Odoo ID with lines
  ///
  /// Offline-first pattern:
  /// 1. Check local database for invoice WITH lines
  /// 2. If found with lines, return from local
  /// 3. If not found or no lines, try to fetch from Odoo (if connected)
  /// 4. Save to local database and return
  Future<AccountMove?> getInvoiceById(
    int odooId, {
    bool forceRefresh = false,
  }) async {
    // 1. Check local cache first with lines (if not forcing refresh)
    if (!forceRefresh) {
      final hasLines = await hasInvoiceLinesLocally(odooId);
      if (hasLines) {
        final cached = await getInvoiceWithLinesLocal(odooId);
        if (cached != null && cached.lines.isNotEmpty) {
          logger.d('[InvoiceRepository]', 'Returning invoice $odooId from local cache with ${cached.lines.length} lines');
          return cached;
        }
      }
    }

    // 2. Fetch from Odoo with lines (only if online)
    if (odooClient == null) {
      // Offline: return local data (even without lines)
      return await getInvoiceWithLinesLocal(odooId);
    }

    try {
      logger.d('[InvoiceRepository]', 'Fetching invoice $odooId from Odoo...');

      final data = await odooClient!.searchRead(
        model: accountMoveManager.odooModel,
        fields: accountMoveManager.odooFields,
        domain: [
          ['id', '=', odooId],
        ],
      );

      if (data.isEmpty) {
        logger.w('[InvoiceRepository]', 'Invoice $odooId not found in Odoo');
        // Try to return from local cache even without lines
        return await getInvoiceByOdooIdLocal(odooId);
      }

      var invoice = accountMoveManager.fromOdoo(data.first);
      logger.d('[InvoiceRepository]', 'Invoice header loaded: ${invoice.name}');

      // 2.5. Load partner address from local database
      if (invoice.partnerId != null) {
        try {
          final partner = await clientManager.readLocal(invoice.partnerId!);
          if (partner != null) {
            logger.d('[InvoiceRepository]', 'Partner loaded: ${partner.name}, street: ${partner.street}');
            invoice = invoice.copyWithPartnerData(
              partnerStreet: partner.street,
              partnerCity: partner.city,
              partnerPhone: partner.phone,
              partnerEmail: partner.email,
            );
          }
        } catch (e) {
          logger.w('[InvoiceRepository]', 'Failed to load partner from local DB: $e');
        }
      }

      // 3. Fetch ALL invoice lines for this move, then filter in code
      // This avoids issues with complex OR domain in Odoo JSON-RPC
      final linesData = await odooClient!.searchRead(
        model: accountMoveLineManager.odooModel,
        fields: accountMoveLineManager.odooFields,
        domain: [
          ['move_id', '=', odooId],
        ],
      );

      logger.d('[InvoiceRepository]', 'Fetched ${linesData.length} raw lines from Odoo');

      // Filter to only report-relevant lines (exclude cogs, payment_term)
      var lines = linesData
          .map((e) => accountMoveLineManager.fromOdoo(e))
          .where((line) => line.isReportLine)
          .toList()
        ..sort((a, b) => a.sequence.compareTo(b.sequence));

      // Enrich lines with product data (barcode, l10n_ec_auxiliary_code)
      lines = await _enrichLinesWithProductData(lines);

      logger.i('[InvoiceRepository]',
        'Invoice ${invoice.name} has ${lines.length} report lines (enriched) '
        '(product: ${lines.where((l) => l.isProductLine).length}, '
        'tax: ${lines.where((l) => l.isTaxLine).length}, '
        'section: ${lines.where((l) => l.isSection).length}, '
        'note: ${lines.where((l) => l.isNote).length})');

      invoice = invoice.copyWith(lines: lines);

      // 4. Save to local cache (including lines)
      await upsertInvoiceLocal(invoice);
      logger.d('[InvoiceRepository]', 'Invoice ${invoice.name} saved to local cache with ${lines.length} lines');

      return invoice;
    } catch (e, stack) {
      logger.e('[InvoiceRepository]', 'Error fetching invoice $odooId from Odoo: $e\n$stack');
      // Fallback to local cache on error (even without lines)
      logger.d('[InvoiceRepository]', 'Falling back to local cache...');
      final cached = await getInvoiceWithLinesLocal(odooId);
      if (cached != null) {
        logger.d('[InvoiceRepository]', 'Returning cached invoice with ${cached.lines.length} lines');
      }
      return cached;
    }
  }

  // ============ Get Invoices by IDs ============

  /// Get multiple invoices by their Odoo IDs with lines
  ///
  /// Useful when loading invoices from invoice_ids field in sale.order
  /// Follows offline-first pattern: check local with lines -> fetch from Odoo -> save locally
  Future<List<AccountMove>> getInvoicesByIds(
    List<int> odooIds, {
    bool forceRefresh = false,
    int? saleOrderId,
  }) async {
    if (odooIds.isEmpty) return [];

    // 1. Check local first WITH lines
    if (!forceRefresh) {
      final cached = await getInvoicesByOdooIdsLocal(odooIds);
      if (cached.length == odooIds.length) {
        // Load lines for each invoice
        final invoicesWithLines = <AccountMove>[];
        for (final invoice in cached) {
          final lines = await getInvoiceLinesForMoveLocal(invoice.id);
          invoicesWithLines.add(invoice.copyWith(lines: lines));
        }
        // If all invoices have lines, return from cache
        if (invoicesWithLines.every((inv) => inv.lines.isNotEmpty)) {
          logger.d('[InvoiceRepository]', 'Returning ${invoicesWithLines.length} invoices from local cache with lines');
          return invoicesWithLines;
        }
      }
    }

    // 2. Fetch from Odoo with lines (only if online)
    if (odooClient == null) {
      // Offline: return local data with lines
      final cached = await getInvoicesByOdooIdsLocal(odooIds);
      final invoicesWithLines = <AccountMove>[];
      for (final invoice in cached) {
        final lines = await getInvoiceLinesForMoveLocal(invoice.id);
        invoicesWithLines.add(invoice.copyWith(lines: lines));
      }
      return invoicesWithLines;
    }

    try {
      final data = await odooClient!.searchRead(
        model: accountMoveManager.odooModel,
        fields: accountMoveManager.odooFields,
        domain: [
          ['id', 'in', odooIds],
        ],
      );

      final invoices = <AccountMove>[];

      for (final invoiceData in data) {
        var invoice = accountMoveManager.fromOdoo(invoiceData);

        // Load partner address from local database
        if (invoice.partnerId != null) {
          try {
            final partner = await clientManager.readLocal(invoice.partnerId!);
            if (partner != null) {
              invoice = invoice.copyWithPartnerData(
                partnerStreet: partner.street,
                partnerCity: partner.city,
                partnerPhone: partner.phone,
                partnerEmail: partner.email,
              );
            }
          } catch (e) {
            logger.w('[InvoiceRepository]', 'Failed to load partner from local DB: $e');
          }
        }

        // Fetch lines for this invoice
        try {
          final linesData = await odooClient!.searchRead(
            model: accountMoveLineManager.odooModel,
            fields: accountMoveLineManager.odooFields,
            domain: [
              ['move_id', '=', invoice.id],
            ],
          );

          // Filter to report-relevant lines only
          var lines = linesData
              .map((e) => accountMoveLineManager.fromOdoo(e))
              .where((line) => line.isReportLine)
              .toList()
            ..sort((a, b) => a.sequence.compareTo(b.sequence));

          // Enrich lines with product data (barcode, l10n_ec_auxiliary_code)
          lines = await _enrichLinesWithProductData(lines);

          invoice = invoice.copyWith(lines: lines);
        } catch (e) {
          logger.w('[InvoiceRepository]', 'Failed to load lines for ${invoice.name}: $e');
        }

        // Apply sale order link if provided
        if (saleOrderId != null) {
          invoice = invoice.copyWith(saleOrderId: saleOrderId);
        }

        // Save to local DB (including lines)
        await upsertInvoiceLocal(invoice);
        invoices.add(invoice);
      }

      return invoices;
    } catch (e) {
      // Fallback to cache with lines
      logger.w('[InvoiceRepository]', 'Error fetching invoices from Odoo, falling back to cache: $e');
      final cached = await getInvoicesByOdooIdsLocal(odooIds);
      final invoicesWithLines = <AccountMove>[];
      for (final invoice in cached) {
        final lines = await getInvoiceLinesForMoveLocal(invoice.id);
        invoicesWithLines.add(invoice.copyWith(lines: lines));
      }
      return invoicesWithLines;
    }
  }

  // ============ Sync Invoice from Sale Order ============

  /// Sync invoices for a sale order using invoice_ids JSON
  ///
  /// This fetches the invoice_ids from the sale order and loads invoice details
  Future<List<AccountMove>> syncInvoicesForOrder(
    int saleOrderOdooId,
    String? invoiceIdsJson,
  ) async {
    if (invoiceIdsJson == null || invoiceIdsJson.isEmpty) {
      return [];
    }

    // Parse invoice IDs from JSON
    List<int> invoiceIds;
    try {
      invoiceIds = List<int>.from(jsonDecode(invoiceIdsJson));
    } catch (e) {
      return [];
    }

    if (invoiceIds.isEmpty) return [];

    // Fetch invoices by IDs with sale order link
    return await getInvoicesByIds(
      invoiceIds,
      forceRefresh: true,
      saleOrderId: saleOrderOdooId,
    );
  }

  // ============ Refresh Invoice ============

  /// Force refresh a single invoice from Odoo
  ///
  /// Useful when needing to verify SRI authorization status
  Future<AccountMove?> refreshInvoice(int odooId) async {
    return getInvoiceById(odooId, forceRefresh: true);
  }

  // ============ Helper Methods ============

  /// Clean up local invoices that are no longer linked to a sale order in Odoo
  ///
  /// This handles cases where:
  /// 1. Invoice was deleted in Odoo
  /// 2. Invoice was replaced (canceled and re-created with new ID)
  /// 3. Invoice was unlinked from the sale order
  Future<void> _cleanupObsoleteInvoices(
    int saleOrderOdooId,
    List<int> validInvoiceIds,
  ) async {
    try {
      // Get local invoices linked to this sale order
      final localInvoices = await getInvoicesForSaleOrderLocal(saleOrderOdooId);

      if (localInvoices.isEmpty) return;

      // Find invoices that are in local DB but not in Odoo's current list
      final obsoleteInvoices = localInvoices
          .where((inv) => !validInvoiceIds.contains(inv.id))
          .toList();

      if (obsoleteInvoices.isEmpty) return;

      logger.i(
        '[InvoiceRepository]',
        'Found ${obsoleteInvoices.length} obsolete invoices for order $saleOrderOdooId: '
        '${obsoleteInvoices.map((i) => '${i.name} (id=${i.id})').join(', ')}',
      );

      // Delete obsolete invoices from local database
      for (final invoice in obsoleteInvoices) {
        await deleteInvoiceLocal(invoice.id);
        logger.d(
          '[InvoiceRepository]',
          'Deleted obsolete invoice: ${invoice.name} (odoo_id=${invoice.id})',
        );
      }
    } catch (e) {
      logger.w(
        '[InvoiceRepository]',
        'Error cleaning up obsolete invoices for order $saleOrderOdooId: $e',
      );
      // Don't fail the sync if cleanup fails
    }
  }

  // ============ Search Invoices ============

  /// Search invoices by number (name) or partner name
  ///
  /// Used for invoice selection dialogs. Searches local database first,
  /// then fetches from Odoo if online.
  ///
  /// [query] - Search term (invoice number or partner name)
  /// [limit] - Maximum number of results (default 20)
  /// [moveTypes] - Filter by move types (default: out_invoice only)
  Future<List<AccountMove>> searchInvoices(
    String query, {
    int limit = 20,
    List<String> moveTypes = const ['out_invoice'],
  }) async {
    if (query.trim().isEmpty) return [];

    // 1. Search locally first
    final localResults = await searchInvoicesLocal(query, limit: limit, moveTypes: moveTypes);
    if (localResults.isNotEmpty) {
      logger.d('[InvoiceRepository]', 'Found ${localResults.length} invoices locally for "$query"');
      return localResults;
    }

    // 2. Try to fetch from Odoo if nothing local (only if online)
    if (odooClient == null) return localResults;

    try {
      // Build domain for search
      // Odoo domain uses Polish notation: '|' applies to next two terms
      final domain = <dynamic>[
        ['move_type', 'in', moveTypes],
        ['state', '=', 'posted'], // Only posted invoices
        '|', // OR applies to next two terms
        ['name', 'ilike', query],
        ['partner_id.name', 'ilike', query],
      ];

      final data = await odooClient!.searchRead(
        model: accountMoveManager.odooModel,
        fields: accountMoveManager.odooFields,
        domain: domain,
        limit: limit,
      );

      if (data.isEmpty) return [];

      final invoices = <AccountMove>[];
      for (final invoiceData in data) {
        var invoice = accountMoveManager.fromOdoo(invoiceData);

        // Save to local DB for future offline access
        await upsertInvoiceLocal(invoice);
        invoices.add(invoice);
      }

      logger.d('[InvoiceRepository]', 'Found ${invoices.length} invoices from Odoo for "$query"');
      return invoices;
    } catch (e) {
      logger.w('[InvoiceRepository]', 'Error searching invoices from Odoo: $e');
      return localResults; // Return local results on error
    }
  }

  /// Check if an invoice has active withholds registered
  ///
  /// Returns the number of posted withholds for this invoice.
  /// Withholds in Odoo are account.move records linked via l10n_ec_withhold_invoice_id
  /// on their lines.
  ///
  /// Returns 0 if no withholds, >0 if has withholds, -1 if error (treated as 0)
  Future<int> getActiveWithholdsCount(int invoiceOdooId) async {
    if (odooClient == null) return 0; // Cannot check withholds offline

    try {
      // In Odoo, withholds are account.move records where their lines have
      // l10n_ec_withhold_invoice_id pointing to the invoice.
      // We search account.move.line to find withholds linked to this invoice.
      final data = await odooClient!.searchRead(
        model: 'account.move.line',
        fields: ['move_id'],
        domain: [
          ['l10n_ec_withhold_invoice_id', '=', invoiceOdooId],
          ['parent_state', '=', 'posted'], // Only posted withholds
        ],
        limit: 10,
      );

      if (data.isEmpty) return 0;

      // Get unique withhold move IDs
      final withholdIds = <int>{};
      for (final line in data) {
        final moveId = line['move_id'];
        if (moveId is List && moveId.isNotEmpty) {
          withholdIds.add(moveId[0] as int);
        } else if (moveId is int) {
          withholdIds.add(moveId);
        }
      }

      return withholdIds.length;
    } catch (e) {
      logger.w('[InvoiceRepository]', 'Error checking withholds for invoice $invoiceOdooId: $e');
      // On error, return -1 to indicate error (will be treated as 0)
      return -1;
    }
  }

  // ============ Private Helpers ============

  /// Upsert invoice lines for a specific invoice using direct Drift access.
  ///
  /// The generated AccountMoveLineManager cannot be used here because the
  /// Drift table has required non-nullable columns (company_id, date, journal_id)
  /// that are not part of the AccountMoveLine model — they are derived from
  /// the parent invoice.
  Future<void> _upsertInvoiceLines(
    int moveOdooId,
    List<AccountMoveLine> lines,
  ) async {
    final db = _appDb;

    // First delete existing lines for this move
    await (db.delete(db.accountMoveLine)
          ..where((tbl) => tbl.moveId.equals(moveOdooId)))
        .go();

    // Get parent invoice to extract required fields
    final invoiceRow = await (db.select(db.accountMove)
          ..where((tbl) => tbl.odooId.equals(moveOdooId)))
        .getSingleOrNull();

    if (invoiceRow == null) return; // Can't insert lines without parent invoice

    // Log warnings for missing required fields that fall back to defaults
    if (invoiceRow.companyId == null) {
      logger.w('[InvoiceRepository]', 'Invoice $moveOdooId has null companyId, using fallback=1');
    }
    if (invoiceRow.journalId == null) {
      logger.w('[InvoiceRepository]', 'Invoice $moveOdooId has null journalId, using fallback=1');
    }

    // Then insert all new lines
    for (final line in lines) {
      if (line.accountId == null) {
        logger.w('[InvoiceRepository]', 'Invoice line ${line.id} has null accountId, using fallback=1');
      }
      await db.into(db.accountMoveLine).insert(
            AccountMoveLineCompanion.insert(
              odooId: line.id,
              moveId: moveOdooId,
              accountId: line.accountId ?? 1, // Use dummy account if not specified
              companyId: invoiceRow.companyId ?? 1,
              date: invoiceRow.date ?? DateTime.now(),
              journalId: invoiceRow.journalId ?? 1,
              name: line.name,
              displayType: drift.Value(line.displayTypeString),
              sequence: drift.Value(line.sequence),
              productId: drift.Value(line.productId),
              productName: drift.Value(line.productName),
              productCode: drift.Value(line.productCode),
              productBarcode: drift.Value(line.productBarcode),
              productL10nEcAuxiliaryCode: drift.Value(line.productL10nEcAuxiliaryCode),
              productType: drift.Value(line.productType),
              quantity: drift.Value(line.quantity),
              productUomId: drift.Value(line.productUomId),
              productUomName: drift.Value(line.productUomName),
              priceUnit: drift.Value(line.priceUnit),
              discount: drift.Value(line.discount),
              priceSubtotal: drift.Value(line.priceSubtotal),
              priceTotal: drift.Value(line.priceTotal),
              taxIds: drift.Value(line.taxIds),
              taxNames: drift.Value(line.taxNames),
              taxLineId: drift.Value(line.taxLineId),
              taxLineName: drift.Value(line.taxLineName),
              accountName: drift.Value(line.accountName),
              collapseComposition: drift.Value(line.collapseComposition),
              collapsePrices: drift.Value(line.collapsePrices),
              lastSyncDate: drift.Value(DateTime.now()),
            ),
            onConflict: drift.DoUpdate(
              (old) => AccountMoveLineCompanion.custom(
                moveId: drift.Variable(moveOdooId),
                accountId: drift.Variable(line.accountId ?? 1),
                companyId: drift.Variable(invoiceRow.companyId ?? 1),
                date: drift.Variable(invoiceRow.date ?? DateTime.now()),
                journalId: drift.Variable(invoiceRow.journalId ?? 1),
                name: drift.Variable(line.name),
                displayType: drift.Variable(line.displayTypeString),
                sequence: drift.Variable(line.sequence),
                productId: drift.Variable(line.productId),
                productName: drift.Variable(line.productName),
                productCode: drift.Variable(line.productCode),
                productBarcode: drift.Variable(line.productBarcode),
                productL10nEcAuxiliaryCode: drift.Variable(line.productL10nEcAuxiliaryCode),
                productType: drift.Variable(line.productType),
                quantity: drift.Variable(line.quantity),
                productUomId: drift.Variable(line.productUomId),
                productUomName: drift.Variable(line.productUomName),
                priceUnit: drift.Variable(line.priceUnit),
                discount: drift.Variable(line.discount),
                priceSubtotal: drift.Variable(line.priceSubtotal),
                priceTotal: drift.Variable(line.priceTotal),
                taxIds: drift.Variable(line.taxIds),
                taxNames: drift.Variable(line.taxNames),
                taxLineId: drift.Variable(line.taxLineId),
                taxLineName: drift.Variable(line.taxLineName),
                accountName: drift.Variable(line.accountName),
                collapseComposition: drift.Variable(line.collapseComposition),
                collapsePrices: drift.Variable(line.collapsePrices),
                lastSyncDate: drift.Variable(DateTime.now()),
              ),
              target: [db.accountMoveLine.odooId],
            ),
          );
    }
  }

  /// Enrich invoice lines with product data (barcode, l10n_ec_auxiliary_code, type)
  ///
  /// Fetches product info from local database and updates lines with:
  /// - productBarcode
  /// - productL10nEcAuxiliaryCode
  /// - productType (Odoo 18+: 'consu', 'service', 'combo')
  Future<List<AccountMoveLine>> _enrichLinesWithProductData(
    List<AccountMoveLine> lines,
  ) async {
    if (lines.isEmpty) return lines;

    final enrichedLines = <AccountMoveLine>[];

    for (final line in lines) {
      if (line.productId == null || _productRepository == null) {
        enrichedLines.add(line);
        continue;
      }

      try {
        // Get product from local database via ProductRepository
        final product = await _productRepository.getById(line.productId!);
        if (product != null) {
          enrichedLines.add(line.copyWithProductData(
            barcode: product.barcode,
            l10nEcAuxiliaryCode: product.l10nEcAuxiliaryCode,
            type: product.type.name, // Odoo 18+: 'consu', 'service', 'combo'
          ));
        } else {
          enrichedLines.add(line);
        }
      } catch (e) {
        logger.w('[InvoiceRepository]', 'Failed to get product ${line.productId} for line enrichment: $e');
        enrichedLines.add(line);
      }
    }

    return enrichedLines;
  }
}
