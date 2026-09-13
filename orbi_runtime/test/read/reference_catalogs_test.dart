import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show AppDatabase;

// Import directo, sin pasar por el barril `orbi_runtime.dart`: no necesita
// nada de `src/realtime/` (en obras por otro agente) ni de `src/account/`.
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/read/json2_read_adapters.dart';
import 'package:orbi_runtime/src/read/local_catalog_adapters.dart';
import 'package:orbi_runtime/src/storage/runtime_database_owner.dart';

/// Lector falso que sirve tanto `searchRead` (proyectando sólo los campos
/// pedidos, como haría el servidor real) como `fieldsGet` (a partir de
/// [fieldsByModel]) — necesario porque `res.groups` se resuelve con
/// [RuntimeCatalogLoader.selfDescribingLoader], no con un descriptor fijo.
class _CatalogReader implements Json2ReadPort, Json2FieldsGetPort {
  _CatalogReader({required this.recordsByModel, this.fieldsByModel = const {}});

  final Map<String, List<Map<String, dynamic>>> recordsByModel;
  final Map<String, Set<String>> fieldsByModel;

  @override
  Future<Map<String, dynamic>> fieldsGet({
    required String model,
    required List<String> fields,
  }) async {
    final present = fieldsByModel[model] ?? fields.toSet();
    return {
      for (final field in fields)
        if (present.contains(field)) field: <String, dynamic>{},
    };
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
    final rows = recordsByModel[model] ?? const [];
    final start = offset ?? 0;
    if (start >= rows.length) return const [];
    final end = limit == null
        ? rows.length
        : (start + limit).clamp(start, rows.length);
    return rows
        .sublist(start, end)
        .map(
          (row) => {
            for (final field in fields)
              if (row.containsKey(field)) field: row[field],
          },
        )
        .toList();
  }
}

void main() {
  late RuntimeDatabaseOwner owner;
  late AppScope scope;

  setUp(() async {
    owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase.memory()),
    );
    scope = AppScope(
      appId: 'panel',
      installationId: 'i',
      normalizedServerUrl: 'https://erp.test',
      database: 'db',
      userId: 2,
    );
    await owner.open(scope);
  });

  tearDown(() => owner.close());

  // Contrato (a) del encargo: una pasada de sync con respuestas simuladas
  // deja filas en res_lang, res_country, res_country_state y res_groups.
  test(
    'a: una pasada de sync deja filas en lang/country/countryState/groups',
    () async {
      final reader = _CatalogReader(
        recordsByModel: {
          'res.lang': [
            {
              'id': 1,
              'name': 'Español (EC)',
              'code': 'es_EC',
              'active': true,
              'write_date': '2026-09-01 00:00:00',
            },
          ],
          'res.country': [
            {
              'id': 65,
              'name': 'Ecuador',
              'code': 'EC',
              'write_date': '2026-09-01 00:00:00',
            },
          ],
          'res.country.state': [
            {
              'id': 700,
              'name': 'Pichincha',
              'code': 'P',
              'country_id': [65, 'Ecuador'],
              'write_date': '2026-09-01 00:00:00',
            },
          ],
          'res.groups': [
            {
              'id': 10,
              'name': 'Ventas / Usuario',
              'full_name': 'Ventas / Usuario',
              // `category_id` no existe en Odoo 19/20 (ver la nota en
              // writeGroupRecords) pero sí en este servidor de prueba —
              // el punto es que el catálogo lo toma si `fields_get` lo
              // confirma, y `xml_id` NUNCA se pide (no es un campo real).
              'category_id': [3, 'Ventas'],
              'write_date': '2026-09-01 00:00:00',
            },
          ],
        },
        fieldsByModel: {
          'res.groups': {'name', 'full_name', 'category_id', 'write_date'},
        },
      );
      final loader = RuntimeCatalogLoader(reader);

      final langStore = DriftCatalogStore<Map<String, dynamic>>(
        owner: owner,
        name: 'lang',
        writeRows: writeLanguageRecords,
        readRows: readLanguageRecords,
      );
      final countryStore = DriftCatalogStore<Map<String, dynamic>>(
        owner: owner,
        name: 'country',
        writeRows: writeCountryRecords,
        readRows: readCountryRecords,
      );
      final stateStore = DriftCatalogStore<Map<String, dynamic>>(
        owner: owner,
        name: 'countryState',
        writeRows: writeCountryStateRecords,
        readRows: readCountryStateRecords,
      );
      final groupsStore = DriftCatalogStore<Map<String, dynamic>>(
        owner: owner,
        name: 'groups',
        writeRows: writeGroupRecords,
        readRows: readGroupRecords,
      );

      await langStore.commit(
        scope,
        await loader.loader(RuntimeCatalogs.languages)(scope, null),
      );
      await countryStore.commit(
        scope,
        await loader.loader(RuntimeCatalogs.countries)(scope, null),
      );
      await stateStore.commit(
        scope,
        await loader.loader(RuntimeCatalogs.countryStates)(scope, null),
      );
      await groupsStore.commit(
        scope,
        await loader.selfDescribingLoader(
          key: 'groups',
          model: 'res.groups',
          candidateFields: const [
            'name',
            'full_name',
            'category_id',
            'write_date',
          ],
        )(scope, null),
      );

      final db = owner.active!.database;
      expect((await db.select(db.resLang).get()).single.code, 'es_EC');
      expect((await db.select(db.resCountry).get()).single.name, 'Ecuador');
      final state = (await db.select(db.resCountryState).get()).single;
      expect(state.name, 'Pichincha');
      expect(state.countryId, 65);
      final group = (await db.select(db.resGroups).get()).single;
      expect(group.name, 'Ventas / Usuario');
      expect(group.categoryId, 3);
      // `xml_id` nunca se pidió al servidor: no hay forma de que llegue.
      expect(group.xmlId, isNull);
    },
  );

  test(
    'res.groups sin category_id disponible (Odoo 20) no revienta y deja '
    'la columna en null',
    () async {
      final reader = _CatalogReader(
        recordsByModel: {
          'res.groups': [
            {
              'id': 11,
              'name': 'Administración / Ajustes',
              'full_name': 'Administración / Ajustes',
              'write_date': '2026-09-01 00:00:00',
            },
          ],
        },
        fieldsByModel: {
          // Sin `category_id`: el servidor lo reemplazó por `privilege_id`.
          'res.groups': {'name', 'full_name', 'write_date'},
        },
      );
      final loader = RuntimeCatalogLoader(reader);
      final groupsStore = DriftCatalogStore<Map<String, dynamic>>(
        owner: owner,
        name: 'groups',
        writeRows: writeGroupRecords,
        readRows: readGroupRecords,
      );

      await groupsStore.commit(
        scope,
        await loader.selfDescribingLoader(
          key: 'groups',
          model: 'res.groups',
          candidateFields: const [
            'name',
            'full_name',
            'category_id',
            'write_date',
          ],
        )(scope, null),
      );

      final db = owner.active!.database;
      final group = (await db.select(db.resGroups).get()).single;
      expect(group.name, 'Administración / Ajustes');
      expect(group.categoryId, isNull);
    },
  );
}
