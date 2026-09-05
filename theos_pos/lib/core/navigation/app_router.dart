import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';

// Critical path - eager (no defer)
import '../../features/authentication/screens/login_screen.dart';
import '../../shared/screens/main_screen.dart';
import '../../shared/screens/splash_screen.dart';
import '../../shared/widgets/deferred_screen.dart';
import 'route_access_policy.dart';

// Deferred imports - loaded on navigation
import '../../features/activities/screens/activities_screen.dart'
    deferred as activities_screen;
import '../../features/collection/screens/collection_dashboard_screen.dart'
    deferred as collection_dashboard;
import '../../features/collection/screens/collection_session_screen.dart'
    deferred as collection_session;
import '../../features/sales/screens/fast_sale/fast_sale_screen.dart'
    deferred as fast_sale;
import '../../features/sales/screens/sales_tabbed_screen.dart'
    deferred as sales_tabbed;
import '../../shared/screens/settings_screen.dart' deferred as settings_screen;
import '../../features/sync/screens/sync_screen.dart' deferred as sync_screen;
import '../../features/sync/screens/offline_sync_management_screen.dart'
    deferred as offline_sync;
import '../../shared/screens/conflict_resolution_screen.dart'
    deferred as conflicts_screen;
import '../../shared/screens/dead_letter_queue_screen.dart'
    deferred as dead_letter;

/// Application Router Configuration
///
/// Centralized navigation configuration using GoRouter.
/// Following Clean Architecture, navigation is separated from main.dart
class AppRouter {
  AppRouter._();

  /// Initial route path
  static const String initialPath = '/splash';

  /// Route paths constants
  static const String splash = '/splash';
  static const String login = '/login';
  static const String home = '/';
  static const String collection = '/collection';
  static const String collectionSession = '/collection/session/:id';
  static const String activities = '/activities';
  static const String sales = '/sales';
  static const String fastSale = '/fast-sale';
  static const String settings = '/settings';
  static const String sync = '/sync';
  static const String offlineSync = '/offline-sync';
  static const String conflicts = '/conflicts';
  static const String deadLetterQueue = '/dead-letter-queue';

  /// Snapshot used by GoRouter redirects. It is deliberately free of
  /// credentials and only contains the identity/permissions needed for route
  /// authorization. Riverpod updates it from the composition root.
  static final ValueNotifier<RouteSessionSnapshot> session =
      ValueNotifier<RouteSessionSnapshot>(const RouteSessionSnapshot());

  /// Build collection session path with ID
  static String collectionSessionPath(int id) => '/collection/session/$id';

  /// Parses a collection-session route ID. Remote IDs are positive and local
  /// offline sessions may be negative, but zero is never a valid identity.
  static int? parseCollectionSessionId(String? rawId) {
    final id = int.tryParse(rawId ?? '');
    return id == null || id == 0 ? null : id;
  }

  /// Create the router instance
  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: initialPath,
      refreshListenable: session,
      redirect: _redirect,
      routes: _routes,
    );
  }

  static String? _redirect(BuildContext context, GoRouterState state) {
    // Route policy matches paths, not query strings. Using toString() here
    // made guarded routes with parameters/returnTo queries look unknown and
    // sent authenticated users back to login.
    final path = state.uri.path;
    final snapshot = session.value;
    final rule = RouteAccessPolicy.ruleFor(path);
    if (rule == null) return login;
    if (!rule.requiresAuthentication) {
      if (snapshot.isAuthenticated && path == login) {
        return RouteAccessPolicy.destinationAfterLogin(
          returnTo: state.uri.queryParameters['returnTo'],
          permissions: snapshot.permissions,
          developerMode: snapshot.developerMode,
        );
      }
      return null;
    }
    if (!snapshot.isAuthenticated) {
      return Uri(
        path: login,
        queryParameters: {'returnTo': state.uri.toString()},
      ).toString();
    }
    if (!RouteAccessPolicy.allows(
      path: path,
      isAuthenticated: true,
      permissions: snapshot.permissions,
      developerMode: snapshot.developerMode,
    )) {
      return home;
    }
    return null;
  }

  /// Helper to wrap a widget in a fade transition page
  static CustomTransitionPage<void> _fadePage({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 120),
      reverseTransitionDuration: const Duration(milliseconds: 80),
    );
  }

  /// Route definitions
  static final List<RouteBase> _routes = [
    GoRoute(path: splash, builder: (context, state) => const SplashScreen()),
    GoRoute(path: login, builder: (context, state) => const LoginScreen()),
    ShellRoute(
      builder: (context, state, child) => MainScreen(child: child),
      routes: [
        GoRoute(
          path: home,
          pageBuilder: (context, state) =>
              _fadePage(state: state, child: const HomeScreen()),
        ),
        GoRoute(
          path: collection,
          pageBuilder: (context, state) => _fadePage(
            state: state,
            child: DeferredScreen(
              loader: collection_dashboard.loadLibrary,
              builder: () => collection_dashboard.CollectionDashboardScreen(),
            ),
          ),
        ),
        GoRoute(
          path: collectionSession,
          redirect: (context, state) =>
              parseCollectionSessionId(state.pathParameters['id']) == null
              ? collection
              : null,
          pageBuilder: (context, state) {
            final id = parseCollectionSessionId(state.pathParameters['id'])!;
            return _fadePage(
              state: state,
              child: DeferredScreen(
                loader: collection_session.loadLibrary,
                builder: () =>
                    collection_session.CollectionSessionScreen(sessionId: id),
              ),
            );
          },
        ),
        GoRoute(
          path: activities,
          pageBuilder: (context, state) => _fadePage(
            state: state,
            child: DeferredScreen(
              loader: activities_screen.loadLibrary,
              builder: () => activities_screen.ActivitiesScreen(),
            ),
          ),
        ),
        // Canonical sales route with its internal tab navigation.
        GoRoute(
          path: sales,
          pageBuilder: (context, state) => _fadePage(
            state: state,
            child: DeferredScreen(
              loader: sales_tabbed.loadLibrary,
              builder: () => sales_tabbed.SalesTabbedScreen(),
            ),
          ),
        ),
        // Fast Sale POS Route
        GoRoute(
          path: fastSale,
          pageBuilder: (context, state) => _fadePage(
            state: state,
            child: DeferredScreen(
              loader: fast_sale.loadLibrary,
              builder: () => fast_sale.FastSaleScreen(),
            ),
          ),
        ),
        GoRoute(
          path: settings,
          pageBuilder: (context, state) => _fadePage(
            state: state,
            child: DeferredScreen(
              loader: settings_screen.loadLibrary,
              builder: () => settings_screen.SettingsScreen(),
            ),
          ),
        ),
        GoRoute(
          path: sync,
          pageBuilder: (context, state) => _fadePage(
            state: state,
            child: DeferredScreen(
              loader: sync_screen.loadLibrary,
              builder: () => sync_screen.SyncScreen(),
            ),
          ),
        ),
        GoRoute(
          path: offlineSync,
          pageBuilder: (context, state) => _fadePage(
            state: state,
            child: DeferredScreen(
              loader: offline_sync.loadLibrary,
              builder: () => offline_sync.OfflineSyncManagementScreen(),
            ),
          ),
        ),
        GoRoute(
          path: conflicts,
          pageBuilder: (context, state) => _fadePage(
            state: state,
            child: DeferredScreen(
              loader: conflicts_screen.loadLibrary,
              builder: () => conflicts_screen.ConflictResolutionScreen(),
            ),
          ),
        ),
        GoRoute(
          path: deadLetterQueue,
          pageBuilder: (context, state) => _fadePage(
            state: state,
            child: DeferredScreen(
              loader: dead_letter.loadLibrary,
              builder: () => dead_letter.DeadLetterQueueScreen(),
            ),
          ),
        ),
      ],
    ),
  ];
}

/// Minimal reactive route authorization state. No token or API key is kept.
@immutable
class RouteSessionSnapshot {
  const RouteSessionSnapshot({
    this.userId,
    this.permissions = const <String>[],
    this.developerMode = false,
  });

  final int? userId;
  final List<String> permissions;
  final bool developerMode;
  bool get isAuthenticated => userId != null && userId! > 0;
}
