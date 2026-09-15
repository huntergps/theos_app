import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/envases/widgets/envases_form_layout.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

/// Cubre la queja del dueño del 14-sep-2026 (revisión visual contra las
/// láminas aprobadas): el campo de fecha de envases se veía «con menos
/// borde» que sus vecinos `TextBox`/`ComboBox` del mismo formulario.
///
/// Causa raíz (ver el docstring de `EnvasesDateField`): el borde visible de
/// un `TextBox` de fluent_ui en reposo son DOS capas — un `Border.all` de
/// fondo Y un `foregroundDecoration` con sólo el borde inferior, más grueso
/// y más oscuro. La primera versión de `EnvasesDateField` sólo copiaba la
/// primera capa.
///
/// Esta prueba NO compara contra números copiados a mano: monta un
/// `TextBox` REAL al lado del `EnvasesDateField` en el mismo árbol y lee de
/// cada uno el `Container.foregroundDecoration` que de verdad pintan — si
/// mañana fluent_ui cambia ese ancho o ese color, la prueba se sigue
/// cumpliendo mientras los dos campos coincidan entre sí, que es lo único
/// que le importa a quien mira el formulario.
///
/// Contra `b0645cd` (sólo `DecoratedBox` con `Border.all`, sin capa de
/// acento) falla porque `EnvasesDateField` no tiene ningún `Container` con
/// `foregroundDecoration`.
BorderSide? _bottomAccentBorder(WidgetTester tester, Finder scope) {
  final finder = find.descendant(
    of: scope,
    matching: find.byWidgetPredicate((widget) => widget is Container && widget.foregroundDecoration != null),
  );
  if (finder.evaluate().isEmpty) return null;
  final container = tester.widget<Container>(finder);
  final decoration = container.foregroundDecoration! as BoxDecoration;
  final border = decoration.border;
  if (border is! Border) return null;
  return border.bottom;
}

void main() {
  Widget host() => FluentApp(
    theme: OrbiFluentTheme.light,
    home: ScaffoldPage(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El `TextBox` de referencia: mismo tema, sin foco, `enabled` por
          // omisión — el estado «en reposo» contra el que se compara.
          SizedBox(width: 220, child: TextBox(key: const Key('textbox-referencia'))),
          const SizedBox(height: 16),
          SizedBox(
            width: 220,
            child: EnvasesDateField(datePickerKey: const Key('fecha'), selected: DateTime(2026, 9, 15)),
          ),
        ],
      ),
    ),
  );

  testWidgets('the date field paints the same bottom accent as a real unfocused TextBox', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    final textBoxBottom = _bottomAccentBorder(tester, find.byKey(const Key('textbox-referencia')));
    expect(
      textBoxBottom,
      isNotNull,
      reason: 'No se pudo leer el acento inferior real de TextBox — revisa el predicado contra text_box.dart.',
    );

    final dateFieldBottom = _bottomAccentBorder(tester, find.byType(EnvasesDateField));
    expect(
      dateFieldBottom,
      isNotNull,
      reason:
          'EnvasesDateField no pinta ningún acento inferior — se ve "con menos '
          'borde" al lado de los TextBox/ComboBox del mismo formulario.',
    );

    // Mismo ancho y mismo color que el TextBox real montado al lado — no un
    // literal copiado a mano.
    expect(dateFieldBottom!.width, textBoxBottom!.width);
    expect(dateFieldBottom.color, textBoxBottom.color);
  });

  testWidgets('the date field keeps the background border TextBox uses', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    final dateFieldFinder = find.byType(EnvasesDateField);
    final decoratedBoxFinder = find.descendant(
      of: dateFieldFinder,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).border is Border,
      ),
    );
    expect(decoratedBoxFinder, findsWidgets);

    final hasExpectedBackgroundBorder = tester
        .widgetList<DecoratedBox>(decoratedBoxFinder)
        .map((widget) => (widget.decoration as BoxDecoration).border! as Border)
        .any((border) => border.top.color == OrbiFluentTheme.light.resources.controlStrokeColorDefault);
    expect(
      hasExpectedBackgroundBorder,
      isTrue,
      reason: 'Falta el borde de fondo — mismo token que usa TextBox (controlStrokeColorDefault).',
    );
  });
}
