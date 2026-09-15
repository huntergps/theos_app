import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/auth/route_access_policy.dart';

/// Orden del dueño, 14-sep-2026: «theos_panel debe ser universal, no sólo
/// funcionar con los módulos custom que tiene newerp» (Mepriga, por
/// ejemplo, no tiene ventas). Estas pruebas cubren `RouteAccessPolicy` con
/// el `ServerFeatures` real que `router.dart` pasa al menú y al `redirect` —
/// el mismo booleano que decide si una entrada del menú aparece
/// (`router.dart`, `.where((entry) => policy.allows(...))`).
void main() {
  const policy = RouteAccessPolicy();

  final checkedAt = DateTime.utc(2026, 9, 14);

  CapabilitySnapshot capabilities(List<String> permissions) =>
      CapabilitySnapshot(
        scopeKey: 'scope',
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime(2026),
        permissions: permissions,
      );

  ServerFeatures featuresWith(Map<ServerFeature, ServerFeatureState> states) {
    var result = ServerFeatures.empty;
    for (final entry in states.entries) {
      result = result.withState(entry.key, entry.value, checkedAt);
    }
    return result;
  }

  bool allows(
    String path,
    List<String> permissions, {
    ServerFeatures? features,
  }) => policy.allows(
    path,
    authenticated: true,
    capabilities: capabilities(permissions),
    features: features,
  );

  group('menu hides sales when the server has no sale.order', () {
    test('a seller with permission still cannot reach /sales', () {
      final features = featuresWith({
        ServerFeature.sales: ServerFeatureState.unavailable,
      });
      expect(allows('/sales', const ['seller'], features: features), isFalse);
      expect(
        allows('/sales/counter', const ['seller'], features: features),
        isFalse,
      );
    });

    test('bodega shares the sales feature: no sale.order, no bodega either', () {
      final features = featuresWith({
        ServerFeature.sales: ServerFeatureState.unavailable,
      });
      expect(
        allows('/warehouse', const ['warehouse'], features: features),
        isFalse,
      );
    });

    test('with sale.order confirmed available, the seller reaches /sales', () {
      final features = featuresWith({
        ServerFeature.sales: ServerFeatureState.available,
      });
      expect(allows('/sales', const ['seller'], features: features), isTrue);
    });
  });

  test('unknown feature enables nothing: envases_read alone is not enough '
      'when nothing has been probed yet', () {
    // `ServerFeatures.empty` is exactly what a brand-new session (or a
    // session whose probe never got a real answer) reports: every feature
    // reads as `unknown`, never `available`.
    expect(
      allows('/envases', const ['envases_read'], features: ServerFeatures.empty),
      isFalse,
    );
    expect(
      allows(
        '/collection',
        const ['cashier'],
        features: ServerFeatures.empty,
      ),
      isFalse,
    );
    expect(
      allows('/approvals', const ['approver'], features: ServerFeatures.empty),
      isFalse,
    );
  });

  test('features == null preserves the old, permissions-only behaviour for '
      'every caller that does not pass one yet', () {
    expect(allows('/sales', const ['seller']), isTrue);
    expect(allows('/collection', const ['cashier']), isTrue);
    expect(allows('/envases', const ['envases_read']), isTrue);
    expect(allows('/approvals', const ['approver']), isTrue);
  });

  test('clients and products need no server evidence: res.partner and '
      'product.product exist on every Odoo with stock', () {
    final noEvidenceAtAll = ServerFeatures.empty;
    expect(
      allows('/clients', const ['seller'], features: noEvidenceAtAll),
      isTrue,
    );
    expect(
      allows('/products', const ['seller'], features: noEvidenceAtAll),
      isTrue,
    );
  });

  test('a permission that is simply absent still refuses, features aside', () {
    final allAvailable = featuresWith({
      ServerFeature.sales: ServerFeatureState.available,
      ServerFeature.cashbox: ServerFeatureState.available,
      ServerFeature.approvals: ServerFeatureState.available,
      ServerFeature.envases: ServerFeatureState.available,
    });
    expect(allows('/collection', const ['seller'], features: allAvailable), isFalse);
  });
}
