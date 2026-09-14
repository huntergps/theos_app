import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/envases/envases_partner_balance_reader.dart';
import 'package:orbi_runtime/src/envases/envases_saldo_terceros_cache.dart';
import 'package:orbi_runtime/src/storage/runtime_database_owner.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  late Directory dir;
  late File file;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('orbi-saldo-terceros-cache-');
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
  Map<String, dynamic> row({int id = 1}) => {
    'id': id,
    'location_id': [8, 'Custodia clientes'],
    'warehouse_id': [3, 'Guayaquil'],
    'envases_rol': 'custodia_cliente',
    'partner_id': [20, 'Cliente Demo'],
    'product_id': [10, 'Jaba 12'],
    'company_id': [1, 'Empresa'],
    'cantidad': 4.0,
  };
  RuntimeDatabaseOwner owner() =>
      RuntimeDatabaseOwner(factory: (_) => AppDatabase(NativeDatabase(file)));
  EnvasesPartnerBalanceReader reader(
    CompanyContext c,
    Future<List<Map<String, dynamic>>> Function() fetch,
  ) => EnvasesPartnerBalanceReader(
    company: c,
    transport:
        ({
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
    final cache = EnvasesSaldoTercerosCache(
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
    final reopened = EnvasesSaldoTercerosCache(
      owner: secondOwner,
      lease: second.lease,
      company: company(1),
    );
    expect((await reopened.read())!.rows, isEmpty);
  });

  test('watch emits committed replacement and preserves it on failure', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    final cache = EnvasesSaldoTercerosCache(
      owner: o,
      lease: db.lease,
      company: company(1),
    );
    final values = cache.watch().take(2).toList();
    await Future<void>.delayed(Duration.zero);
    await cache.refresh(reader(company(1), () async => [row()]));
    final observed = await values;
    expect(observed.first, isNull);
    expect(observed.last!.rows.single.partnerName, 'Cliente Demo');
    expect(observed.last!.rows.single.productName, 'Jaba 12');
    expect(observed.last!.rows.single.warehouseName, 'Guayaquil');
    expect(
      cache.refresh(reader(company(1), () async => throw StateError('offline'))),
      throwsStateError,
    );
  });

  test('isolates company and rejects mismatched reader', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    final cache = EnvasesSaldoTercerosCache(
      owner: o,
      lease: db.lease,
      company: company(1),
    );
    await cache.refresh(reader(company(1), () async => [row()]));
    expect(cache.refresh(reader(company(2), () async => [])), throwsArgumentError);
    expect(
      await EnvasesSaldoTercerosCache(
        owner: o,
        lease: db.lease,
        company: company(2),
      ).read(),
      isNull,
    );
  });

  test('surfaces malformed persisted payload instead of treating it as empty', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    await db.database.customInsert(
      'INSERT INTO orbi_envases_saldo_terceros_cache (scope_key, company_id, payload, cached_at) VALUES (?, ?, ?, ?)',
      variables: [
        Variable<String>(scope.scopeKey),
        Variable<int>(1),
        Variable<String>('{}'),
        Variable<String>('2026-01-01T00:00:00.000Z'),
      ],
    );
    final cache = EnvasesSaldoTercerosCache(
      owner: o,
      lease: db.lease,
      company: company(1),
    );
    expect(cache.read(), throwsFormatException);
  });

  test('rejects same-instance concurrent refreshes', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    final cache = EnvasesSaldoTercerosCache(
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
