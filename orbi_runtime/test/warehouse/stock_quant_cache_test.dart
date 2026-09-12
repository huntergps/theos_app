import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/storage/runtime_database_owner.dart';
import 'package:orbi_runtime/src/warehouse/stock_quant_cache.dart';
import 'package:orbi_runtime/src/warehouse/stock_quant_reader.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  late Directory dir;
  late File file;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('orbi-warehouse-cache-');
    file = File('${dir.path}/runtime.sqlite');
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  final scope = AppScope(
    appId: 'orbi',
    installationId: 'i',
    normalizedServerUrl: 'https://erp.test',
    database: 'db',
    userId: 1,
  );
  CompanyContext company(int id) => CompanyContext.forScope(
    scope: scope,
    companyId: id,
    allowedCompanyIds: [id],
    capabilityRevision: 1,
  );
  Map<String, dynamic> row({int id = 1, int companyId = 1, double quantity = 25}) => {
    'id': id,
    'product_id': [10, 'Tornillo 1/4'],
    'uom_id': [2, 'Unidad'],
    'location_id': [8, 'GYE/Existencias'],
    'warehouse_id': [3, 'Guayaquil'],
    'company_id': [companyId, 'Empresa'],
    'quantity': quantity,
    'reserved_quantity': 5.0,
    'available_quantity': quantity - 5.0,
    'reservado_por': false,
  };
  RuntimeDatabaseOwner owner() =>
      RuntimeDatabaseOwner(factory: (_) => AppDatabase(NativeDatabase(file)));
  StockQuantReader reader(
    CompanyContext c,
    Future<List<Map<String, dynamic>>> Function() fetch,
  ) => StockQuantReader(
    company: c,
    transport: ({
      required model,
      required domain,
      required fields,
      required context,
      required limit,
      required offset,
      required order,
    }) => fetch(),
  );

  test('reopens and distinguishes unloaded from loaded-empty', () async {
    final firstOwner = owner();
    final db = await firstOwner.open(scope);
    final cache = StockQuantCache(
      owner: firstOwner,
      lease: db.lease,
      company: company(1),
    );
    expect(await cache.read(), isNull);
    await cache.refresh(reader(company(1), () async => []));
    expect((await cache.read())!.rows, isEmpty);
    await firstOwner.close();
    final secondOwner = owner();
    final second = await secondOwner.open(scope);
    addTearDown(secondOwner.close);
    final reopened = StockQuantCache(
      owner: secondOwner,
      lease: second.lease,
      company: company(1),
    );
    expect((await reopened.read())!.rows, isEmpty);
  });

  test(
    'watch emits committed replacement and a failed fetch preserves it',
    () async {
      final o = owner();
      final db = await o.open(scope);
      addTearDown(o.close);
      final cache = StockQuantCache(owner: o, lease: db.lease, company: company(1));
      final values = cache.watch().take(2).toList();
      await Future<void>.delayed(Duration.zero);
      await cache.refresh(reader(company(1), () async => [row()]));
      final observed = await values;
      expect(observed.first, isNull);
      expect(observed.last!.rows.single.productId, 10);
      final before = await cache.read();
      expect(
        cache.refresh(
          reader(company(1), () async => throw StateError('offline')),
        ),
        throwsStateError,
      );
      final after = await cache.read();
      expect(after!.rows.single.id, before!.rows.single.id);
      expect(after.cachedAt, before.cachedAt);
    },
  );

  test('isolates company and rejects a reader scoped to another company', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    final cache = StockQuantCache(owner: o, lease: db.lease, company: company(1));
    await cache.refresh(reader(company(1), () async => [row(companyId: 1)]));
    expect(
      cache.refresh(reader(company(2), () async => [])),
      throwsArgumentError,
    );
    expect(
      await StockQuantCache(
        owner: o,
        lease: db.lease,
        company: company(2),
      ).read(),
      isNull,
    );
  });

  test('rejects a refresh reader narrowed by product/location/warehouse', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    final cache = StockQuantCache(owner: o, lease: db.lease, company: company(1));
    final narrowed = <StockQuantReader>[
      StockQuantReader(company: company(1), productId: 10, transport: _empty),
      StockQuantReader(company: company(1), locationId: 8, transport: _empty),
      StockQuantReader(company: company(1), warehouseId: 3, transport: _empty),
    ];
    for (final r in narrowed) {
      expect(cache.refresh(r), throwsArgumentError);
    }
  });

  test('surfaces a malformed persisted payload instead of treating it as empty', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    await db.database.customInsert(
      'INSERT INTO orbi_stock_quant_cache '
      '(scope_key, company_id, payload, cached_at) VALUES (?, ?, ?, ?)',
      variables: [
        Variable<String>(scope.scopeKey),
        Variable<int>(1),
        Variable<String>('{}'),
        Variable<String>('2026-01-01T00:00:00.000Z'),
      ],
    );
    final cache = StockQuantCache(owner: o, lease: db.lease, company: company(1));
    expect(cache.read(), throwsFormatException);
  });

  test('rejects a wrong-version cached payload', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    final cachedAt = '2026-01-01T00:00:00.000Z';
    await db.database.customInsert(
      'INSERT INTO orbi_stock_quant_cache '
      '(scope_key, company_id, payload, cached_at) VALUES (?, ?, ?, ?)',
      variables: [
        Variable<String>(scope.scopeKey),
        Variable<int>(1),
        Variable<String>(jsonEncode({'version': 99, 'cached_at': cachedAt, 'rows': []})),
        Variable<String>(cachedAt),
      ],
    );
    final cache = StockQuantCache(owner: o, lease: db.lease, company: company(1));
    expect(cache.read(), throwsFormatException);
  });

  test(
    'rejects stale cross-instance refresh and preserves the newer response',
    () async {
      final o1 = owner();
      final d1 = await o1.open(scope);
      final o2 = owner();
      final d2 = await o2.open(scope);
      addTearDown(o1.close);
      addTearDown(o2.close);
      final first = StockQuantCache(owner: o1, lease: d1.lease, company: company(1));
      final second = StockQuantCache(owner: o2, lease: d2.lease, company: company(1));
      final gate = Completer<void>();
      final started = Completer<void>();
      final old = first.refresh(
        reader(company(1), () async {
          started.complete();
          await gate.future;
          return [row(quantity: 1)];
        }),
      );
      await started.future;
      await second.refresh(reader(company(1), () async => [row(quantity: 2)]));
      gate.complete();
      await expectLater(old, throwsStateError);
      expect((await second.read())!.rows.single.quantity, 2);
    },
  );

  test('rejects completion after the lease changes during the remote read', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    final cache = StockQuantCache(owner: o, lease: db.lease, company: company(1));
    final gate = Completer<void>();
    final started = Completer<void>();
    final pending = cache.refresh(
      reader(company(1), () async {
        started.complete();
        await gate.future;
        return [row()];
      }),
    );
    await started.future;
    await o.open(scope.copyWith(userId: 2));
    gate.complete();
    await expectLater(pending, throwsStateError);
  });

  test('rejects same-instance concurrent refreshes', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    final cache = StockQuantCache(owner: o, lease: db.lease, company: company(1));
    final gate = Completer<void>();
    final started = Completer<void>();
    final pending = cache.refresh(
      reader(company(1), () async {
        started.complete();
        await gate.future;
        return [row()];
      }),
    );
    await started.future;
    await expectLater(
      cache.refresh(reader(company(1), () async => [])),
      throwsStateError,
    );
    gate.complete();
    await pending;
  });
}

Future<List<Map<String, dynamic>>> _empty({
  required String model,
  required List<dynamic> domain,
  required List<String> fields,
  required Map<String, dynamic> context,
  required int limit,
  required int offset,
  required String order,
}) async => [];
