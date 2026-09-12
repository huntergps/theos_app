import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_widgets/odoo_widgets.dart';

/// El formulario estándar, para que dos pantallas del mismo sistema no
/// parezcan de sistemas distintos.
void main() {
  final secciones = [
    OrbiFormSection(
      title: 'Datos del cliente',
      fields: [
        const OrbiField(
          label: 'Nombre',
          required: true,
          child: TextBox(key: Key('campo-nombre')),
        ),
        const OrbiField(
          label: 'Identificación',
          hint: 'Cédula, RUC o pasaporte',
          child: TextBox(key: Key('campo-id')),
        ),
        const OrbiField(
          label: 'Dirección',
          span: 2,
          child: TextBox(key: Key('campo-direccion')),
        ),
      ],
    ),
  ];

  Future<void> pump(WidgetTester tester, Widget form, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      FluentApp(
        home: ScaffoldPage(
          content: Padding(padding: const EdgeInsets.all(16), child: form),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lo obligatorio se marca antes de escribir, no después', (
    tester,
  ) async {
    await pump(tester, OrbiForm(sections: secciones), const Size(1440, 900));

    expect(find.text('Nombre'), findsOneWidget);
    // El asterisco está junto a la etiqueta y se anuncia como «obligatorio»
    // para quien use lector de pantalla.
    expect(find.text('*'), findsOneWidget);
    expect(find.bySemanticsLabel('obligatorio'), findsOneWidget);
  });

  testWidgets('el error va pegado al campo, no en un aviso arriba', (
    tester,
  ) async {
    await pump(
      tester,
      OrbiForm(
        sections: [
          OrbiFormSection(
            title: 'Datos',
            fields: const [
              OrbiField(
                label: 'Identificación',
                hint: 'Cédula, RUC o pasaporte',
                error: 'La cédula no pasa el dígito verificador',
                child: TextBox(),
              ),
            ],
          ),
        ],
      ),
      const Size(1440, 900),
    );

    final etiqueta = tester.getCenter(find.text('Identificación'));
    final error = tester.getCenter(
      find.text('La cédula no pasa el dígito verificador'),
    );
    expect(error.dy > etiqueta.dy, isTrue);
    // Con un error a la vista, la ayuda se calla: dos líneas bajo el mismo
    // campo compiten y ninguna se lee.
    expect(find.text('Cédula, RUC o pasaporte'), findsNothing);
  });

  testWidgets(
    'en ventana ancha van dos columnas, y el campo largo ocupa las dos',
    (tester) async {
      await pump(tester, OrbiForm(sections: secciones), const Size(1440, 900));

      final nombre = tester.getTopLeft(find.byKey(const Key('campo-nombre')));
      final identificacion = tester.getTopLeft(
        find.byKey(const Key('campo-id')),
      );
      expect(
        nombre.dy,
        identificacion.dy,
        reason: 'los dos primeros comparten fila cuando hay sitio',
      );

      final anchoNombre = tester.getSize(find.byKey(const Key('campo-nombre')));
      final anchoDireccion = tester.getSize(
        find.byKey(const Key('campo-direccion')),
      );
      expect(anchoDireccion.width > anchoNombre.width, isTrue);
    },
  );

  // Un formulario de dos columnas en un teléfono se lee en zigzag.
  testWidgets('en ventana estrecha va a una sola columna', (tester) async {
    await pump(tester, OrbiForm(sections: secciones), const Size(390, 900));

    final nombre = tester.getTopLeft(find.byKey(const Key('campo-nombre')));
    final identificacion = tester.getTopLeft(find.byKey(const Key('campo-id')));
    expect(identificacion.dy > nombre.dy, isTrue);
  });
}
