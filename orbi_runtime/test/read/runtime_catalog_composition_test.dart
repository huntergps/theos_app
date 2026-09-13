import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

class _FakeReader implements Json2ReadPort, Json2FieldsGetPort {
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
    final rows = switch (model) {
      'product.product' => const [
        {'id': 7, 'name': 'Producto', 'list_price': 4.5},
      ],
      // El mismo id (8) sirve tanto para el catálogo `customers` como para
      // `currentUserPartner`: en un servidor real serían la misma fila
      // cuando el usuario también es cliente, y a los tests de composición
      // les basta con que ambos caminos escriban sobre la misma fila.
      'res.partner' => const [
        {
          'id': 8,
          'name': 'Cliente',
          'vat': '999',
          'street': 'Av. Siempre Viva 123',
          'city': 'Quito',
          'country_id': [65, 'Ecuador'],
          'write_date': '2026-09-13 10:00:00',
        },
      ],
      'res.users' => const [
        {
          'id': 2,
          'name': 'Erik',
          'login': 'erik',
          'lang': 'es_EC',
          'tz': 'America/Guayaquil',
          'partner_id': [8, 'Cliente'],
          'company_id': [1, 'Tecnosmart'],
          'group_ids': [10],
          'write_date': '2026-09-13 10:00:00',
        },
      ],
      'res.lang' => const [
        {
          'id': 1,
          'name': 'Español (EC)',
          'code': 'es_EC',
          'active': true,
          'write_date': '2026-09-01 00:00:00',
        },
      ],
      'res.country' => const [
        {
          'id': 65,
          'name': 'Ecuador',
          'code': 'EC',
          'write_date': '2026-09-01 00:00:00',
        },
      ],
      'res.country.state' => const [
        {
          'id': 700,
          'name': 'Pichincha',
          'code': 'P',
          'country_id': [65, 'Ecuador'],
          'write_date': '2026-09-01 00:00:00',
        },
      ],
      'res.groups' => const [
        {
          'id': 10,
          'name': 'Ventas / Usuario',
          'full_name': 'Ventas / Usuario',
          'write_date': '2026-09-01 00:00:00',
        },
      ],
      _ => const <Map<String, dynamic>>[],
    };
    // Proyecta sólo los campos pedidos, como haría el servidor real — así
    // se puede comprobar qué pidió cada catálogo sin duplicar filas por caso.
    return rows
        .map(
          (row) => {
            for (final field in fields)
              if (row.containsKey(field)) field: row[field],
          },
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>> fieldsGet({
    required String model,
    required List<String> fields,
  }) async => {for (final field in fields) field: <String, dynamic>{}};
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
    // El cursor YA NO vuelve a `null` al terminar la carga completa: pasa a
    // modo incremental (`since`) para que la próxima sincronización pida sólo
    // lo que cambió, en vez de recargar todo el catálogo otra vez (ver
    // `RuntimeCatalogLoader` en json2_read_adapters.dart).
    expect(
      (await composition.store('product').read(scope)).cursor,
      contains('"mode":"since"'),
    );
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

  // Contrato (a) del encargo: los seis catálogos nuevos ("Mis preferencias")
  // deben tener su SyncJob registrado con el id `catalog:<clave>` — el mismo
  // contrato que ya cumplen los catorce anteriores.
  test('composition registra los seis jobs de "Mis preferencias"', () async {
    final (owner, activation, _) = await setup();
    addTearDown(owner.close);
    final composition = RuntimeCatalogComposition(
      activation: activation,
      owner: owner,
      reader: _FakeReader(),
    );
    for (final key in const [
      'lang',
      'country',
      'countryState',
      'groups',
      'currentUser',
      'currentUserPartner',
    ]) {
      expect(composition.job(key).id, 'catalog:$key', reason: key);
    }
  });

  // Contrato (b): tras una pasada de todos los jobs nuevos, las tablas de
  // referencia y la fila del usuario actual quedan con datos.
  test(
    'una pasada de los seis jobs deja datos en res_lang/res_country/'
    'res_country_state/res_groups y en el usuario actual',
    () async {
      final (owner, activation, _) = await setup();
      addTearDown(owner.close);
      final composition = RuntimeCatalogComposition(
        activation: activation,
        owner: owner,
        reader: _FakeReader(),
      );
      for (final key in const [
        'lang',
        'country',
        'countryState',
        'groups',
        'currentUser',
        'currentUserPartner',
      ]) {
        final result = await composition.sync(key);
        expect(result.cursorConfirmed, isTrue, reason: key);
      }

      final db = owner.active!.database;
      expect((await db.select(db.resLang).get()), isNotEmpty);
      expect((await db.select(db.resCountry).get()), isNotEmpty);
      expect((await db.select(db.resCountryState).get()), isNotEmpty);
      expect((await db.select(db.resGroups).get()), isNotEmpty);
      final currentUsers = (await db.select(db.resUsers).get())
          .where((row) => row.isCurrentUser)
          .toList();
      expect(currentUsers, hasLength(1));
      expect(currentUsers.single.lang, 'es_EC');
    },
  );

  // Contrato (c): el partner del usuario de la sesión activa sobrevive una
  // salida de dominio del catálogo `customers` una vez que `currentUserPartner`
  // ya corrió — prueba de que `runtime_catalog_composition.dart` conecta de
  // verdad el `CurrentAccountPartnerGuard` con el store `partner`, no sólo
  // que el mecanismo exista en abstracto (eso ya lo cubre
  // `current_account_test.dart`).
  test(
    'el partner del usuario actual sobrevive una salida de dominio de '
    '`customers` después de que currentUserPartner corrió',
    () async {
      final (owner, activation, scope) = await setup();
      addTearDown(owner.close);
      final composition = RuntimeCatalogComposition(
        activation: activation,
        owner: owner,
        reader: _FakeReader(),
      );
      await composition.sync('currentUserPartner');
      final db = owner.active!.database;
      final partnerId = (await db.select(db.resPartner).get()).single.odooId;

      // Simula lo que haría `RuntimeCatalogLoader._fetchDomainExitIds` si el
      // partner del usuario (customer_rank == 0, el caso normal de un
      // vendedor) dejara de cumplir el dominio `customer_rank > 0` de
      // `customers` en la ventana incremental — sin pasar por HTTP, igual
      // que ya se prueba el resto del borrado a nivel de `DriftCatalogStore`
      // en `catalog_deletion_and_pending_guard_test.dart`.
      await composition.store('partner').commit(
        scope,
        CatalogBatch(records: const [], cursor: 'x', deletedIds: [partnerId]),
      );

      final rows = await db.select(db.resPartner).get();
      expect(rows.map((row) => row.odooId), contains(partnerId));
    },
  );
}
