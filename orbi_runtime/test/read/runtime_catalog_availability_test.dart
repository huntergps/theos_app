import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

/// Los 17 modelos que declara `RuntimeCatalogComposition._specs` (ver
/// `runtime_catalog_composition.dart`). Sirve para simular "el servidor
/// tiene todo menos X" sin repetir la lista completa en cada test.
const _allCatalogModels = <String>{
  'account.credit.card.brand',
  'account.credit.card.deadline',
  'account.card.lote',
  'account.payment.method.line',
  'res.partner',
  'product.product',
  'account.payment.term',
  'uom.uom',
  'collection.config',
  'collection.session',
  'account.tax',
  'product.pricelist',
  'stock.warehouse',
  'account.journal',
  'res.lang',
  'res.country',
  'res.country.state',
};

/// Las 17 claves de composición correspondientes, en el mismo orden que
/// `RuntimeCatalogComposition` las declara.
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

/// Lector falso dedicado a `RuntimeCatalogAvailability`/E02: [existingModels]
/// simula la respuesta REAL de `ir.model` (nunca una lista fija), y
/// [fieldsByModel] simula `fields_get` sólo para los modelos que el test
/// necesita recortar — cualquier otro modelo se asume con todos los campos
/// pedidos presentes, igual que un servidor completo.
class _CatalogReader implements Json2ReadPort, Json2FieldsGetPort {
  _CatalogReader({
    required this.existingModels,
    this.recordsByModel = const {},
    this.fieldsByModel = const {},
    this.errorsByModel = const {},
    this.failIrModel = false,
  });

  final Set<String> existingModels;
  final Map<String, List<Map<String, dynamic>>> recordsByModel;
  final Map<String, Set<String>> fieldsByModel;
  final Map<String, Exception Function()> errorsByModel;
  final bool failIrModel;

  final calls = <_RecordedCall>[];

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
    calls.add((model: model, fields: fields, domain: domain));
    if (model == 'ir.model') {
      if (failIrModel) {
        throw const OdooConnectionException('Sin conexión al servidor');
      }
      final clause = (domain ?? const []).whereType<List>().firstWhere(
        (entry) =>
            entry.length == 3 && entry[0] == 'model' && entry[1] == 'in',
        orElse: () => const [],
      );
      final requested = clause.length == 3
          ? (clause[2] as List).cast<String>()
          : const <String>[];
      return [
        for (final name in requested)
          if (existingModels.contains(name)) {'model': name},
      ];
    }
    final failure = errorsByModel[model];
    if (failure != null) throw failure();
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
    'servidor sin account.tax: el catálogo de impuestos queda unsupported '
    'y el ciclo termina sin error',
    () async {
      final reader = _CatalogReader(
        existingModels: _allCatalogModels.difference({'account.tax'}),
      );
      final composition = await compose(reader);

      final result = await composition.sync('tax');
      expect(result.status, SyncJobStatus.committed);
      expect(
        (await composition.availability.resolve('tax')).state,
        OdooCapabilityState.unsupported,
      );
      // El catálogo NUNCA llegó a pedir `account.tax` de verdad: la única
      // llamada de por medio fue `ir.model`.
      expect(reader.calls.any((call) => call.model == 'account.tax'), isFalse);

      // El resto del ciclo (los otros 16 catálogos, que sí existen) termina
      // sin ningún fallo — `tax` no cuenta como error.
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
    'product.product sin taxes_id: productos se sincroniza y el '
    'search_read no pide taxes_id',
    () async {
      final reader = _CatalogReader(
        existingModels: _allCatalogModels,
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

      final productCall = reader.calls.lastWhere(
        (call) => call.model == 'product.product',
      );
      expect(productCall.fields, isNot(contains('taxes_id')));

      final db = owner.active!.database;
      expect((await db.select(db.productProduct).get()).single.name, 'Producto sin impuestos');
    },
  );

  test(
    'res.partner sin customer_rank: clientes se sincroniza sin ese filtro',
    () async {
      final reader = _CatalogReader(
        existingModels: _allCatalogModels,
        fieldsByModel: {
          'res.partner': {
            'id',
            'name',
            'vat',
            'email',
            'phone',
            'company_id',
            'active',
            'write_date',
          },
        },
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
      );
      final composition = await compose(reader);

      final result = await composition.sync('partner');
      expect(result.status, SyncJobStatus.committed);

      final partnerCall = reader.calls.lastWhere(
        (call) => call.model == 'res.partner',
      );
      expect(
        partnerCall.domain!.any(
          (clause) => clause is List && clause.isNotEmpty && clause.first == 'customer_rank',
        ),
        isFalse,
      );
      // El resto del dominio (que no depende de un campo opcional) se
      // conserva tal cual.
      expect(
        partnerCall.domain!.any(
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
    'ir.model falla por red: ningún catálogo queda unsupported',
    () async {
      final reader = _CatalogReader(
        existingModels: _allCatalogModels,
        failIrModel: true,
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

      // `unknown` no apaga nada: el catálogo sigue corriendo con su
      // descriptor de siempre, sin esperar a que el sondeo se resuelva.
      final result = await composition.sync('tax');
      expect(result.status, SyncJobStatus.committed);
      final db = owner.active!.database;
      expect((await db.select(db.accountTax).get()).single.name, 'IVA 15%');
    },
  );

  test(
    'un 500 que no es de campo inexistente sigue siendo fallo',
    () async {
      final reader = _CatalogReader(
        existingModels: _allCatalogModels,
        errorsByModel: {
          'account.tax': () => const OdooServerException(
            'Error interno no relacionado con campos',
          ),
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
