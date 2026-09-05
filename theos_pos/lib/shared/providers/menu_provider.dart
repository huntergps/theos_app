import 'package:fluent_ui/fluent_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'user_provider.dart';
import '../../core/navigation/route_access_policy.dart';
import '../../core/services/config_service.dart';

part 'menu_provider.g.dart';

/// Definition of a menu item with permission requirements
class MenuItemDefinition {
  final String path;
  final IconData icon;
  final String title;

  /// Whether this item is in the footer section
  final bool isFooterItem;

  /// Whether this is an action item (like logout) vs navigation item
  final bool isAction;

  const MenuItemDefinition({
    required this.path,
    required this.icon,
    required this.title,
    this.isFooterItem = false,
    this.isAction = false,
  });

  List<String> get requiredGroups => RouteAccessPolicy.requiredGroupsFor(path);

  bool get isDeveloperOnly => RouteAccessPolicy.isDeveloperOnly(path);

  /// Check if user has permission to access this menu item.
  bool hasAccess(
    List<String> userPermissions, {
    required bool isAuthenticated,
    bool developerMode = false,
  }) {
    // Actions are not routes and therefore do not belong in the route matrix.
    // They still require an authenticated shell before being rendered.
    if (isAction) return isAuthenticated;

    return RouteAccessPolicy.allows(
      path: path,
      isAuthenticated: isAuthenticated,
      permissions: userPermissions,
      developerMode: developerMode,
    );
  }
}

/// All menu item definitions
/// Order matters - items will be displayed in this order
const allMenuItems = [
  // === Main Navigation Items ===

  // Always visible
  MenuItemDefinition(path: '/', icon: FluentIcons.home, title: 'Inicio'),

  // Collection groups only
  MenuItemDefinition(
    path: '/collection',
    icon: FluentIcons.money,
    title: 'Punto de Cobro',
  ),

  // Always visible
  MenuItemDefinition(
    path: '/activities',
    icon: FluentIcons.task_logo,
    title: 'Actividades',
  ),

  // Sales groups only
  MenuItemDefinition(
    path: '/sales',
    icon: FluentIcons.bill,
    title: 'Órdenes de Venta',
  ),

  // Both collection and sales groups
  MenuItemDefinition(
    path: '/fast-sale',
    icon: FluentIcons.shopping_cart,
    title: 'Venta Rápida',
  ),

  // === Footer Items (always visible) ===
  MenuItemDefinition(
    path: '/sync',
    icon: FluentIcons.sync,
    title: 'Sincronización',
    isFooterItem: true,
  ),

  MenuItemDefinition(
    path: '/offline-sync',
    icon: FluentIcons.cloud_upload,
    title: 'Cola Offline',
    isFooterItem: true,
  ),

  MenuItemDefinition(
    path: '/conflicts',
    icon: FluentIcons.error,
    title: 'Conflictos de Sync',
    isFooterItem: true,
  ),

  MenuItemDefinition(
    path: '/dead-letter-queue',
    icon: FluentIcons.warning,
    title: 'Cola Fallida',
    isFooterItem: true,
  ),

  MenuItemDefinition(
    path: '/settings',
    icon: FluentIcons.settings,
    title: 'Configuración',
    isFooterItem: true,
  ),

  // Logout action
  MenuItemDefinition(
    path: 'logout',
    icon: FluentIcons.sign_out,
    title: 'Salir',
    isFooterItem: true,
    isAction: true,
  ),
];

/// State containing filtered menu items
class FilteredMenuItems {
  final List<MenuItemDefinition> navItems;
  final List<MenuItemDefinition> footerItems;

  const FilteredMenuItems({required this.navItems, required this.footerItems});
}

/// Provider that returns filtered menu items based on user permissions and developer mode
@riverpod
FilteredMenuItems filteredMenuItems(Ref ref) {
  final user = ref.watch(userProvider);
  final permissions = user?.permissions ?? [];
  final config = ref.watch(configServiceProvider);
  final isDeveloperMode = config.developerMode;

  final navItems = <MenuItemDefinition>[];
  final footerItems = <MenuItemDefinition>[];

  for (final item in allMenuItems) {
    if (!item.hasAccess(
      permissions,
      isAuthenticated: user != null,
      developerMode: isDeveloperMode,
    )) {
      continue;
    }

    if (item.isFooterItem) {
      footerItems.add(item);
    } else {
      navItems.add(item);
    }
  }

  return FilteredMenuItems(navItems: navItems, footerItems: footerItems);
}

/// Resolves the Fluent navigation index for a route.
///
/// Nested destinations inherit the most-specific visible parent item. Action
/// entries are excluded because Fluent UI does not include [PaneItemAction] in
/// its effective navigation index.
int? selectedMenuIndex({
  required String currentPath,
  required Iterable<MenuItemDefinition> navItems,
  required Iterable<MenuItemDefinition> footerItems,
}) {
  final items = <MenuItemDefinition>[
    ...navItems.where((item) => !item.isAction),
    ...footerItems.where((item) => !item.isAction),
  ];
  if (items.isEmpty) return null;

  var selected = -1;
  var selectedPathLength = -1;
  for (var index = 0; index < items.length; index++) {
    final candidate = items[index].path;
    final matches =
        currentPath == candidate ||
        (candidate != '/' && currentPath.startsWith('$candidate/'));
    if (matches && candidate.length > selectedPathLength) {
      selected = index;
      selectedPathLength = candidate.length;
    }
  }

  return selected >= 0 ? selected : 0;
}

/// Check if user has access to a specific route
@riverpod
bool hasRouteAccess(Ref ref, String path) {
  final user = ref.watch(userProvider);
  final permissions = user?.permissions ?? [];
  final config = ref.watch(configServiceProvider);
  final isDeveloperMode = config.developerMode;

  return RouteAccessPolicy.allows(
    path: path,
    isAuthenticated: user != null,
    permissions: permissions,
    developerMode: isDeveloperMode,
  );
}
