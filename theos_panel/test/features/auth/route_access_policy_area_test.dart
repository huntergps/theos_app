import 'dart:io';

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

  // /clients and /products are the same Ventas area as /sales, not routes
  // of their own — NAVIGATION_CAPABILITY_MATRIX.md groups "Órdenes/
  // cotizaciones; Mostrador; Clientes; Productos" in one row ("Ver:
  // Documentos, clientes y productos visibles"), and router.dart's sidebar
  // gives them the same `group: 'Ventas'` as /sales. They had no rule at
  // all until this was reported against a real Odoo: both fell through to
  // the default (only "/" and "/settings"), unreachable for any user.
  test('a seller or cashier reaches clients and products, same as sales', () {
    expect(allows('/clients', const ['seller']), isTrue);
    expect(allows('/products', const ['seller']), isTrue);
    expect(allows('/clients', const ['cashier']), isTrue);
    expect(allows('/products', const ['cashier']), isTrue);
  });

  test('an unrelated permission does not open clients or products', () {
    expect(allows('/clients', const ['warehouse']), isFalse);
    expect(allows('/products', const ['warehouse']), isFalse);
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

  // Regression guard for the exact defect that shipped twice already: a
  // screen gets built, wired into the router and even certified with its
  // own tests, and NOBODY can reach it because RouteAccessPolicy never
  // learned a rule for its path — it silently falls through to the default
  // (`path == '/' || path == '/settings'`). First the cash shift hub; then
  // /clients and /products (both live, tested screens hidden from every
  // user, admin included — docs/orbi_panel confirmed it against a real
  // Odoo). This does not hand-enumerate the route list: it reads the ACTUAL
  // paths straight out of `lib/app/router.dart`'s own source (owned by
  // another agent — read here, never written) and the ACTUAL permission
  // names this policy checks for, straight out of THIS file's own source.
  // A third orphaned route added later fails this test without anyone
  // having to remember to extend a hand-kept list.
  group('every registered route must be reachable by some permission', () {
    // Resolved relative to the package root, the way `flutter test` is
    // always invoked in this repo (see the root Makefile).
    final routerSource = File('lib/app/router.dart').readAsStringSync();
    final policySource = File(
      'lib/features/auth/route_access_policy.dart',
    ).readAsStringSync();

    // Every `path: '...'` literal in router.dart is either a GoRoute's own
    // path or an OperationalDestination mirroring one 1:1 — see the file's
    // single grep-verified `path:` inventory. A dynamic segment such as
    // `/reports/:documentId` still starts with its static prefix, so no
    // template substitution is needed for RouteAccessPolicy's prefix checks.
    final routePaths = RegExp(
      r"path:\s*'([^']+)'",
    ).allMatches(routerSource).map((m) => m.group(1)!).toSet();

    // Every permission name RouteAccessPolicy itself is written to look
    // for — NOT the set capability_provisioner.dart actually produces.
    // Whether every one of these is ever really granted is a separate
    // question from whether a route has a rule at all.
    final everyPermissionThePolicyKnows = RegExp(
      r"permissions\.contains\('([^']+)'\)",
    ).allMatches(policySource).map((m) => m.group(1)!).toSet();

    test(
      'the source extraction itself is not silently finding nothing',
      () {
        expect(routePaths, isNotEmpty);
        expect(routePaths, contains('/sales'));
        expect(routePaths, contains('/clients'));
        expect(routePaths, contains('/products'));
        expect(everyPermissionThePolicyKnows, isNotEmpty);
        expect(everyPermissionThePolicyKnows, contains('seller'));
      },
    );

    test(
      'no route falls through to the default that only opens "/" and '
      '"/settings"',
      () {
        final policy = const RouteAccessPolicy();
        final everyPermission = CapabilitySnapshot(
          scopeKey: 'scope',
          companyId: 1,
          revision: 1,
          fetchedAt: DateTime.utc(2026, 9, 11),
          permissions: everyPermissionThePolicyKnows,
        );
        final orphaned =
            routePaths
                .where(
                  (path) => !policy.allows(
                    path,
                    authenticated: true,
                    capabilities: everyPermission,
                    // Also covers /sync's developer-mode escape hatch, so a
                    // route gated ONLY behind developerMode is not
                    // misreported as orphaned.
                    developerMode: true,
                  ),
                )
                .toList()
              ..sort();
        expect(
          orphaned,
          isEmpty,
          reason:
              'These routes exist in router.dart but no rule in '
              'RouteAccessPolicy.allows ever opens them for any known '
              'permission: $orphaned. Add a rule there before this route '
              'ships — this is exactly how /clients and /products were '
              'missed.',
        );
      },
    );
  });
}
