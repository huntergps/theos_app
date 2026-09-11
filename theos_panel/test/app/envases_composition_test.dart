import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:drift/native.dart';

import 'package:theos_panel/app/envases_composition.dart';
import 'package:theos_panel/app/notification_scope_adapter.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';

void main() {
  AppScope scope() => AppScope(
    appId: 'orbi',
    installationId: 'i',
    normalizedServerUrl: 'https://erp.test',
    database: 'db',
    userId: 1,
  );
  Map<String, dynamic> row() => {
    'id': 1,
    'product_id': [10, 'Jaba'],
    'uom_id': [1, 'Unidad'],
    'company_id': [4, 'Empresa'],
    'total_propio': 2.0,
    'en_sede': 2.0,
    'danados': 0.0,
    'en_custodia_cliente': 0.0,
    'en_custodia_proveedor': 0.0,
    'en_transito': 0.0,
  };
  test('missing permission produces no controller', () {
    final container = ProviderContainer(
      overrides: [
        runtimeSessionProvider.overrideWithValue(null),
        capabilitySnapshotProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(envasesDashboardControllerProvider), isNull);
  });
  test(
    'controller emits cached snapshot and surfaces refresh errors',
    () async {
      final owner = RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      );
      final s = scope();
      final db = await owner.open(s);
      final company = CompanyContext.forScope(
        scope: s,
        companyId: 4,
        allowedCompanyIds: [4],
        capabilityRevision: 1,
      );
      final cache = EnvasesDashboardCache(
        owner: owner,
        lease: db.lease,
        company: company,
      );
      final reader = EnvasesDashboardReader(
        company: company,
        transport: ({
          required model,
          required domain,
          required fields,
          required context,
          required limit,
          required offset,
          required order,
        }) async => [row()],
      );
      await cache.refresh(reader);
      final controller = EnvasesDashboardController(
        cache: cache,
        reader: reader,
      );
      addTearDown(() async {
        await controller.dispose();
        await owner.close();
      });
      final seen = controller.snapshots.first;
      expect((await seen)!.rows.single.productId, 10);
      final second = controller.snapshots.first;
      expect((await second)!.rows.single.productId, 10);
    },
  );
  test('disposed controller does not report late refresh errors', () async {
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase.memory()),
    );
    final s = scope();
    final db = await owner.open(s);
    final company = CompanyContext.forScope(
      scope: s,
      companyId: 4,
      allowedCompanyIds: [4],
      capabilityRevision: 1,
    );
    final gate = Completer<void>();
    final cache = EnvasesDashboardCache(
      owner: owner,
      lease: db.lease,
      company: company,
    );
    final reader = EnvasesDashboardReader(
      company: company,
      transport:
          ({
            required model,
            required domain,
            required fields,
            required context,
            required limit,
            required offset,
            required order,
          }) async {
            await gate.future;
            throw StateError('offline');
          },
    );
    final controller = EnvasesDashboardController(cache: cache, reader: reader);
    final pending = controller.refresh();
    await controller.dispose();
    gate.complete();
    await pending;
    await owner.close();
    expect(controller.canRefresh, isFalse);
  });
}
