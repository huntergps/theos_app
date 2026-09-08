import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

class _Reader implements CapabilityReader {
  bool fail = false;
  Future<void> Function()? beforeReturn;
  @override
  Future<CapabilitySnapshot> fetch(AppScope scope, int companyId) async {
    if (fail) throw StateError('403 forbidden');
    await beforeReturn?.call();
    return CapabilitySnapshot(
      scopeKey: scope.scopeKey,
      companyId: companyId,
      revision: 1,
      fetchedAt: DateTime.now(),
      permissions: ['seller'],
    );
  }
}

void main() {
  AppScope scope() => AppScope(
    appId: 'panel',
    installationId: 'i',
    normalizedServerUrl: 'https://erp.test',
    database: 'db',
    userId: 2,
  );
  test('403 does not overwrite cached snapshot', () async {
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase.memory()),
    );
    final s = scope();
    final db = await owner.open(s);
    final reader = _Reader();
    final service = RuntimeCapabilityService(owner: owner, reader: reader);
    await service.refresh(scope: s, lease: db.lease, companyId: 7);
    reader.fail = true;
    await expectLater(
      service.refresh(scope: s, lease: db.lease, companyId: 7),
      throwsStateError,
    );
    expect((await service.offline(scope: s, companyId: 7))!.revision, 1);
    await owner.close();
  });

  test('lease change during fetch rejects and does not publish', () async {
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase.memory()),
    );
    final s = scope();
    final db = await owner.open(s);
    final reader = _Reader();
    reader.beforeReturn = owner.close;
    final service = RuntimeCapabilityService(owner: owner, reader: reader);
    await expectLater(
      service.refresh(scope: s, lease: db.lease, companyId: 7),
      throwsStateError,
    );
    expect(owner.active, isNull);
  });
}
