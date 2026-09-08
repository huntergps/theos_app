import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

class _FakeReader implements Json2ReadPort {
  bool fail = false;
  Future<void> Function()? beforeReturn;
  @override
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
  }) async {
    if (fail) throw StateError('401 unauthorized');
    await beforeReturn?.call();
    return switch (model) {
      'product.product' => const [
        {'id': 7, 'name': 'Producto', 'list_price': 4.5},
      ],
      'res.partner' => const [
        {'id': 8, 'name': 'Cliente', 'vat': '999'},
      ],
      _ => const <Map<String, dynamic>>[],
    };
  }
}

void main() {
  Future<(RuntimeDatabaseOwner, SessionActivation, AppScope)> setup() async {
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase.memory()),
    );
    final scope = AppScope(
      appId: 'panel',
      installationId: 'i',
      normalizedServerUrl: 'https://erp.test',
      database: 'db',
      userId: 2,
    );
    final database = await owner.open(scope);
    return (owner, SessionActivation(database: database), scope);
  }

  test('composition syncs product and partner through Drift', () async {
    final (owner, activation, scope) = await setup();
    addTearDown(owner.close);
    final composition = RuntimeCatalogComposition(
      activation: activation,
      owner: owner,
      reader: _FakeReader(),
    );
    expect((await composition.sync('product')).cursorConfirmed, isTrue);
    expect((await composition.sync('partner')).cursorConfirmed, isTrue);
    expect(
      (await owner.active!.database
              .select(owner.active!.database.productProduct)
              .get())
          .single
          .name,
      'Producto',
    );
    expect(
      (await owner.active!.database
              .select(owner.active!.database.resPartner)
              .get())
          .single
          .name,
      'Cliente',
    );
    expect((await composition.store('product').read(scope)).cursor, isNull);
  });

  test('401 leaves prior rows and cursor unchanged', () async {
    final (owner, activation, _) = await setup();
    addTearDown(owner.close);
    final reader = _FakeReader();
    final composition = RuntimeCatalogComposition(
      activation: activation,
      owner: owner,
      reader: reader,
    );
    await composition.sync('product');
    reader.fail = true;
    final result = await composition.sync('product');
    expect(result.status, SyncJobStatus.failed);
    expect(
      (await owner.active!.database
          .select(owner.active!.database.productProduct)
          .get()),
      hasLength(1),
    );
  });

  test('stale lease is rejected before local commit', () async {
    final (owner, activation, _) = await setup();
    addTearDown(owner.close);
    final reader = _FakeReader();
    reader.beforeReturn = owner.close;
    final composition = RuntimeCatalogComposition(
      activation: activation,
      owner: owner,
      reader: reader,
    );
    final result = await composition.sync('product');
    expect(result.status, SyncJobStatus.failed);
    expect(owner.active, isNull);
  });
}
