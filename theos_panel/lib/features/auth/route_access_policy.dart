import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart'
    show CapabilitySnapshot, ServerFeature, ServerFeatures;

final routeAccessPolicyProvider = Provider<RouteAccessPolicy>(
  (ref) => const RouteAccessPolicy(),
);

final class RouteAccessPolicy {
  const RouteAccessPolicy();

  /// [features] es opcional para no romper llamadores viejos ni pruebas que
  /// aún no lo pasan: `null` se comporta EXACTAMENTE como antes de este
  /// parámetro (sólo permisos). Sólo el menú real (`router.dart`) y su
  /// `redirect` deben pasar el `ServerFeatures` de la sesión — orden del
  /// dueño, 14-sep-2026: «theos_panel debe ser universal», toda pantalla se
  /// habilita por evidencia del servidor, y `unknown` no habilita nada (por
  /// eso [ServerFeatures.isAvailable] exige `available`, nunca `unknown`).
  bool allows(
    String path, {
    required bool authenticated,
    CapabilitySnapshot? capabilities,
    bool developerMode = false,
    ServerFeatures? features,
  }) {
    if (path == '/login' || path == '/splash') return true;
    if (!authenticated) return false;
    // Sincronización y cola offline son de TODOS los usuarios autenticados,
    // también mientras los permisos cargan o sin conexión: cada quien ve el
    // estado de sus datos locales y cambia su Modo Ruta (orden del dueño,
    // 13-sep-2026: «todos los usuarios deben poder ver la información de
    // sincronización, offline y poder cambiar su configuración»).
    if (path == '/sync' || path.startsWith('/sync/')) return true;
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
      if (!permissions.contains('cashier')) return false;
      return _hasFeature(features, ServerFeature.cashbox);
    }
    // Bodega lee hoy `sale.order` (`ScopeOrderRepository`), no un modelo de
    // picking propio: en un servidor sin ventas no hay nada que mostrar
    // aquí tampoco, así que comparte la feature `sales`, no una `stock`
    // propia todavía.
    if (path == '/warehouse' || path.startsWith('/warehouse/')) {
      if (!permissions.contains('warehouse')) return false;
      return _hasFeature(features, ServerFeature.sales);
    }
    // Saldo por tercero needs its own rule, ABOVE the generic '/envases/'
    // prefix below: it is gated by `envases_custodia`
    // (`l10n_ec_stock_envases.group_envases_custodia`), a group that does
    // NOT imply and is NOT implied by `group_envases_user` — a custodian
    // without the basic Envases group must still reach this screen, and a
    // plain Envases user must not.
    if (path == '/envases/saldo-terceros') {
      if (!permissions.contains('envases_custodia')) return false;
      return _hasFeature(features, ServerFeature.envases);
    }
    if (path == '/envases' || path.startsWith('/envases/')) {
      if (!permissions.contains('envases_read')) return false;
      return _hasFeature(features, ServerFeature.envases);
    }
    if (path == '/sales' || path.startsWith('/sales/')) {
      if (!(permissions.contains('seller') || permissions.contains('cashier'))) {
        return false;
      }
      return _hasFeature(features, ServerFeature.sales);
    }
    // Clientes y Productos son del mismo área que Órdenes/cotizaciones y
    // Mostrador, no rutas aparte: NAVIGATION_CAPABILITY_MATRIX.md las agrupa
    // en la misma fila 1 ("Ventas — Órdenes/cotizaciones; Mostrador;
    // Clientes; Productos | Ver: Documentos, clientes y productos
    // visibles"), y en el menú lateral (router.dart) llevan el mismo
    // `group: 'Ventas'` que /sales. Antes no tenían regla propia y caían al
    // 'default' de más abajo (sólo "/" y "/settings"), dejándolas
    // inalcanzables para cualquiera, admin incluido — el mismo defecto que
    // ya mordió al hub de turno de Caja.
    if (path == '/clients' || path.startsWith('/clients/')) {
      return permissions.contains('seller') || permissions.contains('cashier');
    }
    if (path == '/products' || path.startsWith('/products/')) {
      return permissions.contains('seller') || permissions.contains('cashier');
    }
    if (path == '/approvals') {
      if (!(permissions.contains('approvals') ||
          permissions.contains('approver'))) {
        return false;
      }
      return _hasFeature(features, ServerFeature.approvals);
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
    ServerFeatures? features,
  }) {
    if (returnTo == null || !returnTo.startsWith('/')) return '/';
    final path = Uri.tryParse(returnTo)?.path;
    if (path == null ||
        !allows(
          path,
          authenticated: authenticated,
          capabilities: capabilities,
          developerMode: developerMode,
          features: features,
        )) {
      return '/';
    }
    return returnTo;
  }

  /// `features == null` (llamadores viejos o pruebas) se comporta como
  /// antes de este parámetro: sólo permisos. Con `features` real, exige
  /// `available` — nunca basta con `unknown`, ver el comentario de
  /// [ServerFeatureState] en `server_features.dart`.
  static bool _hasFeature(ServerFeatures? features, ServerFeature feature) =>
      features == null || features.isAvailable(feature);
}
