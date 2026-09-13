import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show AppDatabase, OfflineQueueDataSource;

import 'package:orbi_runtime/src/account/user_preferences.dart'
    show FieldAvailabilityCache;
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/read/json2_read_adapters.dart';
import 'package:orbi_runtime/src/read/local_catalog_adapters.dart';
import 'package:orbi_runtime/src/storage/runtime_database_owner.dart';
import 'package:orbi_runtime/src/sync/catalog_sync.dart';

/// Lector falso de `res.users`/`res.partner` para [RuntimeAccountLoader].
/// `searchRead` proyecta sólo los campos pedidos (como el servidor real:
/// pedir un campo ausente de la fila simulada nunca lo inventa), y
/// `fieldsGet` responde con [userFieldsMetadata]/[partnerFieldsMetadata] —
/// así los tests controlan exactamente qué campos "existen" en cada modelo.
class _AccountReader implements Json2ReadPort, Json2FieldsGetPort {
  _AccountReader({
    required this.userRow,
    required this.partnerRow,
    required this.userFieldsMetadata,
  });

  final Map<String, dynamic> userRow;
  final Map<String, dynamic> partnerRow;
  final Map<String, dynamic> userFieldsMetadata;

  final List<List<String>> userSearchReadFields = [];

  @override
  Future<Map<String, dynamic>> fieldsGet({
    required String model,
    required List<String> fields,
  }) async {
    if (model == 'res.users') {
      return {
        for (final field in fields)
          if (userFieldsMetadata.containsKey(field))
            field: userFieldsMetadata[field],
      };
    }
    // res.partner: ningún test necesita ocultar un campo de dirección, así
    // que fields_get confirma todo lo pedido — igual de válido que un
    // servidor con `base` completo (el caso real, ver PartnerRecordMapper).
    return {for (final field in fields) field: <String, dynamic>{}};
  }

  @override
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
  }) async {
    if (model == 'res.users') {
      userSearchReadFields.add(fields);
      return [
        {
          for (final field in fields)
            if (userRow.containsKey(field)) field: userRow[field],
        },
      ];
    }
    if (model == 'res.partner') {
      return [
        {
          for (final field in fields)
            if (partnerRow.containsKey(field)) field: partnerRow[field],
        },
      ];
    }
    return const [];
  }
}

const _fullUserFieldsMetadata = <String, dynamic>{
  'name': <String, dynamic>{},
  'login': <String, dynamic>{},
  'lang': <String, dynamic>{},
  'tz': <String, dynamic>{
    'selection': [
      ['America/Guayaquil', 'America/Guayaquil'],
      ['America/New_York', 'America/New_York'],
    ],
  },
  'signature': <String, dynamic>{},
  'notification_type': <String, dynamic>{
    'selection': [
      ['email', 'Correo electrónico'],
      ['inbox', 'Bandeja de entrada'],
    ],
  },
  'property_warehouse_id': <String, dynamic>{},
  'mobile_phone': <String, dynamic>{},
  'work_email': <String, dynamic>{},
  'work_phone': <String, dynamic>{},
  'avatar_128': <String, dynamic>{},
  'group_ids': <String, dynamic>{},
  'partner_id': <String, dynamic>{},
  'company_id': <String, dynamic>{},
  'write_date': <String, dynamic>{},
};

Map<String, dynamic> _userRow({int id = 5}) => {
  'id': id,
  'name': 'Erik Salazar',
  'login': 'erik',
  'lang': 'es_EC',
  'tz': 'America/Guayaquil',
  'signature': '<p>Erik</p>',
  'notification_type': 'email',
  'property_warehouse_id': [3, 'Bodega Central'],
  'mobile_phone': '0999999999',
  'work_email': 'erik@example.com',
  'work_phone': '022222222',
  'avatar_128': 'ZmFrZS1hdmF0YXI=',
  'group_ids': [10, 11],
  'partner_id': [42, 'Erik Salazar'],
  'company_id': [1, 'Tecnosmart'],
  'write_date': '2026-09-13 10:00:00',
};

Map<String, dynamic> _partnerRow({int id = 42}) => {
  'id': id,
  'name': 'Erik Salazar',
  'display_name': 'Erik Salazar',
  'ref': null,
  'vat': '0999999999001',
  'email': 'erik@example.com',
  'phone': '0999999999',
  'street': 'Av. Siempre Viva 123',
  'street2': null,
  'city': 'Quito',
  'zip': '170150',
  'country_id': [65, 'Ecuador'],
  'state_id': [700, 'Pichincha'],
  'avatar_128': null,
  'is_company': false,
  'active': true,
  'parent_id': false,
  'commercial_partner_id': [id, 'Erik Salazar'],
  'property_product_pricelist': false,
  'property_payment_term_id': false,
  'lang': 'es_EC',
  'comment': null,
  'write_date': '2026-09-13 10:00:00',
};

AppScope _scope({int userId = 5}) => AppScope(
  appId: 'panel',
  installationId: 'i',
  normalizedServerUrl: 'https://erp.test',
  database: 'db',
  userId: userId,
);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  // Contrato (b): la fila del usuario actual queda con lang/tz/group_ids, y
  // su partner con la dirección.
  test(
    'b: el usuario actual y su partner quedan en Drift con lang/tz/'
    'group_ids/dirección',
    () async {
      final reader = _AccountReader(
        userRow: _userRow(),
        partnerRow: _partnerRow(),
        userFieldsMetadata: _fullUserFieldsMetadata,
      );
      final loader = RuntimeAccountLoader(reader);
      final scope = _scope();

      final userBatch = await loader.userLoader(scope, null);
      await writeCurrentUserRecords(db, userBatch.records, userBatch.cursor);

      final partnerBatch = await loader.partnerLoader(scope, null);
      final guard = CurrentAccountPartnerGuard();
      await writeCurrentUserPartnerRecords(guard)(
        db,
        partnerBatch.records,
        partnerBatch.cursor,
      );

      final user = (await db.select(db.resUsers).get()).single;
      expect(user.odooId, 5);
      expect(user.name, 'Erik Salazar');
      expect(user.lang, 'es_EC');
      expect(user.tz, 'America/Guayaquil');
      expect(user.groupIds, '[10,11]');
      expect(user.isCurrentUser, isTrue);
      expect(user.partnerId, 42);
      expect(user.propertyWarehouseId, 3);
      expect(user.mobilePhone, '0999999999');

      final partner = (await db.select(db.resPartner).get()).single;
      expect(partner.odooId, 42);
      expect(partner.street, 'Av. Siempre Viva 123');
      expect(partner.city, 'Quito');
      expect(partner.countryId, 65);
      expect(partner.stateId, 700);
      expect(guard.protectedIds, {42});
    },
  );

  // Contrato (c): con fields_get sin mobile_phone ni property_warehouse_id,
  // la sync no los pide y no revienta.
  test(
    'c: sin mobile_phone ni property_warehouse_id en fields_get, la sync '
    'no los pide y no revienta',
    () async {
      final metadataSinModulosOpcionales = Map<String, dynamic>.from(
        _fullUserFieldsMetadata,
      )..removeWhere(
        (key, _) => key == 'mobile_phone' || key == 'property_warehouse_id',
      );
      final userRowSinEsosCampos = Map<String, dynamic>.from(_userRow())
        ..remove('mobile_phone')
        ..remove('property_warehouse_id');
      final reader = _AccountReader(
        userRow: userRowSinEsosCampos,
        partnerRow: _partnerRow(),
        userFieldsMetadata: metadataSinModulosOpcionales,
      );
      final loader = RuntimeAccountLoader(reader);
      final scope = _scope();

      final batch = await loader.userLoader(scope, null);
      await expectLater(
        writeCurrentUserRecords(db, batch.records, batch.cursor),
        completes,
      );

      expect(reader.userSearchReadFields, isNotEmpty);
      final requested = reader.userSearchReadFields.first;
      expect(requested, isNot(contains('mobile_phone')));
      expect(requested, isNot(contains('property_warehouse_id')));

      final user = (await db.select(db.resUsers).get()).single;
      expect(user.mobilePhone, isNull);
      expect(user.propertyWarehouseId, isNull);
      // El resto de campos, que SÍ existían, se sigue pidiendo y guardando.
      expect(user.lang, 'es_EC');
      expect(user.name, 'Erik Salazar');
    },
  );

  // Contrato (f): con fields_get que trae mobile_phone, tras la pasada
  // FieldAvailabilityCache lo da disponible.
  test(
    'f: FieldAvailabilityCache da mobile_phone disponible cuando '
    'fields_get lo confirma',
    () async {
      final reader = _AccountReader(
        userRow: _userRow(),
        partnerRow: _partnerRow(),
        userFieldsMetadata: _fullUserFieldsMetadata,
      );
      final loader = RuntimeAccountLoader(reader);
      final scope = _scope();

      final batch = await loader.userLoader(scope, null);
      await writeCurrentUserRecords(db, batch.records, batch.cursor);

      final available = await FieldAvailabilityCache(
        db,
      ).knownAvailableUserFields();
      expect(available, contains('mobile_phone'));
    },
  );

  // Contrato (g): con fields_get sin property_warehouse_id, lo da NO
  // disponible.
  test(
    'g: FieldAvailabilityCache da property_warehouse_id NO disponible '
    'cuando fields_get no lo trae',
    () async {
      final metadataSinWarehouse = Map<String, dynamic>.from(
        _fullUserFieldsMetadata,
      )..remove('property_warehouse_id');
      final userRowSinWarehouse = Map<String, dynamic>.from(_userRow())
        ..remove('property_warehouse_id');
      final reader = _AccountReader(
        userRow: userRowSinWarehouse,
        partnerRow: _partnerRow(),
        userFieldsMetadata: metadataSinWarehouse,
      );
      final loader = RuntimeAccountLoader(reader);
      final scope = _scope();

      final batch = await loader.userLoader(scope, null);
      await writeCurrentUserRecords(db, batch.records, batch.cursor);

      final available = await FieldAvailabilityCache(
        db,
      ).knownAvailableUserFields();
      expect(available, isNot(contains('property_warehouse_id')));
    },
  );

  // Contrato (h): un campo que estuvo disponible y luego desaparece del
  // servidor (módulo desinstalado) queda NO disponible tras la siguiente
  // sincronización — no un marcador viejo sobreviviendo para siempre.
  test(
    'h: property_warehouse_id deja de figurar disponible cuando '
    'desaparece de fields_get en una segunda pasada',
    () async {
      final scope = _scope();

      final readerConDisponible = _AccountReader(
        userRow: _userRow(),
        partnerRow: _partnerRow(),
        userFieldsMetadata: _fullUserFieldsMetadata,
      );
      final primeraPasada = await RuntimeAccountLoader(
        readerConDisponible,
      ).userLoader(scope, null);
      await writeCurrentUserRecords(
        db,
        primeraPasada.records,
        primeraPasada.cursor,
      );
      final disponibleAntes = await FieldAvailabilityCache(
        db,
      ).knownAvailableUserFields();
      expect(disponibleAntes, contains('property_warehouse_id'));

      final metadataSinWarehouse = Map<String, dynamic>.from(
        _fullUserFieldsMetadata,
      )..remove('property_warehouse_id');
      final userRowSinWarehouse = Map<String, dynamic>.from(_userRow())
        ..remove('property_warehouse_id');
      final readerSinDisponible = _AccountReader(
        userRow: userRowSinWarehouse,
        partnerRow: _partnerRow(),
        userFieldsMetadata: metadataSinWarehouse,
      );
      final segundaPasada = await RuntimeAccountLoader(
        readerSinDisponible,
      ).userLoader(scope, null);
      await writeCurrentUserRecords(
        db,
        segundaPasada.records,
        segundaPasada.cursor,
      );

      final disponibleDespues = await FieldAvailabilityCache(
        db,
      ).knownAvailableUserFields();
      expect(disponibleDespues, isNot(contains('property_warehouse_id')));
    },
  );

  // Contrato (e): las selecciones de tz (y notification_type) quedan en la
  // caché de FieldSelections.
  test('e: las selecciones de tz quedan en la caché local', () async {
    final reader = _AccountReader(
      userRow: _userRow(),
      partnerRow: _partnerRow(),
      userFieldsMetadata: _fullUserFieldsMetadata,
    );
    final loader = RuntimeAccountLoader(reader);
    final scope = _scope();

    final batch = await loader.userLoader(scope, null);
    await writeCurrentUserRecords(db, batch.records, batch.cursor);

    final selections = await db.select(db.fieldSelections).get();
    final tz = selections.singleWhere(
      (row) => row.model == 'res.users' && row.field == 'tz',
    );
    expect(tz.selections, contains('America/Guayaquil'));
    final notificationType = selections.singleWhere(
      (row) => row.model == 'res.users' && row.field == 'notification_type',
    );
    expect(notificationType.selections, contains('inbox'));
  });

  // Contrato (d): una pasada de «customers» que no trae al partner del
  // usuario NO lo borra — probado a nivel de DriftCatalogStore, donde vive
  // el mecanismo real de borrado (domain-exit / sync.deleted.record).
  group('d: el catálogo customers no borra al partner del usuario actual', () {
    late RuntimeDatabaseOwner owner;
    late AppScope scope;

    setUp(() async {
      owner = RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      );
      scope = _scope();
      await owner.open(scope);
    });

    tearDown(() => owner.close());

    test(
      'sin CurrentAccountPartnerGuard, el barrido de salida de dominio SÍ '
      'lo borra (así se ve el problema que la guarda resuelve)',
      () async {
        final store = DriftCatalogStore<Map<String, dynamic>>(
          owner: owner,
          name: 'partner',
          writeRows: writePartnerRecords,
          readRows: readPartnerRecords,
        );
        await store.commit(
          scope,
          CatalogBatch(
            records: const [
              CatalogRecord(
                uuid: 'p42',
                value: {'id': 42, 'name': 'Erik Salazar (vendedor)'},
              ),
            ],
            cursor: 'c1',
          ),
        );
        expect(
          await readPartnerRecords(owner.active!.database),
          hasLength(1),
        );

        // El partner del usuario no es cliente (customer_rank == 0): el
        // escaneo de "salida de dominio" de `customers` lo reporta como
        // borrado en cuanto su write_date entra en la ventana incremental.
        await store.commit(
          scope,
          const CatalogBatch(records: [], cursor: 'c2', deletedIds: [42]),
        );

        expect(await readPartnerRecords(owner.active!.database), isEmpty);
      },
    );

    test(
      'con CurrentAccountPartnerGuard, el mismo escenario NO lo borra',
      () async {
        final guard = CurrentAccountPartnerGuard()..update(42);
        final store = DriftCatalogStore<Map<String, dynamic>>(
          owner: owner,
          name: 'partner',
          writeRows: writePartnerRecords,
          readRows: readPartnerRecords,
          neverDeleteIds: () => guard.protectedIds,
        );
        await store.commit(
          scope,
          CatalogBatch(
            records: const [
              CatalogRecord(
                uuid: 'p42',
                value: {'id': 42, 'name': 'Erik Salazar (vendedor)'},
              ),
            ],
            cursor: 'c1',
          ),
        );

        await store.commit(
          scope,
          const CatalogBatch(records: [], cursor: 'c2', deletedIds: [42]),
        );

        final rows = await readPartnerRecords(owner.active!.database);
        expect(rows.single.value['id'], 42);
      },
    );

    test(
      'la guarda tampoco lo borra cuando el catálogo reconcilia por ids '
      'activos remotos (servidor sin sync.deleted.record)',
      () async {
        final guard = CurrentAccountPartnerGuard()..update(42);
        final store = DriftCatalogStore<Map<String, dynamic>>(
          owner: owner,
          name: 'partner',
          writeRows: writePartnerRecords,
          readRows: readPartnerRecords,
          neverDeleteIds: () => guard.protectedIds,
        );
        await store.commit(
          scope,
          CatalogBatch(
            records: const [
              CatalogRecord(
                uuid: 'p42',
                value: {'id': 42, 'name': 'Erik Salazar (vendedor)'},
              ),
              CatalogRecord(
                uuid: 'p9',
                value: {'id': 9, 'name': 'Cliente real'},
              ),
            ],
            cursor: 'c1',
          ),
        );

        // Reconciliación completa: el servidor sólo confirma el 9 como
        // cliente activo — el 42 (usuario) no aparecería en ese conjunto
        // porque `customer_rank` no es > 0, pero la guarda lo protege.
        await store.commit(
          scope,
          const CatalogBatch(records: [], cursor: 'c2', remoteActiveIds: {9}),
        );

        final ids = (await readPartnerRecords(owner.active!.database))
            .map((row) => row.value['id'])
            .toSet();
        expect(ids, {9, 42});
      },
    );
  });

  // No pedido explícitamente por el encargo, pero necesario por la misma
  // razón que la guarda de (d): si "Mis preferencias" (el agente
  // preferencias-odoo) encoló un cambio de `res.partner` en `offline_queue`
  // que todavía no sincronizó, el catálogo `currentUserPartner` no debe
  // pisarlo con la versión vieja del servidor. Se resuelve registrando
  // 'currentUserPartner' → 'res.partner' en `_catalogOdooModels`
  // (local_catalog_adapters.dart), el mismo mecanismo que ya protege a los
  // otros catorce catálogos.
  test(
    'currentUserPartner respeta una edición pendiente en offline_queue',
    () async {
      final owner = RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      );
      final scope = _scope();
      await owner.open(scope);
      addTearDown(owner.close);

      final store = DriftCatalogStore<Map<String, dynamic>>(
        owner: owner,
        name: 'currentUserPartner',
        writeRows: writePartnerRecords,
      );
      await store.commit(
        scope,
        CatalogBatch(
          records: const [
            CatalogRecord(
              uuid: 'p42',
              value: {'id': 42, 'name': 'Editado offline, aún sin subir'},
            ),
          ],
          cursor: 'c1',
        ),
      );
      await OfflineQueueDataSource(owner.active!.database).queueOperation(
        model: 'res.partner',
        method: 'write',
        recordId: 42,
        values: const {'street': 'Nueva calle'},
      );

      await store.commit(
        scope,
        CatalogBatch(
          records: const [
            CatalogRecord(
              uuid: 'p42',
              value: {'id': 42, 'name': 'Versión remota vieja'},
            ),
          ],
          cursor: 'c2',
        ),
      );

      final activeDb = owner.active!.database;
      final row = (await activeDb.select(activeDb.resPartner).get())
          .where((r) => r.odooId == 42)
          .single;
      expect(row.name, 'Editado offline, aún sin subir');
    },
  );
}
