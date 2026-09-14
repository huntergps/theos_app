import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';
import 'package:theos_panel/ui/layouts/operational_shell.dart';

/// Hueco 1 del encargo del 14-sep-2026: `RealtimeStatus` (`orbi_runtime`) ya
/// existe, pero nada en el armazón lo leía — el único `ref.watch` sobre el
/// coordinador de tiempo real sólo lo mantenía vivo
/// (`theos_panel/lib/app/router.dart:1377`). Esta prueba fija el contrato de
/// PINTADO, sin router ni providers: dado un `RealtimeStatus`, el armazón
/// debe mostrar el texto correspondiente junto a la píldora de conexión.
const _destinations = [
  OperationalDestination(
    label: 'Órdenes',
    path: '/sales',
    icon: FluentIcons.shopping_cart,
    group: 'Ventas',
  ),
];

OperationalContext _contextWith(RealtimeStatus? status) => OperationalContext(
  server: 'erp.test',
  database: 'orbi_test',
  userLabel: 'Erik',
  companyLabel: 'Empresa Demo',
  connectionLabel: 'Conectado',
  syncLabel: '0 pendientes',
  realtimeStatus: status,
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
  testWidgets(
    'RealtimeStatus.retrying se pinta como "Tiempo real: reconectando"',
    (tester) async {
      await _pump(tester, _host(_contextWith(RealtimeStatus.retrying)));
      expect(find.textContaining('Tiempo real: reconectando'), findsOneWidget);
    },
  );

  testWidgets(
    'RealtimeStatus.connecting también se lee como "reconectando"',
    (tester) async {
      await _pump(tester, _host(_contextWith(RealtimeStatus.connecting)));
      expect(find.textContaining('Tiempo real: reconectando'), findsOneWidget);
    },
  );

  testWidgets(
    'RealtimeStatus.disabled se pinta como "no disponible en este servidor", '
    'nunca como un error rojo',
    (tester) async {
      await _pump(tester, _host(_contextWith(RealtimeStatus.disabled)));
      expect(
        find.textContaining('no disponible en este servidor'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'RealtimeStatus.live se pinta como "Tiempo real: conectado"',
    (tester) async {
      await _pump(tester, _host(_contextWith(RealtimeStatus.live)));
      expect(find.textContaining('Tiempo real: conectado'), findsOneWidget);
    },
  );

  testWidgets(
    'sin RealtimeStatus (sesión sin coordinador) no se pinta ninguna píldora',
    (tester) async {
      await _pump(tester, _host(_contextWith(null)));
      expect(find.byKey(const Key('shell-realtime-pill')), findsNothing);
    },
  );
}
