import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import 'support/e2e_configuration.dart';
import 'support/environment_reader.dart';
import 'support/read_only_app_driver.dart';

import 'package:theos_pos/routes/app_routes.dart';

import 'package:theos_pos/core/database/repositories/repository_providers.dart';
import 'package:theos_pos/features/sales/providers/sale_order_tabs_provider.dart';
import 'package:theos_pos/features/sales/repositories/sales_repository.dart';
import 'package:theos_pos/features/sales/screens/sale_order_form/form_header.dart';

const _cashOrderDefine = String.fromEnvironment('THEOS_E2E_CASH_ORDER_ID');
const _creditOrderDefine = String.fromEnvironment('THEOS_E2E_CREDIT_ORDER_ID');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final configuration = E2eConfiguration.fromEnvironment(businessJourney: true);

  testWidgets(
    'ERP2 business approval journey uses real UI and verifies server state',
    (tester) async {
      final cashOrderId = _requiredId(
        'THEOS_E2E_CASH_ORDER_ID',
        _cashOrderDefine,
      );
      final creditOrderId = _requiredId(
        'THEOS_E2E_CREDIT_ORDER_ID',
        _creditOrderDefine,
      );
      expect(configuration.allowWrites, isTrue);
      expect(configuration.expectedUserId, 43);

      final driver = ReadOnlyAppDriver(tester, configuration);
      addTearDown(driver.dispose);
      await driver.launch();
      await driver.authenticateOrVerifyRestoredSession();
      expect(AppRouter.session.value.userId, 43);

      final client = saleOrderManager.client;
      final cashBefore = await _readOrder(client, cashOrderId);
      final creditBefore = await _readOrder(client, creditOrderId);
      _assertFixture(cashBefore, cashOrderId, requireDraft: true);
      _assertFixture(creditBefore, creditOrderId, requireDraft: false);
      expect(creditBefore['state'], 'approved');
      expect(cashBefore['locked'], isFalse);
      expect(creditBefore['locked'], isFalse);

      await _openOrder(tester, driver, cashOrderId);
      await _tapConfirm(tester);
      await _pumpUntil(tester, find.text('Venta confirmada'));
      final cashAfter = await _readOrder(client, cashOrderId);
      expect(cashAfter['locked'], isTrue);
      expect(cashAfter['approval_count'], 0);
      expect(cashAfter['invoice_ids'], isEmpty);
      expect(cashAfter['picking_ids'], isEmpty);

      await _openOrder(tester, driver, creditOrderId);
      await _tapConfirm(tester);
      await _pumpUntil(tester, find.text('Solicitar aprobación'));
      expect(find.text('Solicitar aprobación'), findsWidgets);
      await tester.tap(find.text('Solicitar aprobación').last);
      await _pumpUntil(tester, find.text('Solicitud enviada'));

      final creditAfter = await _readOrder(client, creditOrderId);
      expect(creditAfter['state'], 'waiting');
      final requests = await client.searchRead(
        model: 'approval.request',
        domain: [
          ['sale_order_id', '=', creditOrderId],
          ['approval_type', '=', 'credit'],
          [
            'request_status',
            'in',
            ['new', 'pending'],
          ],
        ],
        fields: ['id', 'request_status', 'sale_order_id'],
        limit: 5,
      );
      expect(requests, isNotEmpty);
      expect(
        requests.any(
          (row) => row['sale_order_id'] is List
              ? (row['sale_order_id'] as List).first == creditOrderId
              : row['sale_order_id'] == creditOrderId,
        ),
        isTrue,
      );
    },
    skip: !configuration.canRun,
  );
}

int _requiredId(String name, String defineValue) {
  final raw = readProcessEnvironment(name) ?? defineValue;
  final id = int.tryParse(raw.trim());
  if (id == null || id <= 0) {
    throw StateError(
      '$name must be a positive integer when business E2E runs.',
    );
  }
  return id;
}

Future<Map<String, dynamic>> _readOrder(OdooClient client, int orderId) async {
  final rows = await client.searchRead(
    model: 'sale.order',
    domain: [
      ['id', '=', orderId],
    ],
    fields: [
      'client_order_ref',
      'user_id',
      'state',
      'locked',
      'approval_count',
      'invoice_ids',
      'picking_ids',
    ],
    limit: 1,
  );
  if (rows.length != 1) throw StateError('Fixture order was not found.');
  return rows.single;
}

void _assertFixture(
  Map<String, dynamic> row,
  int orderId, {
  required bool requireDraft,
}) {
  final reference = row['client_order_ref'];
  expect(reference, isA<String>());
  expect(
    (reference as String).startsWith('THEOS-E2E-APPROVAL-20260905-'),
    isTrue,
  );
  expect(
    row['user_id'] is List ? (row['user_id'] as List).first : row['user_id'],
    43,
  );
  if (requireDraft) expect(row['state'], 'draft');
}

Future<void> _openOrder(
  WidgetTester tester,
  ReadOnlyAppDriver driver,
  int orderId,
) async {
  final repository = driver.container.read(salesRepositoryProvider);
  if (repository == null) throw StateError('Sales repository unavailable.');
  final (order, _) = await repository.getWithLines(orderId, forceRefresh: true);
  if (order == null) throw StateError('Could not warm order cache.');
  appRouter.go(AppRouter.sales);
  await tester.pumpAndSettle(const Duration(seconds: 2));
  driver.container
      .read(saleOrderTabsProvider.notifier)
      .openOrder(orderId, order.name);
  await _pumpUntil(tester, find.byType(SaleOrderFormHeader));
}

Future<void> _tapConfirm(WidgetTester tester) async {
  await tester.tap(find.text('Confirmar Venta').last);
  await tester.pumpAndSettle();
  final yes = find.text('Sí');
  if (yes.evaluate().isNotEmpty) {
    await tester.tap(yes.last);
  }
  await tester.pumpAndSettle();
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
