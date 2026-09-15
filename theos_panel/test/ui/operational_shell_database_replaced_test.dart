import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';
import 'package:theos_panel/ui/layouts/operational_shell.dart';

// Huella de la base de Odoo (14-sep-2026): mismo patrón que
// `operational_shell_storage_mode_test.dart` — fija el contrato de PINTADO,
// sin router ni `SessionRuntime` real. `OperationalContext.databaseReplacedNotice`
// es el único dato que le importa a este widget; `router.dart` es quien arma
// el evento real desde `SessionRuntime.databaseReplacements`.
const _destinations = [
  OperationalDestination(
    label: 'Órdenes',
    path: '/sales',
    icon: FluentIcons.shopping_cart,
    group: 'Ventas',
  ),
];

AppScope _scope() => AppScope(
  appId: 'orbi-panel',
  installationId: 'installation-a',
  normalizedServerUrl: 'https://erp.test',
  database: 'erp',
  userId: 1,
);

OperationalContext _contextWith(OdooDatabaseReplaced? notice) =>
    OperationalContext(
      server: 'erp.test',
      database: 'orbi_test',
      userLabel: 'Erik',
      companyLabel: 'Empresa Demo',
      connectionLabel: 'Conectado',
      syncLabel: '0 pendientes',
      databaseReplacedNotice: notice,
    );

Widget _host(
  OperationalContext context, {
  VoidCallback? onDismissDatabaseReplacedNotice,
}) => FluentApp(
  theme: OrbiFluentTheme.light,
  home: MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: OperationalShell(
      destinations: _destinations,
      selectedPath: '/sales',
      onNavigate: (_) {},
      context: context,
      onLogout: () {},
      onDismissDatabaseReplacedNotice: onDismissDatabaseReplacedNotice,
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
  testWidgets('no notice when nothing replaced the database', (tester) async {
    await _pump(tester, _host(_contextWith(null)));

    expect(
      find.byKey(const Key('shell-database-replaced-warning')),
      findsNothing,
    );
  });

  testWidgets(
    'shell shows database replaced notice with discarded count',
    (tester) async {
      var dismissed = false;
      final notice = OdooDatabaseReplaced(
        scope: _scope(),
        discardedOperations: 3,
        operationsSummary: const ['sale.order.create', 'stock.picking.write'],
      );

      await _pump(
        tester,
        _host(
          _contextWith(notice),
          onDismissDatabaseReplacedNotice: () => dismissed = true,
        ),
      );

      expect(
        find.byKey(const Key('shell-database-replaced-warning')),
        findsOneWidget,
      );
      expect(
        find.textContaining('La base de Odoo de este servidor cambió'),
        findsOneWidget,
      );
      expect(
        find.textContaining('3 operaciones pendientes sin enviar'),
        findsOneWidget,
      );

      // El detalle empieza colapsado.
      expect(find.text('• sale.order.create'), findsNothing);
      await tester.tap(find.text('Ver detalle'));
      await tester.pumpAndSettle();
      expect(find.text('• sale.order.create'), findsOneWidget);
      expect(find.text('• stock.picking.write'), findsOneWidget);

      // Cerrarlo a mano llama al callback de `router.dart` — el widget en sí
      // no decide cuándo desaparece, sólo lo pide.
      expect(dismissed, isFalse);
      await tester.tap(find.byIcon(FluentIcons.chrome_close));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    },
  );

  testWidgets(
    'without discarded operations there is nothing to expand',
    (tester) async {
      final notice = OdooDatabaseReplaced(
        scope: _scope(),
        discardedOperations: 0,
      );

      await _pump(tester, _host(_contextWith(notice)));

      expect(
        find.byKey(const Key('shell-database-replaced-warning')),
        findsOneWidget,
      );
      expect(find.text('Ver detalle'), findsNothing);
    },
  );
}
