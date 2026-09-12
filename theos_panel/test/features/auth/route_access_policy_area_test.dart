import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/auth/route_access_policy.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// A screen that belongs to an area but lives under its own route used to be
/// unreachable: the policy matched each area path exactly, so `/collection/hub`
/// fell through to the catch-all and the router sent the user home. The screen
/// existed, compiled and passed its own tests, and still nobody could open it.
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

  test('an area permission reaches the screens nested under that area', () {
    expect(allows('/collection', const ['cashier']), isTrue);
    expect(allows('/collection/hub', const ['cashier']), isTrue);
    expect(allows('/warehouse/stock', const ['warehouse']), isTrue);
    expect(allows('/envases/movements', const ['envases_read']), isTrue);
  });

  test('a nested screen stays closed without the area permission', () {
    expect(allows('/collection/hub', const ['seller']), isFalse);
    expect(allows('/warehouse/stock', const ['cashier']), isFalse);
    expect(allows('/envases/movements', const ['seller']), isFalse);
  });

  test('the area prefix does not leak into a different area', () {
    // '/collectionish' shares its opening characters with '/collection' but is
    // a different area, so the trailing slash in the check is load-bearing.
    expect(allows('/collectionish', const ['cashier']), isFalse);
    expect(allows('/warehouseish', const ['warehouse']), isFalse);
  });
}
