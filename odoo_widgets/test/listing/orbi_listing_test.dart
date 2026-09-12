import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_widgets/odoo_widgets.dart';
import 'package:syncfusion_flutter_core/theme.dart';

/// El listado estándar, comprobado contra lo que pidió el dueño: *«todas
/// tienen listado, filtro, paginación, exportación a Excel, ocultar/mostrar
/// columnas y título»*.
class _Fila {
  const _Fila(this.nombre, this.total);
  final String nombre;
  final double total;
}

void main() {
  final columnas = <OrbiColumn<_Fila>>[
    OrbiColumn(
      key: 'nombre',
      label: 'Cliente',
      value: (f) => f.nombre,
      alwaysVisible: true,
    ),
    OrbiColumn(
      key: 'total',
      label: 'Total',
      value: (f) => f.total.toStringAsFixed(2),
      numeric: true,
    ),
  ];

  final filas = List.generate(
    120,
    (i) => _Fila('Cliente ${i + 1}', (i + 1) * 3.5),
  );

  Future<void> pump(WidgetTester tester, Widget listado) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      FluentApp(
        home: ScaffoldPage(
          content: Padding(padding: const EdgeInsets.all(16), child: listado),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('trae filtro, columnas y exportación de serie', (tester) async {
    await pump(
      tester,
      OrbiListing<_Fila>(
        rows: filas.take(50).toList(),
        columns: columnas,
        storageKey: 'prueba',
        onExport: (_, _) {},
      ),
    );

    expect(find.byKey(const Key('orbi-listing-filter')), findsOneWidget);
    expect(find.byKey(const Key('orbi-listing-columns')), findsOneWidget);
    expect(find.byKey(const Key('orbi-listing-export')), findsOneWidget);
  });

  // Algunas listas no deben salir del sistema; ahí el botón no aparece, en vez
  // de aparecer y fallar al pulsarlo.
  testWidgets('sin exportación no dibuja el botón', (tester) async {
    await pump(
      tester,
      OrbiListing<_Fila>(
        rows: filas.take(5).toList(),
        columns: columnas,
        storageKey: 'prueba',
      ),
    );

    expect(find.byKey(const Key('orbi-listing-export')), findsNothing);
  });

  testWidgets('la cabecera lleva el color de acento, no un gris', (
    tester,
  ) async {
    await pump(
      tester,
      OrbiListing<_Fila>(
        rows: filas.take(5).toList(),
        columns: columnas,
        storageKey: 'prueba',
      ),
    );

    final tema = tester.widget<SfDataGridTheme>(find.byType(SfDataGridTheme));
    expect(tema.data.headerColor, isNotNull);
    expect(tema.data.headerColor, isNot(Colors.transparent));
  });

  testWidgets('la paginación dice el total, no sólo la página', (tester) async {
    var pagina = 0;
    await pump(
      tester,
      OrbiListing<_Fila>(
        rows: filas.take(50).toList(),
        columns: columnas,
        storageKey: 'prueba',
        totalCount: 120,
        rowsPerPage: 50,
        pageIndex: 0,
        onPageChanged: (p) => pagina = p,
      ),
    );

    // Sin el total nadie sabe si merece la pena seguir pasando páginas.
    expect(find.text('120 registros'), findsOneWidget);
    expect(find.text('1 de 3'), findsOneWidget);

    // En la primera página no se puede retroceder, y el botón se ve
    // deshabilitado en vez de desaparecer.
    final anterior = tester.widget<IconButton>(
      find.byKey(const Key('orbi-listing-prev')),
    );
    expect(anterior.onPressed, isNull);

    await tester.tap(find.byKey(const Key('orbi-listing-next')));
    await tester.pumpAndSettle();
    expect(pagina, 1);
  });

  testWidgets('con una sola página no dibuja paginación', (tester) async {
    await pump(
      tester,
      OrbiListing<_Fila>(
        rows: filas.take(5).toList(),
        columns: columnas,
        storageKey: 'prueba',
        rowsPerPage: 50,
      ),
    );

    expect(find.byKey(const Key('orbi-listing-next')), findsNothing);
  });

  testWidgets('una columna se puede ocultar, salvo la que identifica la fila', (
    tester,
  ) async {
    await pump(
      tester,
      OrbiListing<_Fila>(
        rows: filas.take(5).toList(),
        columns: columnas,
        storageKey: 'prueba',
      ),
    );

    expect(find.text('Total'), findsOneWidget);

    await tester.tap(find.byKey(const Key('orbi-listing-columns')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Total').last);
    await tester.pumpAndSettle();
    // Cerrar el menú desplegable para poder mirar la tabla.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('Total'), findsNothing);
    // La que identifica la fila sigue: sin ella la tabla deja de decir de qué
    // es cada línea.
    expect(find.text('Cliente'), findsOneWidget);
  });

  testWidgets(
    'una lista vacía lo dice, en vez de enseñar una tabla en blanco',
    (tester) async {
      await pump(
        tester,
        OrbiListing<_Fila>(
          rows: const [],
          columns: columnas,
          storageKey: 'prueba',
          emptyMessage: 'Todavía no hay cobros de hoy',
        ),
      );

      expect(find.text('Todavía no hay cobros de hoy'), findsOneWidget);
    },
  );

  // 🔴 La prueba que faltaba, y que dejó pasar el defecto durante horas: todas
  // las de arriba comprobaban la barra, la paginación y la cabecera, y ninguna
  // comprobaba que **se vieran las filas**. El origen de datos sobreescribía
  // `effectiveRows`, que es un getter interno alimentado desde `rows`, así que
  // compilaba, pintaba la cabecera y no enseñaba ni una línea. Se descubrió al
  // usarlo en una pantalla de verdad, no aquí.
  testWidgets('las filas se ven, no sólo la cabecera', (tester) async {
    await pump(
      tester,
      OrbiListing<_Fila>(
        rows: filas.take(3).toList(),
        columns: columnas,
        storageKey: 'prueba',
      ),
    );

    expect(find.text('Cliente 1'), findsOneWidget);
    expect(find.text('Cliente 2'), findsOneWidget);
    // Y el valor formateado por la columna, no el objeto crudo.
    expect(find.text('3.50'), findsOneWidget);
  });

  // El botón de Excel llamaba a quien lo usaba y no había Excel por ninguna
  // parte: era un aviso vacío. Ahora produce el fichero de verdad, y lo que
  // sale es lo que se está viendo.
  testWidgets('exportar entrega un fichero de Excel de verdad', (tester) async {
    List<int>? entregado;
    String? nombre;
    await pump(
      tester,
      OrbiListing<_Fila>(
        rows: filas.take(4).toList(),
        columns: columnas,
        storageKey: 'prueba',
        exportFileName: 'clientes-de-hoy',
        onExport: (bytes, suggested) {
          entregado = bytes;
          nombre = suggested;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('orbi-listing-export')));
    await tester.pumpAndSettle();

    expect(entregado, isNotNull);
    expect(nombre, 'clientes-de-hoy');
    // Un .xlsx es un zip: empieza por «PK». Comprobar sólo que no está vacío
    // dejaría pasar un fichero corrupto.
    expect(entregado!.length, greaterThan(0));
    expect(entregado![0], 0x50);
    expect(entregado![1], 0x4B);
  });
}
