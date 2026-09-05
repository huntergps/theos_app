import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/database/providers.dart';
import 'package:theos_pos/core/database/repositories/repository_providers.dart';
import 'package:theos_pos/features/collection/providers/counter_capabilities_provider.dart';
import 'package:theos_pos/features/sales/screens/fast_sale/fast_sale_providers.dart';
import 'package:theos_pos/features/sales/screens/fast_sale/widgets/pos_actions_panel.dart';
import 'package:theos_pos/features/sales/screens/fast_sale/widgets/pos_order_lines_panel.dart';
import 'package:theos_pos/features/sales/screens/fast_sale/widgets/pos_payment_tab.dart';
import 'package:theos_pos/shared/constants/user_groups.dart';
import 'package:theos_pos/shared/providers/user_provider.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

class _TestUser extends UserNotifier {
  _TestUser(this.user);
  final User? user;
  @override
  User? build() => user;
}

const _cashier = User(
  id: 7,
  name: 'Caja de prueba',
  login: 'cashier-test',
  permissions: [OdooUserGroup.collectionUser],
);

void main() {
  for (final visible in [false, true]) {
    testWidgets('cashier actions follow point visibility $visible', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          userProvider.overrideWith(() => _TestUser(_cashier)),
          fastSaleActiveTabProvider.overrideWithValue(null),
          counterCapabilitiesProvider.overrideWith(
            (ref) => Stream.value(
              PosAppCapabilities.fromJson({
                'version': 1,
                'config_id': 4,
                'company_id': 2,
                'counter_policies': {
                  for (final name in PosAppCapabilities.booleanPolicyNames)
                    name: visible,
                  'panel_dias_pendientes': 30,
                },
              }),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FluentApp(home: POSActionsPanel()),
        ),
      );
      await tester.pump();
      for (final label in ['Cobrar', 'Anticipo', 'Salida Dinero']) {
        expect(find.text(label), visible ? findsOneWidget : findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('restored payments tab does not render cashier UI for seller', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        userProvider.overrideWith(
          () => _TestUser(
            _cashier.copyWith(permissions: [OdooUserGroup.salesUser]),
          ),
        ),
        fastSaleActiveTabProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);
    container.read(orderPanelTabProvider.notifier).goToPayments();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FluentApp(home: POSOrderLinesPanel()),
      ),
    );
    expect(find.byType(POSPaymentTab), findsNothing);
    expect(
      find.text('El cobro de esta venta corresponde al cajero.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  Future<ProviderContainer> invoke(
    WidgetTester tester, {
    User? user = _cashier,
    int sessionUserId = 7,
    SessionState? sessionState = SessionState.opened,
    SaleOrderState? orderState = SaleOrderState.sale,
    bool? paymentVisible,
  }) async {
    final container = ProviderContainer(
      overrides: [
        userProvider.overrideWith(() => _TestUser(user)),
        collectionRepositoryProvider.overrideWithValue(null),
        userRepositoryProvider.overrideWithValue(null),
        if (paymentVisible != null)
          counterCapabilitiesProvider.overrideWith(
            (ref) => Stream.value(
              PosAppCapabilities.fromJson({
                'version': 1,
                'config_id': 4,
                'company_id': 2,
                'counter_policies': {
                  for (final name in PosAppCapabilities.booleanPolicyNames)
                    name: true,
                  'panel_accion_visible_pago': paymentVisible,
                  'panel_dias_pendientes': 30,
                },
              }),
            ),
          ),
      ],
    );
    addTearDown(container.dispose);
    if (sessionState != null) {
      container
          .read(currentSessionProvider.notifier)
          .set(
            CollectionSession(
              id: 9,
              name: 'Caja',
              state: sessionState,
              userId: sessionUserId,
            ),
          );
    }
    final tab = orderState == null
        ? null
        : FastSaleTabState(
            orderId: 12,
            orderName: 'Venta',
            order: SaleOrder(id: 12, name: 'Venta', state: orderState),
          );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: FluentApp(
          home: Consumer(
            builder: (context, ref, _) => Button(
              onPressed: () => goToPaymentsWithAutoConfirm(context, ref, tab),
              child: const Text('Entrar al cobro'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Entrar al cobro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // The point policy arrives through a local stream before the handler acts.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  Future<void> cleanUp(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  }

  testWidgets('F6 shared handler respects disabled payment policy', (
    tester,
  ) async {
    final container = await invoke(tester, paymentVisible: false);
    expect(find.text('Acción no disponible'), findsOneWidget);
    expect(
      container.read(orderPanelTabProvider),
      isNot(OrderPanelTab.payments),
    );
    await cleanUp(tester);
  });

  testWidgets('seller cannot enter payment or confirm via shared F6 handler', (
    tester,
  ) async {
    final container = await invoke(
      tester,
      user: _cashier.copyWith(permissions: [OdooUserGroup.salesUser]),
      orderState: SaleOrderState.draft,
    );
    expect(container.read(orderPanelTabProvider), OrderPanelTab.products);
    expect(find.text('Cobro no autorizado'), findsOneWidget);
    expect(find.text('Confirmar y Cobrar'), findsNothing);
    await cleanUp(tester);
  });

  testWidgets('logged out user cannot enter payment', (tester) async {
    final container = await invoke(tester, user: null);
    expect(container.read(orderPanelTabProvider), OrderPanelTab.products);
    expect(find.text('Cobro no autorizado'), findsOneWidget);
    await cleanUp(tester);
  });

  for (final state in <SessionState?>[
    null,
    SessionState.openingControl,
    SessionState.paused,
    SessionState.closingControl,
    SessionState.closed,
  ]) {
    testWidgets('cashier cannot enter payment with session $state', (
      tester,
    ) async {
      final container = await invoke(tester, sessionState: state);
      expect(container.read(orderPanelTabProvider), OrderPanelTab.products);
      expect(find.text('Caja no disponible'), findsOneWidget);
      await cleanUp(tester);
    });
  }

  testWidgets('cashier with open session enters confirmed sale payment', (
    tester,
  ) async {
    final container = await invoke(tester);
    expect(container.read(orderPanelTabProvider), OrderPanelTab.payments);
    await cleanUp(tester);
  });

  testWidgets('cashier cannot use an open session owned by another user', (
    tester,
  ) async {
    final container = await invoke(tester, sessionUserId: 99);
    expect(container.read(orderPanelTabProvider), OrderPanelTab.products);
    expect(find.text('Caja no disponible'), findsOneWidget);
    await cleanUp(tester);
  });

  for (final group in [
    OdooUserGroup.collectionManager,
    OdooUserGroup.systemAdministrator,
  ]) {
    testWidgets('native session bypass is preserved for $group', (
      tester,
    ) async {
      final container = await invoke(
        tester,
        user: _cashier.copyWith(permissions: [group]),
        sessionState: null,
      );
      expect(container.read(orderPanelTabProvider), OrderPanelTab.payments);
      await cleanUp(tester);
    });
  }

  testWidgets('account manager alone cannot bypass a missing cash session', (
    tester,
  ) async {
    final container = await invoke(
      tester,
      user: _cashier.copyWith(permissions: [OdooUserGroup.accountManager]),
      sessionState: null,
    );
    expect(container.read(orderPanelTabProvider), OrderPanelTab.products);
    await cleanUp(tester);
  });

  testWidgets('cashier must select a sale before entering payment', (
    tester,
  ) async {
    final container = await invoke(tester, orderState: null);
    expect(container.read(orderPanelTabProvider), OrderPanelTab.products);
    expect(find.text('Selecciona una venta'), findsOneWidget);
    await cleanUp(tester);
  });

  for (final state in [
    SaleOrderState.waitingApproval,
    SaleOrderState.rejected,
    SaleOrderState.cancel,
  ]) {
    testWidgets('cashier cannot enter payment for sale $state', (tester) async {
      final container = await invoke(tester, orderState: state);
      expect(container.read(orderPanelTabProvider), OrderPanelTab.products);
      expect(find.text('Venta pendiente de confirmar'), findsOneWidget);
      await cleanUp(tester);
    });
  }
}
