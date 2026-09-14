import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

/// Las 17 claves de composición que declara `RuntimeCatalogComposition`
/// (`orbi_runtime/lib/src/read/runtime_catalog_composition.dart`).
const _specKeys = <String>[
  'partner',
  'product',
  'paymentTerm',
  'uom',
  'collectionConfig',
  'collectionSession',
  'tax',
  'pricelist',
  'warehouse',
  'journal',
  'cardBrand',
  'cardDeadline',
  'cardLote',
  'paymentMethodLine',
  'lang',
  'country',
  'countryState',
];

typedef _RecordedCall = ({
  String model,
  List<String> fields,
  List<dynamic>? domain,
});

/// Lector falso dedicado a `RuntimeCatalogAvailability`/E02 (corrección del
/// 13-sep-2026: sondeo por `fields_get`, sin `ir.model`).
///
/// - [missingModels]: `fieldsGet`/`fieldsGetAttributes` de ese modelo lanza
///   `OdooNotFoundException` — simula que el modelo no existe.
/// - [fieldsByModel]: qué campos de los pedidos existen; un modelo ausente
///   de este mapa se asume con TODOS los campos pedidos presentes (servidor
///   completo).
/// - [fieldsGetErrorsByModel]: `fieldsGet`/`fieldsGetAttributes` de ese
///   modelo lanza la excepción dada (red/401/403) en vez de responder.
/// - [searchReadErrorsByModel]: cola de excepciones que el PRÓXIMO
///   `search_read` de ese modelo lanza, una por intento — se consume en
///   orden; agotada la cola, responde normal desde [recordsByModel].
class _CatalogReader
    implements Json2ReadPort, Json2FieldsGetPort, Json2FieldsGetAttributesPort {
  _CatalogReader({
    this.recordsByModel = const {},
    this.fieldsByModel = const {},
    this.missingModels = const {},
    this.fieldsGetErrorsByModel = const {},
    Map<String, List<Exception Function()>> searchReadErrorsByModel = const {},
  }) : _searchReadErrors = {
         for (final entry in searchReadErrorsByModel.entries)
           entry.key: List.of(entry.value),
       };

  final Map<String, List<Map<String, dynamic>>> recordsByModel;
  final Map<String, Set<String>> fieldsByModel;
  final Set<String> missingModels;
  final Map<String, Exception Function()> fieldsGetErrorsByModel;
  final Map<String, List<Exception Function()>> _searchReadErrors;

  final calls = <_RecordedCall>[];
  final fieldsGetCalls = <String>[];

  Future<Map<String, dynamic>> _fieldsGetImpl(
    String model,
    List<String> fields,
  ) async {
    fieldsGetCalls.add(model);
    if (missingModels.contains(model)) {
      throw const OdooNotFoundException('model does not exist');
    }
    final failure = fieldsGetErrorsByModel[model];
    if (failure != null) throw failure();
    final present = fieldsByModel[model] ?? fields.toSet();
    return {
      for (final field in fields)
        if (present.contains(field)) field: <String, dynamic>{},
    };
  }

  @override
  Future<Map<String, dynamic>> fieldsGet({
    required String model,
    required List<String> fields,
  }) => _fieldsGetImpl(model, fields);

  @override
  Future<Map<String, dynamic>> fieldsGetAttributes({
    required String model,
    required List<String> fields,
    required List<String> attributes,
  }) => _fieldsGetImpl(model, fields);

  @override
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
  }) async {
    calls.add((model: model, fields: fields, domain: domain));
    final queue = _searchReadErrors[model];
    if (queue != null && queue.isNotEmpty) {
      throw queue.removeAt(0)();
    }
    final rows = recordsByModel[model] ?? const <Map<String, dynamic>>[];
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
  late SessionActivation activation;
  late AppScope scope;

  Future<RuntimeCatalogComposition> compose(_CatalogReader reader) async {
    owner = RuntimeDatabaseOwner(factory: (_) => AppDatabase(NativeDatabase.memory()));
    scope = AppScope(
      appId: 'panel',
      installationId: 'i',
      normalizedServerUrl: 'https://erp.test',
      database: 'db',
      userId: 2,
    );
    final database = await owner.open(scope);
    activation = SessionActivation(database: database);
    return RuntimeCatalogComposition(
      activation: activation,
      owner: owner,
      reader: reader,
    );
  }

  tearDown(() => owner.close());

  test(
    'account.tax.fields_get da 404: unsupported, y el ciclo termina sin '
    'error — sin ninguna llamada a ir.model',
    () async {
      final reader = _CatalogReader(missingModels: {'account.tax'});
      final composition = await compose(reader);

      final result = await composition.sync('tax');
      expect(result.status, SyncJobStatus.committed);
      expect(
        (await composition.availability.resolve('tax')).state,
        OdooCapabilityState.unsupported,
      );
      // Nunca se pidió leer el modelo real de `account.tax` — sólo el
      // `fields_get` que lo descubrió inexistente.
      expect(reader.calls.any((call) => call.model == 'account.tax'), isFalse);
      expect(reader.calls.any((call) => call.model == 'ir.model'), isFalse);
      expect(reader.fieldsGetCalls, isNot(contains('ir.model')));

      final coordinator = SyncCoordinatorImpl(
        jobs: [for (final key in _specKeys) composition.job(key)],
      );
      await coordinator.start(scope);
      expect(coordinator.snapshot.failures, isEmpty);
      expect(coordinator.snapshot.failedCount, 0);
      await coordinator.dispose();
    },
  );

  test(
    'product.product sin taxes_id (fields_get): productos se sincroniza sin '
    'él, queda supported, y no hay ninguna llamada a ir.model',
    () async {
      final reader = _CatalogReader(
        fieldsByModel: {
          'product.product': {
            'id',
            'name',
            'default_code',
            'barcode',
            'list_price',
            'uom_id',
            'active',
            'write_date',
          },
        },
        recordsByModel: {
          'product.product': [
            {
              'id': 7,
              'name': 'Producto sin impuestos',
              'active': true,
              'write_date': '2026-09-13 10:00:00',
            },
          ],
        },
      );
      final composition = await compose(reader);

      final result = await composition.sync('product');
      expect(result.status, SyncJobStatus.committed);
      expect(
        (await composition.availability.resolve('product')).state,
        OdooCapabilityState.supported,
      );

      final productCall = reader.calls.lastWhere(
        (call) => call.model == 'product.product',
      );
      expect(productCall.fields, isNot(contains('taxes_id')));
      expect(reader.calls.any((call) => call.model == 'ir.model'), isFalse);

      final db = owner.active!.database;
      expect((await db.select(db.productProduct).get()).single.name, 'Producto sin impuestos');
    },
  );

  test(
    'res.partner: fields_get dice que customer_rank existe, pero el '
    'search_read real igual lanza OdooFieldNotFoundException(customer_rank) '
    '— se quita el filtro y se reintenta una vez, y sincroniza',
    () async {
      final reader = _CatalogReader(
        // `fields_get` no detecta nada raro: customer_rank "existe".
        fieldsByModel: const {},
        recordsByModel: {
          'res.partner': [
            {
              'id': 8,
              'name': 'Bodega sin cuenta cliente',
              'active': true,
              'write_date': '2026-09-13 10:00:00',
            },
          ],
        },
        searchReadErrorsByModel: {
          'res.partner': [
            () => const OdooFieldNotFoundException(
              targetModel: 'res.partner',
              fieldName: 'customer_rank',
              message: 'Invalid field res.partner.customer_rank',
            ),
          ],
        },
      );
      final composition = await compose(reader);

      final result = await composition.sync('partner');
      expect(result.status, SyncJobStatus.committed);

      // Dos intentos contra res.partner: el que falló y el reintento sin el
      // filtro.
      final partnerCalls = reader.calls
          .where((call) => call.model == 'res.partner')
          .toList();
      expect(partnerCalls, hasLength(2));
      expect(
        partnerCalls.last.domain!.any(
          (clause) => clause is List && clause.isNotEmpty && clause.first == 'customer_rank',
        ),
        isFalse,
      );
      expect(
        partnerCalls.last.domain!.any(
          (clause) => clause is List && clause.length == 3 && clause[0] == 'active',
        ),
        isTrue,
      );

      final db = owner.active!.database;
      expect(
        (await db.select(db.resPartner).get()).single.name,
        'Bodega sin cuenta cliente',
      );
    },
  );

  test(
    'fields_get da 403: el catálogo queda unknown y corre igual, con su '
    'descriptor de siempre (sin recortar nada)',
    () async {
      final reader = _CatalogReader(
        fieldsGetErrorsByModel: {
          'account.tax': () =>
              const OdooAccessDeniedException('403 forbidden'),
        },
        recordsByModel: {
          'account.tax': [
            {
              'id': 1,
              'name': 'IVA 15%',
              'amount': 15.0,
              'amount_type': 'percent',
              'active': true,
              'write_date': '2026-09-13 10:00:00',
            },
          ],
        },
      );
      final composition = await compose(reader);

      expect(
        (await composition.availability.resolve('tax')).state,
        OdooCapabilityState.unknown,
      );

      final result = await composition.sync('tax');
      expect(result.status, SyncJobStatus.committed);
      final db = owner.active!.database;
      expect((await db.select(db.accountTax).get()).single.name, 'IVA 15%');

      // Sigue `unknown`, no se cachea como definitivo — el próximo sondeo
      // vuelve a intentar `fields_get`.
      expect(
        (await composition.availability.resolve('tax')).state,
        OdooCapabilityState.unknown,
      );
    },
  );

  test(
    'un 500 que no es de campo inexistente sigue siendo fallo',
    () async {
      final reader = _CatalogReader(
        searchReadErrorsByModel: {
          'account.tax': [
            () => const OdooServerException(
              'Error interno no relacionado con campos',
            ),
          ],
        },
      );
      final composition = await compose(reader);

      final result = await composition.sync('tax');
      expect(result.status, SyncJobStatus.failed);
      // Y no se cachea como `unsupported`: un 500 genérico no es evidencia
      // de que el modelo/campo no exista.
      expect(
        (await composition.availability.resolve('tax')).state,
        isNot(OdooCapabilityState.unsupported),
      );
    },
  );
}
