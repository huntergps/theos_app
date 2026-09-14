import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/auth/route_access_policy.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// `/envases/saldo-terceros` is gated by `envases_custodia`, NOT the generic
/// `envases_read` that the rest of `/envases/*` requires — a custodian
/// without the basic Envases group must still reach it, and a plain Envases
/// user must not. The specific rule has to sit ABOVE the generic
/// `/envases/` prefix in `RouteAccessPolicy.allows`, or it is dead code.
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

  bool allows(String path, List<String> permissions) => policy.allows(
    path,
    authenticated: true,
    capabilities: capabilities(permissions),
  );

  test('envases_custodia alone reaches Saldo por tercero', () {
    expect(
      allows('/envases/saldo-terceros', const ['envases_custodia']),
      isTrue,
    );
  });

  test('envases_read alone does NOT reach Saldo por tercero', () {
    expect(
      allows('/envases/saldo-terceros', const ['envases_read']),
      isFalse,
    );
  });

  test('a custodian without envases_read still reaches the screen', () {
    // The whole point of the separate group: someone can have
    // group_envases_custodia without group_envases_user.
    expect(
      allows('/envases/saldo-terceros', const ['envases_custodia']),
      isTrue,
    );
    expect(allows('/envases/saldo-terceros', const []), isFalse);
  });
}
