import 'package:flutter_test/flutter_test.dart';
// Import directo, sin pasar por el barril `orbi_runtime.dart`: éste no
// necesita nada de `src/realtime/`, y así el test no depende de que ese
// módulo (en obras por otro agente) compile.
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/read/json2_read_adapters.dart';

/// Doble con un evaluador de dominio recursivo en notación polaca completa
/// (`'&'`/`'|'` binarios, `'!'` unario, más AND implícito entre términos de
/// nivel superior) — necesario porque el arreglo de "salida de dominio" pide
/// el dominio del catálogo NEGADO, y una negación mal evaluada en el doble
/// daría un verde que no prueba nada.
final class _FakeReader implements Json2ReadPort, Json2CallPort {
  _FakeReader(this.table);

  List<Map<String, dynamic>> table;
  List<Map<String, dynamic>> deletedSince = const [];

  /// Cuando no es null, cualquier `call()` a `search_read` (el escaneo de
  /// salida de dominio) lanza esto en vez de responder — para probar que un
  /// fallo real del servidor se propaga.
  Object? domainExitError;

  final domainExitCalls =
      <({List<dynamic>? domain, Map<String, dynamic>? context})>[];

  @override
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
  }) async {
    final rows = table.where((row) => _matchesDomain(row, domain)).toList()
      ..sort((a, b) {
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
    if (model == 'sync.deleted.record' && method == 'get_deleted_since') {
      return deletedSince;
    }
    if (method == 'search_read') {
      domainExitCalls.add((
        domain: kwargs?['domain'] as List<dynamic>?,
        context: context,
      ));
      final error = domainExitError;
      if (error != null) throw error;
      final domain = kwargs?['domain'] as List<dynamic>?;
      final limit = kwargs?['limit'] as int?;
      final offset = kwargs?['offset'] as int?;
      final rows = table.where((row) => _matchesDomain(row, domain)).toList()
        ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
      final start = offset ?? 0;
      if (start >= rows.length) return const <Map<String, dynamic>>[];
      final end = limit == null
          ? rows.length
          : (start + limit).clamp(start, rows.length);
      return rows.sublist(start, end);
    }
    throw UnimplementedError('$model.$method');
  }

  static bool _matchesLeaf(Map<String, dynamic> row, dynamic leaf) {
    if (leaf is! List || leaf.length != 3) return true;
    final field = leaf[0] as String;
    final op = leaf[1] as String;
    final value = leaf[2];
    final actual = row[field];
    switch (op) {
      case '=':
        return actual == value;
      case '!=':
        return actual != value;
      case '>=':
        final actualDate = DateTime.parse(
          '${(actual as String).replaceFirst(' ', 'T')}Z',
        );
        final thresholdDate = DateTime.parse(
          '${(value as String).replaceFirst(' ', 'T')}Z',
        );
        return !actualDate.isBefore(thresholdDate);
      default:
        return true;
    }
  }

  /// Evalúa el término que arranca en `domain[index]`. Devuelve el valor y
  /// el índice donde sigue el próximo término — así `'&'`/`'|'`/`'!'`
  /// consumen exactamente su aridad, con la misma semántica que
  /// `odoo/orm/domains.py` documenta (prefijo, recursivo).
  static (bool, int) _evalAt(
    Map<String, dynamic> row,
    List<dynamic> domain,
    int index,
  ) {
    final token = domain[index];
    if (token == '&') {
      final (a, i1) = _evalAt(row, domain, index + 1);
      final (b, i2) = _evalAt(row, domain, i1);
      return (a && b, i2);
    }
    if (token == '|') {
      final (a, i1) = _evalAt(row, domain, index + 1);
      final (b, i2) = _evalAt(row, domain, i1);
      return (a || b, i2);
    }
    if (token == '!') {
      final (a, i1) = _evalAt(row, domain, index + 1);
      return (!a, i1);
    }
    return (_matchesLeaf(row, token), index + 1);
  }

  static bool _matchesDomain(Map<String, dynamic> row, List<dynamic>? domain) {
    if (domain == null || domain.isEmpty) return true;
    var index = 0;
    final results = <bool>[];
    while (index < domain.length) {
      final (value, next) = _evalAt(row, domain, index);
      results.add(value);
      index = next;
    }
    return results.every((r) => r);
  }
}

AppScope _scope() => AppScope(
  appId: 'panel',
  installationId: 'i',
  normalizedServerUrl: 'https://erp.test',
  database: 'db',
  userId: 2,
);

const _productLike = RuntimeCatalogDescriptor(
  key: 'products_test',
  model: 'product.product',
  fields: ['id', 'name', 'write_date', 'active', 'sale_ok'],
  domain: [
    ['sale_ok', '=', true],
    ['active', '=', true],
  ],
  order: 'name asc,id asc',
);

/// Los cursores incrementales filtran por `write_date >= ahora - solape`
/// (donde "ahora" es el reloj real de la máquina en el momento de cada
/// pasada). Un `write_date` fijo en el pasado (p. ej. "2026-01-02") quedaría
/// FUERA de ese filtro tan pronto la fecha del sistema lo supere — por eso
/// cada cambio simulado usa el reloj real, nunca una fecha fija.
String _isoNow([Duration offset = Duration.zero]) => DateTime.now()
    .toUtc()
    .add(offset)
    .toIso8601String()
    .replaceFirst('T', ' ')
    .substring(0, 19);

Map<String, dynamic> _product(
  int id, {
  required String writeDate,
  bool active = true,
  bool saleOk = true,
}) => {
  'id': id,
  'name': 'P$id',
  'write_date': writeDate,
  'active': active,
  'sale_ok': saleOk,
};

void main() {
  test('1: archivar (active=false) saca el registro del local — se trata como '
      'una baja', () async {
    final reader = _FakeReader([_product(1, writeDate: '2026-01-01 00:00:00')]);
    final loader = RuntimeCatalogLoader(reader, pageSize: 50);
    final scope = _scope();

    final first = await loader.loader(_productLike)(scope, null);
    expect(first.records, hasLength(1));

    // El servidor DESACTIVA el producto (write() a active=false), nunca lo
    // borra. `sync.deleted.record` sigue funcionando pero, con razón, no
    // reporta nada — esto no es un unlink.
    reader.table = [_product(1, writeDate: _isoNow(), active: false)];

    final second = await loader.loader(_productLike)(scope, first.cursor);

    expect(
      second.records,
      isEmpty,
      reason: 'el dominio activo excluye al producto desactivado',
    );
    expect(
      second.deletedIds,
      contains(1),
      reason:
          'el producto salió del dominio (se desactivó) y debe tratarse '
          'como una baja local, igual que un unlink',
    );
  });

  test('2: reactivar después vuelve a entrar en la siguiente pasada', () async {
    final reader = _FakeReader([_product(1, writeDate: '2026-01-01 00:00:00')]);
    final loader = RuntimeCatalogLoader(reader, pageSize: 50);
    final scope = _scope();

    final first = await loader.loader(_productLike)(scope, null);

    reader.table = [_product(1, writeDate: _isoNow(), active: false)];
    final second = await loader.loader(_productLike)(scope, first.cursor);
    expect(second.deletedIds, contains(1));

    // El servidor reactiva el producto.
    reader.table = [
      _product(1, writeDate: _isoNow(const Duration(seconds: 2)), active: true),
    ];
    final third = await loader.loader(_productLike)(scope, second.cursor);

    expect(
      third.records.map((r) => r.value['id']),
      contains(1),
      reason:
          'vuelve a cumplir el dominio (active=true de nuevo): la '
          'pasada incremental normal ya lo trae, sin necesitar nada '
          'especial del escaneo de salida de dominio',
    );
  });

  test('3: salir por otro campo del dominio (sale_ok=false) también saca el '
      'registro del local', () async {
    final reader = _FakeReader([_product(1, writeDate: '2026-01-01 00:00:00')]);
    final loader = RuntimeCatalogLoader(reader, pageSize: 50);
    final scope = _scope();

    final first = await loader.loader(_productLike)(scope, null);
    expect(first.records, hasLength(1));

    // Sigue activo, pero deja de venderse: también es una salida del
    // dominio del catálogo (`sale_ok=true`).
    reader.table = [_product(1, writeDate: _isoNow(), saleOk: false)];
    final second = await loader.loader(_productLike)(scope, first.cursor);

    expect(second.records, isEmpty);
    expect(second.deletedIds, contains(1));
  });

  test('5: un fallo real del servidor durante el escaneo de salida de dominio '
      'se propaga, no se traga', () async {
    final reader = _FakeReader([_product(1, writeDate: '2026-01-01 00:00:00')]);
    final loader = RuntimeCatalogLoader(reader, pageSize: 50);
    final scope = _scope();

    final first = await loader.loader(_productLike)(scope, null);

    reader.domainExitError = StateError('el servidor rechazó el dominio');
    await expectLater(
      loader.loader(_productLike)(scope, first.cursor),
      throwsA(isA<StateError>()),
    );
  });

  test('el escaneo de salida de dominio manda active_test:false en el '
      'contexto y el dominio negado esperado', () async {
    final reader = _FakeReader([_product(1, writeDate: '2026-01-01 00:00:00')]);
    final loader = RuntimeCatalogLoader(reader, pageSize: 50);
    final scope = _scope();

    final first = await loader.loader(_productLike)(scope, null);
    reader.table = [_product(1, writeDate: _isoNow(), active: false)];
    await loader.loader(_productLike)(scope, first.cursor);

    final exitCall = reader.domainExitCalls.single;
    expect(exitCall.context, {'active_test': false});
    expect(exitCall.domain, [
      '&',
      ['write_date', '>=', isA<String>()],
      '!',
      '&',
      ['sale_ok', '=', true],
      ['active', '=', true],
    ]);
  });

  test('un catálogo con dominio vacío no dispara ningún escaneo de salida de '
      'dominio', () async {
    const noDomainDescriptor = RuntimeCatalogDescriptor(
      key: 'k',
      model: 'x.model',
      fields: ['id', 'name', 'write_date'],
      order: 'name asc,id asc',
    );
    final reader = _FakeReader([
      {'id': 1, 'name': 'A', 'write_date': '2026-01-01 00:00:00'},
    ]);
    final loader = RuntimeCatalogLoader(reader, pageSize: 50);
    final scope = _scope();

    final first = await loader.loader(noDomainDescriptor)(scope, null);
    await loader.loader(noDomainDescriptor)(scope, first.cursor);

    expect(reader.domainExitCalls, isEmpty);
  });
}
