import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:theos_pos/core/navigation/app_router.dart';
import 'package:theos_pos/core/navigation/route_access_policy.dart';
import 'package:theos_pos/features/dashboard/widgets/supervisor_dashboard.dart';
import 'package:theos_pos/shared/constants/user_groups.dart';
import 'package:theos_pos/shared/providers/menu_provider.dart';

void main() {
  group('role matrix', () {
    test('covers seller, cashier, supervisor, and administrator', () {
      expect(kTheosRoleGroups.keys, containsAll(TheosUserRole.values));
      expect(
        kTheosRoleGroups.values.every((groups) => groups.isNotEmpty),
        isTrue,
      );
    });

    test('manager groups resolve their base and elevated roles', () {
      expect(resolveTheosUserRoles([OdooUserGroup.salesManager]), {
        TheosUserRole.seller,
        TheosUserRole.supervisor,
      });
      expect(resolveTheosUserRoles([OdooUserGroup.collectionManager]), {
        TheosUserRole.cashier,
        TheosUserRole.supervisor,
      });
      expect(resolveTheosUserRoles([OdooUserGroup.systemAdministrator]), {
        TheosUserRole.supervisor,
        TheosUserRole.administrator,
      });
    });
  });

  group('RouteAccessPolicy', () {
    test('allows public routes without a session', () {
      expect(_allows('/splash', authenticated: false), isTrue);
      expect(_allows('/login', authenticated: false), isTrue);
      expect(_allows('/', authenticated: false), isFalse);
    });

    test('allows authenticated routes without a role restriction', () {
      expect(_allows('/', authenticated: true), isTrue);
      expect(_allows('/activities', authenticated: true), isTrue);
      expect(_allows('/settings', authenticated: true), isTrue);
    });

    test('keeps sales on its canonical route only', () {
      const seller = [OdooUserGroup.salesUser];

      expect(_allows('/sales', permissions: seller), isTrue);
      expect(_allows('/sales/new', permissions: seller), isFalse);
      expect(_allows('/sales/42', permissions: seller), isFalse);
      expect(_allows('/sales/42/edit', permissions: seller), isFalse);
      expect(
        _allows('/sales', permissions: [OdooUserGroup.collectionUser]),
        isFalse,
      );
    });

    test('protects collection parameterized routes', () {
      expect(
        _allows(
          '/collection/session/7',
          permissions: [OdooUserGroup.collectionUser],
        ),
        isTrue,
      );
      expect(
        _allows(
          '/collection/session/7',
          permissions: [OdooUserGroup.salesUser],
        ),
        isFalse,
      );
    });

    test(
      'accepts real and offline collection IDs but rejects malformed IDs',
      () {
        expect(AppRouter.parseCollectionSessionId('7'), 7);
        expect(AppRouter.parseCollectionSessionId('-7'), -7);
        expect(AppRouter.parseCollectionSessionId('0'), isNull);
        expect(AppRouter.parseCollectionSessionId('not-an-id'), isNull);
        expect(AppRouter.parseCollectionSessionId(null), isNull);
      },
    );

    test('fast sale accepts seller or cashier', () {
      expect(
        _allows('/fast-sale', permissions: [OdooUserGroup.salesUser]),
        isTrue,
      );
      expect(
        _allows('/fast-sale', permissions: [OdooUserGroup.collectionUser]),
        isTrue,
      );
    });

    test('administrator can access every role-restricted route', () {
      const admin = [OdooUserGroup.systemAdministrator];
      expect(_allows('/sales', permissions: admin), isTrue);
      expect(_allows('/collection/session/8', permissions: admin), isTrue);
      expect(_allows('/sync', permissions: admin), isTrue);
    });

    test('developer routes require administrator and developer mode', () {
      const admin = [OdooUserGroup.systemAdministrator];
      expect(_allows('/conflicts', permissions: admin), isFalse);
      expect(
        _allows('/conflicts', permissions: admin, developerMode: true),
        isTrue,
      );
      expect(
        _allows(
          '/conflicts',
          permissions: [OdooUserGroup.salesUser],
          developerMode: true,
        ),
        isFalse,
      );
    });

    test('normalizes query strings and trailing slashes', () {
      expect(
        _allows('/sales/?tab=lines', permissions: [OdooUserGroup.salesUser]),
        isTrue,
      );
    });

    test('denies unknown, relative, and external routes', () {
      expect(_allows('/unknown', authenticated: true), isFalse);
      expect(_allows('sales', authenticated: true), isFalse);
      expect(
        _allows('https://example.com/sales', authenticated: true),
        isFalse,
      );
    });

    test('restores only authorized guarded destinations after login', () {
      const seller = [OdooUserGroup.salesUser];
      expect(
        RouteAccessPolicy.destinationAfterLogin(
          returnTo: '/sales',
          permissions: seller,
        ),
        '/sales',
      );
      expect(
        RouteAccessPolicy.destinationAfterLogin(
          returnTo: '/sales?tab=lines&focus=3',
          permissions: seller,
        ),
        '/sales?tab=lines&focus=3',
      );
      expect(
        RouteAccessPolicy.destinationAfterLogin(
          returnTo: '/collection',
          permissions: seller,
        ),
        '/',
      );
      expect(
        RouteAccessPolicy.destinationAfterLogin(
          returnTo: 'https://malicious.example',
          permissions: seller,
        ),
        '/',
      );
      expect(
        RouteAccessPolicy.destinationAfterLogin(
          returnTo: '/login',
          permissions: seller,
        ),
        '/',
      );
    });

    test('restores developer deep links only with both required gates', () {
      const admin = [OdooUserGroup.systemAdministrator];

      expect(
        RouteAccessPolicy.destinationAfterLogin(
          returnTo: '/conflicts?filter=pending',
          permissions: admin,
        ),
        '/',
      );
      expect(
        RouteAccessPolicy.destinationAfterLogin(
          returnTo: '/conflicts?filter=pending',
          permissions: admin,
          developerMode: true,
        ),
        '/conflicts?filter=pending',
      );
    });
  });

  group('menu contract', () {
    test('router, access policy, and menu have one-to-one coverage', () {
      final router = AppRouter.createRouter();
      addTearDown(router.dispose);

      final routerPatterns = _routePatterns(router.configuration.routes);
      final policyPatterns = RouteAccessPolicy.rules
          .map((rule) => rule.pattern)
          .toSet();
      final menuPaths = allMenuItems
          .where((item) => !item.isAction)
          .map((item) => item.path)
          .toSet();

      expect(policyPatterns, routerPatterns);
      expect(
        menuPaths,
        routerPatterns.difference({
          AppRouter.splash,
          AppRouter.login,
          AppRouter.collectionSession,
        }),
      );
    });

    test('every quick action is a guarded menu destination', () {
      final menuPaths = allMenuItems
          .where((item) => !item.isAction)
          .map((item) => item.path)
          .toSet();

      for (final action in dashboardQuickActionDefinitions) {
        expect(
          menuPaths,
          contains(action.path),
          reason: '${action.path} must be exposed by the guarded menu',
        );
        expect(
          RouteAccessPolicy.ruleFor(action.path),
          isNotNull,
          reason: '${action.path} must have an access rule',
        );
      }
    });

    test('every navigation item is backed by the route policy', () {
      for (final item in allMenuItems.where((item) => !item.isAction)) {
        expect(
          RouteAccessPolicy.ruleFor(item.path),
          isNotNull,
          reason: '${item.path} must have an access rule',
        );
      }
    });

    test('actions are authenticated UI commands, not pseudo-routes', () {
      final logout = allMenuItems.singleWhere((item) => item.isAction);

      expect(RouteAccessPolicy.ruleFor(logout.path), isNull);
      expect(logout.hasAccess(const [], isAuthenticated: false), isFalse);
      expect(logout.hasAccess(const [], isAuthenticated: true), isTrue);
    });

    test('menu access uses the same role matrix and developer flag', () {
      final sales = allMenuItems.singleWhere((item) => item.path == '/sales');
      final conflicts = allMenuItems.singleWhere(
        (item) => item.path == '/conflicts',
      );

      expect(
        sales.hasAccess([OdooUserGroup.salesUser], isAuthenticated: true),
        isTrue,
      );
      expect(
        sales.hasAccess([OdooUserGroup.collectionUser], isAuthenticated: true),
        isFalse,
      );
      expect(
        sales.hasAccess([OdooUserGroup.salesUser], isAuthenticated: false),
        isFalse,
      );
      expect(
        conflicts.hasAccess([
          OdooUserGroup.systemAdministrator,
        ], isAuthenticated: true),
        isFalse,
      );
      expect(
        conflicts.hasAccess(
          [OdooUserGroup.systemAdministrator],
          isAuthenticated: true,
          developerMode: true,
        ),
        isTrue,
      );
    });

    test('nested routes select their closest visible parent', () {
      final navItems = allMenuItems
          .where((item) => !item.isFooterItem)
          .toList();
      final footerItems = allMenuItems
          .where((item) => item.isFooterItem)
          .toList();

      expect(
        selectedMenuIndex(
          currentPath: '/collection/session/-12',
          navItems: navItems,
          footerItems: footerItems,
        ),
        navItems.indexWhere((item) => item.path == '/collection'),
      );
      expect(
        selectedMenuIndex(
          currentPath: '/settings',
          navItems: navItems,
          footerItems: footerItems,
        ),
        navItems.length +
            footerItems
                .where((item) => !item.isAction)
                .toList()
                .indexWhere((item) => item.path == '/settings'),
      );
      expect(
        selectedMenuIndex(
          currentPath: '/',
          navItems: const [],
          footerItems: const [],
        ),
        isNull,
      );
    });
  });
}

Set<String> _routePatterns(Iterable<RouteBase> routes) {
  final patterns = <String>{};
  for (final route in routes) {
    if (route is GoRoute) patterns.add(route.path);
    patterns.addAll(_routePatterns(route.routes));
  }
  return patterns;
}

bool _allows(
  String path, {
  bool authenticated = true,
  List<String> permissions = const [],
  bool developerMode = false,
}) => RouteAccessPolicy.allows(
  path: path,
  isAuthenticated: authenticated,
  permissions: permissions,
  developerMode: developerMode,
);
