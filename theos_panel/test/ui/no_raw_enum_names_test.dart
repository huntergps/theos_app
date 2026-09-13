@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Impide que un identificador interno vuelva a acabar en la pantalla.
///
/// Esto es un lint casero: lee el código fuente y busca el patrón que ya nos
/// mordió — interpolar `.name` de un `enum` dentro de un texto visible, que
/// produjo «Resultado: queued», «Cobro: synced», «Turno: open» y «Estado
/// fiscal: emittedLocal» delante de quien está cobrando.
///
/// 🔴 Por qué una prueba de texto y no una de widgets: el defecto no está en
/// lo que una pantalla concreta pinta, sino en un hábito que se repite en
/// features distintas. Una prueba por pantalla no lo ve venir en la siguiente;
/// leer el árbol entero, sí. Es el mismo razonamiento que la prueba que exige
/// mensaje para cada área de `RouteAccessPolicy`.
///
/// **Lo que esta prueba NO puede hacer, y conviene saberlo:** sólo caza la
/// forma sintáctica `${algo.name}`. No detecta `toString()` de un enum, ni una
/// variable que ya traiga el nombre crudo desde otra capa, ni un `switch` que
/// devuelva la palabra en inglés. Es una red, no un techo.
void main() {
  // `.name` legítimo: no todo lo que se llama `name` es un enum, y no todo
  // enum acaba en pantalla.
  const allowed = <String>{
    // El nombre del producto de una línea de venta. Es un dato del negocio.
    r'${line.name}',
    // `DOMException.name`, dentro de un StateError que nunca se pinta.
    r'${open.error?.name}',
    r'${request.error?.name}',
    // Los cuatro que destapó la forma directa al estrenarla. Ninguno es un
    // enum: son nombres de datos del negocio que SÍ hay que enseñar —el
    // diario, el tipo de egreso, el producto de la línea y el servidor
    // guardado—. Se listan uno a uno, no con un comodín, para que el
    // siguiente enum que aparezca en un `Text(...)` siga cayendo.
    'Text(j.name)',
    'Text(type.name)',
    'Text(line.name,',
    'Text(server.name,',
    // El nombre de la sesión de caja (p. ej. "CS/005/2026/0008"), no un
    // enum: es el `name` de `collection.session`, dato real del negocio.
    'Text(session.name),',
  };

  // Contextos donde el nombre del enum ES el valor correcto porque no se
  // muestra: identificadores de widget, claves de comando, banderas internas.
  final identifierContexts = <RegExp>[
    RegExp(r'\bKey\('),
    RegExp(r'\bcommandId:'),
    RegExp(r'\bdedupeKey:'),
    RegExp(r'\bsourceKey:'),
    RegExp(r'_busy = '),
  ];

  // Ficheros cuyo `.name` no llega jamás a una pantalla.
  const exemptFiles = <String>{
    // Arnés de pruebas E2E: sus textos son mensajes de excepción para quien
    // ejecuta la suite, no para un operador.
    'lib/erp2_harness.dart',
  };

  test('ningún nombre interno se interpola en un texto visible', () {
    final offenders = <String>[];
    // Sin exigir `}` justo después: el caso real
    // `${item.fiscalState?.name ?? '—'}` seguía con un `??`, y un patrón que
    // pidiera el cierre inmediato lo habría dejado pasar.
    final pattern = RegExp(r'\$\{[^}]*\.name\b');
    // 🔴 La interpolación no era la única forma de que un nombre interno
    // llegara a pantalla. `Text(mode.name)` no lleva `${...}` y esta prueba lo
    // dejaba pasar: aparecieron dos así en Configuración, para el tema y la
    // densidad, y se vieron al migrar la pantalla, no aquí. Se caza también la
    // forma directa.
    final direct = RegExp(r'\bText\(\s*[A-Za-z_][A-Za-z0-9_.]*\.name\b');

    for (final entry in Directory('lib').listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      final relative = entry.path;
      if (exemptFiles.any(relative.endsWith)) continue;

      final lines = entry.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // `toString()` es para depuración y registros, nunca para pantalla.
        if (line.contains('String toString()')) continue;
        if (identifierContexts.any((c) => c.hasMatch(line))) continue;
        if (!pattern.hasMatch(line) && !direct.hasMatch(line)) continue;
        if (allowed.any(line.contains)) continue;
        offenders.add('$relative:${i + 1}  ${line.trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Un identificador interno está a punto de aparecer en pantalla.\n'
          'Traduce el estado en lib/ui/state_labels.dart y usa esa función, '
          'igual que se hizo con CollectionResultState, OperationSyncState y '
          'FiscalState. Si de verdad no es un enum (el nombre de un producto, '
          'por ejemplo), añádelo a la lista `allowed` de esta prueba con su '
          'razón.\n\n${offenders.join('\n')}',
    );
  });

  test('la prueba sabría cazarlo: el patrón reconoce el defecto original', () {
    // Sin esto, un cambio que rompiera la expresión regular dejaría la prueba
    // en verde para siempre sin comprobar nada — que es exactamente como una
    // prueba mía dejó de morder esta misma noche.
    final pattern = RegExp(r'\$\{[^}]*\.name\b');
    for (final original in [
      r"Text('Resultado: ${result.name}')",
      r"'Turno: ${_currentShift.state.name}'",
      r"label: 'Fiscal: ${item.fiscalState?.name ?? '—'}'",
    ]) {
      expect(
        pattern.hasMatch(original),
        isTrue,
        reason: 'El patrón ya no reconoce el defecto que existe para cazar.',
      );
    }
  });

  test('la forma directa también se caza, no sólo la interpolada', () {
    // El defecto real que se escapó: `Text(mode.name)` en Configuración, sin
    // interpolación. Se vio migrando la pantalla, no aquí, que es tarde.
    final direct = RegExp(r'\bText\(\s*[A-Za-z_][A-Za-z0-9_.]*\.name\b');
    for (final original in [
      'Text(mode.name)',
      'Text(density.name)',
      'Text(item.state.name, style: algo)',
    ]) {
      expect(
        direct.hasMatch(original),
        isTrue,
        reason: 'el patrón dejó de reconocer «$original»',
      );
    }
    // Y no muerde donde no debe: un nombre de persona o de producto sí se
    // enseña, y para eso está la lista de excepciones, no un falso positivo.
    expect(direct.hasMatch("Text('Nombre: \$nombre')"), isFalse);
  });
}
