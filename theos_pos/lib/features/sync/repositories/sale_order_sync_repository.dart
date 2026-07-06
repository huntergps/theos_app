import 'package:drift/drift.dart';

import '../../../core/services/handlers/related_record_resolver.dart';
import 'base_sync_repository.dart';
import 'sync_models.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;
import '../../invoices/repositories/invoice_repository.dart';
import '../../products/repositories/product_repository.dart';

/// Repository for syncing sale.order and sale.order.line from Odoo
///
/// Handles:
/// - Full sync of sale orders with their lines
/// - Incremental sync based on write_date
/// - Pagination with configurable batch size
/// - Progress reporting
/// - Cancellation support
/// - Related record resolution (partners, products, taxes, etc.)
/// - Fetch/search operations with online/offline fallback
///
/// MODULE DEPENDENCIES for custom fields:
///   - 'is_final_consumer', 'end_customer_*' -> requires: sale_final_consumer (custom module)
///   - 'is_cash', 'is_credit', 'nota_adicional' -> requires: l10n_ec_collection_box
///   - 'total_discount_amount', 'total_amount_undiscounted' -> requires: l10n_ec_sale_discount
///   - 'collection_session_id', 'collection_user_id' -> requires: l10n_ec_collection_box
///   - 'withhold_line_ids' -> requires: l10n_ec_withhold
/// These modules are ALWAYS installed on our target servers (erp1, localhost).
/// Syncing against a vanilla Odoo instance without these modules will cause HTTP 500.

// ============ Field List Constants ============

/// Campos estándar de Odoo para sale.order — presentes en Odoo 19.1 y 19.2.
const _saleOrderBaseFields = [
  'id',
  'name',
  'state',
  'date_order',
  'validity_date',
  'commitment_date',
  'expected_date',
  'partner_id',
  'partner_invoice_id',
  'partner_shipping_id',
  'user_id',
  'team_id',
  'company_id',
  'warehouse_id',
  'pricelist_id',
  'currency_id',
  'currency_rate',
  'payment_term_id',
  'fiscal_position_id',
  'amount_untaxed',
  'amount_tax',
  'amount_total',
  'amount_to_invoice',
  'amount_invoiced',
  'invoice_status',
  'invoice_count',
  'note',
  'client_order_ref',
  'order_line',
  'invoice_ids',
  'locked',
  'is_expired',
  'delivery_status',
  'write_date',
];

/// Campos custom de Ecuador para sale.order — presentes en ambas versiones
/// del servidor porque los módulos custom siempre están instalados.
///
/// Requieren: sale_final_consumer, l10n_ec_collection_box, l10n_ec_sale_discount,
/// l10n_ec_withhold (todos instalados en erp1.tecnosmart.com.ec y localhost).
const _saleOrderEcuadorFields = [
  // sale_final_consumer: Consumidor Final
  'is_final_consumer',
  'end_customer_name',
  'end_customer_phone',
  'end_customer_email',
  // l10n_ec_sale_discount: Descuentos
  'total_discount_amount',
  'total_amount_undiscounted',
  // l10n_ec_collection_box: Cobro y sesiones
  'is_cash',
  'is_credit',
  'collection_session_id',
  'collection_user_id',
  'sale_created_user_id',
  'nota_adicional',
  // l10n_ec_withhold: Retenciones
  'withhold_line_ids',
  // Custom UUID for offline-first identification
  'x_uuid',
];

/// Lista completa de campos para sale.order (base + Ecuador custom).
const _saleOrderAllFields = [..._saleOrderBaseFields, ..._saleOrderEcuadorFields];

class SaleOrderSyncRepository extends BaseSyncRepository {
  final ProductRepository? _productRepository;

  SaleOrderSyncRepository({
    required super.db,
    super.odooClient,
    ProductRepository? productRepository,
  })  : _productRepository = productRepository;

  @override
  String get logTag => 'SaleOrderSync';

  // ============ Sale Orders Sync ============

  /// Sync sale orders and their lines from Odoo using pagination
  /// [sinceDate] if provided, only sync records modified after this date (incremental sync)
  Future<int> syncSaleOrders({
    int batchSize = 200,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    if (!isOnline) return 0;

    int syncedCount = 0;
    int totalRecords = 0;

    try {
      final isIncremental = sinceDate != null;
      logDebug('[SaleOrderSync] Syncing sale orders (incremental: $isIncremental)...');

      // Get recent sale orders (last 90 days or active)
      final List<dynamic> domain = [
        '|',
        ['state', 'in', ['draft', 'sent', 'sale']],
        ['date_order', '>=', _getDateNDaysAgo(90)],
      ];

      // Add write_date filter for incremental sync
      if (sinceDate != null) {
        final sinceDateStr = formatDateForOdoo(sinceDate);
        domain.add(['write_date', '>', sinceDateStr]);
        logDebug('[SaleOrderSync] Filtering sale orders with write_date > $sinceDateStr');
      }

      // Get total count
      totalRecords = await odooClient!.searchCount(
        model: 'sale.order',
        domain: domain,
      ) ?? 0;

      logDebug('[SaleOrderSync] Total sale orders to sync: $totalRecords');

      onProgress?.call(SyncProgress(
        total: totalRecords,
        synced: 0,
        currentItem: 'Iniciando...',
      ));

      if (totalRecords == 0) {
        onProgress?.call(const SyncProgress(total: 0, synced: 0));
        return 0;
      }

      int offset = 0;
      bool hasMore = true;

      while (hasMore) {
        logDebug('[SaleOrderSync] Fetching sale orders batch offset=$offset limit=$batchSize');

        final orders = await odooClient!.searchRead(
          model: 'sale.order',
          domain: domain,
          fields: _saleOrderAllFields,
          limit: batchSize,
          offset: offset,
          order: 'id asc', // Use id for consistent pagination
        );

        if (orders.isEmpty) {
          hasMore = false;
          break;
        }

        // Upsert all order headers first
        for (final order in orders) {
          if (syncedCount % 5 == 0) {
            checkCancellation(syncedCount);
          }
          await _upsertSaleOrder(order);
          syncedCount++;
        }

        // FIX 2: Batch fetch lines for all orders in this page (1 HTTP request
        // instead of N). Group by order_id in memory to preserve per-order semantics.
        final orderIds = orders.map((o) => o['id'] as int).toList();

        await _syncSaleOrderLinesBatch(orderIds);
        await _syncSaleOrderWithholdLinesBatch(orderIds);

        // Invoice sync: uses InvoiceRepository which has its own internal batching.
        // Still called per-order because getInvoicesByIds already batches internally.
        for (final order in orders) {
          final invoiceIds = order['invoice_ids'] as List? ?? [];
          if (invoiceIds.isNotEmpty) {
            await _syncSaleOrderInvoices(order['id'] as int, invoiceIds.cast<int>());
          }
        }

        // Report progress after each page
        if (orders.isNotEmpty) {
          final lastOrderName = orders.last['name'] as String? ?? '';
          onProgress?.call(SyncProgress(
            total: totalRecords,
            synced: syncedCount,
            currentItem: lastOrderName,
          ));
        }

        logDebug('[SaleOrderSync] Batch complete: ${orders.length} sale orders (total: $syncedCount)');

        if (orders.length < batchSize) {
          hasMore = false;
        } else {
          offset += batchSize;
        }
      }

      onProgress?.call(SyncProgress(
        total: totalRecords,
        synced: syncedCount,
      ));

      logDebug('[SaleOrderSync] Synced $syncedCount sale orders total');

      // Resolve missing related records (products, partners, taxes, etc.)
      if (syncedCount > 0) {
        try {
          logDebug('[SaleOrderSync] Resolving missing related records...');
          final resolver = RelatedRecordResolver(odooClient: odooClient, db: appDb);

          // Get all synced orders and lines to extract IDs
          final orders = await _getLocalSaleOrders(limit: 1000);
      
          final allLines = await (appDb.select(appDb.saleOrderLine)).get();

          // Extract all related IDs from orders
          final partnerIds = orders.map((o) => o.partnerId).whereType<int>().toSet().toList();
          final pricelistIds = orders.map((o) => o.pricelistId).whereType<int>().toSet().toList();
          final paymentTermIds = orders.map((o) => o.paymentTermId).whereType<int>().toSet().toList();
          final warehouseIds = orders.map((o) => o.warehouseId).whereType<int>().toSet().toList();
          final userIds = orders.map((o) => o.userId).whereType<int>().toSet().toList();
          final teamIds = orders.map((o) => o.teamId).whereType<int>().toSet().toList();
          final fiscalPositionIds = orders.map((o) => o.fiscalPositionId).whereType<int>().toSet().toList();

          // Resolve order-level related records
          for (final partnerId in partnerIds) {
            await resolver.resolveForOrderIds(partnerId: partnerId);
          }
          for (final pricelistId in pricelistIds) {
            await resolver.resolveForOrderIds(pricelistId: pricelistId);
          }
          for (final paymentTermId in paymentTermIds) {
            await resolver.resolveForOrderIds(paymentTermId: paymentTermId);
          }
          for (final warehouseId in warehouseIds) {
            await resolver.resolveForOrderIds(warehouseId: warehouseId);
          }
          for (final userId in userIds) {
            await resolver.resolveForOrderIds(userId: userId);
          }
          for (final teamId in teamIds) {
            await resolver.resolveForOrderIds(teamId: teamId);
          }
          for (final fiscalPositionId in fiscalPositionIds) {
            await resolver.resolveForOrderIds(fiscalPositionId: fiscalPositionId);
          }

          // Resolve line-level related records in batch
          await resolver.resolveForLineIds(
            productIds: allLines.map((l) => l.productId).cast<int?>().toList(),
            taxIdsStrings: allLines.map((l) => l.taxIds).cast<String?>().toList(),
            uomIds: allLines.map((l) => l.productUomId).cast<int?>().toList(),
          );

          logDebug('[SaleOrderSync] ✅ Related records resolved');
        } catch (e) {
          logWarning('[SaleOrderSync] Error resolving related records: $e');
          // Non-fatal: continue even if related record resolution fails
        }
      }

      return syncedCount;
    } catch (e) {
      logError('[SaleOrderSync] Error syncing sale orders: $e (synced $syncedCount before error)');
      onProgress?.call(SyncProgress(
        total: totalRecords,
        synced: syncedCount,
        error: e.toString(),
      ));
      rethrow;
    }
  }

  /// Fetch sale orders with lines from Odoo and return the synced orders
  /// This is the unified method that replaces OdooRepository.syncSaleOrders()
  ///
  /// Features:
  /// - Syncs both headers AND lines (unlike deprecated OdooRepository.syncSaleOrders)
  /// - Supports filters: state, partnerId, allUsers
  /// - Returns `List<SaleOrderData>` for use with providers
  /// - Falls back to local cache if offline or on error
  Future<List<SaleOrderData>> fetchSaleOrdersWithLines({
    bool forceRefresh = false,
    bool allUsers = false,
    String? state,
    int? partnerId,
    int limit = 50,
  }) async {
    // Return cached if not forcing refresh and we have data
    if (!forceRefresh) {
      final cached = await _getLocalSaleOrders(
        state: state,
        partnerId: partnerId,
        limit: limit,
      );
      if (cached.isNotEmpty) {
        logDebug('[SaleOrderSync] Returning ${cached.length} cached sale orders');
        return cached;
      }
    }

    if (!isOnline) {
      logDebug('[SaleOrderSync] Offline - returning local sale orders');
      return _getLocalSaleOrders(state: state, partnerId: partnerId, limit: limit);
    }

    try {
      logDebug('[SaleOrderSync] Fetching sale orders from Odoo...');

      // Build domain
      final domain = <List<dynamic>>[];
      if (!allUsers) {
        // Get current user from local database
        final currentUser = await userManager.getCurrentUser();
        final uid = currentUser?.id;
        if (uid != null) {
          domain.add(['user_id', '=', uid]);
        }
      }
      if (state != null) {
        domain.add(['state', '=', state]);
      }
      if (partnerId != null) {
        domain.add(['partner_id', '=', partnerId]);
      }

      final data = await odooClient!.searchRead(
        model: 'sale.order',
        fields: _saleOrderAllFields,
        domain: domain,
        limit: limit,
        order: 'date_order desc',
      );

      if (data.isNotEmpty) {
        logDebug('[SaleOrderSync] Syncing ${data.length} sale orders with lines');

        for (final order in data) {
          await _upsertSaleOrder(order);

          // Sync lines for this order
          final orderLineIds = order['order_line'] as List? ?? [];
          if (orderLineIds.isNotEmpty) {
            await _syncSaleOrderLines(order['id'] as int, orderLineIds);
          }

          // Sync withhold lines for this order (Ecuador)
          final withholdLineIds = order['withhold_line_ids'] as List? ?? [];
          if (withholdLineIds.isNotEmpty) {
            await _syncSaleOrderWithholdLines(order['id'] as int, withholdLineIds);
          }
        }

        logInfo('[SaleOrderSync] Synced ${data.length} sale orders with lines');
      }

      // Return fresh data from local database
      return _getLocalSaleOrders(state: state, partnerId: partnerId, limit: limit);
    } catch (e) {
      logError('[SaleOrderSync] Error fetching sale orders: $e');
      // Fallback to local cache
      return _getLocalSaleOrders(state: state, partnerId: partnerId, limit: limit);
    }
  }

  /// Get sale orders from local database with optional filters
  Future<List<SaleOrderData>> _getLocalSaleOrders({
    String? state,
    int? partnerId,
    int limit = 50,
  }) async {

    var query = appDb.select(appDb.saleOrder);

    if (state != null) {
      query = query..where((t) => t.state.equals(state));
    }
    if (partnerId != null) {
      query = query..where((t) => t.partnerId.equals(partnerId));
    }

    return (query
          ..orderBy([(t) => OrderingTerm.desc(t.dateOrder)])
          ..limit(limit))
        .get();
  }

  /// Search sale orders in local database and sync from Odoo if online
  Future<List<SaleOrderData>> searchSaleOrdersWithLines(
    String query, {
    int limit = 20,
  }) async {
    if (query.isEmpty) return [];



    // First try to sync from Odoo if online
    if (isOnline) {
      try {
        logDebug('[SaleOrderSync] Searching sale orders in Odoo: "$query"');
        final data = await odooClient!.searchRead(
          model: 'sale.order',
          fields: _saleOrderAllFields,
          domain: [
            '|',
            '|',
            ['name', 'ilike', query],
            ['client_order_ref', 'ilike', query],
            ['partner_id.name', 'ilike', query],
          ],
          limit: limit,
          order: 'date_order desc',
        );

        if (data.isNotEmpty) {
          for (final order in data) {
            await _upsertSaleOrder(order);

            // Sync lines for this order
            final orderLineIds = order['order_line'] as List? ?? [];
            if (orderLineIds.isNotEmpty) {
              await _syncSaleOrderLines(order['id'] as int, orderLineIds);
            }

            // Sync withhold lines for this order (Ecuador)
            final withholdLineIds = order['withhold_line_ids'] as List? ?? [];
            if (withholdLineIds.isNotEmpty) {
              await _syncSaleOrderWithholdLines(order['id'] as int, withholdLineIds);
            }
          }
          logDebug('[SaleOrderSync] Synced ${data.length} search results with lines');
        }
      } catch (e) {
        logError('[SaleOrderSync] Error searching sale orders in Odoo: $e');
      }
    }

    // Search in local database
    final pattern = '%${query.toLowerCase()}%';
    return (appDb.select(appDb.saleOrder)
          ..where((t) =>
              t.name.lower().like(pattern) |
              t.clientOrderRef.lower().like(pattern) |
              t.partnerName.lower().like(pattern))
          ..orderBy([(t) => OrderingTerm.desc(t.dateOrder)])
          ..limit(limit))
        .get();
  }

  // ============ Private Helper Methods ============

  String _getDateNDaysAgo(int days) {
    final date = DateTime.now().subtract(Duration(days: days));
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _upsertSaleOrder(Map<String, dynamic> o) async {

    final odooId = o['id'] as int;

    final existing = await (appDb.select(appDb.saleOrder)
          ..where((t) => t.odooId.equals(odooId)))
        .getSingleOrNull();

    // Get partner details from local res_partner table
    final partnerId = extractId(o['partner_id']);
    String? partnerVat;
    String? partnerStreet;
    String? partnerPhone;
    String? partnerEmail;

    if (partnerId != null) {
      final partner = await (appDb.select(appDb.resPartner)
            ..where((t) => t.odooId.equals(partnerId)))
          .getSingleOrNull();
      if (partner != null) {
        partnerVat = partner.vat;
        partnerStreet = partner.street;
        partnerPhone = partner.phone;
        partnerEmail = partner.email;
      }
    }

    final companion = SaleOrderCompanion(
      odooId: Value(odooId),
      name: Value(o['name'] as String? ?? ''),
      state: Value(o['state'] as String? ?? 'draft'),
      dateOrder: Value(parseDateTime(o['date_order'])),
      validityDate: Value(parseDateTime(o['validity_date'])),
      commitmentDate: Value(parseDateTime(o['commitment_date'])),
      expectedDate: Value(parseDateTime(o['expected_date'])),
      partnerId: Value(partnerId),
      partnerName: Value(extractName(o['partner_id'])),
      partnerVat: Value(partnerVat),
      partnerStreet: Value(partnerStreet),
      partnerPhone: Value(partnerPhone),
      partnerEmail: Value(partnerEmail),
      partnerInvoiceId: Value(extractId(o['partner_invoice_id'])),
      partnerInvoiceAddress: Value(extractName(o['partner_invoice_id'])),
      partnerShippingId: Value(extractId(o['partner_shipping_id'])),
      partnerShippingAddress: Value(extractName(o['partner_shipping_id'])),
      // Final consumer fields (Consumidor Final)
      isFinalConsumer: Value(o['is_final_consumer'] == true),
      endCustomerName: Value(o['end_customer_name'] is String ? o['end_customer_name'] : null),
      endCustomerPhone: Value(o['end_customer_phone'] is String ? o['end_customer_phone'] : null),
      endCustomerEmail: Value(o['end_customer_email'] is String ? o['end_customer_email'] : null),
      userId: Value(extractId(o['user_id'])),
      userName: Value(extractName(o['user_id'])),
      teamId: Value(extractId(o['team_id'])),
      teamName: Value(extractName(o['team_id'])),
      companyId: Value(extractId(o['company_id'])),
      companyName: Value(extractName(o['company_id'])),
      warehouseId: Value(extractId(o['warehouse_id'])),
      warehouseName: Value(extractName(o['warehouse_id'])),
      pricelistId: Value(extractId(o['pricelist_id'])),
      pricelistName: Value(extractName(o['pricelist_id'])),
      currencyId: Value(extractId(o['currency_id'])),
      currencySymbol: Value(extractName(o['currency_id'])),
      currencyRate: Value((o['currency_rate'] as num?)?.toDouble() ?? 1.0),
      paymentTermId: Value(extractId(o['payment_term_id'])),
      paymentTermName: Value(extractName(o['payment_term_id'])),
      isCash: Value(o['is_cash'] == true),
      isCredit: Value(o['is_credit'] == true),
      fiscalPositionId: Value(extractId(o['fiscal_position_id'])),
      fiscalPositionName: Value(extractName(o['fiscal_position_id'])),
      amountUntaxed: Value((o['amount_untaxed'] as num?)?.toDouble() ?? 0.0),
      amountTax: Value((o['amount_tax'] as num?)?.toDouble() ?? 0.0),
      amountTotal: Value((o['amount_total'] as num?)?.toDouble() ?? 0.0),
      amountToInvoice: Value((o['amount_to_invoice'] as num?)?.toDouble() ?? 0.0),
      amountInvoiced: Value((o['amount_invoiced'] as num?)?.toDouble() ?? 0.0),
      // Discount fields from l10n_ec_sale_discount
      totalDiscountAmount: Value((o['total_discount_amount'] as num?)?.toDouble() ?? 0.0),
      totalAmountUndiscounted: Value((o['total_amount_undiscounted'] as num?)?.toDouble() ?? 0.0),
      invoiceStatus: Value(o['invoice_status'] as String? ?? 'no'),
      invoiceCount: Value(o['invoice_count'] as int? ?? 0),
      note: Value(o['note'] is String ? o['note'] : null),
      clientOrderRef: Value(o['client_order_ref'] is String ? o['client_order_ref'] : null),
      // Note: invoiceIds field removed from SaleOrder table
      // Invoice relationship is tracked via invoice.sale_order_id instead
      // invoiceIds: Value(
      //   (o['invoice_ids'] as List?)?.isNotEmpty == true
      //       ? jsonEncode((o['invoice_ids'] as List).cast<int>())
      //       : null,
      // ),
      writeDate: Value(parseDateTime(o['write_date'])),
      isSynced: const Value(true),
    );

    if (existing != null) {
      await (appDb.update(appDb.saleOrder)
            ..where((t) => t.odooId.equals(odooId)))
          .write(companion);
    } else {
      await appDb.into(appDb.saleOrder).insert(companion);
    }
  }

  // ============ Batch Sync Methods (FIX 2 — eliminan N+1 HTTP) ============

  /// Sync sale order lines for a batch of orders with a SINGLE HTTP request.
  ///
  /// Replaces N individual calls to _syncSaleOrderLines when processing a page
  /// of orders. Groups results by order_id in memory to preserve per-order
  /// cleanup semantics (delete obsolete lines only for orders in this batch).
  Future<void> _syncSaleOrderLinesBatch(List<int> orderIds) async {
    if (orderIds.isEmpty) return;
    try {
      final allLines = await odooClient!.searchRead(
        model: 'sale.order.line',
        domain: [
          ['order_id', 'in', orderIds],
        ],
        fields: [
          'id',
          'order_id',
          'name',
          'sequence',
          'product_id',
          'product_default_code',
          'product_uom_qty',
          'product_uom_id',
          'price_unit',
          'discount',
          'discount_amount',
          'price_subtotal',
          'price_tax',
          'price_total',
          'tax_ids',
          'qty_delivered',
          'qty_invoiced',
          'qty_to_invoice',
          'invoice_status',
          'display_type',
          'state',
          'write_date',
        ],
        order: 'order_id asc, sequence asc',
      );

      // Group lines by order_id for per-order processing
      final linesByOrder = <int, List<Map<String, dynamic>>>{};
      for (final line in allLines) {
        // order_id comes as [id, name] tuple
        final oid = extractId(line['order_id']) ?? (line['order_id'] as num?)?.toInt();
        if (oid == null) continue;
        linesByOrder.putIfAbsent(oid, () => []).add(line);
      }

      // Process each order's lines
      for (final orderId in orderIds) {
        final lines = linesByOrder[orderId] ?? [];
        await _upsertSaleOrderLinesForOrder(orderId, lines);
      }
    } catch (e) {
      logError('[SaleOrderSync] Error batch-syncing order lines: $e');
    }
  }

  /// Sync withhold lines for a batch of orders with a SINGLE HTTP request.
  Future<void> _syncSaleOrderWithholdLinesBatch(List<int> orderIds) async {
    if (orderIds.isEmpty) return;
    try {
      final allLines = await odooClient!.searchRead(
        model: 'sale.order.withhold.line',
        domain: [
          ['sale_id', 'in', orderIds],
        ],
        fields: [
          'id',
          'sale_id',
          'sequence',
          'tax_id',
          'taxsupport_code',
          'base',
          'amount',
          'notes',
          'write_date',
        ],
        order: 'sale_id asc, sequence asc',
      );

      // Group by sale_id (sale_id is [id, name] tuple)
      final linesByOrder = <int, List<Map<String, dynamic>>>{};
      for (final line in allLines) {
        final oid = extractId(line['sale_id']) ?? (line['sale_id'] as num?)?.toInt();
        if (oid == null) continue;
        linesByOrder.putIfAbsent(oid, () => []).add(line);
      }

      for (final orderId in orderIds) {
        final lines = linesByOrder[orderId] ?? [];
        await _upsertSaleOrderWithholdLinesForOrder(orderId, lines);
      }
    } catch (e) {
      logError('[SaleOrderSync] Error batch-syncing withhold lines: $e');
    }
  }

  // ============ Per-Order Upsert Helpers (FIX 3 — eliminan select N+1 local) ============

  /// Upsert sale order lines for one order using insertOrReplace (no select previo).
  ///
  /// FIX 3: Reemplaza el patrón select→decide→insert/update por un único
  /// insertOrReplace que usa odooId como clave de conflicto.
  Future<void> _upsertSaleOrderLinesForOrder(
    int orderId,
    List<Map<String, dynamic>> lines,
  ) async {
    try {
      for (final line in lines) {
        final lineId = line['id'] as int;

        String? taxIdsJson;
        final lineTaxIds = line['tax_ids'] as List?;
        if (lineTaxIds != null && lineTaxIds.isNotEmpty) {
          taxIdsJson = lineTaxIds.cast<int>().join(',');
        }

        final companion = SaleOrderLineCompanion(
          odooId: Value(lineId),
          orderId: Value(orderId),
          name: Value(line['name'] is String ? line['name'] as String : ''),
          sequence: Value(line['sequence'] as int? ?? 10),
          productId: Value(extractId(line['product_id'])),
          productName: Value(extractName(line['product_id'])),
          productCode: Value(line['product_default_code'] is String ? line['product_default_code'] as String : null),
          productUomQty: Value((line['product_uom_qty'] as num?)?.toDouble() ?? 0.0),
          productUomId: Value(extractId(line['product_uom_id'])),
          productUomName: Value(extractName(line['product_uom_id'])),
          priceUnit: Value((line['price_unit'] as num?)?.toDouble() ?? 0.0),
          discount: Value((line['discount'] as num?)?.toDouble() ?? 0.0),
          discountAmount: Value((line['discount_amount'] as num?)?.toDouble() ?? 0.0),
          priceSubtotal: Value((line['price_subtotal'] as num?)?.toDouble() ?? 0.0),
          priceTax: Value((line['price_tax'] as num?)?.toDouble() ?? 0.0),
          priceTotal: Value((line['price_total'] as num?)?.toDouble() ?? 0.0),
          taxIds: Value(taxIdsJson),
          qtyDelivered: Value((line['qty_delivered'] as num?)?.toDouble() ?? 0.0),
          qtyInvoiced: Value((line['qty_invoiced'] as num?)?.toDouble() ?? 0.0),
          displayType: Value(line['display_type'] is String ? line['display_type'] : ''),
          state: Value(line['state'] as String? ?? 'draft'),
          writeDate: Value(parseDateTime(line['write_date'])),
          isSynced: const Value(true),
        );

        await appDb.into(appDb.saleOrderLine).insertOnConflictUpdate(companion);
      }

      // Delete local lines for this order that no longer exist in Odoo
      final remoteIds = lines.map((l) => l['id'] as int).toList();
      final localLines = await (appDb.select(appDb.saleOrderLine)
            ..where((t) => t.orderId.equals(orderId)))
          .get();

      int deletedCount = 0;
      for (final localLine in localLines) {
        if (localLine.odooId != null && !remoteIds.contains(localLine.odooId)) {
          await (appDb.delete(appDb.saleOrderLine)
                ..where((t) => t.id.equals(localLine.id)))
              .go();
          deletedCount++;
        }
      }

      if (deletedCount > 0) {
        logDebug('[SaleOrderSync] Cleaned up $deletedCount obsolete lines for order $orderId');
      }
    } catch (e) {
      logError('[SaleOrderSync] Error upserting lines for order $orderId: $e');
    }
  }

  /// Upsert withhold lines for one order using insertOrReplace (no select previo).
  Future<void> _upsertSaleOrderWithholdLinesForOrder(
    int orderId,
    List<Map<String, dynamic>> lines,
  ) async {
    try {
      for (final line in lines) {
        final lineId = line['id'] as int;

        final taxId = extractId(line['tax_id']);
        final taxName = extractName(line['tax_id']) ?? '';

        String withholdType = 'withhold_income_sale';
        double taxPercent = 0.0;

        if (taxName.toLowerCase().contains('iva')) {
          withholdType = 'withhold_vat_sale';
        }
        final percentMatch = RegExp(r'(\d+(?:[.,]\d+)?)\s*%').firstMatch(taxName);
        if (percentMatch != null) {
          taxPercent = (double.tryParse(percentMatch.group(1)!.replaceAll(',', '.')) ?? 0) / 100;
        }

        final companion = SaleOrderWithholdLineCompanion(
          odooId: Value(lineId),
          orderId: Value(orderId),
          sequence: Value(line['sequence'] as int? ?? 10),
          taxId: Value(taxId ?? 0),
          taxName: Value(taxName),
          taxPercent: Value(taxPercent),
          withholdType: Value(withholdType),
          taxsupportCode: Value(line['taxsupport_code'] is String ? line['taxsupport_code'] : null),
          base: Value((line['base'] as num?)?.toDouble() ?? 0.0),
          amount: Value((line['amount'] as num?)?.toDouble() ?? 0.0),
          notes: Value(line['notes'] is String ? line['notes'] : null),
          writeDate: Value(parseDateTime(line['write_date'])),
          isSynced: const Value(true),
          lastSyncDate: Value(DateTime.now()),
        );

        await appDb.into(appDb.saleOrderWithholdLine).insertOnConflictUpdate(companion);
      }

      // Delete local withhold lines that no longer exist in Odoo
      final remoteIds = lines.map((l) => l['id'] as int).toList();
      final localLines = await (appDb.select(appDb.saleOrderWithholdLine)
            ..where((t) => t.orderId.equals(orderId)))
          .get();

      for (final localLine in localLines) {
        if (localLine.odooId != null && !remoteIds.contains(localLine.odooId)) {
          await (appDb.delete(appDb.saleOrderWithholdLine)
                ..where((t) => t.id.equals(localLine.id)))
              .go();
        }
      }
    } catch (e) {
      logError('[SaleOrderSync] Error upserting withhold lines for order $orderId: $e');
    }
  }

  // ============ Single-Order Sync Methods (used by fetchSaleOrdersWithLines / searchSaleOrdersWithLines) ============

  Future<void> _syncSaleOrderLines(int orderId, List orderLineIds) async {
    try {
      final lines = await odooClient!.searchRead(
        model: 'sale.order.line',
        domain: [
          ['order_id', '=', orderId],
        ],
        fields: [
          'id',
          'name',
          'sequence',
          'product_id',
          'product_default_code', // product internal reference
          'product_uom_qty',
          'product_uom_id', // Odoo 18/19: renamed from product_uom
          'price_unit',
          'discount',
          'discount_amount', // l10n_ec_sale_discount: monto de descuento calculado
          'price_subtotal',
          'price_tax',
          'price_total',
          'tax_ids', // Odoo 18/19: renamed from tax_id
          'qty_delivered',
          'qty_invoiced',
          'qty_to_invoice',
          'invoice_status',
          'display_type',
          'state',
          'write_date',
        ],
        order: 'sequence asc',
      );

  

      // FIX 3: Use insertOnConflictUpdate — eliminates a SELECT per line
      for (final line in lines) {
        final lineId = line['id'] as int;

        // Build taxIds JSON from tax_ids (Odoo 18/19: renamed from tax_id)
        String? taxIdsJson;
        final lineTaxIds = line['tax_ids'] as List?;
        if (lineTaxIds != null && lineTaxIds.isNotEmpty) {
          taxIdsJson = lineTaxIds.cast<int>().join(',');
        }

        final companion = SaleOrderLineCompanion(
          odooId: Value(lineId),
          orderId: Value(orderId),
          name: Value(line['name'] is String ? line['name'] as String : ''),
          sequence: Value(line['sequence'] as int? ?? 10),
          productId: Value(extractId(line['product_id'])),
          productName: Value(extractName(line['product_id'])),
          productCode: Value(line['product_default_code'] is String ? line['product_default_code'] as String : null),
          productUomQty: Value((line['product_uom_qty'] as num?)?.toDouble() ?? 0.0),
          productUomId: Value(extractId(line['product_uom_id'])),
          productUomName: Value(extractName(line['product_uom_id'])),
          priceUnit: Value((line['price_unit'] as num?)?.toDouble() ?? 0.0),
          discount: Value((line['discount'] as num?)?.toDouble() ?? 0.0),
          discountAmount: Value((line['discount_amount'] as num?)?.toDouble() ?? 0.0),
          priceSubtotal: Value((line['price_subtotal'] as num?)?.toDouble() ?? 0.0),
          priceTax: Value((line['price_tax'] as num?)?.toDouble() ?? 0.0),
          priceTotal: Value((line['price_total'] as num?)?.toDouble() ?? 0.0),
          taxIds: Value(taxIdsJson),
          qtyDelivered: Value((line['qty_delivered'] as num?)?.toDouble() ?? 0.0),
          qtyInvoiced: Value((line['qty_invoiced'] as num?)?.toDouble() ?? 0.0),
          displayType: Value(line['display_type'] is String ? line['display_type'] : ''),
          state: Value(line['state'] as String? ?? 'draft'),
          writeDate: Value(parseDateTime(line['write_date'])),
          isSynced: const Value(true),
        );

        await appDb.into(appDb.saleOrderLine).insertOnConflictUpdate(companion);
      }

      // Clean up obsolete lines: delete local lines that no longer exist in Odoo
      final remoteIds = lines.map((l) => l['id'] as int).toList();
      final localLines = await (appDb.select(appDb.saleOrderLine)
            ..where((t) => t.orderId.equals(orderId)))
          .get();

      int deletedCount = 0;
      for (final localLine in localLines) {
        if (localLine.odooId != null && !remoteIds.contains(localLine.odooId)) {
          await (appDb.delete(appDb.saleOrderLine)
                ..where((t) => t.id.equals(localLine.id)))
              .go();
          deletedCount++;
        }
      }

      if (deletedCount > 0) {
        logDebug('[SaleOrderSync] Cleaned up $deletedCount obsolete lines for order $orderId');
      }
    } catch (e) {
      logError('[SaleOrderSync] Error syncing lines for order $orderId: $e');
    }
  }

  /// Sync withhold lines for a specific sale order from Odoo
  /// Similar to _syncSaleOrderLines but for Ecuador tax withholdings
  Future<void> _syncSaleOrderWithholdLines(int orderId, List withholdLineIds) async {
    if (withholdLineIds.isEmpty) return;

    try {
      final lines = await odooClient!.searchRead(
        model: 'sale.order.withhold.line',
        domain: [
          ['sale_id', '=', orderId],
        ],
        fields: [
          'id',
          'sale_id',
          'sequence',
          'tax_id',
          'taxsupport_code',
          'base',
          'amount',
          'notes',
          'write_date',
        ],
        order: 'sequence asc',
      );

  

      // FIX 3: Use insertOnConflictUpdate — eliminates a SELECT per line
      for (final line in lines) {
        final lineId = line['id'] as int;

        // Extract tax info (tax_id is [id, name] tuple in Odoo)
        final taxId = extractId(line['tax_id']);
        final taxName = extractName(line['tax_id']) ?? '';

        // Determine withhold type and percentage from tax name
        // e.g., "Ret. IVA 30%" -> type: withhold_vat_sale, percent: 0.30
        String withholdType = 'withhold_income_sale';
        double taxPercent = 0.0;

        if (taxName.toLowerCase().contains('iva')) {
          withholdType = 'withhold_vat_sale';
        }
        // Extract percentage from tax name if present
        final percentMatch = RegExp(r'(\d+(?:[.,]\d+)?)\s*%').firstMatch(taxName);
        if (percentMatch != null) {
          taxPercent = (double.tryParse(percentMatch.group(1)!.replaceAll(',', '.')) ?? 0) / 100;
        }

        final companion = SaleOrderWithholdLineCompanion(
          odooId: Value(lineId),
          orderId: Value(orderId),
          sequence: Value(line['sequence'] as int? ?? 10),
          taxId: Value(taxId ?? 0),
          taxName: Value(taxName),
          taxPercent: Value(taxPercent),
          withholdType: Value(withholdType),
          taxsupportCode: Value(line['taxsupport_code'] is String ? line['taxsupport_code'] : null),
          base: Value((line['base'] as num?)?.toDouble() ?? 0.0),
          amount: Value((line['amount'] as num?)?.toDouble() ?? 0.0),
          notes: Value(line['notes'] is String ? line['notes'] : null),
          writeDate: Value(parseDateTime(line['write_date'])),
          isSynced: const Value(true),
          lastSyncDate: Value(DateTime.now()),
        );

        await appDb.into(appDb.saleOrderWithholdLine).insertOnConflictUpdate(companion);
      }

      // Delete local withhold lines that no longer exist in Odoo
      final remoteIds = lines.map((l) => l['id'] as int).toList();
      final localLines = await (appDb.select(appDb.saleOrderWithholdLine)
            ..where((t) => t.orderId.equals(orderId)))
          .get();

      for (final localLine in localLines) {
        if (localLine.odooId != null && !remoteIds.contains(localLine.odooId)) {
          await (appDb.delete(appDb.saleOrderWithholdLine)
                ..where((t) => t.id.equals(localLine.id)))
              .go();
        }
      }

      logDebug('[SaleOrderSync] Synced ${lines.length} withhold lines for order $orderId');
    } catch (e) {
      logError('[SaleOrderSync] Error syncing withhold lines for order $orderId: $e');
    }
  }

  /// Sync invoices and their lines for a sale order
  ///
  /// Uses InvoiceRepository to fetch invoices by IDs and save them to local database
  /// with their lines, following the same pattern as payment lines synchronization
  Future<void> _syncSaleOrderInvoices(int orderId, List<int> invoiceIds) async {
    if (invoiceIds.isEmpty || odooClient == null) return;

    try {
      logDebug('[SaleOrderSync] Syncing ${invoiceIds.length} invoices for order $orderId');

      // Use InvoiceRepository to sync invoices with their lines
      // F5: InvoiceRepository ya no recibe OdooClient (usa managers
      // internamente) — este repo (sale_order_sync_repository.dart) sigue
      // usando su propio odooClient para el resto de sus operaciones, fuera
      // de alcance de esta fase.
      final invoiceRepository = InvoiceRepository(
        productRepository: _productRepository,
        appDb: appDb,
      );

      // Fetch invoices by IDs (this will also sync their lines)
      await invoiceRepository.getInvoicesByIds(
        invoiceIds,
        forceRefresh: true,
        saleOrderId: orderId,
      );

      logDebug('[SaleOrderSync] Synced ${invoiceIds.length} invoices with lines for order $orderId');
    } catch (e) {
      logError('[SaleOrderSync] Error syncing invoices for order $orderId: $e');
      // Non-fatal: continue even if invoice sync fails
    }
  }
}
