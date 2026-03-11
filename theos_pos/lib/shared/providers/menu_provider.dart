import 'package:fluent_ui/fluent_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'user_provider.dart';

part 'menu_provider.g.dart';

/// Groups that have access to ALL menu options
const adminGroups = [
  'account.group_account_manager',
  'base.group_system',
];

/// Groups that have access to collection features
const collectionGroups = [
  'l10n_ec_collection_box.group_collection_user',
  'l10n_ec_collection_box.group_collection_manager',
];

/// Groups that have access to sales features
const salesGroups = [
  'sales_team.group_sale_salesman',
  'sales_team.group_sale_manager',
];

/// Definition of a menu item with permission requirements
class MenuItemDefinition {
  final String path;
  final IconData icon;
  final String title;

  /// List of group names that can access this item.
  /// If empty, the item is visible to all users.
  /// If not empty, user must belong to at least one of these groups.
  final List<String> requiredGroups;

  /// Whether this item is in the footer section
  final bool isFooterItem;

  /// Whether this is an action item (like logout) vs navigation item
  final bool isAction;

  const MenuItemDefinition({
    required this.path,
    required this.icon,
    required this.title,
    this.requiredGroups = const [],
    this.isFooterItem = false,
    this.isAction = false,
  });

  /// Check if user has permission to access this menu item
  bool hasAccess(List<String> userPermissions) {
    // If no required groups, always accessible
    if (requiredGroups.isEmpty) return true;

    // Check if user has any admin group (access to all)
    for (final adminGroup in adminGroups) {
      if (userPermissions.contains(adminGroup)) return true;
    }

    // Check if user has any of the required groups
    for (final group in requiredGroups) {
      if (userPermissions.contains(group)) return true;
    }

    return false;
  }
}

/// All menu item definitions
/// Order matters - items will be displayed in this order
const allMenuItems = [
  // === Main Navigation Items ===

  // Always visible
  MenuItemDefinition(
    path: '/',
    icon: FluentIcons.home,
    title: 'Inicio',
  ),

  // Collection groups only
  MenuItemDefinition(
    path: '/collection',
    icon: FluentIcons.money,
    title: 'Punto de Cobro',
    requiredGroups: collectionGroups,
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
    requiredGroups: salesGroups,
  ),

  // Both collection and sales groups
  MenuItemDefinition(
    path: '/fast-sale',
    icon: FluentIcons.shopping_cart,
    title: 'Venta Rápida',
    requiredGroups: [...collectionGroups, ...salesGroups],
  ),

  // === Footer Items (always visible) ===

  MenuItemDefinition(
    path: '/sync',
    icon: FluentIcons.sync,
    title: 'Sincronización',
    isFooterItem: true,
    requiredGroups: adminGroups,
  ),

  MenuItemDefinition(
    path: '/offline-sync',
    icon: FluentIcons.cloud_upload,
    title: 'Cola Offline',
    isFooterItem: true,
    requiredGroups: adminGroups,
  ),

  MenuItemDefinition(
    path: '/conflicts',
    icon: FluentIcons.error,
    title: 'Conflictos',
    isFooterItem: true,
    requiredGroups: adminGroups,
  ),

  MenuItemDefinition(
    path: '/websocket-debug',
    icon: FluentIcons.plug_connected,
    title: 'WebSocket Debug',
    isFooterItem: true,
    requiredGroups: adminGroups,
  ),

  MenuItemDefinition(
    path: '/settings',
    icon: FluentIcons.settings,
    title: 'Configuración',
    isFooterItem: true,
  ),

  // Logout action
  MenuItemDefinition(
    path: '/logout',
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

  const FilteredMenuItems({
    required this.navItems,
    required this.footerItems,
  });
}

/// Provider that returns filtered menu items based on user permissions
@riverpod
FilteredMenuItems filteredMenuItems(Ref ref) {
  final user = ref.watch(userProvider);
  final permissions = user?.permissions ?? [];

  final navItems = <MenuItemDefinition>[];
  final footerItems = <MenuItemDefinition>[];

  for (final item in allMenuItems) {
    if (!item.hasAccess(permissions)) continue;

    if (item.isFooterItem) {
      footerItems.add(item);
    } else {
      navItems.add(item);
    }
  }

  return FilteredMenuItems(
    navItems: navItems,
    footerItems: footerItems,
  );
}

/// Check if user has access to a specific route
@riverpod
bool hasRouteAccess(Ref ref, String path) {
  final user = ref.watch(userProvider);
  final permissions = user?.permissions ?? [];

  final item = allMenuItems.where((m) => m.path == path).firstOrNull;
  if (item == null) return true; // Unknown routes are accessible

  return item.hasAccess(permissions);
}
