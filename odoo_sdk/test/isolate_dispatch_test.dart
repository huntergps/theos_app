/// Tests for the isolate dispatch shim (`isolate_dispatch.dart`).
///
/// `dart test` corre en la VM nativa (no Web), así que este archivo ejercita
/// `isolate_dispatch_io.dart` (el que usa `Isolate.run()` de verdad) vía el
/// export condicional de `isolate_dispatch.dart`. El comportamiento
/// específico de Web (`isolate_dispatch_web.dart`, sin isolate real) no se
/// puede probar con `dart test` — ver justificación en el plan de Fase E.
import 'package:test/test.dart';

import 'package:odoo_sdk/src/sync/isolate_dispatch.dart';

/// Función top-level (isolate-safe) usada como parser en los tests.
///
/// Debe ser top-level o static — un closure que capture estado del test
/// (variables locales, mocks, etc.) NO sería transferible a `Isolate.run()`,
/// exactamente el problema que este shim existe para evitar en producción.
_ParsedRecord _parseRecord(Map<String, dynamic> data) {
  return _ParsedRecord(
    id: data['id'] as int,
    name: data['name'] as String,
  );
}

/// Parser que lanza una excepción para probar la propagación de errores.
_ParsedRecord _throwingParser(Map<String, dynamic> data) {
  if (data['id'] == 2) {
    throw FormatException('registro malformado: ${data['id']}');
  }
  return _parseRecord(data);
}

class _ParsedRecord {
  final int id;
  final String name;
  const _ParsedRecord({required this.id, required this.name});
}

void main() {
  group('parseInIsolate', () {
    test('parses a page of records using a top-level function', () async {
      final pages = [
        {'id': 1, 'name': 'Uno'},
        {'id': 2, 'name': 'Dos'},
        {'id': 3, 'name': 'Tres'},
      ];

      final result = await parseInIsolate(pages, _parseRecord);

      expect(result, hasLength(3));
      expect(result[0].id, equals(1));
      expect(result[0].name, equals('Uno'));
      expect(result[2].id, equals(3));
      expect(result[2].name, equals('Tres'));
    });

    test('returns an empty list for an empty page', () async {
      final result = await parseInIsolate<_ParsedRecord>([], _parseRecord);
      expect(result, isEmpty);
    });

    test('handles a large page (many2one-like volume) correctly', () async {
      final pages = List.generate(
        500,
        (i) => {'id': i, 'name': 'Producto $i'},
      );

      final result = await parseInIsolate(pages, _parseRecord);

      expect(result, hasLength(500));
      expect(result.first.id, equals(0));
      expect(result.last.id, equals(499));
      expect(result[250].name, equals('Producto 250'));
    });

    test(
      'propagates exceptions raised by the parser (mismo comportamiento '
      'que el camino per-row: todo-o-nada por página)',
      () async {
        final pages = [
          {'id': 1, 'name': 'Uno'},
          {'id': 2, 'name': 'Malo'}, // dispara la excepción
          {'id': 3, 'name': 'Tres'},
        ];

        expect(
          () => parseInIsolate(pages, _throwingParser),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });
}
