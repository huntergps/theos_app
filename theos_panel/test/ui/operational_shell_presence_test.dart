import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';
import 'package:theos_panel/ui/layouts/operational_shell.dart';

/// La presencia del usuario en el menú del avatar, igual que `theos_pos`
/// (`theos_pos/lib/shared/screens/main_screen.dart:1054-1111,1129-1178`).
/// Sólo UI: quién enchufa esto al runtime real es `router.dart`, que no se
/// toca aquí — `presence`/`onPresenceChanged` llegan como parámetros sueltos
/// de [OperationalShell], sin `orbi_runtime` de por medio salvo por el tipo
/// [OdooPresence] mismo, que ya es público.
const _context = OperationalContext(
  server: 'erp.test',
  database: 'orbi_test',
  userLabel: 'Erik',
  companyLabel: 'Empresa Demo',
  connectionLabel: 'Conectado',
  syncLabel: 'al día',
);

const _destinations = [
  OperationalDestination(
    label: 'Órdenes',
    path: '/sales',
    icon: FluentIcons.shopping_cart,
    group: 'Ventas',
  ),
];

Widget _host({
  OdooPresence? presence,
  ValueChanged<OdooPresence>? onPresenceChanged,
}) => FluentApp(
  theme: OrbiFluentTheme.light,
  home: MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: OperationalShell(
      destinations: _destinations,
      selectedPath: '/sales',
      onNavigate: (_) {},
      context: _context,
      onLogout: () {},
      clockTickInterval: null,
      presence: presence,
      onPresenceChanged: onPresenceChanged,
      child: const Center(child: Text('Contenido operativo')),
    ),
  ),
);

Future<void> _pump(WidgetTester tester, Widget host) async {
  const size = Size(1920, 1080);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(host);
  await tester.pumpAndSettle();
}

Color _dotColor(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.byKey(const Key('shell-presence-dot')),
  );
  final decoration = container.decoration! as BoxDecoration;
  return decoration.color!;
}

void main() {
  group('el punto de presencia en el avatar', () {
    testWidgets('(a) con presence: busy, el punto se ve con el color de '
        '«No molestar»', (tester) async {
      await _pump(tester, _host(presence: OdooPresence.busy));

      final dot = find.byKey(const Key('shell-presence-dot'));
      expect(dot, findsOneWidget);

      final theme = OrbiFluentTheme.light;
      expect(_dotColor(tester), theme.resources.systemFillColorCritical);
    });

    testWidgets('(d) con presence: null, no hay punto', (tester) async {
      await _pump(tester, _host());

      expect(find.byKey(const Key('shell-presence-dot')), findsNothing);
    });
  });

  group('el submenú «Estado»', () {
    testWidgets(
      '(b) con onPresenceChanged, aparece con las cuatro opciones, y elegir '
      '«Ausente» avisa `away` y cambia el punto',
      (tester) async {
        OdooPresence? avisado;
        await _pump(
          tester,
          _host(
            presence: OdooPresence.online,
            onPresenceChanged: (status) => avisado = status,
          ),
        );

        await tester.tap(find.byKey(const Key('shell-avatar-button')));
        await tester.pumpAndSettle();

        final submenu = find.byKey(const Key('shell-presence-submenu'));
        expect(submenu, findsOneWidget);
        await tester.tap(submenu);
        await tester.pumpAndSettle();

        // Por clave, no por texto: Fluent anima la apertura del submenú y
        // puede dejar en el árbol una copia transitoria del renglón durante
        // la transición — el texto ya no es único mientras eso pasa, la
        // clave de cada opción sí.
        expect(
          find.byKey(const Key('shell-presence-option-online')),
          findsWidgets,
        );
        expect(
          find.byKey(const Key('shell-presence-option-away')),
          findsWidgets,
        );
        expect(
          find.byKey(const Key('shell-presence-option-busy')),
          findsWidgets,
        );
        expect(
          find.byKey(const Key('shell-presence-option-offline')),
          findsWidgets,
        );
        // Las mismas cuatro palabras de `theos_pos`
        // (`theos_pos/lib/shared/models/im_status.dart:17,19,21,23`) y de
        // Odoo web — no un nombre propio de Orbi.
        expect(find.text('En línea'), findsWidgets);
        expect(find.text('Ausente'), findsWidgets);
        expect(find.text('No molestar'), findsWidgets);
        expect(find.text('Desconectado'), findsWidgets);

        await tester.tap(
          find.byKey(const Key('shell-presence-option-away')).first,
        );
        await tester.pumpAndSettle();

        expect(avisado, OdooPresence.away);

        final theme = OrbiFluentTheme.light;
        expect(_dotColor(tester), theme.resources.systemFillColorCaution);
      },
    );

    testWidgets('(c) con onPresenceChanged: null, no aparece «Estado»', (
      tester,
    ) async {
      await _pump(tester, _host(presence: OdooPresence.online));

      await tester.tap(find.byKey(const Key('shell-avatar-button')));
      await tester.pumpAndSettle();

      expect(find.text('Estado'), findsNothing);
    });
  });
}
