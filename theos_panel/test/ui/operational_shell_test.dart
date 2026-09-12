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

Widget _host(
  Size size, {
  ValueChanged<String>? onNavigate,
  ThemeData? theme,
  bool locked = false,
  VoidCallback? onLock,
  Future<bool> Function(String password)? onUnlock,
  VoidCallback? onSwitchUser,
  Widget? child,
}) => MaterialApp(
  theme: theme,
  home: MediaQuery(
    data: MediaQueryData(size: size),
    child: OperationalShell(
      destinations: _destinations,
      selectedPath: '/sales',
      onNavigate: onNavigate ?? (_) {},
      context: _context,
      onLogout: () {},
      locked: locked,
      onLock: onLock,
      onUnlock: onUnlock,
      onSwitchUser: onSwitchUser,
      child: child ?? const Center(child: Text('Contenido operativo')),
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
    expect(find.bySemanticsLabel('Órdenes'), findsAtLeastNWidgets(1));
    expect(find.text('Servidor: erp.test'), findsOneWidget);
    expect(find.textContaining('Hora del servidor'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
    expect(find.byKey(const Key('logout-button')), findsOneWidget);
    expect(find.bySemanticsLabel('Navegación principal'), findsOneWidget);
    await tester.tap(find.text('Órdenes'));
    expect(selected, '/sales');
    expect(tester.takeException(), isNull);
  });

  // Regression guard for the exact defect the dueño reported (2026-09-12):
  // a desktop-sized window with no permanent navigation, only a hamburger.
  // The old `_isDesktop` gate required >= 1200 logical px — nowhere else in
  // this app's own responsive code (`OrbiTheme.mediumBreakpoint` = 840,
  // already used by `login_screen.dart`, `pin_login_screen.dart` and
  // `collection_screen.dart` for their own "wide" layout) draws that line
  // that high. 1000px is comfortably "desktop" by every other screen in
  // this app and was still getting the hidden drawer before this fix.
  testWidgets(
    'a 1000px-wide window — desktop by every other screen in this app — '
    'gets the permanent sidebar, not a hidden hamburger drawer',
    (tester) async {
      const size = Size(1000, 700);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_host(size));
      await tester.pump();
      expect(find.bySemanticsLabel('Navegación principal'), findsOneWidget);
      expect(find.text('Órdenes'), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
      expect(find.byTooltip('Open navigation menu'), findsNothing);
    },
  );

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

  testWidgets(
    'sin onLock/onSwitchUser el shell no ofrece botones que no puede ejecutar',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_host(const Size(1440, 900)));
      await tester.pump();
      expect(find.byKey(const Key('lock-button')), findsNothing);
      expect(find.byKey(const Key('switch-user-button')), findsNothing);
      expect(find.byKey(const Key('logout-button')), findsOneWidget);
    },
  );

  testWidgets('cambiar de usuario es alcanzable desde el shell y es una acción '
      'distinta de bloquear y de cerrar sesión', (tester) async {
    var switchTapped = 0;
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _host(
        const Size(1440, 900),
        onLock: () {},
        onUnlock: (_) async => true,
        onSwitchUser: () => switchTapped++,
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('lock-button')), findsOneWidget);
    expect(find.byKey(const Key('switch-user-button')), findsOneWidget);
    expect(find.byKey(const Key('logout-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('switch-user-button')));
    expect(switchTapped, 1);
  });

  testWidgets(
    'bloquear cubre el contenido sin descartarlo: un borrador a medias '
    'sobrevive el bloqueo y sale intacto al desbloquear con la contraseña '
    'correcta; una contraseña incorrecta no expone el contenido ni lo borra',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final draftController = TextEditingController();
      addTearDown(draftController.dispose);
      var locked = false;

      Future<bool> unlock(String password) async => password == 'correcta';

      late StateSetter setState;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setter) {
            setState = setter;
            return _host(
              const Size(1440, 900),
              locked: locked,
              onLock: () => setState(() => locked = true),
              onUnlock: (password) async {
                final ok = await unlock(password);
                if (ok) setState(() => locked = false);
                return ok;
              },
              child: TextField(
                key: const Key('draft-field'),
                controller: draftController,
              ),
            );
          },
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('draft-field')),
        'borrador a medias',
      );
      expect(draftController.text, 'borrador a medias');

      await tester.tap(find.byKey(const Key('lock-button')));
      await tester.pump();
      expect(find.text('Sesión bloqueada'), findsOneWidget);
      // The draft stays mounted underneath — nothing was discarded, only
      // hidden and made unreachable.
      expect(find.byKey(const Key('draft-field')), findsOneWidget);
      expect(draftController.text, 'borrador a medias');

      // A wrong password never unlocks, never touches the draft.
      await tester.enterText(
        find.byKey(const Key('workspace-lock-password')),
        'incorrecta',
      );
      await tester.tap(find.byKey(const Key('workspace-unlock-button')));
      await tester.pumpAndSettle();
      expect(find.text('Sesión bloqueada'), findsOneWidget);
      expect(
        find.textContaining('No se pudo verificar la contraseña'),
        findsOneWidget,
      );
      expect(draftController.text, 'borrador a medias');

      // The right password unlocks and the draft comes back exactly as it
      // was left, because it was never rebuilt or disposed.
      await tester.enterText(
        find.byKey(const Key('workspace-lock-password')),
        'correcta',
      );
      await tester.tap(find.byKey(const Key('workspace-unlock-button')));
      await tester.pumpAndSettle();
      expect(find.text('Sesión bloqueada'), findsNothing);
      expect(draftController.text, 'borrador a medias');
    },
  );

  testWidgets(
    'el shell bloqueado ignora los toques sobre el contenido cubierto, '
    'aunque siga montado debajo del bloqueo',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var navigated = false;
      await tester.pumpWidget(
        _host(
          const Size(1440, 900),
          locked: true,
          onLock: () {},
          onUnlock: (_) async => false,
          onNavigate: (_) => navigated = true,
        ),
      );
      await tester.pump();
      expect(find.text('Sesión bloqueada'), findsOneWidget);
      // The sidebar destination is still mounted underneath (nothing was
      // torn down by locking) but a tap on it must never reach onNavigate:
      // the lock overlay sits on top and absorbs/ignores pointer events.
      expect(find.text('Órdenes'), findsOneWidget);
      await tester.tap(find.text('Órdenes'), warnIfMissed: false);
      await tester.pump();
      expect(navigated, isFalse);
    },
  );

  testWidgets(
    'cambiar de usuario también es alcanzable desde la propia pantalla de '
    'bloqueo, como escape hatch distinto de reintentar la contraseña',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var switchTapped = 0;
      await tester.pumpWidget(
        _host(
          const Size(1440, 900),
          locked: true,
          onLock: () {},
          onUnlock: (_) async => false,
          onSwitchUser: () => switchTapped++,
        ),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('workspace-lock-switch-user-button')),
      );
      expect(switchTapped, 1);
    },
  );
}
