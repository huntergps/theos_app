import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/envases/envases_sedes_cache.dart';
import 'package:orbi_runtime/src/envases/envases_sedes_reader.dart';
import 'package:orbi_runtime/src/storage/runtime_database_owner.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  late Directory dir;
  late File file;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('orbi-sedes-cache-');
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
    userId: 7,
  );
  CompanyContext company(int id) =>
      CompanyContext.forScope(scope: scope, companyId: id, allowedCompanyIds: [id], capabilityRevision: 1);
  RuntimeDatabaseOwner owner() => RuntimeDatabaseOwner(factory: (_) => AppDatabase(NativeDatabase(file)));
  EnvasesSedesReader reader(CompanyContext c, Future<EnvasesSedesResult> Function() fetch) => EnvasesSedesReader(
    company: c,
    userId: 7,
    transport: ({required model, required domain, required fields, required context, required limit, required offset, required order}) async {
      final result = await fetch();
      if (model == 'stock.warehouse') {
        return [for (final sede in result.posibles) {'id': sede.id, 'name': sede.name}];
      }
      return [
        {'id': 7, 'envases_warehouse_ids': result.propias.map((s) => s.id).toList()},
      ];
    },
  );
  EnvasesSedesResult result({List<EnvasesSedeRow> propias = const [], List<EnvasesSedeRow> posibles = const []}) =>
      EnvasesSedesResult(propias: propias, posibles: posibles);

  test('reopens and distinguishes unloaded from loaded-empty', () async {
    final firstOwner = owner();
    final db = await firstOwner.open(scope);
    final cache = EnvasesSedesCache(owner: firstOwner, lease: db.lease, company: company(1));
    expect(await cache.read(), isNull);
    await cache.refresh(reader(company(1), () async => result()));
    expect((await cache.read())!.posibles, isEmpty);
    await firstOwner.close();
    final secondOwner = owner();
    final second = await secondOwner.open(scope);
    addTearDown(secondOwner.close);
    final reopened = EnvasesSedesCache(owner: secondOwner, lease: second.lease, company: company(1));
    expect((await reopened.read())!.posibles, isEmpty);
  });

  test('watch emits committed replacement and failed fetch preserves it', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    final cache = EnvasesSedesCache(owner: o, lease: db.lease, company: company(1));
    final values = cache.watch().take(2).toList();
    await Future<void>.delayed(Duration.zero);
    await cache.refresh(
      reader(company(1), () async => result(posibles: const [EnvasesSedeRow(id: 1, name: 'Guayaquil')])),
    );
    final observed = await values;
    expect(observed.first, isNull);
    expect(observed.last!.posibles.single.id, 1);
    await expectLater(
      cache.refresh(reader(company(1), () async => throw StateError('offline'))),
      throwsStateError,
    );
  });

  test('isolates company and rejects mismatched reader', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    final cache = EnvasesSedesCache(owner: o, lease: db.lease, company: company(1));
    await cache.refresh(reader(company(1), () async => result()));
    expect(cache.refresh(reader(company(2), () async => result())), throwsArgumentError);
    expect(await EnvasesSedesCache(owner: o, lease: db.lease, company: company(2)).read(), isNull);
  });

  test('surfaces malformed persisted payload instead of treating it as empty', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    await db.database.customInsert(
      'INSERT INTO orbi_envases_sedes_cache (scope_key, company_id, payload, cached_at) VALUES (?, ?, ?, ?)',
      variables: [
        Variable<String>(scope.scopeKey),
        Variable<int>(1),
        Variable<String>('{}'),
        Variable<String>('2026-01-01T00:00:00.000Z'),
      ],
    );
    final cache = EnvasesSedesCache(owner: o, lease: db.lease, company: company(1));
    expect(cache.read(), throwsFormatException);
  });
}
