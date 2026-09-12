import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/envases/envases_dashboard_cache.dart';
import 'package:orbi_runtime/src/envases/envases_dashboard_reader.dart';
import 'package:orbi_runtime/src/envases/envases_location_reader.dart';
import 'package:orbi_runtime/src/storage/runtime_database_owner.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  late Directory dir;
  late File file;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('orbi-envases-cache-');
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
  Map<String, dynamic> row({int product = 10, double total = 4}) => {
    'id': product,
    'product_id': [product, 'Envase'],
    'uom_id': [1, 'Unidad'],
    'company_id': [1, 'Empresa'],
    'total_propio': total,
    'en_sede': 1.0,
    'danados': 0.0,
    'en_custodia_cliente': 2.0,
    'en_custodia_proveedor': 1.0,
    'en_transito': 0.0,
  };
  RuntimeDatabaseOwner owner() =>
      RuntimeDatabaseOwner(factory: (_) => AppDatabase(NativeDatabase(file)));
  EnvasesDashboardReader reader(
    CompanyContext c,
    Future<List<Map<String, dynamic>>> Function() fetch,
  ) => EnvasesDashboardReader(
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
  EnvasesLocationReader locationReader(
    CompanyContext c,
    Future<List<Map<String, dynamic>>> Function() fetch,
  ) => EnvasesLocationReader(
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
  Map<String, dynamic> locationRow({int companyId = 1, int id = 9}) => {
    'id': id,
    'product_id': [10, 'Envase'],
    'uom_id': [1, 'Unidad'],
    'location_id': [8, 'Sede'],
    'warehouse_id': [3, 'Guayaquil'],
    'company_id': [companyId, 'Empresa'],
    'envases_rol': 'sede',
    'envases_origen_id': false,
    'envases_destino_id': null,
    'quantity': 2.0,
  };

  test('reopens and distinguishes unloaded from loaded-empty', () async {
    final firstOwner = owner();
    final db = await firstOwner.open(scope);
    final cache = EnvasesDashboardCache(
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
    final reopened = EnvasesDashboardCache(
      owner: secondOwner,
      lease: second.lease,
      company: company(1),
    );
    expect((await reopened.read())!.rows, isEmpty);
  });

  test(
    'watch emits committed replacement and failed fetch preserves it',
    () async {
      final o = owner();
      final db = await o.open(scope);
      addTearDown(o.close);
      final cache = EnvasesDashboardCache(
        owner: o,
        lease: db.lease,
        company: company(1),
      );
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
      expect(after!.rows.single.productId, before!.rows.single.productId);
      expect(after.cachedAt, before.cachedAt);
    },
  );

  test('isolates company and rejects mismatched reader', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    final cache = EnvasesDashboardCache(
      owner: o,
      lease: db.lease,
      company: company(1),
    );
    await cache.refresh(reader(company(1), () async => [row()]));
    expect(
      cache.refresh(reader(company(2), () async => [])),
      throwsArgumentError,
    );
    expect(
      cache.refresh(
        reader(company(1), () async => []),
        locationReader: locationReader(company(2), () async => []),
      ),
      throwsArgumentError,
    );
    expect(
      cache.refresh(
        reader(company(1), () async => []),
        locationReader: EnvasesLocationReader(
          company: company(1),
          productId: 10,
          transport: ({
            required model,
            required domain,
            required fields,
            required context,
            required limit,
            required offset,
            required order,
          }) async => [],
        ),
      ),
      throwsArgumentError,
    );
    expect(
      await EnvasesDashboardCache(
        owner: o,
        lease: db.lease,
        company: company(2),
      ).read(),
      isNull,
    );
  });

  test('persists optional locations and reopens them', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    final cache = EnvasesDashboardCache(
      owner: o,
      lease: db.lease,
      company: company(1),
    );
    await cache.refresh(
      reader(company(1), () async => [row()]),
      locationReader: locationReader(company(1), () async => [locationRow()]),
    );
    expect((await cache.read())!.locations!.single.locationId, 8);
    await o.close();
    final reopenedOwner = owner();
    final reopenedDb = await reopenedOwner.open(scope);
    addTearDown(reopenedOwner.close);
    final reopened = EnvasesDashboardCache(
      owner: reopenedOwner,
      lease: reopenedDb.lease,
      company: company(1),
    );
    expect((await reopened.read())!.locations!.single.quantity, 2);
  });

  test('rejects every partial location reader filter', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    final cache = EnvasesDashboardCache(
      owner: o,
      lease: db.lease,
      company: company(1),
    );
    final partial = <EnvasesLocationReader>[
      EnvasesLocationReader(
        company: company(1),
        locationId: 8,
        transport: _emptyLocation,
      ),
      EnvasesLocationReader(
        company: company(1),
        warehouseId: 3,
        transport: _emptyLocation,
      ),
      EnvasesLocationReader(
        company: company(1),
        originWarehouseId: 3,
        transport: _emptyLocation,
      ),
      EnvasesLocationReader(
        company: company(1),
        destinationWarehouseId: 4,
        transport: _emptyLocation,
      ),
      EnvasesLocationReader(
        company: company(1),
        role: 'sede',
        transport: _emptyLocation,
      ),
    ];
    for (final location in partial) {
      expect(
        cache.refresh(
          reader(company(1), () async => []),
          locationReader: location,
        ),
        throwsArgumentError,
      );
    }
  });

  test(
    'detail fetch failure preserves the previous aggregate snapshot',
    () async {
      final o = owner();
      final db = await o.open(scope);
      addTearDown(o.close);
      final cache = EnvasesDashboardCache(
        owner: o,
        lease: db.lease,
        company: company(1),
      );
      await cache.refresh(reader(company(1), () async => [row(total: 4)]));
      final before = await cache.read();
      expect(
        cache.refresh(
          reader(company(1), () async => [row(total: 9)]),
          locationReader: locationReader(
            company(1),
            () async => throw StateError('denied'),
          ),
        ),
        throwsStateError,
      );
      final after = await cache.read();
      expect(after!.rows.single.totalPropio, before!.rows.single.totalPropio);
      expect(after.locations, isNull);
    },
  );

  test('decodes v1 payload with locations absent as null', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    final cachedAt = '2026-01-01T00:00:00.000Z';
    await db.database.customInsert(
      'INSERT INTO orbi_envases_dashboard_cache '
      '(scope_key, company_id, payload, cached_at) VALUES (?, ?, ?, ?)',
      variables: [
        Variable<String>(scope.scopeKey),
        Variable<int>(1),
        Variable<String>(
          jsonEncode({
            'version': 1,
            'cached_at': cachedAt,
            'rows': [row()],
          }),
        ),
        Variable<String>(cachedAt),
      ],
    );
    final cache = EnvasesDashboardCache(
      owner: o,
      lease: db.lease,
      company: company(1),
    );
    final snapshot = await cache.read();
    expect(snapshot!.locations, isNull);
  });

  test(
    'rejects stale cross-instance refresh and preserves newer response',
    () async {
      final o1 = owner();
      final d1 = await o1.open(scope);
      final o2 = owner();
      final d2 = await o2.open(scope);
      addTearDown(o1.close);
      addTearDown(o2.close);
      final first = EnvasesDashboardCache(
        owner: o1,
        lease: d1.lease,
        company: company(1),
      );
      final second = EnvasesDashboardCache(
        owner: o2,
        lease: d2.lease,
        company: company(1),
      );
      final gate = Completer<void>();
      final started = Completer<void>();
      final old = first.refresh(
        reader(company(1), () async {
          started.complete();
          await gate.future;
          return [row(total: 1)];
        }),
      );
      await started.future;
      await second.refresh(reader(company(1), () async => [row(total: 2)]));
      gate.complete();
      await expectLater(old, throwsStateError);
      expect((await second.read())!.rows.single.totalPropio, 2);
    },
  );

  test(
    'surfaces malformed persisted payload instead of treating it as empty',
    () async {
      final o = owner();
      final db = await o.open(scope);
      addTearDown(o.close);
      await db.database.customInsert(
        'INSERT INTO orbi_envases_dashboard_cache '
        '(scope_key, company_id, payload, cached_at) VALUES (?, ?, ?, ?)',
        variables: [
          Variable<String>(scope.scopeKey),
          Variable<int>(1),
          Variable<String>('{}'),
          Variable<String>('2026-01-01T00:00:00.000Z'),
        ],
      );
      final cache = EnvasesDashboardCache(
        owner: o,
        lease: db.lease,
        company: company(1),
      );
      expect(cache.read(), throwsFormatException);
    },
  );

  test('rejects completion after lease changes during remote read', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    final cache = EnvasesDashboardCache(
      owner: o,
      lease: db.lease,
      company: company(1),
    );
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
    final cache = EnvasesDashboardCache(
      owner: o,
      lease: db.lease,
      company: company(1),
    );
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

Future<List<Map<String, dynamic>>> _emptyLocation({
  required String model,
  required List<dynamic> domain,
  required List<String> fields,
  required Map<String, dynamic> context,
  required int limit,
  required int offset,
  required String order,
}) async => [];
