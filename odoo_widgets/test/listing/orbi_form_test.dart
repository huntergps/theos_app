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

  // 🔴 El formulario compartido sólo sabía ser el cuerpo entero de una página:
  // envolvía sus secciones en `Expanded` + scroll, así que exigía altura
  // acotada y **reventaba** dentro de un `ListView`. Como casi ningún
  // formulario es la pantalla entera —los ajustes, el editor de cobro y el
  // resumen de venta son trozos de pantallas que ya scrollean—, eso dejaba
  // fuera del estándar justo a las que más falta les hacía: estandarizar la
  // etiqueta obligaba a rehacer el scroll de la pantalla completa.
  testWidgets('cabe dentro de una lista que ya scrollea, sin reventar', (
    tester,
  ) async {
    await tester.pumpWidget(
      FluentApp(
        home: ScaffoldPage(
          content: ListView(
            children: [
              const Text('Algo que va antes del formulario'),
              OrbiForm(
                sections: [
                  OrbiFormSection(
                    title: 'Datos',
                    fields: [
                      OrbiField(
                        label: 'Nombre',
                        required: true,
                        child: const TextBox(),
                      ),
                    ],
                  ),
                ],
              ),
              const Text('Y algo que va después'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Algo que va antes del formulario'), findsOneWidget);
    expect(find.text('Y algo que va después'), findsOneWidget);
    expect(find.text('Nombre'), findsOneWidget);
  });

  testWidgets('midiendo lo suyo, no se come el alto de lo que va debajo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      FluentApp(
        home: ScaffoldPage(
          content: Column(
            children: [
              OrbiForm(
                sections: [
                  OrbiFormSection(
                    title: 'Datos',
                    fields: [
                      OrbiField(label: 'Nombre', child: const TextBox()),
                    ],
                  ),
                ],
              ),
              const Text('Acciones de abajo'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Si el formulario se comiera el alto sobrante, esto quedaría empujado
    // fuera de pantalla o la columna reventaría.
    expect(find.text('Acciones de abajo'), findsOneWidget);
    expect(
      tester.getSize(find.byType(OrbiForm)).height,
      lessThan(400),
      reason: 'debe medir sus campos, no todo el alto disponible',
    );
  });

  testWidgets('la variante de página deja las acciones fijas abajo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      FluentApp(
        home: ScaffoldPage(
          content: OrbiForm.filling(
            sections: [
              for (var i = 0; i < 20; i++)
                OrbiFormSection(
                  title: 'Sección $i',
                  fields: [
                    OrbiField(label: 'Campo $i', child: const TextBox()),
                  ],
                ),
            ],
            actions: const Text('Guardar'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Con veinte secciones la última cae fuera de la ventana, pero el botón
    // sigue dentro: eso es lo que aporta la variante de página. Se comprueba
    // por geometría, no con `findsNothing`: un `SingleChildScrollView`
    // construye TODOS sus hijos, así que la sección 19 existe en el árbol
    // aunque nadie pueda verla.
    expect(
      tester.getBottomLeft(find.text('Guardar')).dy,
      lessThanOrEqualTo(800),
    );
    expect(
      tester.getTopLeft(find.text('Sección 19')).dy,
      greaterThan(800),
      reason: 'la última sección queda fuera de la ventana, sin scrollear',
    );
  });

  // 🔴 La etiqueta iba en una fila sin límite de ancho. Con letra grande en un
  // teléfono, una etiqueta larga desbordaba por la derecha: rompió la prueba
  // de cobros a 360 px y 2x, y quedaba latente en el alta de PIN y el editor
  // de venta. Tiene que partir en líneas, NO recortarse: una etiqueta cortada
  // esconde de qué es el campo.
  testWidgets(
    'una etiqueta larga con letra grande parte en líneas, no desborda',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        FluentApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: ScaffoldPage(
                content: SingleChildScrollView(
                  child: OrbiForm(
                    sections: [
                      OrbiFormSection(
                        title: 'Datos',
                        fields: [
                          OrbiField(
                            label: 'Confirmar el número de identificación',
                            required: true,
                            child: const TextBox(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'la etiqueta desbordó');
      expect(
        find.text('Confirmar el número de identificación'),
        findsOneWidget,
      );
      expect(find.text('*'), findsOneWidget);
    },
  );
}
