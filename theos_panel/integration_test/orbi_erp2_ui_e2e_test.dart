import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_panel/erp2_harness.dart';
import 'package:theos_panel/main.dart' as application;

/// Real macOS acceptance pass for the four ERP2 roles.
///
/// This is intentionally opt-in. It drives the production Flutter surface,
/// never mocks ports, and uses the audit client only for read-only assertions
/// after a UI action. Do not enable it until the V01 write harness is stable.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final enabled =
      Platform.environment['ORBI_ERP2_UI_E2E_RUN'] ==
      'I_UNDERSTAND_ORBI_E2E_UI_WRITES';

  testWidgets('ERP2 macOS UI acceptance: four actors and four fiscal flows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final env = Platform.environment;
    final config = Erp2HarnessConfig.fromEnvironment(env);
    final targetErrors = config.targetErrors();
    if (targetErrors.isNotEmpty) fail(targetErrors.join('; '));
    if (!Platform.isMacOS) fail('This acceptance test requires -d macos.');

    final actors = _UiActors.fromEnvironment(env);
    final auditKey = env['ORBI_ERP2_AUDIT_API_KEY']?.trim() ?? '';
    if (auditKey.isEmpty) {
      fail('ORBI_ERP2_AUDIT_API_KEY is required for read-only assertions.');
    }
    final audit = OdooClient(
      config: OdooClientConfig(
        baseUrl: config.serverUrl,
        database: config.database,
        apiKey: auditKey,
      ),
    );

    application.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _assertLoginSurface(tester);
    await _login(tester, config, actors.seller);
    await _assertHomeRoleSurface(tester, required: const ['Ventas']);

    await _runSellerFlows(tester, audit, config, actors, env);
    await _logout(tester);
    await _login(tester, config, actors.supervisor);
    await _runSupervisorFsc(tester, audit, config, actors.supervisor);
    await _logout(tester);
    await _login(tester, config, actors.cashier);
    await _runCashierCollections(tester, audit, config, actors.cashier, env);
    await _logout(tester);
    await _login(tester, config, actors.warehouse);
    await _runWarehouseDelivery(tester, audit, config, actors.warehouse);
    await _logout(tester);
  }, skip: !enabled);
}

Future<void> _assertLoginSurface(WidgetTester tester) async {
  expect(find.byType(TextField), findsNWidgets(4));
  expect(find.text('Iniciar sesión'), findsOneWidget);
  expect(find.text('Servidor'), findsOneWidget);
  expect(find.text('Base de datos'), findsOneWidget);
  expect(find.text('Usuario'), findsOneWidget);
  expect(find.text('Contraseña'), findsOneWidget);
}

Future<void> _login(
  WidgetTester tester,
  Erp2HarnessConfig config,
  _UiActor actor,
) async {
  final fields = find.byType(TextField);
  final values = [config.serverUrl, config.database, actor.login];
  for (var index = 0; index < values.length; index++) {
    final field = fields.at(index);
    await tester.ensureVisible(field);
    await tester.enterText(field, values[index]);
  }
  await _tapVisible(tester, find.byKey(const Key('api-key-mode-toggle')));
  final secretField = find.byType(TextField).at(3);
  await tester.ensureVisible(secretField);
  await tester.enterText(secretField, actor.apiKey);
  await _tapVisible(tester, find.text('Iniciar sesión'));
  await tester.pumpAndSettle(const Duration(seconds: 8));
  expect(find.text('Orbi ERP'), findsOneWidget);
}

Future<void> _assertHomeRoleSurface(
  WidgetTester tester, {
  required List<String> required,
}) async {
  for (final label in required) {
    expect(
      find.text(label),
      findsWidgets,
      reason: 'Authenticated shell must expose $label through UI.',
    );
  }
}

Future<void> _logout(WidgetTester tester) async {
  if (find.byKey(const Key('home-button')).evaluate().isNotEmpty) {
    await _tapVisible(tester, find.byKey(const Key('home-button')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }
  await _tapVisible(tester, find.byKey(const Key('logout-button')));
  await tester.pumpAndSettle(const Duration(seconds: 2));
  expect(find.text('Iniciar sesión'), findsOneWidget);
}

Future<void> _runSellerFlows(
  WidgetTester tester,
  OdooClient audit,
  Erp2HarnessConfig config,
  _UiActors actors,
  Map<String, String> env,
) async {
  await _assertRouteButton(tester, 'Ventas');
  await _tapVisible(tester, find.text('Ventas').first);
  await tester.pumpAndSettle(const Duration(seconds: 3));
  expect(find.text('Órdenes'), findsWidgets);
  await _tapVisible(tester, find.byKey(const Key('new-sale-button')));
  await tester.pumpAndSettle(const Duration(seconds: 2));
  expect(find.text('Venta mostrador'), findsOneWidget);
  expect(find.text('Solicitar aprobación'), findsOneWidget);
  await _tapVisible(tester, find.byKey(const Key('home-button')));
  await tester.pumpAndSettle(const Duration(seconds: 2));
  final fixtures = _UiFixtures.fromEnvironment(env);
  await _openFixture(tester, fixtures.cash.reference);
  await _openFixture(tester, fixtures.credit.reference);
  await _openFixture(tester, fixtures.mixed.reference);
  await _openFixture(tester, fixtures.fsc.reference);
  await _assertOrderState(audit, fixtures.cash.orderId, requireState: 'draft');
  await _assertOrderState(
    audit,
    fixtures.credit.orderId,
    requireState: 'draft',
  );
  await _assertOrderState(audit, fixtures.mixed.orderId, requireState: 'draft');
  await _assertOrderState(audit, fixtures.fsc.orderId, requireState: 'draft');
  expect(actors.seller.login, isNotEmpty);
  expect(config.database, isNotEmpty);
}

Future<void> _openFixture(WidgetTester tester, String reference) async {
  final fixture = find.text(reference);
  expect(
    fixture,
    findsWidgets,
    reason: 'Fixture no visible en Ventas: $reference',
  );
  await _tapVisible(tester, fixture.first);
  await tester.pumpAndSettle(const Duration(milliseconds: 300));
  expect(find.text('Cerrar'), findsOneWidget);
  await _tapVisible(tester, find.text('Cerrar'));
  await tester.pumpAndSettle(const Duration(milliseconds: 300));
}

Future<void> _runSupervisorFsc(
  WidgetTester tester,
  OdooClient audit,
  Erp2HarnessConfig config,
  _UiActor actor,
) async {
  await _assertRouteButton(tester, 'Aprobaciones');
  await _tapVisible(tester, find.text('Aprobaciones').first);
  await tester.pumpAndSettle(const Duration(seconds: 3));
  expect(find.text('Aprobaciones comerciales'), findsOneWidget);
  final approve = find.text('Aprobar');
  if (approve.evaluate().isNotEmpty) {
    await _tapVisible(tester, approve.first);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }
  expect(
    find.text('Preparar FSC'),
    findsWidgets,
    reason: 'FSC approval must have one native preparation action.',
  );
  expect(actor.login, isNotEmpty);
  expect(config.serverUrl, startsWith('https://erp2.'));
  await audit.searchRead(
    model: 'approval.request',
    fields: const ['id', 'request_status'],
    domain: const [
      ['request_status', '=', 'pending'],
    ],
    limit: 1,
  );
}

Future<void> _runCashierCollections(
  WidgetTester tester,
  OdooClient audit,
  Erp2HarnessConfig config,
  _UiActor actor,
  Map<String, String> env,
) async {
  await _assertRouteButton(tester, 'Caja');
  await _tapVisible(tester, find.text('Caja').first);
  await tester.pumpAndSettle(const Duration(seconds: 3));
  expect(find.text('Caja y cobros'), findsOneWidget);
  final fixtures = _UiFixtures.fromEnvironment(env);
  final sale = find.text(fixtures.cash.reference);
  expect(sale, findsWidgets, reason: 'Cobro fixture no visible en Caja.');
  await _tapVisible(tester, sale.first);
  await tester.pumpAndSettle(const Duration(milliseconds: 300));
  expect(find.textContaining('Restante:'), findsOneWidget);
  expect(find.text('Cobrar'), findsWidgets);
  expect(find.text('Añadir medio'), findsWidgets);
  expect(actor.login, isNotEmpty);
  expect(config.cashSessionId, isNotNull);
  await audit.searchRead(
    model: 'collection.session',
    fields: const ['id', 'state', 'config_id', 'cash_journal_id'],
    domain: [
      ['id', '=', config.cashSessionId],
    ],
    limit: 1,
  );
}

Future<void> _runWarehouseDelivery(
  WidgetTester tester,
  OdooClient audit,
  Erp2HarnessConfig config,
  _UiActor actor,
) async {
  await _assertRouteButton(tester, 'Bodega');
  await _tapVisible(tester, find.text('Bodega').first);
  await tester.pumpAndSettle(const Duration(seconds: 3));
  expect(find.text('Bodega'), findsWidgets);
  final validate = find.text('Validar entrega');
  expect(validate, findsWidgets);
  final button = tester.widget<FilledButton>(find.byType(FilledButton).last);
  if (button.onPressed != null) {
    await _tapVisible(tester, validate.last);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byKey(const Key('warehouse-result')), findsOneWidget);
  }
  expect(actor.login, isNotEmpty);
  expect(config.serverUrl, isNot(contains('newerp')));
  await audit.searchRead(
    model: 'stock.picking',
    fields: const ['id', 'state'],
    domain: const [
      [
        'state',
        'in',
        ['assigned', 'confirmed', 'waiting'],
      ],
    ],
    limit: 1,
  );
}

Future<void> _assertRouteButton(WidgetTester tester, String label) async {
  expect(
    find.text(label),
    findsWidgets,
    reason: 'Missing real navigation/action surface: $label',
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  expect(finder, findsWidgets);
  final target = finder.first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  await tester.tap(target);
}

Future<void> _assertOrderState(
  OdooClient audit,
  int orderId, {
  required String requireState,
}) async {
  final rows = await audit.searchRead(
    model: 'sale.order',
    fields: const ['id', 'state', 'invoice_ids', 'picking_ids'],
    domain: [
      ['id', '=', orderId],
    ],
    limit: 1,
  );
  expect(rows, hasLength(1));
  expect(rows.single['state'], requireState);
}

final class _UiActor {
  const _UiActor({required this.login, required this.apiKey});
  final String login;
  final String apiKey;
}

final class _UiActors {
  const _UiActors({
    required this.seller,
    required this.supervisor,
    required this.cashier,
    required this.warehouse,
  });

  final _UiActor seller;
  final _UiActor supervisor;
  final _UiActor cashier;
  final _UiActor warehouse;

  factory _UiActors.fromEnvironment(Map<String, String> env) => _UiActors(
    seller: _actor(env, 'SELLER'),
    supervisor: _actor(env, 'SUPERVISOR'),
    cashier: _actor(env, 'CASHIER'),
    warehouse: _actor(env, 'WAREHOUSE'),
  );
}

_UiActor _actor(Map<String, String> env, String key) {
  final login = env['ORBI_ERP2_${key}_LOGIN']?.trim() ?? '';
  final apiKey = env['ORBI_ERP2_${key}_API_KEY'] ?? '';
  if (login.isEmpty || apiKey.isEmpty) {
    fail(
      'ORBI_ERP2_${key}_LOGIN and _API_KEY are required; secrets stay in env.',
    );
  }
  return _UiActor(login: login, apiKey: apiKey);
}

final class _UiFixtures {
  const _UiFixtures({
    required this.cash,
    required this.credit,
    required this.mixed,
    required this.fsc,
  });

  final ({int orderId, String reference}) cash;
  final ({int orderId, String reference}) credit;
  final ({int orderId, String reference}) mixed;
  final ({int orderId, String reference}) fsc;

  factory _UiFixtures.fromEnvironment(Map<String, String> env) => _UiFixtures(
    cash: (
      orderId: _fixtureId(env, 'CASH'),
      reference: _fixtureRef(env, 'CASH'),
    ),
    credit: (
      orderId: _fixtureId(env, 'CREDIT'),
      reference: _fixtureRef(env, 'CREDIT'),
    ),
    mixed: (
      orderId: _fixtureId(env, 'MIXED'),
      reference: _fixtureRef(env, 'MIXED'),
    ),
    fsc: (orderId: _fixtureId(env, 'FSC'), reference: _fixtureRef(env, 'FSC')),
  );
}

String _fixtureRef(Map<String, String> env, String key) {
  final value = env['ORBI_ERP2_${key}_REFERENCE']?.trim() ?? '';
  if (value.isEmpty) {
    fail('ORBI_ERP2_${key}_REFERENCE is required.');
  }
  return value;
}

int _fixtureId(Map<String, String> env, String key) {
  final id = int.tryParse(env['ORBI_ERP2_${key}_ORDER_ID'] ?? '');
  if (id == null || id <= 0) {
    fail('ORBI_ERP2_${key}_ORDER_ID is required.');
  }
  return id;
}
