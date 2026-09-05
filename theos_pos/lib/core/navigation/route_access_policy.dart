/// Política de acceso a rutas independiente del router y de la UI.
library;

import '../../shared/constants/user_groups.dart';

/// Requisito de acceso para una ruta o patrón de ruta.
class RouteAccessRule {
  final String pattern;
  final bool requiresAuthentication;
  final List<TheosUserRole> allowedRoles;
  final bool developerOnly;

  const RouteAccessRule({
    required this.pattern,
    this.requiresAuthentication = true,
    this.allowedRoles = const [],
    this.developerOnly = false,
  });

  bool get isRoleRestricted => allowedRoles.isNotEmpty;
}

/// Matriz default-deny compartida por guards y menú.
abstract final class RouteAccessPolicy {
  static const rules = <RouteAccessRule>[
    RouteAccessRule(pattern: '/splash', requiresAuthentication: false),
    RouteAccessRule(pattern: '/login', requiresAuthentication: false),
    RouteAccessRule(pattern: '/'),
    RouteAccessRule(pattern: '/activities'),
    RouteAccessRule(pattern: '/settings'),
    RouteAccessRule(
      pattern: '/collection',
      allowedRoles: [TheosUserRole.cashier],
    ),
    RouteAccessRule(
      pattern: '/collection/session/:id',
      allowedRoles: [TheosUserRole.cashier],
    ),
    RouteAccessRule(pattern: '/sales', allowedRoles: [TheosUserRole.seller]),
    RouteAccessRule(
      pattern: '/fast-sale',
      allowedRoles: [TheosUserRole.cashier, TheosUserRole.seller],
    ),
    RouteAccessRule(
      pattern: '/sync',
      allowedRoles: [TheosUserRole.administrator],
    ),
    RouteAccessRule(
      pattern: '/offline-sync',
      allowedRoles: [TheosUserRole.administrator],
    ),
    RouteAccessRule(
      pattern: '/conflicts',
      allowedRoles: [TheosUserRole.administrator],
      developerOnly: true,
    ),
    RouteAccessRule(
      pattern: '/dead-letter-queue',
      allowedRoles: [TheosUserRole.administrator],
      developerOnly: true,
    ),
  ];

  /// Busca la regla más específica que coincide con [rawPath].
  static RouteAccessRule? ruleFor(String rawPath) {
    final path = _normalizePath(rawPath);
    if (path == null) return null;

    for (final rule in rules) {
      if (_matches(rule.pattern, path)) return rule;
    }
    return null;
  }

  /// Evalúa acceso. La ausencia de una regla siempre deniega.
  static bool allows({
    required String path,
    required bool isAuthenticated,
    Iterable<String> permissions = const [],
    bool developerMode = false,
  }) {
    final rule = ruleFor(path);
    if (rule == null) return false;
    if (!rule.requiresAuthentication) return true;
    if (!isAuthenticated) return false;
    if (rule.developerOnly && !developerMode) return false;
    if (!rule.isRoleRestricted) return true;

    final roles = resolveTheosUserRoles(permissions);
    if (roles.contains(TheosUserRole.administrator)) return true;
    return rule.allowedRoles.any(roles.contains);
  }

  static bool isDeveloperOnly(String path) =>
      ruleFor(path)?.developerOnly ?? false;

  /// Resolves a guarded deep link after authentication. Unsafe, public,
  /// unknown, or unauthorized destinations fall back to Home.
  static String destinationAfterLogin({
    required String? returnTo,
    required Iterable<String> permissions,
    bool developerMode = false,
  }) {
    if (returnTo == null || returnTo.isEmpty) return '/';
    final location = _normalizeLocation(returnTo);
    if (location == null) return '/';
    final path = Uri.parse(location).path;
    final rule = ruleFor(path);
    if (rule == null || !rule.requiresAuthentication) return '/';
    return allows(
          path: path,
          isAuthenticated: true,
          permissions: permissions,
          developerMode: developerMode,
        )
        ? location
        : '/';
  }

  /// Grupos que satisfacen directamente los roles requeridos por [path].
  static List<String> requiredGroupsFor(String path) {
    final rule = ruleFor(path);
    if (rule == null) return const [];

    final groups = <String>{};
    for (final role in rule.allowedRoles) {
      groups.addAll(kTheosRoleGroups[role] ?? const []);
    }
    return List.unmodifiable(groups);
  }

  static String? _normalizePath(String rawPath) {
    final location = _normalizeLocation(rawPath);
    return location == null ? null : Uri.parse(location).path;
  }

  static String? _normalizeLocation(String rawLocation) {
    if (rawLocation.isEmpty) return null;
    final uri = Uri.tryParse(rawLocation);
    if (uri == null || uri.hasScheme || uri.hasAuthority) return null;

    var path = uri.path;
    if (!path.startsWith('/')) return null;
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return uri.replace(path: path).toString();
  }

  static bool _matches(String pattern, String path) {
    if (pattern == path) return true;

    final patternSegments = pattern
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    final pathSegments = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (patternSegments.length != pathSegments.length) return false;

    for (var index = 0; index < patternSegments.length; index++) {
      final expected = patternSegments[index];
      if (expected.startsWith(':')) continue;
      if (expected != pathSegments[index]) return false;
    }
    return true;
  }
}
