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
    // 'reports' rides along with 'seller': the document viewer it gates
    // only ever renders sale-side documents, so it is derived from the same
    // group as Ventas itself (see CapabilityProvisioner), not an
    // independent one.
    expect(snapshot.permissions, {'seller', 'reports'});
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

  test('only real administrator groups materialize synchronization access', () {
    final administrator = CapabilityProvisioner.materialize(
      scopeKey: 'erp2-administrator',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime.utc(2026, 9, 8),
      allGroupIds: [50],
      externalIds: {50: 'base.group_system'},
      hasGroup: (_) => true,
    );
    final seller = CapabilityProvisioner.materialize(
      scopeKey: 'erp2-seller',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime.utc(2026, 9, 8),
      allGroupIds: [51],
      externalIds: {51: 'sales_team.group_sale_salesman'},
      hasGroup: (_) => true,
    );

    expect(administrator.permissions, containsAll(['administrator', 'sync']));
    expect(seller.permissions, isNot(contains('administrator')));
    expect(seller.permissions, isNot(contains('sync')));
  });

  test('envases user group materializes envases_read capability', () {
    final snapshot = CapabilityProvisioner.materialize(
      scopeKey: 'erp2-envases-user',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime.utc(2026, 9, 11),
      allGroupIds: [60],
      externalIds: {60: 'l10n_ec_stock_envases.group_envases_user'},
      hasGroup: (_) => true,
    );

    expect(snapshot.permissions, contains('envases_read'));
  });

  test('envases manager group also materializes envases_read capability', () {
    final snapshot = CapabilityProvisioner.materialize(
      scopeKey: 'erp2-envases-manager',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime.utc(2026, 9, 11),
      allGroupIds: [61],
      externalIds: {61: 'l10n_ec_stock_envases.group_envases_manager'},
      hasGroup: (_) => true,
    );

    expect(snapshot.permissions, contains('envases_read'));
  });

  test(
    'hasGroup denying the envases group keeps envases_read closed even '
    'though the group is listed in externalIds',
    () {
      final snapshot = CapabilityProvisioner.materialize(
        scopeKey: 'erp2-envases-denied',
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime.utc(2026, 9, 11),
        allGroupIds: [62],
        externalIds: {62: 'l10n_ec_stock_envases.group_envases_user'},
        hasGroup: (_) => false,
      );

      expect(snapshot.permissions, isNot(contains('envases_read')));
    },
  );

  test(
    'a real internal user materializes the personal-diagnostic '
    'capabilities, never the sales-facing reports capability by itself',
    () {
      final snapshot = CapabilityProvisioner.materialize(
        scopeKey: 'erp2-internal-user',
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime.utc(2026, 9, 11),
        allGroupIds: [63],
        externalIds: {63: 'base.group_user'},
        hasGroup: (_) => true,
      );

      expect(snapshot.permissions, containsAll(['activities', 'notifications']));
      expect(snapshot.permissions, isNot(contains('reports')));
    },
  );

  test(
    'hasGroup denying base.group_user keeps activities and notifications '
    'closed while a sibling capability from another group still comes '
    'through',
    () {
      final snapshot = CapabilityProvisioner.materialize(
        scopeKey: 'erp2-not-internal-user',
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime.utc(2026, 9, 11),
        allGroupIds: [64, 65],
        externalIds: {
          64: 'base.group_user',
          65: 'sales_team.group_sale_salesman',
        },
        hasGroup: (externalId) => externalId != 'base.group_user',
      );

      expect(snapshot.permissions, isNot(contains('activities')));
      expect(snapshot.permissions, isNot(contains('notifications')));
      expect(snapshot.permissions, contains('seller'));
    },
  );

  test('seller and cashier groups both materialize the reports capability', () {
    final seller = CapabilityProvisioner.materialize(
      scopeKey: 'erp2-reports-seller',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime.utc(2026, 9, 11),
      allGroupIds: [66],
      externalIds: {66: 'sales_team.group_sale_salesman'},
      hasGroup: (_) => true,
    );
    final cashier = CapabilityProvisioner.materialize(
      scopeKey: 'erp2-reports-cashier',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime.utc(2026, 9, 11),
      allGroupIds: [67],
      externalIds: {67: 'l10n_ec_collection_box.group_collection_user'},
      hasGroup: (_) => true,
    );

    expect(seller.permissions, contains('reports'));
    expect(cashier.permissions, contains('reports'));
  });

  test(
    'a warehouse-only group does not materialize the reports capability',
    () {
      final snapshot = CapabilityProvisioner.materialize(
        scopeKey: 'erp2-reports-warehouse-only',
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime.utc(2026, 9, 11),
        allGroupIds: [68],
        externalIds: {68: 'stock.group_stock_user'},
        hasGroup: (_) => true,
      );

      expect(snapshot.permissions, isNot(contains('reports')));
    },
  );

  test(
    'hasGroup denying seller and cashier groups keeps reports closed even '
    'though both groups are listed in externalIds',
    () {
      final snapshot = CapabilityProvisioner.materialize(
        scopeKey: 'erp2-reports-denied',
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime.utc(2026, 9, 11),
        allGroupIds: [69, 70],
        externalIds: {
          69: 'sales_team.group_sale_salesman',
          70: 'l10n_ec_collection_box.group_collection_user',
        },
        hasGroup: (_) => false,
      );

      expect(snapshot.permissions, isNot(contains('reports')));
      expect(snapshot.permissions, isNot(contains('seller')));
      expect(snapshot.permissions, isNot(contains('cashier')));
    },
  );

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
