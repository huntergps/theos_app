import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:theos_pos/routes/app_routes.dart';
import 'package:theos_pos/features/sales/providers/sale_order_tabs_provider.dart';
import 'package:theos_pos/features/sales/screens/sale_order_form/form_header.dart';

import 'support/e2e_configuration.dart';
import 'support/erp2_sales_flow_support.dart';
import 'support/read_only_app_driver.dart';

/// ERP2 fixture contract for the four distinct journeys.  The test is
/// intentionally opt-in and starts by reading server state independently of
/// any UI result; root can add the write stages once the fixture is assigned.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final configuration = E2eConfiguration.fromEnvironment(businessJourney: true);

  testWidgets('ERP2 contado fixture is classified and locked contractually', (
    tester,
  ) async {
    final ids = Erp2SalesFlowIds.fromEnvironment();
    final driver = await _authenticatedDriver(tester, configuration);
    addTearDown(driver.dispose);
    final client = saleOrderManager.client;
    final order = await readErp2SaleOrder(client, ids.cash);
    assertErp2FixtureTag(order, 'cash');
    expect(order['is_cash'], isTrue);
    expect(order['is_credit'], isFalse);
    expect(order['state'], 'draft');
    expect(order['invoice_ids'], isEmpty);
    expect(order['picking_ids'], isEmpty);

    await _confirmOrderThroughUi(tester, driver, ids.cash);
    await _waitForOrder(
      tester,
      client,
      ids.cash,
      (row) => row['state'] == 'sale' && row['locked'] == true,
    );
    final confirmed = await readErp2SaleOrder(client, ids.cash);
    expect(confirmed['invoice_ids'], isEmpty);
    expect(confirmed['picking_ids'], isEmpty);
    // The subsequent cash collection UI requires the fixture's journal and
    // method IDs; those are deliberately not guessed here and remain the
    // next ERP2 stage owned by the cashier fixture.
  }, skip: !configuration.canRun);

  testWidgets('ERP2 crédito puro fixture exposes approval preconditions', (
    tester,
  ) async {
    final ids = Erp2SalesFlowIds.fromEnvironment();
    final driver = await _authenticatedDriver(tester, configuration);
    addTearDown(driver.dispose);
    final order = await readErp2SaleOrder(saleOrderManager.client, ids.credit);
    assertErp2FixtureTag(order, 'credit');
    expect(order['is_cash'], isFalse);
    expect(order['is_credit'], isTrue);
    expect(order['state'], 'approved');
    expect(order['locked'], isFalse);
    expect(order['invoice_ids'], isEmpty);
    expect(order['picking_ids'], isEmpty);

    final client = saleOrderManager.client;
    await _confirmOrderThroughUi(tester, driver, ids.credit);
    final confirmed = await _waitForOrder(
      tester,
      client,
      ids.credit,
      (row) => row['state'] == 'sale' && row['locked'] == true,
    );
    expect(confirmed['invoice_ids'], isNotEmpty);
    expect(confirmed['picking_ids'], isNotEmpty);
  }, skip: !configuration.canRun);

  testWidgets('ERP2 mixto fixture keeps both payment-term flags', (
    tester,
  ) async {
    final ids = Erp2SalesFlowIds.fromEnvironment();
    final driver = await _authenticatedDriver(tester, configuration);
    addTearDown(driver.dispose);
    final order = await readErp2SaleOrder(saleOrderManager.client, ids.mixed);
    assertErp2FixtureTag(order, 'mixed');
    expect(order['is_cash'], isTrue);
    expect(order['is_credit'], isTrue);
    expect(order['state'], 'approved');
    expect(order['locked'], isFalse);
    expect(order['invoice_ids'], isEmpty);
    final client = saleOrderManager.client;
    await _confirmOrderThroughUi(tester, driver, ids.mixed);
    final confirmed = await _waitForOrder(
      tester,
      client,
      ids.mixed,
      (row) => row['state'] == 'sale' && row['locked'] == true,
    );
    expect(confirmed['invoice_ids'], isNotEmpty);
    expect(confirmed['picking_ids'], isEmpty);
  }, skip: !configuration.canRun);

  testWidgets('ERP2 facturar sin cobro fixture is cash and invoice-free', (
    tester,
  ) async {
    final ids = Erp2SalesFlowIds.fromEnvironment();
    final driver = await _authenticatedDriver(tester, configuration);
    addTearDown(driver.dispose);
    final order = await readErp2SaleOrder(
      saleOrderManager.client,
      ids.facturarSinCobro,
    );
    assertErp2FixtureTag(order, 'fsc');
    expect(order['is_cash'], isTrue);
    expect(order['is_credit'], isFalse);
    expect(order['invoice_ids'], isEmpty);
    expect(order['picking_ids'], isEmpty);
  }, skip: !configuration.canRun);
}

Future<ReadOnlyAppDriver> _authenticatedDriver(
  WidgetTester tester,
  E2eConfiguration configuration,
) async {
  final driver = ReadOnlyAppDriver(tester, configuration);
  await driver.launch();
  await driver.authenticateOrVerifyRestoredSession();
  expect(AppRouter.session.value.userId, configuration.expectedUserId);
  return driver;
}

Future<void> _openOrder(
  WidgetTester tester,
  ReadOnlyAppDriver driver,
  int orderId,
) async {
  final row = await readErp2SaleOrder(saleOrderManager.client, orderId);
  final orderName = row['name'] as String? ?? 'ERP2-$orderId';
  appRouter.go(AppRouter.sales);
  await tester.pumpAndSettle(const Duration(seconds: 2));
  driver.container
      .read(saleOrderTabsProvider.notifier)
      .openOrder(orderId, orderName);
  await _pumpUntil(tester, find.byType(SaleOrderFormHeader));
}

Future<void> _confirmOrderThroughUi(
  WidgetTester tester,
  ReadOnlyAppDriver driver,
  int orderId,
) async {
  await _openOrder(tester, driver, orderId);
  await tester.tap(find.text('Confirmar Venta').last);
  await tester.pumpAndSettle();
  final confirmation = find.text('Sí');
  if (confirmation.evaluate().isNotEmpty) {
    await tester.tap(confirmation.last);
  }
  await tester.pumpAndSettle();
}

Future<Map<String, dynamic>> _waitForOrder(
  WidgetTester tester,
  OdooClient client,
  int orderId,
  bool Function(Map<String, dynamic>) predicate,
) async {
  final deadline = DateTime.now().add(const Duration(minutes: 3));
  while (true) {
    final row = await readErp2SaleOrder(client, orderId);
    if (predicate(row)) return row;
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Timed out waiting for ERP2 order $orderId state.');
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(minutes: 3));
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Timed out waiting for $finder.');
    }
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
