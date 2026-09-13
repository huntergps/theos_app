import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart'
    show
        OdooAccessDeniedException,
        OdooMethodNotFoundException,
        OdooNotFoundException,
        OdooServerException;
// Import directo, sin pasar por el barril `orbi_runtime.dart`: éste no
// necesita nada de `src/realtime/`, y así el test no depende de que ese
// módulo (en obras por otro agente) compile.
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/read/json2_read_adapters.dart';

/// Cómo el doble responde a `sync.deleted.record.get_deleted_since`.
///
/// No hay un modo "ir.model no lo encuentra": medido contra ERP2 el
/// 13-sep-2026, un vendedor real recibe `403 POST /json/2/ir.model/search_read`
/// (`ir.model` exige `base.group_no_one`) aunque SÍ puede llamar
/// `get_deleted_since` directamente. Por eso `RuntimeCatalogLoader` ya no
/// sondea `ir.model`: intenta la llamada real y clasifica lo que responde.
enum _DeletedSinceBehavior {
  success,
  modelNotFound,
  methodNotFound,
  accessDenied,
  serverError,
}

/// Doble mínimo de `searchRead`/`call` que simula una tabla remota con
/// `write_date`, más `sync.deleted.record.get_deleted_since` para poder
/// mover el reloj del servidor entre llamadas.
final class _FakeReader implements Json2ReadPort, Json2CallPort {
  _FakeReader(this.table);

  /// Filas remotas "vivas". El test las muta entre llamadas para simular
  /// altas/bajas del servidor.
  List<Map<String, dynamic>> table;

  List<Map<String, dynamic>> deletedSince = const [];
  _DeletedSinceBehavior deletedSinceBehavior = _DeletedSinceBehavior.success;

  final calls = <({String model, List<dynamic>? domain, int? offset})>[];
  final rpcCalls =
      <({String model, String method, Map<String, dynamic>? kwargs})>[];

  @override
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
  }) async {
    calls.add((model: model, domain: domain, offset: offset));
    var rows = table;
    final since = _writeDateFloor(domain);
    if (since != null) {
      // Ambos lados de la comparación deben leerse como UTC: `since` ya lo
      // hace (`_writeDateFloor` le añade 'Z'), y la fila debe pasar por el
      // mismo `_parseUtc` — de lo contrario `DateTime.parse` interpretaría
      // el `write_date` de la fila en la hora LOCAL de esta máquina, y la
      // comparación quedaría desplazada por el huso horario en vez de por
      // el solapamiento que la prueba quiere medir.
      rows = rows
          .where(
            (row) => !_parseUtc(row['write_date'] as String).isBefore(since),
          )
          .toList();
    }
    rows.sort((a, b) {
      final byDate = (a['write_date'] as String).compareTo(
        b['write_date'] as String,
      );
      if (byDate != 0) return byDate;
      return (a['id'] as int).compareTo(b['id'] as int);
    });
    final start = offset ?? 0;
    if (start >= rows.length) return const [];
    final end = limit == null
        ? rows.length
        : (start + limit).clamp(start, rows.length);
    return rows.sublist(start, end);
  }

  @override
  Future<dynamic> call({
    required String model,
    required String method,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? context,
  }) async {
    rpcCalls.add((model: model, method: method, kwargs: kwargs));
    switch (deletedSinceBehavior) {
      case _DeletedSinceBehavior.success:
        return deletedSince;
      case _DeletedSinceBehavior.modelNotFound:
        // Servidor sin el módulo instalado.
        throw const OdooNotFoundException(
          'Object sync.deleted.record doesn\'t exist',
        );
      case _DeletedSinceBehavior.methodNotFound:
        // El modelo existe pero es una versión vieja del módulo, sin
        // `get_deleted_since` todavía.
        throw const OdooMethodNotFoundException(
          targetModel: 'sync.deleted.record',
          methodName: 'get_deleted_since',
          message: 'Method get_deleted_since does not exist',
        );
      case _DeletedSinceBehavior.accessDenied:
        // El modelo existe, pero esta sesión no puede leerlo.
        throw const OdooAccessDeniedException('Access Denied');
      case _DeletedSinceBehavior.serverError:
        throw const OdooServerException('boom');
    }
  }

  static DateTime? _writeDateFloor(List<dynamic>? domain) {
    if (domain == null) return null;
    for (final clause in domain) {
      if (clause is List &&
          clause.length == 3 &&
          clause[0] == 'write_date' &&
          clause[1] == '>=') {
        return _parseUtc(clause[2] as String);
      }
    }
    return null;
  }

  static DateTime _parseUtc(String odooDateTime) =>
      DateTime.parse('${odooDateTime.replaceFirst(' ', 'T')}Z');
}

Map<String, dynamic> _row(int id, String writeDate) => {
  'id': id,
  'name': 'row-$id',
  'write_date': writeDate,
};

String _isoOf(DateTime value) =>
    value.toUtc().toIso8601String().replaceFirst('T', ' ').substring(0, 19);

AppScope _scope() => AppScope(
  appId: 'panel',
  installationId: 'i',
  normalizedServerUrl: 'https://erp.test',
  database: 'db',
  userId: 2,
);

const _descriptor = RuntimeCatalogDescriptor(
  key: 'k',
  model: 'x.model',
  fields: ['id', 'name', 'write_date'],
  order: 'name asc,id asc',
);

const _descriptorWithoutWriteDate = RuntimeCatalogDescriptor(
  key: 'k',
  model: 'x.model',
  fields: ['id', 'name'],
  order: 'name asc,id asc',
);

Future<String?> _finishFirstPass(
  RuntimeCatalogLoader loader,
  AppScope scope,
) async {
  final first = await loader.loader(_descriptor)(scope, null);
  return first.cursor;
}

void main() {
  test('A: tras la primera carga completa, la segunda lectura pide sólo '
      'write_date >= X y no vuelve a traer todo', () async {
    final reader = _FakeReader([
      _row(1, '2026-01-01 00:00:00'),
      _row(2, '2026-01-01 00:00:00'),
      _row(3, '2026-01-01 00:00:00'),
    ]);
    final loader = RuntimeCatalogLoader(reader, pageSize: 50);
    final scope = _scope();

    final first = await loader.loader(_descriptor)(scope, null);
    expect(first.records, hasLength(3));
    final decoded = jsonDecode(first.cursor!) as Map<String, dynamic>;
    expect(decoded['mode'], 'since');
    // La primera lectura (carga completa) no manda ningún filtro de
    // `write_date`: hoy trae todo, como debe ser la primera vez.
    expect(
      reader.calls
          .where((call) => call.model == 'x.model')
          .every((call) => call.domain == null || call.domain!.isEmpty),
      isTrue,
    );

    // Toma la llamada de la página en sí, no la del sondeo/reconciliación
    // que puede correr después dentro de la misma pasada (ver más abajo).
    final callsBeforeSecond = reader.calls.length;
    final second = await loader.loader(_descriptor)(scope, first.cursor);
    final secondPageCall = reader.calls[callsBeforeSecond];
    expect(secondPageCall.model, 'x.model');
    // La segunda lectura SÍ manda el filtro de `write_date` y no trae nada
    // nuevo, porque nada cambió desde la primera carga.
    expect(
      secondPageCall.domain!.any(
        (part) => part is List && part[0] == 'write_date' && part[1] == '>=',
      ),
      isTrue,
      reason: 'la segunda lectura debe filtrar por write_date',
    );
    expect(second.records, isEmpty);
  });

  test(
    'B: get_deleted_since se llama con el modelo y el since correctos, y sus '
    'ids llegan como deletedIds',
    () async {
      final reader = _FakeReader([_row(1, '2026-01-01 00:00:00')])
        ..deletedSince = [
          {'record_id': 42, 'delete_date': '2026-01-02 00:00:00'},
        ];
      final loader = RuntimeCatalogLoader(reader, pageSize: 50);
      final scope = _scope();

      final cursor = await _finishFirstPass(loader, scope);
      final second = await loader.loader(_descriptor)(scope, cursor);

      expect(second.deletedIds, [42]);
      expect(second.remoteActiveIds, isNull);
      final rpc = reader.rpcCalls.single;
      expect(rpc.model, 'sync.deleted.record');
      expect(rpc.method, 'get_deleted_since');
      expect(rpc.kwargs!['model_name'], 'x.model');
      expect(rpc.kwargs!['since_date'], isA<String>());
    },
  );

  test('C: un servidor sin el modelo (o sin el método) responde "no existe" y '
      'se reconcilia por el conjunto completo de ids activos', () async {
    final reader = _FakeReader([
      _row(1, '2026-01-01 00:00:00'),
      _row(2, '2026-01-01 00:00:00'),
    ])..deletedSinceBehavior = _DeletedSinceBehavior.modelNotFound;
    final loader = RuntimeCatalogLoader(reader, pageSize: 50);
    final scope = _scope();

    final cursor = await _finishFirstPass(loader, scope);
    final second = await loader.loader(_descriptor)(scope, cursor);

    expect(second.deletedIds, isEmpty);
    expect(second.remoteActiveIds, {1, 2});
    expect(reader.rpcCalls, hasLength(1), reason: 'sí se intenta una vez');
  });

  test(
    'un método viejo (OdooMethodNotFoundException) se trata igual que '
    '"no existe": el módulo está pero es una versión sin get_deleted_since',
    () async {
      final reader = _FakeReader([
        _row(1, '2026-01-01 00:00:00'),
        _row(2, '2026-01-01 00:00:00'),
      ])..deletedSinceBehavior = _DeletedSinceBehavior.methodNotFound;
      final loader = RuntimeCatalogLoader(reader, pageSize: 50);
      final scope = _scope();
      final cursor = await _finishFirstPass(loader, scope);

      final second = await loader.loader(_descriptor)(scope, cursor);
      expect(second.deletedIds, isEmpty);
      expect(second.remoteActiveIds, {1, 2});
    },
  );

  test('D: un servidor con el modelo pero sin permiso (403) también reconcilia '
      'por ids, no se trata como un fallo del ciclo', () async {
    final reader = _FakeReader([
      _row(1, '2026-01-01 00:00:00'),
      _row(2, '2026-01-01 00:00:00'),
    ])..deletedSinceBehavior = _DeletedSinceBehavior.accessDenied;
    final loader = RuntimeCatalogLoader(reader, pageSize: 50);
    final scope = _scope();

    final cursor = await _finishFirstPass(loader, scope);
    final second = await loader.loader(_descriptor)(scope, cursor);

    expect(second.deletedIds, isEmpty);
    expect(second.remoteActiveIds, {1, 2});
  });

  test('el resultado (soportado o no) se cachea por scope: la segunda pasada '
      'no reintenta get_deleted_since una vez que dio 403', () async {
    final reader = _FakeReader([_row(1, '2026-01-01 00:00:00')])
      ..deletedSinceBehavior = _DeletedSinceBehavior.accessDenied;
    // Cada pasada reconcilia (reconcileEveryNCycles: 1) para forzar varios
    // intentos si el código NO cacheara — la prueba real es que
    // `rpcCalls` no crece.
    final loader = RuntimeCatalogLoader(
      reader,
      pageSize: 50,
      reconcileEveryNCycles: 1,
    );
    final scope = _scope();

    var cursor = await _finishFirstPass(loader, scope);
    for (var i = 0; i < 3; i++) {
      final batch = await loader.loader(_descriptor)(scope, cursor);
      cursor = batch.cursor;
    }

    expect(
      reader.rpcCalls,
      hasLength(1),
      reason:
          'el 403 se cachea por scope: sólo el primer intento llama a '
          'get_deleted_since, los siguientes van directo a reconciliar',
    );
  });

  test('un fallo real (500, red, sesión caducada) durante get_deleted_since NO '
      'se confunde con "no soportado": se propaga', () async {
    final reader = _FakeReader([_row(1, '2026-01-01 00:00:00')])
      ..deletedSinceBehavior = _DeletedSinceBehavior.serverError;
    final loader = RuntimeCatalogLoader(reader, pageSize: 50);
    final scope = _scope();

    final cursor = await _finishFirstPass(loader, scope);
    await expectLater(
      loader.loader(_descriptor)(scope, cursor),
      throwsA(isA<OdooServerException>()),
    );
  });

  test('un catálogo sin write_date en los campos pedidos repite la carga '
      'completa siempre, y lo documenta con un cursor null', () async {
    final reader = _FakeReader([_row(1, '2026-01-01 00:00:00')]);
    final loader = RuntimeCatalogLoader(reader, pageSize: 50);
    final scope = _scope();

    final batch = await loader.loader(_descriptorWithoutWriteDate)(scope, null);
    expect(batch.cursor, isNull);
  });

  test('el margen de solapamiento cubre una fila cuya transacción confirmó '
      'tarde: write_date es el INICIO de la transacción, no el commit '
      '(odoo/sql_db.py:339)', () async {
    // Reloj inyectado: la escena necesita minutos de separación entre dos
    // pasadas, y una prueba no puede permitirse dormir minutos de verdad.
    final t0 = DateTime.utc(2026, 1, 1, 12, 0, 0);
    var now = t0;
    final reader = _FakeReader([]);
    final loader = RuntimeCatalogLoader(
      reader,
      pageSize: 50,
      incrementalOverlap: const Duration(minutes: 10),
      clock: () => now,
    );
    final scope = _scope();

    // Carga completa en T0: la tabla está vacía todavía (la transacción
    // larga de abajo ni siquiera había confirmado).
    final first = await loader.loader(_descriptor)(scope, null);
    expect(first.records, isEmpty);

    // Una transacción EMPEZÓ en T0-5min (ese es su `write_date`: el
    // inicio, no el commit) pero recién confirma en T0+8min — el reloj
    // avanza para simular ese retraso real, y la fila se vuelve visible
    // recién ahora.
    now = t0.add(const Duration(minutes: 8));
    reader.table = [_row(1, _isoOf(t0.subtract(const Duration(minutes: 5))))];

    final second = await loader.loader(_descriptor)(scope, first.cursor);

    expect(
      second.records.map((row) => row.value['id']),
      contains(1),
      reason:
          'con 10 minutos de solape, T0-5min sigue siendo >= since '
          '(T0-10min): la fila debe entrar aunque su write_date sea '
          'anterior a T0. Con el margen viejo de 60s (since=T0-1min) '
          'esta misma fila quedaba fuera para siempre — se confirmó '
          'corriendo esta prueba con incrementalOverlap: Duration('
          'seconds: 60) antes de subir el valor por defecto.',
    );
  });
}
