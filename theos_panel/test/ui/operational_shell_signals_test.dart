import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/auth/saved_servers.dart' show ServerEnvironment;
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';
import 'package:theos_panel/ui/layouts/operational_shell.dart';

/// Señales nuevas del armazón (encargo del 14-sep-2026): ambiente del
/// servidor, caja abierta y pendientes del SRI. Mismo contrato de pintado
/// que ya fija `operational_shell_realtime_status_test.dart`: dado un
/// `OperationalContext`, sin router ni providers, el armazón debe mostrar (o
/// callar) la píldora correspondiente.
const _destinations = [
  OperationalDestination(
    label: 'Órdenes',
    path: '/sales',
    icon: FluentIcons.shopping_cart,
    group: 'Ventas',
  ),
];

OperationalContext _contextWith({
  ServerEnvironment? environment,
  bool cashSessionOpen = false,
  SriPendingStatus? sriPending,
  String? deviceName,
}) => OperationalContext(
  server: 'erp.test',
  database: 'orbi_test',
  userLabel: 'Erik',
  companyLabel: 'Empresa Demo',
  connectionLabel: 'Conectado',
  syncLabel: '0 pendientes',
  environment: environment,
  cashSessionOpen: cashSessionOpen,
  sriPending: sriPending,
  deviceName: deviceName,
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
  group('píldora de ambiente', () {
    testWidgets('shows Pruebas pill for a test server', (tester) async {
      await _pump(
        tester,
        _host(_contextWith(environment: ServerEnvironment.test)),
      );
      expect(find.byKey(const Key('shell-environment-pill')), findsOneWidget);
      expect(find.text('Pruebas'), findsOneWidget);
    });

    testWidgets('shows Producción pill for a production server', (
      tester,
    ) async {
      await _pump(
        tester,
        _host(_contextWith(environment: ServerEnvironment.production)),
      );
      expect(find.byKey(const Key('shell-environment-pill')), findsOneWidget);
      expect(find.text('Producción'), findsOneWidget);
    });

    testWidgets('shows nothing when environment is not set', (tester) async {
      await _pump(tester, _host(_contextWith()));
      expect(find.byKey(const Key('shell-environment-pill')), findsNothing);
    });
  });

  group('píldora de caja', () {
    testWidgets('cash pill appears only with cashier and an open session', (
      tester,
    ) async {
      await _pump(tester, _host(_contextWith(cashSessionOpen: true)));
      expect(find.byKey(const Key('shell-cash-session-pill')), findsOneWidget);
      expect(find.text('Caja abierta'), findsOneWidget);
    });

    testWidgets('no cash pill without an open session', (tester) async {
      await _pump(tester, _host(_contextWith()));
      expect(find.byKey(const Key('shell-cash-session-pill')), findsNothing);
    });
  });

  group('píldora del SRI', () {
    testWidgets('sri count is hidden when the field does not exist', (
      tester,
    ) async {
      // `sriPending: null` es exactamente lo que arma `router.dart` cuando
      // `OdooClient.hasField('account.move', 'edi_state')` respondió
      // `false` — el servidor no tiene contabilidad electrónica.
      await _pump(tester, _host(_contextWith()));
      expect(find.byKey(const Key('shell-sri-pending-pill')), findsNothing);
    });

    testWidgets('sri count shows last reading offline', (tester) async {
      await _pump(
        tester,
        _host(
          _contextWith(
            sriPending: const SriPendingStatus(count: 3, isLastReading: true),
          ),
        ),
      );
      expect(find.byKey(const Key('shell-sri-pending-pill')), findsOneWidget);
      expect(
        find.textContaining('3 pendientes SRI (última lectura)'),
        findsOneWidget,
      );
    });

    testWidgets('sri count shows a fresh count without the caveat', (
      tester,
    ) async {
      await _pump(
        tester,
        _host(
          _contextWith(
            sriPending: const SriPendingStatus(count: 5),
          ),
        ),
      );
      expect(find.text('5 pendientes SRI'), findsOneWidget);
    });
  });

  group('nombre del equipo en el pie', () {
    testWidgets('se ve junto a servidor y base', (tester) async {
      await _pump(
        tester,
        _host(_contextWith(deviceName: 'iMac de la caja 2')),
      );
      expect(find.text('iMac de la caja 2'), findsOneWidget);
    });

    testWidgets('sin nombre no se pinta nada de más', (tester) async {
      await _pump(tester, _host(_contextWith()));
      expect(find.byIcon(FluentIcons.device_run), findsNothing);
    });
  });
}
