import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

import 'package:theos_panel/ui/components/orbi_components.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

Widget _host(Widget child) =>
    FluentApp(theme: OrbiFluentTheme.light, home: ScaffoldPage(content: child));

void main() {
  group('OrbiReactiveTextField', () {
    testWidgets(
      'con error, se ve el mensaje y el campo es un TextFormBox cuyo '
      'FormRow lo muestra',
      (tester) async {
        final control = FormControl<String>(
          validators: [
            Validators.delegate(
              (control) => (control.value == null || control.value!.isEmpty)
                  ? {'Campo requerido': true}
                  : null,
            ),
          ],
        );
        addTearDown(control.dispose);

        await tester.pumpWidget(
          _host(OrbiReactiveTextField(control: control, label: 'Cliente')),
        );
        await tester.pump();

        // Nadie ve el error todavía: el control no ha sido tocado.
        expect(find.text('Campo requerido'), findsNothing);

        control.markAsTouched();
        // El cambio de `touched` llega por un `Stream` de reactive_forms: un
        // `pump()` drena el microtask que lo entrega y el `setState`, y el
        // siguiente reconstruye con el error ya resuelto.
        await tester.pump();
        await tester.pump();

        expect(find.byType(TextFormBox), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(FormRow),
            matching: find.text('Campo requerido'),
          ),
          findsOneWidget,
          reason: 'el mensaje debe venir del FormRow que arma TextFormBox, '
              'no de un Text rojo aparte',
        );

        final textBox = tester.widget<TextBox>(find.byType(TextBox));
        expect(
          textBox.highlightColor,
          Colors.red.defaultBrushFor(OrbiFluentTheme.light.brightness),
          reason: 'con error, el borde del campo se pinta crítico — no basta '
              'con el texto rojo debajo',
        );
      },
    );

    testWidgets('sin error, no hay borde crítico', (tester) async {
      final control = FormControl<String>(value: 'Acme');
      addTearDown(control.dispose);

      await tester.pumpWidget(
        _host(OrbiReactiveTextField(control: control, label: 'Cliente')),
      );
      await tester.pump();

      final textBox = tester.widget<TextBox>(find.byType(TextBox));
      expect(textBox.highlightColor, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('OrbiActionCard', () {
    testWidgets(
      'con Tab se le da foco a la tarjeta y con Enter se ejecuta su acción',
      (tester) async {
        var pressed = 0;
        final anteriorFocus = FocusNode(debugLabel: 'anterior');
        addTearDown(anteriorFocus.dispose);

        await tester.pumpWidget(
          _host(
            Column(
              children: [
                Button(
                  focusNode: anteriorFocus,
                  onPressed: () {},
                  child: const Text('anterior'),
                ),
                OrbiActionCard(
                  title: 'Órdenes pendientes',
                  subtitle: '12 por revisar',
                  onPressed: () => pressed++,
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        anteriorFocus.requestFocus();
        await tester.pump();
        expect(anteriorFocus.hasFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(
          anteriorFocus.hasFocus,
          isFalse,
          reason: 'Tab debe mover el foco fuera del botón anterior',
        );
        expect(
          primaryFocus?.debugLabel,
          'HoverButton',
          reason:
              'la tarjeta debe ser alcanzable con Tab — el nodo de foco que '
              'HoverButton crea por defecto se llama así por su runtimeType',
        );

        expect(pressed, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        // `HoverButton.handleActionTap` agenda un `Future.delayed` corto
        // antes de soltar el estado de "pulsado"; hay que drenarlo o el
        // binding de test se queja de un timer vivo al terminar.
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          pressed,
          1,
          reason: 'con foco en la tarjeta, Enter debe ejecutar su acción',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('se construye sobre HoverButton, no sobre un contenedor propio', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          OrbiActionCard(
            title: 'Órdenes pendientes',
            subtitle: '12 por revisar',
            onPressed: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(HoverButton), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });
  });
}
