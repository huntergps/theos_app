import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos/core/services/odoo_service.dart';
import 'package:theos_pos/features/sales/services/payment_line_persistence_service.dart';
import 'package:theos_pos/features/sales/services/payment_wizard_contract.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import '../../../mocks/mock_odoo_client.dart';

void main() {
  late AppDatabase database;
  late MockOdooClient client;
  late PaymentLinePersistenceService service;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    client = MockOdooClient.online();
    when(
      () => client.hasField(
        'l10n_ec_collection_box.sale.order.payment.wizard.line',
        'line_type',
      ),
    ).thenAnswer((_) async => true);
    service = PaymentLinePersistenceService(
      OdooService(client: client),
      null,
      database,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'ERP2 wizard omits absent discriminator and keeps bank and amount',
    () async {
      when(
        () => client.hasField(
          'l10n_ec_collection_box.sale.order.payment.wizard.line',
          'line_type',
        ),
      ).thenAnswer((_) async => false);
      final values = <String, dynamic>{
        'line_type': 'payment',
        'l10n_ec_bank_id': 9,
        'amount': 25.0,
      };
      final adapted = await adaptPaymentWizardCommands(client, [
        [0, 0, values],
      ]);
      expect((adapted.single as List)[2], {
        'l10n_ec_bank_id': 9,
        'amount': 25.0,
      });
      expect(values, containsPair('line_type', 'payment'));
    },
  );

  test(
    'failed wizard discovery does not guess that a field is absent',
    () async {
      when(
        () => client.hasField(
          'l10n_ec_collection_box.sale.order.payment.wizard.line',
          'line_type',
        ),
      ).thenThrow(const OdooConnectionException());
      await expectLater(
        adaptPaymentWizardCommands(client, [
          [
            0,
            0,
            {'line_type': 'payment'},
          ],
        ]),
        throwsA(isA<OdooConnectionException>()),
      );
    },
  );

  test('offline payload preserves custom bank identity without a version', () {
    final offlineService = PaymentLinePersistenceService(
      OdooService(),
      null,
      database,
    );
    final line = _paymentLine(amount: 20)
        .copyWith(bankId: 9, bankName: 'Banco Pruebas');
    final values = offlineService.applyBankFieldGuard({'bank_id': 99}, line);
    expect(values, containsPair('l10n_ec_bank_id', 9));
    expect(values, containsPair('bank_name_ec', 'Banco Pruebas'));
    expect(values, isNot(contains('bank_id')));
  });

  test('cash invoice uses canonical wizard and its recordset action', () async {
    when(
      () => client.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'create',
        ids: null,
        // ignore: deprecated_member_use
        args: null,
        kwargs: any(named: 'kwargs'),
      ),
    ).thenAnswer((_) async => 71);
    when(
      () => client.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'action_apply_and_create_invoice',
        ids: [71],
        // ignore: deprecated_member_use
        args: null,
        kwargs: null,
      ),
    ).thenAnswer(
      (_) async => {
        'type': 'ir.actions.act_window',
        'res_model': 'account.move',
        'res_id': 901,
      },
    );

    final result = await service.savePaymentLinesAndCreateInvoice(42, [
      _paymentLine(amount: 20),
    ], collectionSessionId: 8);

    expect(result?.invoiceId, 901);
    final invocation = verify(
      () => client.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'create',
        ids: null,
        // ignore: deprecated_member_use
        args: null,
        kwargs: captureAny(named: 'kwargs'),
      ),
    );
    final kwargs = invocation.captured.single as Map<String, dynamic>;
    final wizard = (kwargs['vals_list'] as List).single as Map;
    expect(wizard['sale_id'], 42);
    expect(wizard['collection_session_id'], 8);
    final command = (wizard['line_ids'] as List).single as List;
    final line = command[2] as Map<String, dynamic>;
    expect(line, containsPair('line_type', 'payment'));
    expect(line, containsPair('journal_id', 4));
    expect(line, containsPair('payment_method_line_id', 6));
    expect(line, isNot(contains('state')));
  });

  test('advance and card fields use the transient-line contract', () {
    final advance = PaymentLine.fromAdvance(
      date: DateTime.utc(2026, 8, 26),
      amount: 10,
      advanceId: 81,
      advanceName: 'ANTC/1',
      advanceAvailable: 10,
    );
    final card = PaymentLine(
      type: PaymentLineType.payment,
      date: DateTime.utc(2026, 8, 26),
      amount: 12,
      journalId: 4,
      paymentMethodLineId: 6,
      cardType: CardType.credit,
      cardBrandId: 7,
      cardDeadlineId: 8,
      bankId: 9,
      bankName: 'Banco Pruebas',
    );

    final advanceValues = service.toPaymentWizardLineValues(advance);
    expect(advanceValues, containsPair('advance_id', 81));
    expect(advanceValues, containsPair('line_type', 'advance'));
    final cardValues = service.toPaymentWizardLineValues(card);
    expect(cardValues, containsPair('card_type', 'credit'));
    expect(cardValues, containsPair('l10n_ec_bank_id', 9));
    expect(cardValues, containsPair('bank_name_ec', 'Banco Pruebas'));
  });

  test(
    'overpayment action is intermediate until cashier confirms it',
    () async {
      when(
        () => client.call(
          model: any(named: 'model'),
          method: 'create',
          ids: null,
          // ignore: deprecated_member_use
          args: null,
          kwargs: any(named: 'kwargs'),
        ),
      ).thenAnswer((invocation) async {
        return invocation.namedArguments[#model] ==
                'l10n_ec_collection_box.sale.order.payment.wizard'
            ? 71
            : 72;
      });
      when(
        () => client.call(
          model: 'l10n_ec_collection_box.sale.order.payment.wizard',
          method: 'action_apply_and_create_invoice',
          ids: [71],
          // ignore: deprecated_member_use
          args: null,
          kwargs: null,
        ),
      ).thenAnswer(
        (_) async => {
          'type': 'ir.actions.act_window',
          'res_model': 'l10n_ec_collection_box.confirm.advance.wizard',
          'context': {
            'default_payment_wizard_id': 71,
            'default_sale_id': 42,
            'default_overpayment_amount': 3.5,
          },
        },
      );
      when(
        () => client.call(
          model: 'l10n_ec_collection_box.confirm.advance.wizard',
          method: 'action_create_advance',
          ids: [72],
          // ignore: deprecated_member_use
          args: null,
          kwargs: null,
        ),
      ).thenAnswer(
        (_) async => {
          'type': 'ir.actions.act_window',
          'res_model': 'account.move',
          'res_id': 902,
        },
      );

      final pending = await service.savePaymentLinesAndCreateInvoice(42, [
        _paymentLine(amount: 23.5),
      ]);

      expect(pending?.requiresOverpaymentConfirmation, isTrue);
      expect(pending?.invoiceId, isNull);
      expect(pending?.overpaymentAmount, 3.5);

      final completed = await service.confirmOverpaymentAndCreateInvoice(
        pending!,
      );
      expect(completed.invoiceId, 902);
    },
  );

  test(
    'server business errors are not converted into offline success',
    () async {
      when(
        () => client.call(
          model: 'l10n_ec_collection_box.sale.order.payment.wizard',
          method: 'create',
          ids: null,
          // ignore: deprecated_member_use
          args: null,
          kwargs: any(named: 'kwargs'),
        ),
      ).thenThrow(OdooValidationException('Pago insuficiente'));

      await expectLater(
        service.savePaymentLinesAndCreateInvoice(51, [
          _paymentLine(amount: 20),
        ]),
        throwsA(isA<OdooValidationException>()),
      );
    },
  );

  test(
    'connection failures return null for the explicit offline flow',
    () async {
      when(
        () => client.call(
          model: 'l10n_ec_collection_box.sale.order.payment.wizard',
          method: 'create',
          ids: null,
          // ignore: deprecated_member_use
          args: null,
          kwargs: any(named: 'kwargs'),
        ),
      ).thenThrow(const OdooConnectionException());

      final result = await service.savePaymentLinesAndCreateInvoice(52, [
        _paymentLine(amount: 20),
      ]);
      expect(result, isNull);
    },
  );

  test('saving payment lines queues only connectivity failures', () async {
    final queue = OfflineQueueDataSource(database);
    final queuedService = PaymentLinePersistenceService(
      OdooService(client: client),
      queue,
      database,
    );
    when(
      () => client.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'create',
        ids: null,
        // ignore: deprecated_member_use
        args: null,
        kwargs: any(named: 'kwargs'),
      ),
    ).thenAnswer((_) async => 73);
    when(
      () => client.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'action_apply',
        ids: [73],
        // ignore: deprecated_member_use
        args: null,
        kwargs: null,
      ),
    ).thenThrow(const OdooConnectionException());

    final saved = await queuedService.savePaymentLines(61, [
      _paymentLine(amount: 15),
    ], collectionSessionId: 8);

    expect(saved, isTrue);
    final operations = await database.select(database.offlineQueue).get();
    expect(operations, hasLength(1));
    expect(
      operations.single.method,
      OfflineLocalCommand.paymentWizardApply.storageName,
    );
    expect(operations.single.commandVersion, 1);
    final values = jsonDecode(operations.single.values) as Map<String, dynamic>;
    final line = (values['line_ids'] as List).single as Map<String, dynamic>;
    expect(line, containsPair('line_type', 'payment'));
    expect(line, isNot(contains('state')));
  });

  test(
    'saving payment lines does not queue a server validation error',
    () async {
      final queue = OfflineQueueDataSource(database);
      final queuedService = PaymentLinePersistenceService(
        OdooService(client: client),
        queue,
        database,
      );
      when(
        () => client.call(
          model: 'l10n_ec_collection_box.sale.order.payment.wizard',
          method: 'create',
          ids: null,
          // ignore: deprecated_member_use
          args: null,
          kwargs: any(named: 'kwargs'),
        ),
      ).thenAnswer((_) async => 74);
      when(
        () => client.call(
          model: 'l10n_ec_collection_box.sale.order.payment.wizard',
          method: 'action_apply',
          ids: [74],
          // ignore: deprecated_member_use
          args: null,
          kwargs: null,
        ),
      ).thenThrow(OdooValidationException('El anticipo no está disponible'));

      final saved = await queuedService.savePaymentLines(62, [
        _paymentLine(amount: 15),
      ]);

      expect(saved, isFalse);
      expect(await database.select(database.offlineQueue).get(), isEmpty);
    },
  );
}

PaymentLine _paymentLine({required double amount}) {
  return PaymentLine(
    lineUuid: 'payment-test',
    type: PaymentLineType.payment,
    date: DateTime.utc(2026, 8, 26),
    amount: amount,
    journalId: 4,
    paymentMethodLineId: 6,
  );
}
