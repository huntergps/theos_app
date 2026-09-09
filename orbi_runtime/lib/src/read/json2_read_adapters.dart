import 'package:theos_pos_core/theos_pos_core.dart';

import '../contracts.dart';
import '../session/session_runtime.dart';
import '../sync/catalog_sync.dart';

/// The only JSON-2 read surface used by runtime catalog/order adapters.
/// It deliberately returns raw records: concrete local stores own models/schema.
abstract interface class Json2ReadPort {
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
  });
}

/// Optional metadata surface used to validate read contracts before a runtime
/// reader is enabled against a new Odoo deployment.  Keeping it separate from
/// [Json2ReadPort] preserves small in-memory readers used by offline tests.
abstract interface class Json2FieldsGetPort {
  Future<Map<String, dynamic>> fieldsGet({
    required String model,
    required List<String> fields,
  });
}

final class OdooJson2ReadPort implements Json2ReadPort, Json2FieldsGetPort {
  final OdooClient client;
  const OdooJson2ReadPort(this.client);

  @override
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
  }) => client.searchRead(
    model: model,
    fields: fields,
    domain: domain,
    limit: limit,
    offset: offset,
    order: order,
  );

  @override
  Future<Map<String, dynamic>> fieldsGet({
    required String model,
    required List<String> fields,
  }) => client.fieldsGet(model: model, fields: fields);
}

/// Binds reads to the currently activated scope/epoch. A stale lease cannot
/// publish records into a newly activated company or user scope.
final class SessionJson2Reader {
  final SessionRuntime sessions;
  const SessionJson2Reader(this.sessions);

  Future<List<Map<String, dynamic>>> searchRead({
    required SessionLease lease,
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
  }) async {
    final activation = sessions.active;
    if (activation == null || !sessions.accepts(lease)) {
      throw StateError('Session lease is no longer active');
    }
    final client = activation.client;
    if (client == null) throw StateError('Online session is not authenticated');
    return OdooJson2ReadPort(client).searchRead(
      model: model,
      fields: fields,
      domain: domain,
      limit: limit,
      offset: offset,
      order: order,
    );
  }
}

final class RuntimeCatalogDescriptor {
  const RuntimeCatalogDescriptor({
    required this.key,
    required this.model,
    required this.fields,
    this.domain = const [],
    this.order = 'id asc',
  });
  final String key;
  final String model;
  final List<String> fields;
  final List<dynamic> domain;
  final String order;
}

/// Essential catalog reads. The local store decides which generated model to
/// parse and persist; no runtime schema or bank model is introduced here.
abstract final class RuntimeCatalogs {
  static const cardBrands = RuntimeCatalogDescriptor(
    key: 'card_brands',
    model: 'account.card.brand',
    fields: PaymentConfigRecordMapper.cardBrandFields,
    order: 'name asc,id asc',
  );
  static const cardDeadlines = RuntimeCatalogDescriptor(
    key: 'card_deadlines',
    model: 'account.card.deadline',
    fields: PaymentConfigRecordMapper.cardDeadlineFields,
    order: 'name asc,id asc',
  );
  static const cardLotes = RuntimeCatalogDescriptor(
    key: 'card_lotes',
    model: 'account.card.lote',
    fields: PaymentConfigRecordMapper.cardLoteFields,
    order: 'id asc',
  );
  static const paymentMethodLines = RuntimeCatalogDescriptor(
    key: 'payment_method_lines',
    model: 'account.payment.method.line',
    fields: PaymentConfigRecordMapper.paymentMethodLineFields,
    order: 'id asc',
  );
  static const customers = RuntimeCatalogDescriptor(
    key: 'customers',
    model: 'res.partner',
    fields: ['id', 'name', 'vat', 'email', 'phone', 'company_id', 'active'],
    domain: [
      ['customer_rank', '>', 0],
      ['active', '=', true],
    ],
    order: 'name asc,id asc',
  );
  static const products = RuntimeCatalogDescriptor(
    key: 'products',
    model: 'product.product',
    fields: [
      'id',
      'name',
      'default_code',
      'barcode',
      'list_price',
      'uom_id',
      'taxes_id',
      'active',
    ],
    domain: [
      ['sale_ok', '=', true],
      ['active', '=', true],
    ],
    order: 'name asc,id asc',
  );
  static const paymentTerms = RuntimeCatalogDescriptor(
    key: 'payment_terms',
    model: 'account.payment.term',
    fields: ['id', 'name', 'line_ids', 'active'],
    order: 'name asc,id asc',
  );
  static const uoms = RuntimeCatalogDescriptor(
    key: 'uoms',
    model: 'uom.uom',
    fields: ['id', 'name', 'factor', 'rounding', 'active', 'write_date'],
    domain: [
      ['active', '=', true],
    ],
    order: 'name asc,id asc',
  );
  static const collectionConfigs = RuntimeCatalogDescriptor(
    key: 'collection_configs',
    model: 'collection.config',
    fields: [
      'id',
      'name',
      'code',
      'active',
      'company_id',
      'journal_id',
      'cash_journal_id',
      'allowed_journal_ids',
      'cash_difference_account_id',
      'set_maximum_difference',
      'amount_authorized_diff',
      'user_ids',
      'current_session_id',
      'current_session_state',
      'current_session_name',
      'number_of_opened_session',
      'last_session_closing_date',
      'last_session_closing_cash',
      'collection_session_username',
      'current_session_state_display',
      'number_of_rescue_session',
      'write_date',
    ],
    order: 'id asc',
  );
  static const collectionSessions = RuntimeCatalogDescriptor(
    key: 'collection_sessions',
    model: 'collection.session',
    fields: [
      'id',
      'session_uuid',
      'name',
      'state',
      'config_id',
      'company_id',
      'user_id',
      'currency_id',
      'currency_symbol',
      'cash_journal_id',
      'start_at',
      'stop_at',
      'cash_register_balance_start',
      'cash_register_balance_end_real',
      'cash_register_balance_end',
      'cash_register_difference',
      'total_payments_amount',
      'write_date',
    ],
    order: 'id asc',
  );
  static const taxes = RuntimeCatalogDescriptor(
    key: 'taxes',
    model: 'account.tax',
    fields: [
      'id',
      'name',
      'amount',
      'amount_type',
      'price_include',
      'company_id',
      'active',
    ],
    domain: [
      ['active', '=', true],
    ],
    order: 'sequence asc,id asc',
  );
  static const pricelists = RuntimeCatalogDescriptor(
    key: 'pricelists',
    model: 'product.pricelist',
    fields: ['id', 'name', 'currency_id', 'company_id', 'active'],
    order: 'name asc,id asc',
  );
  static const warehouses = RuntimeCatalogDescriptor(
    key: 'warehouses',
    model: 'stock.warehouse',
    fields: ['id', 'name', 'code', 'company_id', 'active'],
    order: 'name asc,id asc',
  );
  static const journals = RuntimeCatalogDescriptor(
    key: 'journals',
    model: 'account.journal',
    fields: ['id', 'name', 'type', 'company_id', 'active'],
    domain: [
      [
        'type',
        'in',
        ['cash', 'bank'],
      ],
      ['active', '=', true],
    ],
    order: 'name asc,id asc',
  );
}

final class RuntimeCatalogLoader {
  final Json2ReadPort reader;
  final int pageSize;
  const RuntimeCatalogLoader(this.reader, {this.pageSize = 100});

  CatalogLoader<Map<String, dynamic>> loader(
    RuntimeCatalogDescriptor descriptor,
  ) => (scope, cursor) async {
    final offset = int.tryParse(cursor ?? '0') ?? 0;
    final rows = await reader.searchRead(
      model: descriptor.model,
      fields: descriptor.fields,
      domain: descriptor.domain,
      limit: pageSize,
      offset: offset,
      order: descriptor.order,
    );
    return CatalogBatch(
      records: rows
          .map((row) {
            final id = row['id'];
            if (id is! int || id <= 0) {
              throw FormatException('Invalid ${descriptor.key} id');
            }
            return CatalogRecord(
              uuid: '${scope.scopeKey}:${descriptor.key}:$id',
              value: row,
            );
          })
          .toList(growable: false),
      cursor: rows.length < pageSize ? null : '${offset + rows.length}',
    );
  };
}

/// Fields that are real on the deployed sale/order and accounting models.
///
/// `payment_state` belongs to `account.move`, not `sale.order`.  Likewise,
/// `amount_to_invoice` is a readable but non-stored sale-order compute and
/// therefore must never be placed in a remote domain.  The remaining summary
/// fields used by the local cache are derived by [RuntimeOrderRemoteState].
abstract final class RuntimeOrderRemoteFields {
  static const saleOrder = [
    'id',
    'name',
    'client_order_ref',
    'state',
    'locked',
    'user_id',
    'partner_id',
    'amount_total',
    'invoice_status',
    'amount_to_invoice',
    'invoice_ids',
    'picking_ids',
    'date_order',
    'company_id',
  ];

  static const invoice = ['id', 'state', 'payment_state', 'amount_residual'];

  static const paymentLine = [
    'id',
    'sale_id',
    // This is a computed, non-stored field on the native payment-line model.
    // It is intentionally read and filtered locally, never used in a domain.
    'state',
    'move_id',
    'amount',
  ];

  /// Validates the exact fields requested by the reader against a JSON-2
  /// `fields_get` response.  The server may return extra metadata, but every
  /// requested field must be present before the reader can rely on it.
  static void assertReadable(
    String model,
    List<String> requested,
    Map<String, dynamic> metadata,
  ) {
    final missing = requested
        .where((field) => !metadata.containsKey(field))
        .toList(growable: false);
    if (missing.isNotEmpty) {
      throw StateError(
        'Odoo read contract for $model is missing: ${missing.join(', ')}',
      );
    }
  }
}

/// Enriches sale orders from native invoices/payment lines without pretending
/// that local summary columns are searchable Odoo fields.  The returned
/// summary keys intentionally retain the local-cache contract so callers do
/// not need a second representation of an order.
final class RuntimeOrderRemoteState {
  const RuntimeOrderRemoteState(this.reader);

  final Json2ReadPort reader;

  Future<List<Map<String, dynamic>>> enrich(
    List<Map<String, dynamic>> orders,
  ) async {
    if (orders.isEmpty) return const [];
    final orderIds = <int>{};
    for (final order in orders) {
      final id = _positiveInt(order['id']);
      if (id != null) orderIds.add(id);
    }
    final invoiceIds = <int>{};
    for (final order in orders) {
      invoiceIds.addAll(_manyIds(order['invoice_ids']));
    }
    final invoices = invoiceIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _readAll(
            model: 'account.move',
            fields: RuntimeOrderRemoteFields.invoice,
            domain: [
              ['id', 'in', invoiceIds.toList()..sort()],
            ],
          );
    final paymentLines = orderIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _readAll(
            model: 'l10n_ec_collection_box.sale.order.payment',
            fields: RuntimeOrderRemoteFields.paymentLine,
            domain: [
              ['sale_id', 'in', orderIds.toList()..sort()],
            ],
          );
    final invoicesById = <int, Map<String, dynamic>>{};
    for (final invoice in invoices) {
      final id = _positiveInt(invoice['id']);
      if (id != null) invoicesById[id] = invoice;
    }
    final paymentsBySale = <int, List<Map<String, dynamic>>>{};
    for (final payment in paymentLines) {
      final saleId = _positiveInt(_many2oneId(payment['sale_id']));
      if (saleId == null) continue;
      (paymentsBySale[saleId] ??= []).add(payment);
    }
    return [
      for (final source in orders)
        _withDerivedState(
          source,
          invoicesById,
          paymentsBySale[_positiveInt(source['id'])] ?? const [],
        ),
    ];
  }

  static Map<String, dynamic> _withDerivedState(
    Map<String, dynamic> source,
    Map<int, Map<String, dynamic>> invoicesById,
    List<Map<String, dynamic>> paymentLines,
  ) {
    final invoices = <Map<String, dynamic>>[];
    for (final id in _manyIds(source['invoice_ids'])) {
      final invoice = invoicesById[id];
      if (invoice != null) invoices.add(invoice);
    }
    var amountUnpaid = 0.0;
    final paymentStates = <String>{};
    for (final invoice in invoices) {
      if (invoice['state'] == 'cancel') continue;
      final residual = _number(invoice['amount_residual']);
      if (residual > 0) amountUnpaid += residual;
      final state = invoice['payment_state'];
      if (state is String && state.isNotEmpty) paymentStates.add(state);
    }
    final paymentState = _aggregatePaymentState(paymentStates);
    final hasNativePendingPayment = paymentLines.any((line) {
      final state = line['state'];
      // A posted line is already accounted for. Only a draft line without
      // its native move is still pending; cancelled and posted lines must not
      // make a fully paid order appear in the cashier queue.
      return state == 'draft' &&
          _many2oneId(line['move_id']) == null &&
          _number(line['amount']) > 0;
    });
    final amountToInvoice = _number(source['amount_to_invoice']);
    final invoiceStatus = source['invoice_status'];
    final pendingCollection =
        amountUnpaid > 0.01 ||
        const {'not_paid', 'partial', 'in_payment'}.contains(paymentState) ||
        hasNativePendingPayment;
    final pendingInvoicing =
        amountToInvoice > 0.01 ||
        invoiceStatus == 'to invoice' ||
        invoiceStatus == 'upselling';
    return {
      ...source,
      'payment_state': paymentState,
      'amount_unpaid': amountUnpaid,
      // No server field exists for this local queue marker. Preserve it when
      // a caller enriches an already-local row; refreshOnline also omits this
      // column from the conflict update so remote reads cannot clear it.
      'has_queued_invoice': source['has_queued_invoice'] == true,
      '_runtime_pending_collection': pendingCollection,
      '_runtime_pending_invoicing': pendingInvoicing,
    };
  }

  static bool isCashierPending(Map<String, dynamic> row) =>
      row['_runtime_pending_collection'] == true ||
      row['_runtime_pending_invoicing'] == true;

  static String? _aggregatePaymentState(Set<String> states) {
    if (states.contains('in_payment')) return 'in_payment';
    if (states.contains('partial')) return 'partial';
    if (states.contains('not_paid')) return 'not_paid';
    if (states.contains('paid')) return 'paid';
    return null;
  }

  Future<List<Map<String, dynamic>>> _readAll({
    required String model,
    required List<String> fields,
    required List<dynamic> domain,
  }) async {
    const pageSize = 200;
    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await reader.searchRead(
        model: model,
        fields: fields,
        domain: domain,
        limit: pageSize,
        offset: offset,
        order: 'id asc',
      );
      if (page.isEmpty) break;
      rows.addAll(page);
      if (page.length < pageSize) break;
      offset += page.length;
    }
    return rows;
  }

  static double _number(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : 0;

  static int? _positiveInt(Object? value) {
    if (value is int && value > 0) return value;
    if (value is num && value.isFinite && value > 0) return value.toInt();
    return null;
  }

  static int? _many2oneId(Object? value) {
    if (value is List && value.isNotEmpty) return _positiveInt(value.first);
    return _positiveInt(value);
  }

  static Set<int> _manyIds(Object? value) {
    if (value is! List) return const {};
    final ids = <int>{};
    for (final item in value) {
      final directId = _positiveInt(item);
      if (directId != null) {
        ids.add(directId);
      } else if (item is List && item.isNotEmpty) {
        final pairId = _positiveInt(item.first);
        if (pairId != null) ids.add(pairId);
      }
    }
    return ids;
  }
}

final class RuntimeOrderReader {
  final Json2ReadPort reader;
  const RuntimeOrderReader(this.reader);

  /// Performs the read-only JSON-2 contract probe used when activating a new
  /// Odoo scope. This is intentionally explicit (rather than on every page)
  /// because `fields_get` is metadata I/O and the SDK/client owns its cache.
  Future<void> validateRemoteContract() async {
    if (reader is! Json2FieldsGetPort) {
      throw StateError('Odoo reader does not expose fields_get');
    }
    final metadataReader = reader as Json2FieldsGetPort;
    final contracts = <String, List<String>>{
      'sale.order': RuntimeOrderRemoteFields.saleOrder,
      'account.move': RuntimeOrderRemoteFields.invoice,
      'l10n_ec_collection_box.sale.order.payment':
          RuntimeOrderRemoteFields.paymentLine,
    };
    for (final entry in contracts.entries) {
      final metadata = await metadataReader.fieldsGet(
        model: entry.key,
        fields: entry.value,
      );
      RuntimeOrderRemoteFields.assertReadable(entry.key, entry.value, metadata);
    }
  }

  Future<List<Map<String, dynamic>>> read(OrderQuery query) async {
    final domain = _domain(query);
    final state = RuntimeOrderRemoteState(reader);
    if (query.workQueue != OrderWorkQueue.cashierPending) {
      final rows = await reader.searchRead(
        model: 'sale.order',
        fields: RuntimeOrderRemoteFields.saleOrder,
        domain: domain,
        limit: query.limit,
        order: query.stableOrder,
      );
      return state.enrich(rows);
    }

    // Cashier state is derived from native account.move/payment rows. Keep
    // fetching stable pages until the requested number of pending orders is
    // found or Odoo proves that there are no more orders.
    const pageSize = 100;
    final pending = <Map<String, dynamic>>[];
    var offset = 0;
    while (pending.length < query.limit) {
      final page = await reader.searchRead(
        model: 'sale.order',
        fields: RuntimeOrderRemoteFields.saleOrder,
        domain: domain,
        limit: pageSize,
        offset: offset,
        order: query.stableOrder,
      );
      if (page.isEmpty) break;
      final enriched = await state.enrich(page);
      pending.addAll(enriched.where(RuntimeOrderRemoteState.isCashierPending));
      if (page.length < pageSize) break;
      offset += page.length;
    }
    return pending.take(query.limit).toList(growable: false);
  }

  static List<dynamic> _domain(OrderQuery query) {
    final domain = <dynamic>[
      ['company_id', '=', query.companyId],
    ];
    if (query.workQueue == OrderWorkQueue.cashierPending) {
      // The cashier predicate is derived after reading native invoices and
      // payment lines. These local summary fields are not remote fields.
      domain.add(['state', '=', SaleOrderState.sale.code]);
    }
    if (query.states.isNotEmpty) {
      domain.add([
        'state',
        'in',
        query.states.map((state) => state.code).toList(growable: false),
      ]);
    }
    if (query.workQueue != OrderWorkQueue.cashierPending &&
        query.authorFilter != null) {
      domain.add(['user_id', '=', query.authorFilter]);
    }
    if (query.text case final text? when text.trim().isNotEmpty) {
      domain.add('|');
      domain.add(['name', 'ilike', text.trim()]);
      domain.add(['client_order_ref', 'ilike', text.trim()]);
    }
    if (query.dateFrom != null) {
      domain.add(['date_order', '>=', query.dateFrom!.toIso8601String()]);
    }
    if (query.dateTo != null) {
      domain.add(['date_order', '<=', query.dateTo!.toIso8601String()]);
    }
    if (query.afterId != null) domain.add(['id', '<', query.afterId]);
    return domain;
  }
}
