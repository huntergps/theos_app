import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:theos_pos/features/sync/repositories/partner_sync_repository.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import '../../../mocks/mock_odoo_client.dart';

void main() {
  late AppDatabase db;
  late MockOdooClient client;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    client = MockOdooClient.online();
    when(
      () => client.searchCount(
        model: 'res.partner',
        domain: any(named: 'domain'),
      ),
    ).thenAnswer((_) async => 1);
    when(
      () => client.searchRead(
        model: 'res.partner',
        domain: any(named: 'domain'),
        fields: any(named: 'fields'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        order: any(named: 'order'),
      ),
    ).thenAnswer((_) async => const <Map<String, dynamic>>[]);
  });

  tearDown(() => db.close());

  test('full partner sync reuses the generated ERP2 contract', () async {
    final repository = PartnerSyncRepository(db: db, odooClient: client);

    await repository.syncPartners();

    final captured =
        verify(
              () => client.searchRead(
                model: 'res.partner',
                domain: any(named: 'domain'),
                fields: captureAny(named: 'fields'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
                order: any(named: 'order'),
              ),
            ).captured.single
            as List<String>;
    expect(captured, orderedEquals(clientManager.odooFields));
    expect(captured, isNot(contains('unpaid_invoices_count')));
    expect(captured, isNot(contains('oldest_overdue_days')));
  });

  test('propagates a failed generic sync result to the coordinator', () async {
    when(
      () => client.searchCount(
        model: 'res.partner',
        domain: any(named: 'domain'),
      ),
    ).thenThrow(StateError('transport failed'));
    final repository = PartnerSyncRepository(db: db, odooClient: client);

    await expectLater(repository.syncPartners(), throwsStateError);
  });
}
