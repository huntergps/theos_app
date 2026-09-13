import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reportado por el dueño (captura de iPhone, Safari, 13-sep-2026): en tema
/// oscuro, la barra de estado de Safari salía clara y debajo quedaba una
/// franja en blanco. La causa: `web/index.html` no tenía forma de decirle a
/// Safari qué color usar (`theme-color`) ni de que el fondo de respaldo
/// (una foto clara) cambiara con el tema — y sin `viewport-fit=cover`,
/// Safari nunca reporta una altura de viewport estable mientras su barra de
/// direcciones se pliega o despliega, que es cuando ese fondo asoma.
///
/// No hay `flutter test` para CSS/HTML: esta prueba lee el archivo fuente
/// tal cual queda en el árbol y comprueba, por texto, que el arreglo sigue
/// puesto. No es un golden test (no compara imágenes), sólo characterizes el
/// contrato mínimo que `index.html` tiene que cumplir.
void main() {
  late String html;

  setUpAll(() {
    html = File('web/index.html').readAsStringSync();
  });

  test('pide viewport-fit=cover para saber su altura real en iOS Safari', () {
    expect(html, contains('viewport-fit=cover'));
  });

  test('tiñe la barra de Safari con el color del tema, claro y oscuro', () {
    expect(
      html,
      contains(
        'name="theme-color" content="#f3f3f3" media="(prefers-color-scheme: light)"',
      ),
    );
    expect(
      html,
      contains(
        'name="theme-color" content="#202020" media="(prefers-color-scheme: dark)"',
      ),
    );
  });

  test('el fondo de respaldo es oscuro en tema oscuro, no la foto clara', () {
    final darkBlock = RegExp(
      r'@media \(prefers-color-scheme: dark\)\s*\{\s*html, body\s*\{([^}]*)\}',
    ).firstMatch(html);
    expect(
      darkBlock,
      isNotNull,
      reason: 'falta la regla @media (prefers-color-scheme: dark) para html,body',
    );
    expect(darkBlock!.group(1), contains('#202020'));
  });

  test('el alto del respaldo sigue la altura dinámica real del navegador', () {
    expect(html, contains('100dvh'));
  });

  test(
    'el panel de diagnóstico está detrás de la marca orbi.diag y no bloquea toques',
    () {
      expect(
        html,
        contains('orbi.diag'),
        reason: 'el panel debe activarse/leerse por la marca orbi.diag en localStorage',
      );
      expect(
        html.contains('pointer-events:none') ||
            html.contains('pointer-events: none'),
        isTrue,
        reason: 'el panel no debe interceptar toques sobre la app',
      );
    },
  );
}
