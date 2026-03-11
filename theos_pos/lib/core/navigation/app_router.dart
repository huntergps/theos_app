import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';

// Critical path - eager (no defer)
import '../../features/authentication/screens/login_screen.dart';
import '../../shared/screens/main_screen.dart';
import '../../shared/screens/splash_screen.dart';
import '../../shared/widgets/deferred_screen.dart';

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
import '../../shared/screens/settings_screen.dart'
    deferred as settings_screen;
import '../../features/sync/screens/sync_screen.dart'
    deferred as sync_screen;
import '../../features/sync/screens/offline_sync_management_screen.dart'
    deferred as offline_sync;
import '../../shared/screens/websocket_debug_screen.dart'
    deferred as ws_debug;
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
  static const String pos = '/pos';
  static const String fastSale = '/fast-sale';
  static const String salesNew = '/sales/new';
  static const String salesDetail = '/sales/:id';
  static const String salesEdit = '/sales/:id/edit';
  static const String settings = '/settings';
  static const String sync = '/sync';
  static const String offlineSync = '/offline-sync';
  static const String websocketDebug = '/websocket-debug';
  static const String conflicts = '/conflicts';
  static const String deadLetterQueue = '/dead-letter-queue';

  /// Build collection session path with ID
  static String collectionSessionPath(int id) => '/collection/session/$id';

  /// Build sales detail path with ID
  static String salesDetailPath(int id) => '/sales/$id';

  /// Build sales edit path with ID
  static String salesEditPath(int id) => '/sales/$id/edit';

  /// Create the router instance
  static GoRouter createRouter() {
    return GoRouter(initialLocation: initialPath, routes: _routes);
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
      transitionDuration: const Duration(milliseconds: 200),
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
          pageBuilder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
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
        // Sales module con sistema de pestañas como Odoo 19.0
        // Todas las sub-rutas redirigen al contenedor con pestañas
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
        // Mantener rutas por compatibilidad pero redirigen a /sales
        GoRoute(path: salesNew, redirect: (context, state) => sales),
        GoRoute(path: salesDetail, redirect: (context, state) => sales),
        GoRoute(path: salesEdit, redirect: (context, state) => sales),
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
          path: websocketDebug,
          pageBuilder: (context, state) => _fadePage(
            state: state,
            child: DeferredScreen(
              loader: ws_debug.loadLibrary,
              builder: () => ws_debug.WebSocketDebugScreen(),
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
