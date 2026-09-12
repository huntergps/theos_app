import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';
import 'package:theos_panel/ui/fluent/orbi_page.dart';

/// Lo que hace posible migrar pantalla a pantalla en vez de de golpe.
///
/// La raíz de Orbi sigue siendo `MaterialApp.router` mientras dure la
/// migración a Fluent, decidida por el dueño el 11-sep-2026. Si una pantalla
/// Fluent no pudiera vivir bajo esa raíz, no habría término medio: habría que
/// convertir las 45 pantallas en un solo cambio, sin poder probar ninguna por
/// separado. Medido aquí, no supuesto: **sí puede**, envolviéndola en un
/// `FluentTheme`.
///
/// Cuando la raíz pase a `FluentApp` y no quede ninguna pantalla Material,
/// esta prueba deja de hacer falta y se borra. Mientras exista, protege el
/// camino: si alguien rompe la convivencia, se ve aquí y no al abrir la
/// aplicación.
void main() {
  testWidgets('una pantalla Fluent vive dentro de la raíz Material actual', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: fluent.FluentTheme(
          data: OrbiFluentTheme.light,
          child: const OrbiPage(
            title: 'Pantalla migrada',
            subtitle: 'Convive con las que todavía son Material',
            child: Text('contenido'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pantalla migrada'), findsOneWidget);
    expect(
      find.text('Convive con las que todavía son Material'),
      findsOneWidget,
    );
    expect(find.text('contenido'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
