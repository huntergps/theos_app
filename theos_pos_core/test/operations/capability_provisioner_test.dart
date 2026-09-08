import 'package:test/test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:drift/native.dart';

void main() {
  test('materializes role capabilities only from effective groups', () {
    final snapshot = CapabilityProvisioner.materialize(
      scopeKey: 'scope',
      companyId: 2,
      revision: 3,
      fetchedAt: DateTime.utc(2026, 1, 1),
      allGroupIds: [1, 2],
      externalIds: {1: 'sales.seller', 2: 'sales.cashier'},
      hasGroup: (id) => id == 'sales.seller',
      offlineOperations: ['confirm'],
    );
    expect(snapshot.permissions, {'seller'});
    expect(snapshot.offlineOperations, {'confirm'});
  });

  test('materializes the real ERP2 seller and cashier XML IDs', () {
    final snapshot = CapabilityProvisioner.materialize(
      scopeKey: 'erp2-user',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime.utc(2026, 9, 7),
      allGroupIds: [10, 20],
      externalIds: {
        10: 'sales_team.group_sale_salesman_all_leads',
        20: 'l10n_ec_collection_box.group_collection_user',
      },
      hasGroup: (_) => true,
    );

    expect(
      snapshot.permissions,
      containsAll(['seller', 'cashier', 'view_all', 'orders.view_all']),
    );
  });

  test('collection manager is a cashier but not a commercial approver', () {
    final snapshot = CapabilityProvisioner.materialize(
      scopeKey: 'erp2-manager',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime.utc(2026, 9, 7),
      allGroupIds: [30],
      externalIds: {30: 'l10n_ec_collection_box.group_collection_manager'},
      hasGroup: (_) => true,
    );

    expect(snapshot.permissions, contains('cashier'));
    expect(snapshot.permissions, isNot(contains('approver')));
  });

  test('approval manager materializes approver capability', () {
    final snapshot = CapabilityProvisioner.materialize(
      scopeKey: 'erp2-approval-manager',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime.utc(2026, 9, 7),
      allGroupIds: [40],
      externalIds: {40: 'l10n_ec_sale_credit.group_credit_approver'},
      hasGroup: (_) => true,
    );

    expect(snapshot.permissions, contains('approver'));
  });

  test('snapshot cache is identity-bound and survives close/reopen', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = CapabilitySnapshotStore(db);
    final snapshot = CapabilitySnapshot(
      scopeKey: 'user:2/company:7',
      companyId: 7,
      revision: 4,
      fetchedAt: DateTime.utc(2026, 1, 1),
      permissions: ['seller'],
      offlineOperations: ['confirm'],
    );
    await store.save(snapshot.scopeKey, snapshot);
    expect((await store.read(snapshot.scopeKey, companyId: 7))!.revision, 4);
    expect(await store.read('user:3/company:7', companyId: 7), isNull);
    expect(await store.read(snapshot.scopeKey, companyId: 8), isNull);
  });
}
