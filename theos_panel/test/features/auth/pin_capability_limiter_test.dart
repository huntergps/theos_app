import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/auth/pin_capability_limiter.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  CapabilitySnapshot snapshotWith(
    List<String> permissions, {
    List<String> offlineOperations = const [],
    List<String> counterPolicies = const [],
  }) => CapabilitySnapshot(
    scopeKey: 'scope',
    companyId: 1,
    pointId: 9,
    revision: 3,
    fetchedAt: DateTime.utc(2026, 9, 11),
    permissions: permissions,
    offlineOperations: offlineOperations,
    counterPolicies: counterPolicies,
  );

  group('snapshotAllowsSellerPin', () {
    test('a seller-only account may use PIN', () {
      expect(snapshotAllowsSellerPin(snapshotWith(const ['seller'])), isTrue);
    });

    test('a cashier without the seller permission may not use PIN', () {
      expect(snapshotAllowsSellerPin(snapshotWith(const ['cashier'])), isFalse);
    });

    test('an empty snapshot may not use PIN', () {
      expect(snapshotAllowsSellerPin(snapshotWith(const [])), isFalse);
    });
  });

  group('restrictSnapshotToSellerPin', () {
    // The one rule the coordinator called non-negotiable: "Usuarios
    // multirrol ven capacidades conjuntas; modo PIN limita a vendedor
    // aunque tenga otros roles." — COORDINATOR_HANDOFF_2026_09_11.md.
    test(
      'a cashier-and-seller account entering by PIN keeps only seller',
      () {
        final full = snapshotWith(const ['seller', 'cashier']);
        final restricted = restrictSnapshotToSellerPin(full);
        expect(restricted.permissions, {'seller'});
        expect(restricted.permissions.contains('cashier'), isFalse);
      },
    );

    test('approver, warehouse, administrator and sync are all dropped', () {
      final full = snapshotWith(const [
        'seller',
        'cashier',
        'approver',
        'warehouse',
        'administrator',
        'sync',
        'view_all',
        'orders.view_all',
      ]);
      final restricted = restrictSnapshotToSellerPin(full);
      expect(restricted.permissions, {'seller'});
    });

    test(
      'offlineOperations and counterPolicies are cleared, not filtered by '
      'name, because this layer has no catalogue of which ones are '
      'seller-safe',
      () {
        final full = snapshotWith(
          const ['seller', 'cashier'],
          offlineOperations: const ['sale.confirm', 'collection.pay'],
          counterPolicies: const ['collection_box.default'],
        );
        final restricted = restrictSnapshotToSellerPin(full);
        expect(restricted.offlineOperations, isEmpty);
        expect(restricted.counterPolicies, isEmpty);
      },
    );

    test('identity fields (scope, company, point, revision) pass through', () {
      final full = snapshotWith(const ['seller']);
      final restricted = restrictSnapshotToSellerPin(full);
      expect(restricted.scopeKey, full.scopeKey);
      expect(restricted.companyId, full.companyId);
      expect(restricted.pointId, full.pointId);
      expect(restricted.revision, full.revision);
      expect(restricted.fetchedAt, full.fetchedAt);
    });

    test('a non-seller account is restricted to an empty permission set', () {
      final full = snapshotWith(const ['cashier', 'administrator']);
      final restricted = restrictSnapshotToSellerPin(full);
      expect(restricted.permissions, isEmpty);
    });
  });
}
