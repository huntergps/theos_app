import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/envases/widgets/lista_estado_chip.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

void main() {
  group('envasesEstadoColor', () {
    test('every estado gets a distinct theme color, never a literal', () {
      final theme = OrbiFluentTheme.light;
      final colors = {
        for (final estado in EnvasesOperacionEstado.values) estado: envasesEstadoColor(theme, estado),
      };
      // Cuatro estados, cuatro colores: si dos se confunden no se pueden
      // distinguir de un vistazo en la tabla o en la tarjeta.
      expect(colors.values.toSet().length, EnvasesOperacionEstado.values.length);
      // Todos vienen de `theme.resources`/`theme.accentColor`, así que
      // cambian solos si el tema cambia — nunca un `Color(0x...)` fijo.
      final dark = OrbiFluentTheme.dark;
      for (final estado in EnvasesOperacionEstado.values) {
        // Al menos uno de los cuatro debe diferir entre claro y oscuro para
        // demostrar que el valor sale del tema, no de una tabla cableada
        // igual en ambos.
        if (envasesEstadoColor(dark, estado) != colors[estado]) return;
      }
      fail('ningún color cambió entre tema claro y oscuro: parecen cableados');
    });
  });

  group('envasesCustodyRoleColor', () {
    test('cliente y proveedor tienen colores distintos', () {
      final theme = OrbiFluentTheme.light;
      expect(
        envasesCustodyRoleColor(theme, 'custodia_cliente'),
        isNot(envasesCustodyRoleColor(theme, 'custodia_proveedor')),
      );
    });
  });

  testWidgets('ListaEstadoChip pinta la etiqueta con el color recibido', (tester) async {
    await tester.pumpWidget(
      const FluentApp(
        home: ListaEstadoChip(label: 'Enviada', color: Color(0xFF00FF00)),
      ),
    );
    final text = tester.widget<Text>(find.text('Enviada'));
    expect(text.style?.color, const Color(0xFF00FF00));
  });
}
