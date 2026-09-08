import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/app/session_composition.dart';
import 'package:theos_panel/features/auth/route_access_policy.dart';

void main() {
  test('route policy keeps shell available without capabilities', () {
    const policy = RouteAccessPolicy();
    expect(policy.allows('/', authenticated: true, capabilities: null), isTrue);
    expect(
      policy.allows('/sales', authenticated: true, capabilities: null),
      isFalse,
    );
  });

  test('business menu permissions are capability based', () {
    final snapshot = CapabilitySnapshot(
      scopeKey: 'scope',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime(2026),
      permissions: const ['seller', 'notifications'],
    );
    const policy = RouteAccessPolicy();
    expect(
      policy.allows('/sales', authenticated: true, capabilities: snapshot),
      isTrue,
    );
    expect(
      policy.allows('/collection', authenticated: true, capabilities: snapshot),
      isFalse,
    );
    expect(
      policy.allows(
        '/notifications',
        authenticated: true,
        capabilities: snapshot,
      ),
      isTrue,
    );
  });

  test('default composition has no service masquerading as configured', () {
    const composition = OrbiSessionComposition();
    expect(composition.home, isNull);
    expect(composition.sync, isNull);
    expect(composition.notifications, isNull);
    expect(composition.documents, isNull);
    expect(composition.runtime, isNull);
  });
}
