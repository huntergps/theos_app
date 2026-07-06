/// Tests for `SyncConfigBuilder.create`'s isolate dispatch threshold
/// (Fase E1): por debajo de [isolateThreshold] debe usar `fromOdoo` inline;
/// en o por encima del umbral debe despachar el parseo de la página
/// completa a `parseInIsolate` (isolate real, ya que `dart test` corre en
/// la VM nativa — ver `isolate_dispatch_test.dart` para el shim en sí).
import 'package:test/test.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

import 'mocks/mock_odoo_client.dart';

/// Modelo de prueba — el campo [source] deja constancia de QUÉ función de
/// parseo generó el registro, para poder verificar el dispatch sin depender
/// de espiar closures (que de todas formas no serían transferibles a un
/// isolate real).
class _FakeRecord {
  final int id;
  final String source;
  const _FakeRecord({required this.id, required this.source});
}

/// Tear-off de instancia simulado — se usa en el camino per-row y como
/// fallback bajo el umbral. NO necesita ser static para este test (a
/// diferencia de [_fromOdooIsolate], que si se despacha a un isolate real
/// SÍ debe ser top-level/static).
_FakeRecord _fromOdooInline(Map<String, dynamic> data) =>
    _FakeRecord(id: data['id'] as int, source: 'inline');

/// Versión "estática pura" (top-level acá) — equivalente a
/// `XxxManager.fromOdooMap` en producción. Debe ser top-level/static para
/// ser transferible a `Isolate.run()`.
_FakeRecord _fromOdooIsolate(Map<String, dynamic> data) =>
    _FakeRecord(id: data['id'] as int, source: 'isolate');

void main() {
  setUpAll(() {
    registerOdooClientFallbacks();
  });

  group('SyncConfigBuilder.create — isolateParser dispatch (Fase E1)', () {
    late MockOdooClient client;
    late GenericSyncRepository repo;

    setUp(() {
      client = MockOdooClient();
      repo = GenericSyncRepository(odooClient: client);
    });

    /// Configura el mock para devolver [records] en la única página
    /// esperada (records.length < batchSize ⇒ syncModel() no pide una
    /// segunda página).
    void setupSinglePage(List<Map<String, dynamic>> records) {
      client.setupSearchCount(model: 'test.model', count: records.length);
      client.setupSearchRead(model: 'test.model', results: records);
    }

    test(
      'por debajo de isolateThreshold usa fromOdoo inline (sin isolate)',
      () async {
        final records = List.generate(5, (i) => {'id': i, 'name': 'r$i'});
        setupSinglePage(records);

        final captured = <_FakeRecord>[];
        final config = SyncConfigBuilder.create<_FakeRecord>(
          model: 'test.model',
          fields: const ['id', 'name'],
          batchSize: 500,
          fromOdoo: _fromOdooInline,
          upsertLocal: (r) async => captured.add(r),
          upsertLocalBatch: (list) async => captured.addAll(list),
          isolateParser: _fromOdooIsolate,
          isolateThreshold: 10, // 5 registros < 10 ⇒ camino inline
        );

        final result = await repo.syncModel(config);

        expect(result.synced, equals(5));
        expect(captured, hasLength(5));
        expect(captured.every((r) => r.source == 'inline'), isTrue);
      },
    );

    test(
      'en o por encima de isolateThreshold despacha a parseInIsolate',
      () async {
        final records = List.generate(5, (i) => {'id': i, 'name': 'r$i'});
        setupSinglePage(records);

        final captured = <_FakeRecord>[];
        final config = SyncConfigBuilder.create<_FakeRecord>(
          model: 'test.model',
          fields: const ['id', 'name'],
          batchSize: 500,
          fromOdoo: _fromOdooInline,
          upsertLocal: (r) async => captured.add(r),
          upsertLocalBatch: (list) async => captured.addAll(list),
          isolateParser: _fromOdooIsolate,
          isolateThreshold: 3, // 5 registros >= 3 ⇒ camino isolate
        );

        final result = await repo.syncModel(config);

        expect(result.synced, equals(5));
        expect(captured, hasLength(5));
        expect(captured.every((r) => r.source == 'isolate'), isTrue);
      },
    );

    test(
      'sin isolateParser, upsertLocalBatch sigue usando fromOdoo inline '
      '(cero cambio de comportamiento para configs existentes)',
      () async {
        final records = List.generate(500, (i) => {'id': i, 'name': 'r$i'});
        setupSinglePage(records);

        final captured = <_FakeRecord>[];
        final config = SyncConfigBuilder.create<_FakeRecord>(
          model: 'test.model',
          fields: const ['id', 'name'],
          // batchSize > records.length para que syncModel() corte la
          // paginación tras la primera página (ver `records.length <
          // config.batchSize` en generic_sync_repository.dart). Si fueran
          // iguales, syncModel() pediría una página más — y el mock, al no
          // discriminar por offset, devolvería lo mismo para siempre.
          batchSize: 501,
          fromOdoo: _fromOdooInline,
          upsertLocal: (r) async => captured.add(r),
          upsertLocalBatch: (list) async => captured.addAll(list),
          // isolateParser NO se pasa — aunque la página (500) supere
          // cualquier isolateThreshold razonable, no hay a dónde despachar.
        );

        final result = await repo.syncModel(config);

        expect(result.synced, equals(500));
        expect(captured.every((r) => r.source == 'inline'), isTrue);
      },
    );

    test(
      'sin upsertLocalBatch, isolateParser no tiene efecto (camino per-row '
      'de siempre, fromOdoo + upsertLocal)',
      () async {
        final records = List.generate(5, (i) => {'id': i, 'name': 'r$i'});
        setupSinglePage(records);

        final captured = <_FakeRecord>[];
        final config = SyncConfigBuilder.create<_FakeRecord>(
          model: 'test.model',
          fields: const ['id', 'name'],
          batchSize: 500,
          fromOdoo: _fromOdooInline,
          upsertLocal: (r) async => captured.add(r),
          // upsertLocalBatch NO se pasa ⇒ upsertBatch queda null en
          // ModelSyncConfig ⇒ syncModel() usa el camino per-row.
          isolateParser: _fromOdooIsolate,
          isolateThreshold: 1,
        );

        final result = await repo.syncModel(config);

        expect(result.synced, equals(5));
        expect(captured, hasLength(5));
        expect(captured.every((r) => r.source == 'inline'), isTrue);
      },
    );
  });
}
