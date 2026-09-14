import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';
import 'package:theos_panel/ui/layouts/operational_shell.dart';

/// Bloque B de la auditoría de "se pierde todo lo que estaba haciendo"
/// (14-sep-2026): si el navegador cae a un almacenamiento que no sobrevive a
/// cerrar la pestaña (`WasmStorageImplementation.inMemory`), antes de esto
/// nadie lo veía — el único rastro era un `print` de drift_flutter en la
/// consola. Esta prueba fija el contrato de PINTADO, sin router ni runtime:
/// `OperationalContext.storageIsVolatile` es el único dato que le importa a
/// este widget — es el punto donde `router.dart` inyecta la medida real
/// (`RuntimeDatabaseOwner.storageMode`).
const _destinations = [
  OperationalDestination(
    label: 'Órdenes',
    path: '/sales',
    icon: FluentIcons.shopping_cart,
    group: 'Ventas',
  ),
];

OperationalContext _contextWith({required bool storageIsVolatile}) =>
    OperationalContext(
      server: 'erp.test',
      database: 'orbi_test',
      userLabel: 'Erik',
      companyLabel: 'Empresa Demo',
      connectionLabel: 'Conectado',
      syncLabel: '0 pendientes',
      storageIsVolatile: storageIsVolatile,
    );

Widget _host(OperationalContext context) => FluentApp(
  theme: OrbiFluentTheme.light,
  home: MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: OperationalShell(
      destinations: _destinations,
      selectedPath: '/sales',
      onNavigate: (_) {},
      context: context,
      onLogout: () {},
      child: const Center(child: Text('Contenido operativo')),
    ),
  ),
);

Future<void> _pump(WidgetTester tester, Widget host) async {
  await tester.binding.setSurfaceSize(const Size(1920, 1080));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(host);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('volatile storage shows the warning', (tester) async {
    await _pump(tester, _host(_contextWith(storageIsVolatile: true)));

    expect(
      find.byKey(const Key('shell-volatile-storage-warning')),
      findsOneWidget,
    );
    expect(
      find.textContaining('no está guardando datos en el equipo'),
      findsOneWidget,
    );
  });

  testWidgets('persistent storage shows no warning', (tester) async {
    await _pump(tester, _host(_contextWith(storageIsVolatile: false)));

    expect(
      find.byKey(const Key('shell-volatile-storage-warning')),
      findsNothing,
    );
  });
}
