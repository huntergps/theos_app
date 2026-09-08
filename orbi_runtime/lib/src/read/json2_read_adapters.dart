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

final class OdooJson2ReadPort implements Json2ReadPort {
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

final class RuntimeOrderReader {
  final Json2ReadPort reader;
  const RuntimeOrderReader(this.reader);

  Future<List<Map<String, dynamic>>> read(OrderQuery query) {
    final domain = <dynamic>[
      ['company_id', '=', query.companyId],
    ];
    if (query.workQueue == OrderWorkQueue.cashierPending) {
      domain.addAll([
        ['state', '=', SaleOrderState.sale.code],
        '|',
        '|',
        '|',
        ['amount_unpaid', '>', 0],
        [
          'payment_state',
          'in',
          ['not_paid', 'partial', 'in_payment'],
        ],
        ['amount_to_invoice', '>', 0],
        ['has_queued_invoice', '=', true],
      ]);
    } else {
      if (query.authorFilter != null) {
        domain.add(['user_id', '=', query.authorFilter]);
      }
      if (query.states.isNotEmpty) {
        domain.add(['state', 'in', query.states.map((s) => s.code).toList()]);
      }
    }
    if (query.afterId != null) domain.add(['id', '<', query.afterId]);
    if (query.text case final text? when text.trim().isNotEmpty) {
      domain.add(['name', 'ilike', text.trim()]);
    }
    if (query.dateFrom != null) {
      domain.add(['date_order', '>=', query.dateFrom!.toIso8601String()]);
    }
    if (query.dateTo != null) {
      domain.add(['date_order', '<=', query.dateTo!.toIso8601String()]);
    }
    return reader.searchRead(
      model: 'sale.order',
      fields: [
        'id',
        'name',
        'state',
        'locked',
        'user_id',
        'partner_id',
        'amount_total',
        'invoice_status',
        'payment_state',
        'amount_unpaid',
        'amount_to_invoice',
        'has_queued_invoice',
        'date_order',
        'company_id',
      ],
      domain: domain,
      limit: query.limit,
      order: query.stableOrder,
    );
  }
}
