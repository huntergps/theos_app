import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/auth/route_access_policy.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  final policy = const RouteAccessPolicy();

  CapabilitySnapshot capabilities(List<String> permissions) =>
      CapabilitySnapshot(
        scopeKey: 'scope',
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime(2026),
        permissions: permissions,
      );

  test('warehouse actor can enter warehouse but not cashier', () {
    final snapshot = capabilities(const ['warehouse']);
    expect(
      policy.allows('/warehouse', authenticated: true, capabilities: snapshot),
      isTrue,
    );
    expect(
      policy.allows('/collection', authenticated: true, capabilities: snapshot),
      isFalse,
    );
  });

  test('seller cannot enter warehouse', () {
    final snapshot = capabilities(const ['seller']);
    expect(
      policy.allows('/warehouse', authenticated: true, capabilities: snapshot),
      isFalse,
    );
  });
}
