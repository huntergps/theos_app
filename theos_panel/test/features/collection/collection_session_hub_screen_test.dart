import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/collection/collection_contracts.dart';
import 'package:theos_panel/features/collection/collection_session_hub_screen.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

void main() {
  CollectionSessionHubScreen buildScreen({
    void Function()? onOpenTurn,
    void Function()? onOpenRecords,
    void Function()? onGoToClosing,
    CollectionHubActionAvailability closingAvailability =
        CollectionHubActionAvailability.available,
    CollectionSessionRecordCounts? counts,
    CollectionShiftState state = CollectionShiftState.opened,
  }) => CollectionSessionHubScreen(
    point: const CollectionPointContext(
      pointLabel: 'Caja principal',
      cashierLabel: 'Cajera: María Sánchez',
    ),
    shift: CollectionShiftSnapshot(
      id: '42',
      state: state,
      expectedVersion: 1,
    ),
    counts: counts,
    turnActions: [
      CollectionHubAction(
        label: 'Anticipo',
        description: 'Registrar un anticipo del cliente contra la sesión.',
        icon: FluentIcons.savings,
        onOpen: onOpenTurn,
      ),
      const CollectionHubAction(
        label: 'Retención SRI',
        description:
            'Consultar la clave de acceso, revisar los datos descargados y registrar la retención electrónica del SRI.',
        icon: FluentIcons.invoice,
        availability: CollectionHubActionAvailability.forbidden,
      ),
    ],
    recordActions: [
      CollectionHubAction(
        label: 'Registros del turno',
        description: 'Órdenes, facturas y pagos de la sesión abierta.',
        icon: FluentIcons.clipboard_list,
        onOpen: onOpenRecords,
      ),
    ],
    closing: CollectionHubAction(
      label: 'Ir a cierre',
      description: 'Iniciar el control de cierre de la sesión actual.',
      icon: FluentIcons.clock,
      availability: closingAvailability,
      onOpen: onGoToClosing,
    ),
  );

  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    Widget child, {
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: FluentApp(theme: OrbiFluentTheme.light, home: child),
      ),
    );
    await tester.pump();
  }

  const desktop = Size(1400, 900);
  const tabletLandscape = Size(1024, 768);
  const tabletPortrait = Size(768, 1024);
  const phone = Size(390, 844);

  for (final entry in {
    'escritorio': desktop,
    'tablet horizontal': tabletLandscape,
    'tablet vertical': tabletPortrait,
    'teléfono': phone,
  }.entries) {
    testWidgets('${entry.key}: compone sin desbordes y muestra el hub', (
      tester,
    ) async {
      await pumpAt(
        tester,
        entry.value,
        buildScreen(
          onOpenTurn: () {},
          onOpenRecords: () {},
          onGoToClosing: () {},
          counts: const CollectionSessionRecordCounts(
            orderCount: 3,
            invoiceCount: 2,
            paymentCount: null,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Caja principal'), findsOneWidget);
      expect(find.text('Turno: En curso'), findsOneWidget);
      expect(find.text('Anticipo'), findsOneWidget);
      expect(find.text('Registros del turno'), findsOneWidget);
      expect(find.text('Ir a cierre'), findsOneWidget);
      expect(find.text('Sin autorización'), findsOneWidget);
      expect(find.text('Órdenes: 3'), findsOneWidget);
      expect(find.text('Facturas: 2'), findsOneWidget);
      expect(find.text('Pagos: No disponible'), findsOneWidget);
    });

    testWidgets('${entry.key}: no desborda con texto largo a doble escala', (
      tester,
    ) async {
      await pumpAt(
        tester,
        entry.value,
        buildScreen(
          onOpenTurn: () {},
          onOpenRecords: () {},
          onGoToClosing: () {},
        ),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Retención SRI'), findsOneWidget);
    });
  }

  testWidgets(
    'una acción sin destino aún queda visible pero inerte, no forbidden',
    (tester) async {
      await pumpAt(tester, desktop, buildScreen());

      expect(tester.takeException(), isNull);
      expect(find.text('No disponible todavía'), findsNWidgets(3));
      await tester.tap(find.text('Anticipo'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tocar una acción del turno navega usando el callback dado', (
    tester,
  ) async {
    var openedTurn = 0;
    await pumpAt(tester, desktop, buildScreen(onOpenTurn: () => openedTurn++));

    await tester.tap(find.text('Anticipo'));
    await tester.pump();
    expect(openedTurn, 1);
  });

  testWidgets('tocar registros navega usando el callback dado', (
    tester,
  ) async {
    var openedRecords = 0;
    await pumpAt(
      tester,
      desktop,
      buildScreen(onOpenRecords: () => openedRecords++),
    );

    await tester.tap(find.text('Registros del turno'));
    await tester.pump();
    expect(openedRecords, 1);
  });

  testWidgets('tocar cierre navega usando el callback dado cuando disponible', (
    tester,
  ) async {
    var wentToClosing = 0;
    await pumpAt(
      tester,
      desktop,
      buildScreen(onGoToClosing: () => wentToClosing++),
    );

    await tester.tap(find.text('Ir a cierre'));
    await tester.pump();
    expect(wentToClosing, 1);
  });

  testWidgets('una acción no autorizada no puede tocarse', (tester) async {
    await pumpAt(tester, desktop, buildScreen());

    await tester.tap(find.text('Retención SRI'));
    await tester.pump();
    // Forbidden never had a callback attached, so the only observable
    // guarantee is that tapping it does not throw or fake a result.
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin conteos de registros, no se muestra el resumen', (
    tester,
  ) async {
    await pumpAt(tester, desktop, buildScreen(counts: null));

    expect(find.textContaining('Órdenes:'), findsNothing);
  });

  // La composición real de un turno ajeno (`/collection/sessions/:id`,
  // supervisor sobre OTRO cajero) vive en `CollectionSupervisedSessionScreen`
  // (`collection_supervised_session_screen_test.dart`), que SÍ ofrece las
  // acciones que Odoo permite — reabrir, validar, cerrar, pausar, reanudar,
  // en línea — según el estado y el rol de quien mira. Este archivo prueba
  // sólo la composición GENÉRICA del hub (recibe la lista de acciones ya
  // resuelta y las pinta), no una versión "sin acciones" hoy obsoleta.
}
