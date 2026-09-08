import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

final class _PaymentReader implements Json2ReadPort {
  @override
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
  }) async => switch (model) {
    'account.card.brand' => const [
      {'id': 1, 'name': 'Visa', 'code': 'visa'},
    ],
    'account.card.deadline' => const [
      {'id': 2, 'name': '30 días', 'deadline_days': 30, 'percentage': 2.5},
    ],
    'account.card.lote' => const [
      {
        'id': 3,
        'name': 'Lote',
        'journal_id': [4, 'Banco'],
        'state': 'open',
      },
    ],
    'account.payment.method.line' => const [
      {
        'id': 5,
        'name': 'Tarjeta',
        'code': 'card_credit_in',
        'journal_id': [4, 'Banco'],
        'payment_method_id': [6, 'Electrónico'],
        'payment_type': 'inbound',
      },
    ],
    _ => const [],
  };
}

void main() {
  test('JSON-2 payment catalogs commit and survive physical reopen', () async {
    final dir = await Directory.systemTemp.createTemp('orbi-payment-catalog-');
    final path = '${dir.path}/payment.sqlite';
    final first = AppDatabase(NativeDatabase(File(path)));
    final owner = RuntimeDatabaseOwner(factory: (_) => first);
    final scope = AppScope(
      appId: 'panel',
      installationId: 'i',
      normalizedServerUrl: 'https://erp.test',
      database: 'db',
      userId: 2,
    );
    final database = await owner.open(scope);
    final composition = RuntimeCatalogComposition(
      activation: SessionActivation(database: database),
      owner: owner,
      reader: _PaymentReader(),
    );
    for (final key in const [
      'cardBrand',
      'cardDeadline',
      'cardLote',
      'paymentMethodLine',
    ]) {
      expect((await composition.sync(key)).status, SyncJobStatus.committed);
    }
    await owner.close();

    final second = AppDatabase(NativeDatabase(File(path)));
    addTearDown(() async {
      await second.close();
      await dir.delete(recursive: true);
    });
    expect(
      (await second.select(second.accountCreditCardBrand).get()).single.name,
      'Visa',
    );
    expect(
      (await second.select(second.accountCreditCardDeadline).get())
          .single
          .deadlineDays,
      30,
    );
    expect(
      (await second.select(second.accountCardLote).get()).single.odooId,
      3,
    );
    expect(
      (await second.select(second.accountPaymentMethodLine).get())
          .single
          .paymentMethodId,
      6,
    );
  });
}
