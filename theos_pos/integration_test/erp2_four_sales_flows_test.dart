import 'package:integration_test/integration_test.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:theos_pos/core/database/providers.dart';
import 'package:theos_pos/routes/app_routes.dart';
import 'package:theos_pos/features/sales/providers/sale_order_tabs_provider.dart';
import 'package:theos_pos/features/sales/screens/fast_sale/widgets/pos_payment_providers.dart';
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
    final driver = await _authenticatedDriver(
      tester,
      configuration,
      stage: 'seller',
    );
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
  }, skip: !configuration.canRun || erp2FlowStage() != 'seller');

  testWidgets('ERP2 crédito puro fixture exposes approval preconditions', (
    tester,
  ) async {
    final ids = Erp2SalesFlowIds.fromEnvironment();
    final driver = await _authenticatedDriver(
      tester,
      configuration,
      stage: 'seller',
    );
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
    final amount = await _readOrderTotal(client, ids.credit);
    await _confirmOrderThroughUi(tester, driver, ids.credit);
    final confirmed = await _waitForOrder(
      tester,
      client,
      ids.credit,
      (row) => row['state'] == 'sale' && row['locked'] == true,
    );
    expect(confirmed['invoice_ids'], hasLength(1));
    await _assertPostedInvoices(client, confirmed, expectedTotal: amount);
    expect(confirmed['picking_ids'], isNotEmpty);
  }, skip: !configuration.canRun || erp2FlowStage() != 'seller');

  testWidgets('ERP2 mixto fixture keeps both payment-term flags', (
    tester,
  ) async {
    final ids = Erp2SalesFlowIds.fromEnvironment();
    final driver = await _authenticatedDriver(
      tester,
      configuration,
      stage: 'seller',
    );
    addTearDown(driver.dispose);
    final order = await readErp2SaleOrder(saleOrderManager.client, ids.mixed);
    assertErp2FixtureTag(order, 'mixed');
    expect(order['is_cash'], isTrue);
    expect(order['is_credit'], isTrue);
    expect(order['state'], 'approved');
    expect(order['locked'], isFalse);
    expect(order['invoice_ids'], isEmpty);
    final client = saleOrderManager.client;
    final amount = await _readOrderTotal(client, ids.mixed);
    await _confirmOrderThroughUi(tester, driver, ids.mixed);
    final confirmed = await _waitForOrder(
      tester,
      client,
      ids.mixed,
      (row) => row['state'] == 'sale' && row['locked'] == true,
    );
    expect(confirmed['invoice_ids'], hasLength(1));
    await _assertPostedInvoices(client, confirmed, expectedTotal: amount);
    expect(confirmed['picking_ids'], isEmpty);
  }, skip: !configuration.canRun || erp2FlowStage() != 'seller');

  testWidgets('ERP2 facturar sin cobro fixture is cash and invoice-free', (
    tester,
  ) async {
    final ids = Erp2SalesFlowIds.fromEnvironment();
    final driver = await _authenticatedDriver(
      tester,
      configuration,
      stage: 'approver',
    );
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

    final approvalId = Erp2SalesFlowIds.optional('THEOS_E2E_FSC_APPROVAL_ID');
    if (approvalId == null) {
      throw StateError('THEOS_E2E_FSC_APPROVAL_ID is required for FSC stage.');
    }
    expect(configuration.expectedUserId, isNotNull);
    final requests = await saleOrderManager.client.searchRead(
      model: 'approval.request',
      domain: [
        ['id', '=', approvalId],
      ],
      fields: ['id', 'sale_order_id', 'request_status'],
      limit: 1,
    );
    expect(requests, hasLength(1));
    expect(many2oneId(requests.single['sale_order_id']), ids.facturarSinCobro);
    expect(requests.single['request_status'], anyOf('new', 'pending'));

    final amount = await _readOrderTotal(
      saleOrderManager.client,
      ids.facturarSinCobro,
    );
    await saleOrderManager.client.call(
      model: 'sale.order',
      method: 'action_l10n_ec_aprobar_fsc',
      ids: [ids.facturarSinCobro],
    );
    final completed = await _waitForOrder(
      tester,
      saleOrderManager.client,
      ids.facturarSinCobro,
      (row) =>
          row['invoice_ids'] is List &&
          (row['invoice_ids'] as List).isNotEmpty &&
          row['picking_ids'] is List &&
          (row['picking_ids'] as List).isNotEmpty,
    );
    expect(completed['exige_pago_total_entrega'], isTrue);
    expect(completed['invoice_ids'], hasLength(1));
    await _assertPostedInvoices(
      saleOrderManager.client,
      completed,
      expectedTotal: amount,
    );
  }, skip: !configuration.canRun || erp2FlowStage() != 'approver');

  testWidgets('ERP2 cajera cobra contado through the native payment UI', (
    tester,
  ) async {
    final ids = Erp2SalesFlowIds.fromEnvironment();
    final sessionId = Erp2SalesFlowIds.optional('THEOS_E2E_CASH_SESSION_ID');
    final journalId = Erp2SalesFlowIds.optional('THEOS_E2E_CASH_JOURNAL_ID');
    final methodId = Erp2SalesFlowIds.optional('THEOS_E2E_CASH_METHOD_ID');
    if (sessionId == null || journalId == null || methodId == null) {
      throw StateError(
        'Cashier stage requires THEOS_E2E_CASH_SESSION_ID, '
        'THEOS_E2E_CASH_JOURNAL_ID and THEOS_E2E_CASH_METHOD_ID.',
      );
    }
    final driver = await _authenticatedDriver(
      tester,
      configuration,
      stage: 'cashier',
    );
    addTearDown(driver.dispose);
    final client = saleOrderManager.client;
    final currentSession = await driver.container
        .read(currentSessionProvider.notifier)
        .ensureLoaded();
    expect(currentSession, isNotNull);
    expect(currentSession!.id, sessionId);
    expect(currentSession.userId, 23);

    final journals = await driver.container.read(
      posAvailableJournalsProvider.future,
    );
    final selectedJournal = journals.singleWhere(
      (journal) => journal.id == journalId,
      orElse: () => throw StateError(
        'Configured journal $journalId is unavailable in session $sessionId.',
      ),
    );
    final selectedMethod = selectedJournal.paymentMethods.singleWhere(
      (method) => method.id == methodId,
      orElse: () => throw StateError(
        'Configured method $methodId is unavailable in journal $journalId.',
      ),
    );
    final before = await readErp2SaleOrder(client, ids.cash);
    assertErp2FixtureTag(before, 'cash');
    expect(before['state'], 'sale');
    expect(before['locked'], isTrue);
    expect(before['invoice_ids'], isEmpty);
    final beforePayments = await _readSalePayments(client, ids.cash);
    final beforePaymentIds = beforePayments
        .map((payment) => payment['id'] as int)
        .toSet();

    await _openOrder(tester, driver, ids.cash);
    await tester.tap(find.text('Pagos').last);
    await tester.pumpAndSettle();
    final addPayment = find.widgetWithText(FilledButton, 'Agregar');
    expect(addPayment, findsOneWidget);
    await tester.tap(addPayment);
    await tester.pumpAndSettle();
    await _selectPaymentFixture(tester, selectedJournal, selectedMethod);
    final amountBox = find.descendant(
      of: find.widgetWithText(InfoLabel, 'Monto a pagar'),
      matching: find.byType(TextBox),
    );
    expect(amountBox, findsOneWidget);
    final amount = await _readOrderTotal(client, ids.cash);
    await tester.enterText(amountBox, amount.toStringAsFixed(2));
    final sessionBeforePayment = driver.container.read(currentSessionProvider);
    expect(sessionBeforePayment?.id, sessionId);
    expect(sessionBeforePayment?.userId, 23);
    await tester.tap(find.text('Abonar Pago'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar y Facturar').last);
    await tester.pumpAndSettle();
    final after = await _waitForOrder(
      tester,
      client,
      ids.cash,
      (row) =>
          row['invoice_ids'] is List && (row['invoice_ids'] as List).isNotEmpty,
    );
    expect(after['picking_ids'], isNotEmpty);
    expect(after['invoice_ids'], hasLength(1));
    final payments = await _readSalePayments(client, ids.cash);
    expect(
      payments.map((payment) => payment['id'] as int).toSet(),
      containsAll(beforePaymentIds),
    );
    final newPayments = payments
        .where((payment) => !beforePaymentIds.contains(payment['id']))
        .toList(growable: false);
    expect(newPayments, hasLength(1));
    final payment = newPayments.single;
    expect((payment['amount'] as num).toDouble(), closeTo(amount, 0.01));
    expect(payment['state'], 'posted');
    expect(many2oneId(payment['collection_session_id']), sessionId);
    expect(many2oneId(payment['journal_id']), journalId);
    expect(many2oneId(payment['payment_method_line_id']), methodId);
    expect(many2oneId(payment['move_id']), greaterThan(0));
    await _assertPostedInvoices(client, after, expectedTotal: amount);
  }, skip: !configuration.canRun || erp2FlowStage() != 'cashier');
}

Future<ReadOnlyAppDriver> _authenticatedDriver(
  WidgetTester tester,
  E2eConfiguration configuration, {
  required String stage,
}) async {
  final driver = ReadOnlyAppDriver(tester, configuration);
  await driver.launch();
  await driver.authenticateOrVerifyRestoredSession();
  expect(AppRouter.session.value.userId, configuration.expectedUserId);
  validateErp2StageActor(
    stage: stage,
    userId: AppRouter.session.value.userId,
    configuredApproverUserId: configuration.expectedUserId,
    permissions: AppRouter.session.value.permissions,
  );
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

Future<void> _selectPaymentFixture(
  WidgetTester tester,
  AvailableJournal journal,
  PaymentMethod method,
) async {
  final journalFinder = find.byType(ComboBox<AvailableJournal>);
  expect(journalFinder, findsOneWidget);
  var journalBox = tester.widget<ComboBox<AvailableJournal>>(journalFinder);
  if (journalBox.value?.id != journal.id) {
    await tester.tap(journalFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text(journal.name).last);
    await tester.pumpAndSettle();
    journalBox = tester.widget<ComboBox<AvailableJournal>>(journalFinder);
  }
  expect(journalBox.value?.id, journal.id);

  if (journal.paymentMethods.length == 1) {
    expect(journal.paymentMethods.single.id, method.id);
    return;
  }

  final methodFinder = find.byType(ComboBox<PaymentMethod>);
  expect(methodFinder, findsOneWidget);
  var methodBox = tester.widget<ComboBox<PaymentMethod>>(methodFinder);
  if (methodBox.value?.id != method.id) {
    await tester.tap(methodFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text(method.displayName).last);
    await tester.pumpAndSettle();
    methodBox = tester.widget<ComboBox<PaymentMethod>>(methodFinder);
  }
  expect(methodBox.value?.id, method.id);
}

Future<double> _readOrderTotal(OdooClient client, int orderId) async {
  final rows = await client.searchRead(
    model: 'sale.order',
    domain: [
      ['id', '=', orderId],
    ],
    fields: ['amount_total'],
    limit: 1,
  );
  return (rows.single['amount_total'] as num).toDouble();
}

Future<List<Map<String, dynamic>>> _readSalePayments(
  OdooClient client,
  int orderId,
) => client.searchRead(
  model: 'l10n_ec_collection_box.sale.order.payment',
  domain: [
    ['sale_id', '=', orderId],
  ],
  fields: [
    'id',
    'amount',
    'state',
    'move_id',
    'collection_session_id',
    'journal_id',
    'payment_method_line_id',
  ],
);

Future<void> _assertPostedInvoices(
  OdooClient client,
  Map<String, dynamic> order, {
  double? expectedTotal,
}) async {
  final invoiceIds = (order['invoice_ids'] as List)
      .map(many2oneId)
      .toList(growable: false);
  final invoices = await client.searchRead(
    model: 'account.move',
    domain: [
      ['id', 'in', invoiceIds],
    ],
    fields: [
      'id',
      'state',
      'move_type',
      'amount_total',
      'amount_residual',
      'payment_state',
    ],
  );
  expect(invoices, hasLength(invoiceIds.length));
  expect(invoices.every((row) => row['state'] == 'posted'), isTrue);
  expect(invoices.every((row) => row['move_type'] == 'out_invoice'), isTrue);
  for (final invoice in invoices) {
    final total = (invoice['amount_total'] as num).toDouble();
    final residual = (invoice['amount_residual'] as num).toDouble();
    expect(total, greaterThan(0));
    expect(residual, inInclusiveRange(0, total));
    if (residual.abs() <= 0.01) {
      expect(invoice['payment_state'], 'paid');
    } else if ((residual - total).abs() <= 0.01) {
      expect(invoice['payment_state'], 'not_paid');
    } else {
      expect(invoice['payment_state'], 'partial');
    }
  }
  if (expectedTotal != null) {
    expect(invoices, hasLength(1));
    final invoice = invoices.single;
    expect(
      (invoice['amount_total'] as num).toDouble(),
      closeTo(expectedTotal, 0.01),
    );
    expect((invoice['amount_residual'] as num).toDouble(), closeTo(0, 0.01));
    expect(invoice['payment_state'], 'paid');
  }
}
