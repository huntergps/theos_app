import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart' show CapabilitySnapshot;

final routeAccessPolicyProvider = Provider<RouteAccessPolicy>(
  (ref) => const RouteAccessPolicy(),
);

final class RouteAccessPolicy {
  const RouteAccessPolicy();

  bool allows(
    String path, {
    required bool authenticated,
    CapabilitySnapshot? capabilities,
    bool developerMode = false,
  }) {
    if (path == '/login' || path == '/splash') return true;
    if (!authenticated) return false;
    // The authenticated shell remains usable while capability retrieval is
    // pending or unavailable; gated business routes stay closed.
    if (capabilities == null) return path == '/' || path == '/settings';
    final permissions = capabilities.permissions;
    // Match the area prefix, not just the exact path. An area screen that
    // lives under its own route (for example the cash shift hub) was
    // otherwise unreachable: it fell through to the catch-all below and got
    // redirected home. A child route needing a DIFFERENT permission than its
    // area must be declared above this block, or it will inherit this one.
    if (path == '/collection' || path.startsWith('/collection/')) {
      return permissions.contains('cashier');
    }
    if (path == '/warehouse' || path.startsWith('/warehouse/')) {
      return permissions.contains('warehouse');
    }
    if (path == '/envases' || path.startsWith('/envases/')) {
      return permissions.contains('envases_read');
    }
    if (path == '/sales' || path.startsWith('/sales/')) {
      return permissions.contains('seller') || permissions.contains('cashier');
    }
    if (path == '/approvals') {
      return permissions.contains('approvals') ||
          permissions.contains('approver');
    }
    if (path == '/sync') {
      return developerMode ||
          permissions.contains('sync') ||
          permissions.contains('administrator');
    }
    if (path == '/activities') return permissions.contains('activities');
    if (path == '/notifications') return permissions.contains('notifications');
    if (path.startsWith('/reports/')) return permissions.contains('reports');
    return path == '/' || path == '/settings';
  }

  String destinationAfterLogin(
    String? returnTo, {
    required bool authenticated,
    CapabilitySnapshot? capabilities,
    bool developerMode = false,
  }) {
    if (returnTo == null || !returnTo.startsWith('/')) return '/';
    final path = Uri.tryParse(returnTo)?.path;
    if (path == null ||
        !allows(
          path,
          authenticated: authenticated,
          capabilities: capabilities,
          developerMode: developerMode,
        )) {
      return '/';
    }
    return returnTo;
  }
}
