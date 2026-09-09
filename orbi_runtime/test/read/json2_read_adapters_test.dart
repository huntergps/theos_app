import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

class _Reader implements Json2ReadPort, Json2FieldsGetPort {
  String? model;
  List<dynamic>? domain;
  int? limit;
  int? offset;
  final calls =
      <
        ({
          String model,
          List<String> fields,
          List<dynamic>? domain,
          int? limit,
          int? offset,
          String? order,
        })
      >[];
  Map<String, List<Map<String, dynamic>>> records = {};

  @override
  Future<Map<String, dynamic>> fieldsGet({
    required String model,
    required List<String> fields,
  }) async => {for (final field in fields) field: <String, dynamic>{}};
  @override
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
  }) async {
    this.model = model;
    this.domain = domain;
    this.limit = limit;
    this.offset = offset;
    calls.add((
      model: model,
      fields: fields,
      domain: domain,
      limit: limit,
      offset: offset,
      order: order,
    ));
    final source = records[model] ?? _defaultRecords(model);
    if (!records.containsKey(model)) return source;
    final start = offset ?? 0;
    if (start >= source.length) return const [];
    final end = limit == null
        ? source.length
        : (start + limit).clamp(start, source.length);
    return source.sublist(start, end);
  }

  List<Map<String, dynamic>> _defaultRecords(String model) {
    if (model == 'sale.order') {
      return [
        {
          'id': 7,
          'name': 'A',
          'state': 'sale',
          'company_id': 4,
          'invoice_ids': [101],
          'invoice_status': 'invoiced',
          'amount_to_invoice': 0,
        },
      ];
    }
    if (model == 'account.move') {
      return [
        {
          'id': 101,
          'state': 'posted',
          'payment_state': 'not_paid',
          'amount_residual': 5.0,
        },
      ];
    }
    if (model == 'l10n_ec_collection_box.sale.order.payment') {
      return const [];
    }
    return const [
      <String, dynamic>{'id': 7, 'name': 'A'},
    ];
  }
}

Map<String, dynamic> _order(
  int id, {
  List<int> invoices = const [],
  String state = 'sale',
  String invoiceStatus = 'invoiced',
  num amountToInvoice = 0,
}) => {
  'id': id,
  'name': 'SO$id',
  'state': state,
  'company_id': 4,
  'invoice_ids': invoices,
  'invoice_status': invoiceStatus,
  'amount_to_invoice': amountToInvoice,
};

Map<String, dynamic> _invoice(
  int id, {
  String state = 'posted',
  String paymentState = 'paid',
  num residual = 0,
}) => {
  'id': id,
  'state': state,
  'payment_state': paymentState,
  'amount_residual': residual,
};

void main() {
  test(
    'catalog loader uses stable cursor pagination and scoped UUID',
    () async {
      final reader = _Reader();
      final loader = RuntimeCatalogLoader(reader, pageSize: 10);
      final scope = AppScope(
        appId: 'panel',
        installationId: 'i',
        normalizedServerUrl: 'https://erp.test',
        database: 'db',
        userId: 2,
      );
      final batch = await loader.loader(RuntimeCatalogs.products)(scope, '10');
      expect(reader.model, 'product.product');
      expect(reader.offset, 10);
      expect(batch.records.single.uuid, contains(':products:7'));
      expect(batch.cursor, isNull);
    },
  );

  test(
    'cashier pending uses native state reads, not invalid sale domains',
    () async {
      final reader = _Reader();
      final rows = await RuntimeOrderReader(reader).read(
        OrderQuery(
          companyId: 4,
          authorFilter: 99,
          workQueue: OrderWorkQueue.cashierPending,
        ),
      );
      expect(reader.calls.any((call) => call.model == 'sale.order'), isTrue);
      final saleCall = reader.calls.singleWhere(
        (call) => call.model == 'sale.order',
      );
      expect(
        saleCall.domain!.any(
          (part) => part is List && part.contains('user_id'),
        ),
        isFalse,
      );
      expect(
        saleCall.domain!.any(
          (part) =>
              part is List &&
              part.length == 3 &&
              part[0] == 'state' &&
              part[2] == 'sale',
        ),
        isTrue,
      );
      expect(saleCall.domain, isNot(contains('|')));
      expect(saleCall.fields, isNot(contains('payment_state')));
      expect(saleCall.fields, isNot(contains('amount_unpaid')));
      expect(saleCall.fields, isNot(contains('has_queued_invoice')));
      expect(reader.calls.any((call) => call.model == 'account.move'), isTrue);
      expect(
        reader.calls.any(
          (call) => call.model == 'l10n_ec_collection_box.sale.order.payment',
        ),
        isTrue,
      );
      expect(rows, hasLength(1));
      expect(rows.single['payment_state'], 'not_paid');
      expect(rows.single['amount_unpaid'], 5.0);
    },
  );

  test('fields_get contract contains only readable native fields', () async {
    final reader = _Reader();
    await RuntimeOrderReader(reader).validateRemoteContract();
    final metadata = await reader.fieldsGet(
      model: 'sale.order',
      fields: RuntimeOrderRemoteFields.saleOrder,
    );
    expect(
      () => RuntimeOrderRemoteFields.assertReadable(
        'sale.order',
        RuntimeOrderRemoteFields.saleOrder,
        metadata,
      ),
      returnsNormally,
    );
    expect(
      () => RuntimeOrderRemoteFields.assertReadable('sale.order', [
        ...RuntimeOrderRemoteFields.saleOrder,
        'payment_state',
      ], metadata),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'derives pending across multiple, cancelled and paid invoices',
    () async {
      final reader = _Reader()
        ..records = {
          'sale.order': [
            _order(1, invoices: [11]),
            _order(2, invoices: [12, 13]),
            _order(3, invoices: [14]),
          ],
          'account.move': [
            _invoice(11, paymentState: 'partial', residual: 3),
            _invoice(
              12,
              state: 'cancel',
              paymentState: 'not_paid',
              residual: 9,
            ),
            _invoice(13),
            _invoice(14),
          ],
          'l10n_ec_collection_box.sale.order.payment': [
            {
              'id': 31,
              'sale_id': [3, 'SO3'],
              'state': 'cancel',
              'amount': 20,
            },
          ],
        };
      final rows = await RuntimeOrderReader(reader).read(
        OrderQuery(companyId: 4, workQueue: OrderWorkQueue.cashierPending),
      );
      expect(rows.map((row) => row['id']), [1]);
      expect(rows.single['amount_unpaid'], 3.0);
      expect(rows.single['payment_state'], 'partial');
    },
  );

  test('posted native payment does not keep a paid order pending', () async {
    final reader = _Reader()
      ..records = {
        'sale.order': [
          {
            ..._order(9, invoices: [19]),
            'has_queued_invoice': true,
          },
        ],
        'account.move': [_invoice(19)],
        'l10n_ec_collection_box.sale.order.payment': [
          {
            'id': 91,
            'sale_id': [9, 'SO9'],
            'state': 'posted',
            'move_id': [991, 'MOVE991'],
            'amount': 5,
          },
        ],
      };

    final rows = await RuntimeOrderReader(
      reader,
    ).read(OrderQuery(companyId: 4, workQueue: OrderWorkQueue.cashierPending));

    expect(rows, isEmpty);
    final enriched = await RuntimeOrderRemoteState(reader).enrich([
      {
        ..._order(9, invoices: [19]),
        'has_queued_invoice': true,
      },
    ]);
    expect(enriched.single['has_queued_invoice'], isTrue);
    expect(enriched.single['_runtime_pending_collection'], isFalse);
  });

  test('cashier order pages continue beyond 200 rows', () async {
    final reader = _Reader()
      ..records = {
        'sale.order': [
          for (var id = 1; id <= 201; id++) _order(id),
          _order(202, invoices: [202]),
        ],
        'account.move': [_invoice(202, paymentState: 'not_paid', residual: 1)],
        'l10n_ec_collection_box.sale.order.payment': const [],
      };
    final rows = await RuntimeOrderReader(
      reader,
    ).read(OrderQuery(companyId: 4, workQueue: OrderWorkQueue.cashierPending));
    expect(rows, hasLength(1));
    expect(rows.single['id'], 202);
    final saleOffsets = reader.calls
        .where((call) => call.model == 'sale.order')
        .map((call) => call.offset ?? 0)
        .toList();
    expect(saleOffsets, [0, 100, 200]);
  });

  test('payment lines continue beyond 500 rows', () async {
    final reader = _Reader()
      ..records = {
        'sale.order': [_order(1)],
        'account.move': const [],
        'l10n_ec_collection_box.sale.order.payment': [
          for (var id = 1; id <= 500; id++)
            {
              'id': id,
              'sale_id': [1, 'SO1'],
              'state': 'cancel',
              'amount': 1,
            },
          {
            'id': 501,
            'sale_id': [1, 'SO1'],
            'state': 'draft',
            'amount': 0.5,
          },
        ],
      };
    final rows = await RuntimeOrderReader(
      reader,
    ).read(OrderQuery(companyId: 4, workQueue: OrderWorkQueue.cashierPending));
    expect(rows.map((row) => row['id']), [1]);
    final paymentOffsets = reader.calls
        .where(
          (call) => call.model == 'l10n_ec_collection_box.sale.order.payment',
        )
        .map((call) => call.offset ?? 0)
        .toList();
    expect(paymentOffsets, [0, 200, 400]);
  });

  test(
    'all-orders query carries author, state, text, dates and cursor filters',
    () async {
      final reader = _Reader();
      await RuntimeOrderReader(reader).read(
        OrderQuery(
          companyId: 4,
          authorFilter: 9,
          states: [SaleOrderState.approved],
          text: 'abc',
          dateFrom: DateTime.utc(2026, 1, 1),
          dateTo: DateTime.utc(2026, 1, 31),
          afterId: 100,
        ),
      );
      final saleCall = reader.calls.singleWhere(
        (call) => call.model == 'sale.order',
      );
      expect(
        saleCall.domain!.any(
          (part) =>
              part is List &&
              part.length == 3 &&
              part[0] == 'user_id' &&
              part[2] == 9,
        ),
        isTrue,
      );
      expect(
        saleCall.domain!.any(
          (part) =>
              part is List &&
              part.length == 3 &&
              part[0] == 'state' &&
              part[1] == 'in' &&
              part[2] is List &&
              (part[2] as List).contains('approved'),
        ),
        isTrue,
      );
      expect(
        saleCall.domain!.any(
          (part) =>
              part is List &&
              part.length == 3 &&
              part[0] == 'date_order' &&
              part[1] == '>=' &&
              part[2] == '2026-01-01T00:00:00.000Z',
        ),
        isTrue,
      );
      expect(
        saleCall.domain!.any(
          (part) =>
              part is List &&
              part.length == 3 &&
              part[0] == 'date_order' &&
              part[1] == '<=' &&
              part[2] == '2026-01-31T00:00:00.000Z',
        ),
        isTrue,
      );
      expect(
        saleCall.domain!.any(
          (part) =>
              part is List &&
              part.length == 3 &&
              part[0] == 'id' &&
              part[2] == 100,
        ),
        isTrue,
      );
      expect(saleCall.domain, contains('|'));
      expect(
        saleCall.domain!.any(
          (part) =>
              part is List &&
              part.length == 3 &&
              part[0] == 'name' &&
              part[2] == 'abc',
        ),
        isTrue,
      );
      expect(
        saleCall.domain!.any(
          (part) =>
              part is List &&
              part.length == 3 &&
              part[0] == 'client_order_ref' &&
              part[2] == 'abc',
        ),
        isTrue,
      );
    },
  );

  test('misconfigured page cursor is rejected safely', () async {
    final reader = _Reader();
    final loader = RuntimeCatalogLoader(reader);
    final scope = AppScope(
      appId: 'panel',
      installationId: 'i',
      normalizedServerUrl: 'https://erp.test',
      database: 'db',
      userId: 2,
    );
    final batch = await loader.loader(RuntimeCatalogs.customers)(scope, 'bad');
    expect(reader.offset, 0);
    expect(batch.records, hasLength(1));
  });
}
