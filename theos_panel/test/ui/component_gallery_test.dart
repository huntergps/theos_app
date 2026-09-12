import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

import '../../dev/component_gallery.dart';

import 'package:theos_panel/ui/layouts/orbi_adaptive_layout.dart';

void main() {
  testWidgets('gallery reflows and preserves field state', (tester) async {
    final media = MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: const ComponentGallery(),
    );
    await tester.pumpWidget(
      FluentApp(theme: OrbiFluentTheme.dark, home: media),
    );
    expect(find.bySemanticsLabel('Logo de Orbi ERP'), findsOneWidget);
    // `OrbiReactiveTextField` ya no envuelve el `ReactiveTextField<String>` de
    // `reactive_forms` (ese renderiza un `TextField` Material sin equivalente
    // Fluent); se construye directo sobre `ReactiveFormField` y pinta un
    // `TextBox` Fluent — ver `lib/ui/components/orbi_components.dart`.
    final field = find.byType(TextBox);
    expect(find.text('Cliente ficticio'), findsOneWidget);

    await tester.enterText(field, 'Acme largo');
    for (final width in [599.0, 600.0, 839.0, 840.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpAndSettle();
      expect(
        orbiLayoutSizeFor(width),
        width == 599
            ? OrbiLayoutSize.compact
            : width == 840
            ? OrbiLayoutSize.wide
            : OrbiLayoutSize.medium,
      );
      expect(find.text('Acme largo'), findsOneWidget);
      // Este `expect` es el que de verdad ejercita `OrbiStatusChip`: sólo con
      // los TRES a la vez — un ancho angosto (599, compacto), una etiqueta
      // larga y la escala de texto 2x de arriba (justo lo que usa quien no ve
      // bien) — se veía el `Row` interno del chip desbordar. Antes quedaba
      // tapado porque esta prueba moría antes, en la línea del
      // `ReactiveTextField` que ya no existe, así que nunca llegaba a este
      // ancho con esta escala. Arreglado en `OrbiStatusChip` (`Flexible` +
      // elipsis en la etiqueta), no aquí.
      expect(tester.takeException(), isNull);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
