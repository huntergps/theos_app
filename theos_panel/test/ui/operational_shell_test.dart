import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:theos_panel/ui/layouts/operational_shell.dart';

const _context = OperationalContext(
  server: 'erp.test',
  database: 'orbi_test',
  userLabel: 'Erik',
  companyLabel: 'Empresa Demo',
  connectionLabel: 'Conectado',
  syncLabel: '3 pendientes',
);

const _destinations = [
  OperationalDestination(
    label: 'Órdenes',
    path: '/sales',
    icon: Icons.shopping_cart_outlined,
    group: 'Ventas',
  ),
  OperationalDestination(
    label: 'Clientes',
    path: '/clients',
    icon: Icons.people_outline,
    group: 'Ventas',
  ),
  OperationalDestination(
    label: 'Dashboard',
    path: '/envases',
    icon: Icons.inventory_2_outlined,
    group: 'Envases',
  ),
];

Widget _host(Size size, {ValueChanged<String>? onNavigate, ThemeData? theme}) =>
    MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: OperationalShell(
          destinations: _destinations,
          selectedPath: '/sales',
          onNavigate: onNavigate ?? (_) {},
          context: _context,
          onLogout: () {},
          child: const Center(child: Text('Contenido operativo')),
        ),
      ),
    );

void main() {
  testWidgets('uses grouped sidebar on desktop and footer context', (
    tester,
  ) async {
    String? selected;
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _host(const Size(1440, 900), onNavigate: (path) => selected = path),
    );
    await tester.pump();
    expect(find.text('Ventas'), findsOneWidget);
    expect(find.text('Órdenes'), findsOneWidget);
    expect(find.text('Servidor: erp.test'), findsOneWidget);
    expect(find.textContaining('Hora del servidor'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
    expect(find.byKey(const Key('logout-button')), findsOneWidget);
    expect(find.bySemanticsLabel('Navegación principal'), findsOneWidget);
    await tester.tap(find.text('Órdenes'));
    expect(selected, '/sales');
    expect(tester.takeException(), isNull);
  });

  testWidgets('tints the existing logo from the active theme', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: _host(const Size(1440, 900), theme: ThemeData.dark())),
    );
    await tester.pump();
    final logo = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(logo.colorFilter, isA<ColorFilter>());
  });

  testWidgets('uses responsive navigation and context across four viewports', (
    tester,
  ) async {
    const sizes = [
      Size(1440, 900),
      Size(1180, 820),
      Size(820, 1180),
      Size(390, 844),
    ];
    for (final size in sizes) {
      String? selected;
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        _host(size, onNavigate: (path) => selected = path),
      );
      await tester.pump();

      final horizontal = size.width >= 600 && size.width >= size.height;
      if (horizontal) {
        expect(find.text('Servidor: erp.test'), findsOneWidget);
        expect(find.textContaining('BD: orbi_test'), findsOneWidget);
      } else {
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
        expect(find.text('Dashboard'), findsOneWidget);
        await tester.tap(find.text('Dashboard'));
        await tester.pumpAndSettle();
        expect(selected, '/envases');
        expect(find.text('Dashboard'), findsNothing);

        expect(
          find.byKey(const Key('operational-context-button')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('operational-context-button')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Servidor: erp.test'), findsOneWidget);
        expect(find.textContaining('BD: orbi_test'), findsOneWidget);
        expect(
          find.textContaining('Hora del servidor no disponible'),
          findsOneWidget,
        );
        Navigator.of(tester.element(find.byType(OperationalShell))).pop();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('navigates through drawer destinations', (tester) async {
    String? selected;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _host(
        const Size(390, 844),
        onNavigate: (path) {
          selected = path;
        },
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(selected, '/envases');
    expect(find.text('Dashboard'), findsNothing);
  });
}
