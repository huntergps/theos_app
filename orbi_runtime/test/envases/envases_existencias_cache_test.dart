import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/envases/envases_existencias_cache.dart';
import 'package:orbi_runtime/src/envases/envases_existencias_reader.dart';
import 'package:orbi_runtime/src/storage/runtime_database_owner.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  late Directory dir;
  late File file;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('orbi-envases-existencias-cache-');
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
  Map<String, dynamic> datos({int productId = 501, double total = 340.0}) => {
    'columnas': [
      {'id': 'sede-1', 'nombre': 'Sede 1', 'location_id': 11, 'tipo': 'sede'},
      {'id': 'sede-2', 'nombre': 'Sede 2', 'location_id': 12, 'tipo': 'sede'},
    ],
    'filas': [
      {
        'id': productId,
        'nombre': 'Botella retornable',
        'uom': 'Unidades',
        'celdas': {'sede-1': total / 2, 'sede-2': total / 2},
        'total': total,
      },
    ],
    'totales_columna': {'sede-1': total / 2, 'sede-2': total / 2},
    'total_general': total,
    'pendientes': 1,
  };
  RuntimeDatabaseOwner owner() =>
      RuntimeDatabaseOwner(factory: (_) => AppDatabase(NativeDatabase(file)));
  EnvasesExistenciasReader reader(
    CompanyContext c,
    Future<Map<String, dynamic>> Function() fetch,
  ) => EnvasesExistenciasReader(
    company: c,
    transport:
        ({
          required model,
          required method,
          required kwargs,
          required context,
        }) => fetch(),
  );

  test('reopens and distinguishes unloaded from loaded-empty grid', () async {
    final firstOwner = owner();
    final db = await firstOwner.open(scope);
    final cache = EnvasesExistenciasCache(
      owner: firstOwner,
      lease: db.lease,
      company: company(1),
    );
    expect(await cache.read(), isNull);
    await cache.refresh(
      reader(company(1), () async => {...datos(), 'filas': const []}),
    );
    expect((await cache.read())!.data.filas, isEmpty);
    await firstOwner.close();
    final secondOwner = owner();
    final second = await secondOwner.open(scope);
    addTearDown(secondOwner.close);
    final reopened = EnvasesExistenciasCache(
      owner: secondOwner,
      lease: second.lease,
      company: company(1),
    );
    expect((await reopened.read())!.data.filas, isEmpty);
  });

  test('watch emits committed replacement and failed fetch preserves it, '
      'keeping the cached_at moment', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    final cache = EnvasesExistenciasCache(
      owner: o,
      lease: db.lease,
      company: company(1),
    );
    final values = cache.watch().take(2).toList();
    await Future<void>.delayed(Duration.zero);
    await cache.refresh(reader(company(1), () async => datos()));
    final observed = await values;
    expect(observed.first, isNull);
    expect(observed.last!.data.filas.single.id, 501);
    final before = await cache.read();
    expect(
      cache.refresh(
        reader(company(1), () async => throw StateError('offline')),
      ),
      throwsStateError,
    );
    final after = await cache.read();
    expect(after!.data.filas.single.total, before!.data.filas.single.total);
    expect(after.cachedAt, before.cachedAt);
  });

  test('isolates company and rejects a reader for another scope/company', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    final cache = EnvasesExistenciasCache(
      owner: o,
      lease: db.lease,
      company: company(1),
    );
    await cache.refresh(reader(company(1), () async => datos()));
    expect(
      cache.refresh(reader(company(2), () async => datos())),
      throwsArgumentError,
    );
    expect(
      await EnvasesExistenciasCache(
        owner: o,
        lease: db.lease,
        company: company(2),
      ).read(),
      isNull,
    );
  });

  test(
    'surfaces malformed persisted payload instead of treating it as empty',
    () async {
      final o = owner();
      final db = await o.open(scope);
      addTearDown(o.close);
      await db.database.customInsert(
        'INSERT INTO orbi_envases_existencias_cache '
        '(scope_key, company_id, payload, cached_at) VALUES (?, ?, ?, ?)',
        variables: [
          Variable<String>(scope.scopeKey),
          Variable<int>(1),
          Variable<String>('{}'),
          Variable<String>('2026-01-01T00:00:00.000Z'),
        ],
      );
      final cache = EnvasesExistenciasCache(
        owner: o,
        lease: db.lease,
        company: company(1),
      );
      expect(cache.read(), throwsFormatException);
    },
  );

  test('rejects same-instance concurrent refreshes', () async {
    final o = owner();
    final db = await o.open(scope);
    addTearDown(o.close);
    final cache = EnvasesExistenciasCache(
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
        return datos();
      }),
    );
    await started.future;
    await expectLater(
      cache.refresh(reader(company(1), () async => datos())),
      throwsStateError,
    );
    gate.complete();
    await pending;
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
      final first = EnvasesExistenciasCache(
        owner: o1,
        lease: d1.lease,
        company: company(1),
      );
      final second = EnvasesExistenciasCache(
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
          return datos(total: 1);
        }),
      );
      await started.future;
      await second.refresh(reader(company(1), () async => datos(total: 2)));
      gate.complete();
      await expectLater(old, throwsStateError);
      expect((await second.read())!.data.totalGeneral, 2);
    },
  );
}
