import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import 'dart:convert';
import 'dart:math';

import '../../core/constants/app_constants.dart';
import '../../core/database/repositories/base_repository.dart';
import '../../features/authentication/services/server_service.dart';
import '../../core/services/config_service.dart';
import '../../core/services/platform/server_connectivity_service.dart';
import '../../features/sync/services/connectivity_sync_orchestrator.dart';
import '../widgets/server_info_bar.dart';
import '../widgets/server_status_widget.dart';
import '../widgets/theos_logo.dart';
import '../../core/theme/spacing.dart';
import '../providers/user_provider.dart';
import '../providers/im_status_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/server_info_provider.dart';
import '../../core/database/repositories/repository_providers.dart';
import '../../core/navigation/app_router.dart';
import '../../features/products/providers/product_providers.dart';
import '../../features/sales/screens/fast_sale/fast_sale_providers.dart';
import '../../features/sales/providers/order_cache_provider.dart';
import '../../features/sales/providers/sale_order_form_notifier.dart';
import '../../features/sync/providers/sync_provider.dart';
import '../../core/database/providers.dart';
import '../../core/services/app_initializer.dart';
import '../../core/session/session_cleanup_sequence.dart';
import '../models/im_status.dart';
import '../widgets/user_preferences_dialog.dart';
import '../constants/user_groups.dart';
import '../providers/menu_provider.dart';
import '../../features/sync/widgets/sync_status_badge.dart';
import '../../features/sync/widgets/route_mode_indicator.dart';
import '../providers/offline_queue_provider.dart';
import '../../core/managers/managers.dart';
import '../../features/dashboard/widgets/supervisor_dashboard.dart';
import '../widgets/credit_approval_notification.dart';

import 'package:theos_pos_core/theos_pos_core.dart';

/// Allows integration harnesses to render the real authenticated shell while
/// keeping every automatic synchronization writer disabled.
///
/// Production containers use `true`; read-only tests override it with `false`.
final sessionBackgroundServicesEnabledProvider = Provider<bool>((ref) => true);

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with WindowListener {
  Timer? _saveDebounceTimer;
  Timer? _startupTimer;
  bool _isMaximized = false;

  bool get _isDesktop {
    if (kIsWeb) return false;
    return [
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    ].contains(defaultTargetPlatform);
  }

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      // Get initial maximized state
      windowManager.isMaximized().then((value) => _isMaximized = value);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Let the first interactive frame settle before opening network streams
      // and starting connectivity/sync observers.
      _startupTimer = Timer(const Duration(seconds: 1), () {
        if (!mounted) return;
        unawaited(_initializeBackgroundServices());
      });
    });
  }

  /// Starts connectivity services after Home has rendered. None of this work
  /// is required to paint or navigate through locally available data.
  Future<void> _initializeBackgroundServices() async {
    if (!ref.read(sessionBackgroundServicesEnabledProvider)) {
      logger.d('[MainScreen] Background session services disabled');
      return;
    }
    final serverService = ref.read(serverServiceProvider.notifier);
    final currentSession = serverService.currentSession;
    if (currentSession != null) {
      // Initialize server health monitoring (reads the provider to trigger initialization)
      ref.read(serverHealthServiceProvider);
      logger.d('[MainScreen] ✅ Server health monitoring started');

      // Initialize connectivity sync orchestrator (auto-sync on recovery)
      ref.read(connectivitySyncOrchestratorProvider);
      logger.d('[MainScreen] ✅ Connectivity sync orchestrator initialized');
    } else {
      logger.d('[MainScreen] ⚠️ No authenticated session available');
    }
  }

  /// Stops every background consumer that can still access the current
  /// server/database. The Drift scope remains open so logout can finish its
  /// local cleanup before [AppInitializer.deactivateSessionScope] closes it.
  Future<void> _stopSessionServices() async {
    final offlineSync = ref.read(offlineSyncServiceProvider);
    await runBestEffortSessionCleanup(
      [
        // Invalidate the scheduler first. An in-flight queue drain is allowed
        // to finish, but its disposed-scope guard prevents it from starting a
        // catalog read while the session is being torn down.
        SessionCleanupStep('connectivity sync cancellation', () {
          ref.invalidate(connectivitySyncOrchestratorProvider);
        }),
        // Synchronization cancellation is cooperative. Wait for its active
        // writer before shutting down the second queue consumer.
        SessionCleanupStep(
          'foreground sync cancellation',
          ref.read(syncProvider.notifier).cancelAndWait,
        ),
        if (offlineSync != null)
          SessionCleanupStep('offline sync shutdown', offlineSync.shutdown),
        SessionCleanupStep('provider invalidation', () {
          // Background services are recreated with the next session.
          ref.invalidate(serverHealthServiceProvider);
          ref.invalidate(serverInfoProvider);
          ref.invalidate(notificationCounterProvider);
          // Data-layer providers cache DB/server-specific state.
          ref.invalidate(offlineSyncServiceProvider);
          ref.invalidate(catalogServiceProvider);
          ref.invalidate(fastSaleProvider);
          ref.invalidate(orderCacheProvider);
          ref.invalidate(imStatusProvider);

          ref.invalidate(syncProvider);
          ref.invalidate(currentSessionProvider);
          ref.invalidate(saleOrderFormProvider);
        }),
      ],
      onError: (step, error, stackTrace) => logger.e(
        '[MainScreen]',
        'Session service cleanup failed at $step',
        error,
        stackTrace,
      ),
    );
  }

  @override
  void dispose() {
    _saveDebounceTimer?.cancel();
    _startupTimer?.cancel();
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  /// Save window state with debounce to avoid excessive saves during resize
  void _saveWindowState() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!_isDesktop) return;

      final isMaximized = await windowManager.isMaximized();
      final bounds = await windowManager.getBounds();

      logger.d(
        '[MainScreen] 💾 Guardando estado de ventana: ${bounds.width}x${bounds.height}, maximized=$isMaximized',
      );

      ref
          .read(configServiceProvider.notifier)
          .updateWindowPosition(
            bounds.width,
            bounds.height,
            bounds.topLeft.dx,
            bounds.topLeft.dy,
            isMaximized: isMaximized,
          );
    });
  }

  @override
  void onWindowResized() {
    // Called when window resize is complete
    if (!_isMaximized) {
      _saveWindowState();
    }
  }

  @override
  void onWindowMoved() {
    // Save position when window is moved
    if (!_isMaximized) {
      _saveWindowState();
    }
  }

  @override
  void onWindowMaximize() {
    _isMaximized = true;
    _saveWindowState();
  }

  @override
  void onWindowUnmaximize() {
    _isMaximized = false;
    _saveWindowState();
  }

  @override
  void onWindowClose() async {
    if (!_isDesktop) return;

    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose && mounted) {
      showDialog(
        context: context,
        builder: (_) {
          return ContentDialog(
            title: const Text('Confirmar cierre'),
            content: const Text(
              '¿Estás seguro de que deseas cerrar la aplicación?',
            ),
            actions: [
              Button(
                child: const Text('No'),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              FilledButton(
                child: const Text('Sí'),
                onPressed: () async {
                  Navigator.pop(context);

                  // Save window bounds and maximized state
                  final bounds = await windowManager.getBounds();
                  final isMaximized = await windowManager.isMaximized();

                  // Update config service
                  ref
                      .read(configServiceProvider.notifier)
                      .updateWindowPosition(
                        bounds.width,
                        bounds.height,
                        bounds.topLeft.dx,
                        bounds.topLeft.dy,
                        isMaximized: isMaximized,
                      );

                  // Closing the window is not logout: retain the secure
                  // session, but finish every local writer and close Drift
                  // cleanly before terminating the process. A failed service
                  // stop must never skip the database close.
                  await runBestEffortSessionCleanup(
                    [
                      SessionCleanupStep(
                        'session services',
                        _stopSessionServices,
                      ),
                      SessionCleanupStep(
                        'model manager scope',
                        resetModelManagersSession,
                      ),
                      SessionCleanupStep('repository session handles', () {
                        ref.read(odooClientProvider.notifier).set(null);
                        ref.read(databaseHelperProvider.notifier).set(null);
                      }),
                      SessionCleanupStep(
                        'session database',
                        AppInitializer.deactivateSessionScope,
                      ),
                    ],
                    onError: (step, error, stackTrace) => logger.e(
                      '[MainScreen]',
                      'Application close cleanup failed at $step',
                      error,
                      stackTrace,
                    ),
                  );

                  await windowManager.destroy();
                },
              ),
            ],
          );
        },
      );
    }
  }

  /// Calculate selected index based on current route and filtered menu items
  int? _calculateSelectedIndex(
    BuildContext context,
    List<MenuItemDefinition> navItems,
    List<MenuItemDefinition> footerItems,
  ) => selectedMenuIndex(
    currentPath: GoRouterState.of(context).uri.path,
    navItems: navItems,
    footerItems: footerItems,
  );

  /// Build navigation pane items from menu definitions
  List<NavigationPaneItem> _buildNavItems(List<MenuItemDefinition> items) {
    final List<NavigationPaneItem> result = [];
    for (final item in items) {
      // El ítem de Órdenes de Venta muestra badge con solicitudes de crédito pendientes
      final icon = item.path == '/sales'
          ? SalesBadgeIcon(baseIcon: item.icon)
          : Icon(item.icon);

      result.add(
        PaneItem(
          key: ValueKey(item.path),
          icon: icon,
          title: Text(item.title),
          body: const SizedBox.shrink(),
        ),
      );
    }
    return result;
  }

  /// Build footer pane items from menu definitions
  List<NavigationPaneItem> _buildFooterItems(List<MenuItemDefinition> items) {
    final List<NavigationPaneItem> result = [];
    for (final item in items) {
      if (item.isAction) {
        result.add(
          PaneItemAction(
            key: ValueKey(item.path),
            icon: Icon(item.icon),
            title: Text(item.title),
            onTap: () async {
              final navigator = GoRouter.of(context);

              final serverService = ref.read(serverServiceProvider.notifier);
              final currentServer = serverService.currentSession;
              final currentUserId = ref.read(userProvider)?.id;
              await runBestEffortSessionCleanup(
                [
                  // Stop writers first, but keep Drift open for local cleanup.
                  SessionCleanupStep('session services', _stopSessionServices),
                  SessionCleanupStep(
                    'current user marker',
                    userManager.clearCurrentUser,
                  ),
                  SessionCleanupStep(
                    'model manager scope',
                    resetModelManagersSession,
                  ),
                  SessionCleanupStep('repository session handles', () {
                    ref.read(odooClientProvider.notifier).set(null);
                    ref.read(databaseHelperProvider.notifier).set(null);
                  }),
                  SessionCleanupStep('session info cache', () {
                    SessionInfoCache.clearCache();
                  }),
                  if (currentServer != null && currentUserId != null)
                    SessionCleanupStep(
                      'remembered offline credential',
                      () => serverService.removeStoredCredential(
                        serverUrl: currentServer.url,
                        database: currentServer.database,
                        userId: currentUserId,
                      ),
                    ),
                  SessionCleanupStep(
                    'secure credentials',
                    serverService.clearSession,
                  ),
                  // The scoped database is always the final session resource.
                  SessionCleanupStep(
                    'session database',
                    AppInitializer.deactivateSessionScope,
                  ),
                ],
                onError: (step, error, stackTrace) => logger.e(
                  '[MainScreen]',
                  'Logout cleanup failed at $step',
                  error,
                  stackTrace,
                ),
              );

              ref.read(userProvider.notifier).clearUser();
              AppRouter.session.value = const RouteSessionSnapshot();

              navigator.go('/login');
            },
          ),
        );
      } else {
        result.add(
          PaneItem(
            key: ValueKey(item.path),
            icon: Icon(item.icon),
            title: Text(item.title),
            body: const SizedBox.shrink(),
          ),
        );
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configServiceProvider);
    final spacing = ref.watch(themedSpacingProvider);
    final canAccessOfflineSync = ref.watch(
      hasRouteAccessProvider(AppRouter.offlineSync),
    );
    final canAccessSync = ref.watch(hasRouteAccessProvider(AppRouter.sync));
    final canAccessActivities = ref.watch(
      hasRouteAccessProvider(AppRouter.activities),
    );

    // Get filtered menu items based on user permissions
    final filteredMenu = ref.watch(filteredMenuItemsProvider);
    final navItems = _buildNavItems(filteredMenu.navItems);
    final footerItems = _buildFooterItems(filteredMenu.footerItems);

    // Determine display mode based on device type and config
    PaneDisplayMode displayMode = config.displayMode;

    // Check if it's a phone (or small screen) to force auto mode
    // We use a LayoutBuilder or MediaQuery to check screen width.
    // However, NavigationView doesn't provide constraints directly in build.
    // We can use MediaQuery.
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone =
        screenWidth < ScreenBreakpoints.mobileMaxWidth &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);

    if (isPhone) {
      displayMode = PaneDisplayMode.auto;
    }

    return CreditApprovalNotificationListener(
      child: Column(
        children: [
          Expanded(
            child: NavigationView(
              titleBar: SingleInsetTitleBar(
                key: appShellHeaderKey,
                content: DragToMoveArea(
                  key: appShellHeaderContentKey,
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text('Orbi ERP'),
                      ),
                      const Spacer(),
                      // Route Mode Badge — aparece cuando el vendedor activa Modo Ruta
                      Padding(
                        padding: EdgeInsets.only(right: spacing.sm),
                        child: const RouteModeIndicatorBadge(),
                      ),

                      // Offline Mode Indicator
                      Consumer(
                        builder: (context, ref, child) {
                          // Use the same live authority as the green server
                          // status badge. The old session flag meant "login
                          // was restored offline" and remained true after the
                          // connection recovered, showing both states at once.
                          final isOffline = !ref.watch(isServerOnlineProvider);
                          if (!isOffline) return const SizedBox.shrink();

                          return Padding(
                            padding: EdgeInsets.only(right: spacing.sm),
                            child: Tooltip(
                              message: 'Sin internet — Sus ventas están seguras y se enviarán cuando vuelva la conexión',
                              child: Semantics(
                                label: 'Sin internet',
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 44,
                                  ),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.orange,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            FluentIcons.cloud_not_synced,
                                            size: 14,
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Sin internet',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Pending offline operations badge — always visible when there are ops queued
                      Consumer(
                        builder: (context, ref, child) {
                          final offlineState = ref.watch(offlineQueueProvider);
                          final pendingCount = offlineState.totalCount;
                          if (pendingCount == 0 || !canAccessOfflineSync) {
                            return const SizedBox.shrink();
                          }

                          final label = pendingCount == 1
                              ? '1 pendiente'
                              : '$pendingCount pendientes';

                          return Padding(
                            padding: EdgeInsets.only(right: spacing.sm),
                            child: Tooltip(
                              message:
                                  '$pendingCount ${pendingCount == 1 ? 'operación pendiente' : 'operaciones pendientes'} de enviar al servidor',
                              child: Semantics(
                                button: true,
                                label: label,
                                child: GestureDetector(
                                  onTap: () =>
                                      context.go(AppRouter.offlineSync),
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 44,
                                      ),
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: Colors.orange,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                FluentIcons.cloud_upload,
                                                size: 14,
                                                color: Colors.orange,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                label,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Sync Status Badge - shows sync progress and errors
                      if (canAccessSync)
                        Padding(
                          padding: EdgeInsets.only(right: spacing.sm),
                          child: SyncStatusBadge(
                            size: 24,
                            showTooltip: true,
                            onTap: () => context.go(AppRouter.sync),
                          ),
                        ),

                      // Activities
                      if (canAccessActivities)
                        Consumer(
                          builder: (context, ref, child) {
                            final counters = ref.watch(
                              notificationCounterProvider,
                            );
                            final activityCount = counters.activityCounter;

                            return Tooltip(
                              message: 'Actividades pendientes',
                              child: IconButton(
                                icon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        const Icon(FluentIcons.clock, size: 20),
                                        if (activityCount > 0)
                                          Positioned(
                                            top: -4,
                                            right: -4,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              constraints: const BoxConstraints(
                                                minWidth: 14,
                                                minHeight: 14,
                                              ),
                                              child: Text(
                                                activityCount > 99
                                                    ? '99+'
                                                    : '$activityCount',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (screenWidth >=
                                        ScreenBreakpoints.tabletMaxWidth) ...[
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Actividades',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ],
                                ),
                                onPressed: () {
                                  context.go(AppRouter.activities);
                                },
                              ),
                            );
                          },
                        ),
                      spacing.horizontal.sm,

                      // Server Status Indicator
                      const ServerStatusWidget(showLatency: true),
                      spacing.horizontal.sm,

                      // Theme Toggle
                      Tooltip(
                        message: 'Cambiar Tema',
                        child: IconButton(
                          icon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                FluentTheme.of(context).brightness ==
                                        Brightness.dark
                                    ? FluentIcons.sunny
                                    : FluentIcons.clear_night,
                                size: 20,
                              ),
                              if (screenWidth >=
                                  ScreenBreakpoints.tabletMaxWidth) ...[
                                const SizedBox(width: 4),
                                Text(
                                  FluentTheme.of(context).brightness ==
                                          Brightness.dark
                                      ? 'Claro'
                                      : 'Oscuro',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                          onPressed: () {
                            final currentMode = ref
                                .read(configServiceProvider)
                                .themeMode;
                            final newMode = currentMode == ThemeMode.dark
                                ? ThemeMode.light
                                : ThemeMode.dark;
                            ref
                                .read(configServiceProvider.notifier)
                                .setThemeMode(newMode);
                          },
                        ),
                      ),
                      spacing.horizontal.md,

                      // User Profile
                      UserProfileBar(spacing: spacing),

                      if (!kIsWeb &&
                          (defaultTargetPlatform == TargetPlatform.windows ||
                              defaultTargetPlatform == TargetPlatform.macOS ||
                              defaultTargetPlatform == TargetPlatform.linux))
                        SizedBox(
                          width: 138,
                          height: 50,
                          child: WindowCaption(
                            brightness: FluentTheme.of(context).brightness,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              pane: NavigationPane(
                header: Padding(
                  padding: EdgeInsets.only(left: spacing.sm),
                  child: TheosLogoName(height: 32),
                ),
                selected: _calculateSelectedIndex(
                  context,
                  filteredMenu.navItems,
                  filteredMenu.footerItems,
                ),
                onChanged: (index) {
                  final allItems = <MenuItemDefinition>[
                    ...filteredMenu.navItems.where((item) => !item.isAction),
                    ...filteredMenu.footerItems.where((item) => !item.isAction),
                  ];
                  if (index < 0 || index >= allItems.length) return;
                  final item = allItems[index];
                  if (!item.isAction &&
                      GoRouterState.of(context).uri.path != item.path) {
                    context.go(item.path);
                  }
                },
                displayMode: displayMode,
                items: navItems,
                footerItems: footerItems,
              ),
              paneBodyBuilder: (item, body) => widget.child,
            ),
          ),
          const ServerInfoBar(),
        ],
      ),
    );
  }
}

const appShellHeaderHeight = 50.0;
const appShellHeaderKey = ValueKey<String>('app-shell-header');
const appShellHeaderContentKey = ValueKey<String>('app-shell-header-content');

/// Fluent's stock [TitleBar] applies the system inset twice: once in its
/// `SafeArea` and again in `calculateHeight`. This keeps the `TitleBar` type so
/// NavigationView uses the correct effective height in its iPad pane modes,
/// while applying the still-unconsumed inset exactly once to the controls.
class SingleInsetTitleBar extends TitleBar {
  const SingleInsetTitleBar({required super.content, super.key})
    : super(height: appShellHeaderHeight, isBackButtonVisible: false);

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: FluentTheme.of(context).scaffoldBackgroundColor,
      child: SizedBox(
        width: double.infinity,
        height: appShellHeaderHeight + topInset,
        child: Padding(
          padding: EdgeInsets.only(top: topInset),
          child: SizedBox(height: appShellHeaderHeight, child: content),
        ),
      ),
    );
  }
}

class UserProfileBar extends ConsumerWidget {
  const UserProfileBar({super.key, required this.spacing});

  final ThemedSpacing spacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    return Padding(
      padding: EdgeInsets.only(right: spacing.ms),
      child: Row(
        children: [
          if (MediaQuery.of(context).size.width >=
              ScreenBreakpoints.tabletMaxWidth) ...[
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  user?.companyName ?? 'Cargando...',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  user?.name ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
            SizedBox(width: spacing.sm),
          ],
          _UserAvatarMenu(user: user),
        ],
      ),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  static const startSaleKey = ValueKey<String>('home.start-sale');

  const HomeScreen({super.key});

  /// Returns true when the user has supervisor-level permissions:
  /// collection_manager, sale_manager, account_manager, or system admin.
  bool _isSupervisor(List<String> permissions) {
    return kSupervisorGroups.any((g) => permissions.contains(g));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final user = ref.watch(userProvider);
    final spacing = ref.watch(themedSpacingProvider);

    final permissions = user?.permissions ?? [];
    final isSupervisor = _isSupervisor(permissions);
    final canStartFastSale = ref.watch(
      hasRouteAccessProvider(AppRouter.fastSale),
    );

    if (isSupervisor) {
      return ScaffoldPage.scrollable(
        header: PageHeader(title: Text('Hola, ${user?.name ?? 'Usuario'}')),
        children: [const SupervisorDashboard()],
      );
    }

    // Vista de cajero basico: boton unico para empezar a vender
    return ScaffoldPage.scrollable(
      header: PageHeader(title: Text('Hola, ${user?.name ?? 'Usuario'}')),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                spacing.vertical.lg,
                Icon(
                  FluentIcons.shopping_cart,
                  size: 64,
                  color: theme.accentColor,
                ),
                spacing.vertical.md,
                Text('Listo para vender', style: theme.typography.subtitle),
                spacing.vertical.sm,
                Text(
                  'Selecciona una opcion del menu o empieza una venta rapida',
                  style: theme.typography.body?.copyWith(
                    color: theme.inactiveColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                spacing.vertical.lg,
                if (canStartFastSale)
                  SizedBox(
                    width: 280,
                    height: 48,
                    child: FilledButton(
                      key: startSaleKey,
                      onPressed: () => context.go(AppRouter.fastSale),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(FluentIcons.shopping_cart, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Empezar a Vender',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                spacing.vertical.xl,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _UserAvatarMenu extends ConsumerStatefulWidget {
  final User? user;

  const _UserAvatarMenu({required this.user});

  @override
  ConsumerState<_UserAvatarMenu> createState() => _UserAvatarMenuState();
}

class _UserAvatarMenuState extends ConsumerState<_UserAvatarMenu> {
  final FlyoutController _controller = FlyoutController();
  Uint8List? _cachedAvatarBytes;
  String? _lastAvatarString;

  @override
  void initState() {
    super.initState();
    _updateAvatarCache();
  }

  @override
  void didUpdateWidget(_UserAvatarMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user?.avatar128 != oldWidget.user?.avatar128) {
      _updateAvatarCache();
    }
  }

  void _updateAvatarCache() {
    final avatar = widget.user?.avatar128;
    if (avatar != _lastAvatarString) {
      _lastAvatarString = avatar;
      if (_isValidAvatar(avatar)) {
        try {
          _cachedAvatarBytes = base64Decode(avatar!);
        } catch (e) {
          logger.d('Error decoding avatar: $e');
          _cachedAvatarBytes = null;
        }
      } else {
        _cachedAvatarBytes = null;
      }
    }
  }

  Color _getRandomColor(String input) {
    final int hash = input.hashCode;
    final Random random = Random(hash);
    return Color.fromARGB(
      255,
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
    );
  }

  /// Check if avatar is valid (not null, not empty, not 'false', not SVG)
  bool _isValidAvatar(String? avatar) {
    if (avatar == null || avatar.isEmpty || avatar == 'false') return false;
    // SVG starts with "PD94bWwg" (<?xml) when base64 encoded - Flutter can't decode SVG
    if (avatar.startsWith('PD94bWwg')) return false;
    return true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final initial = user?.name.isNotEmpty == true
        ? user!.name[0].toUpperCase()
        : 'U';
    final backgroundColor = user?.name.isNotEmpty == true
        ? _getRandomColor(user!.name)
        : Colors.grey;

    return FlyoutTarget(
      controller: _controller,
      child: GestureDetector(
        onTap: () {
          _controller.showFlyout(
            autoModeConfiguration: FlyoutAutoConfiguration(
              preferredMode: FlyoutPlacementMode.bottomRight,
            ),
            barrierDismissible: true,
            dismissOnPointerMoveAway: false,
            builder: (context) {
              // Use Consumer here to access provider inside the flyout
              return Consumer(
                builder: (context, ref, _) {
                  final currentImStatus = ref.watch(imStatusProvider);
                  return MenuFlyout(
                    items: [
                      const MenuFlyoutSeparator(),
                      // IM Status Submenu - Matches Odoo 19.0
                      MenuFlyoutSubItem(
                        text: Text(currentImStatus.label),
                        leading: Icon(
                          currentImStatus.icon,
                          color: currentImStatus.color,
                          size: 14,
                        ),
                        items: (context) => ImStatus.values.map((status) {
                          final isSelected = currentImStatus == status;
                          return MenuFlyoutItem(
                            text: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    if (isSelected)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 4),
                                        child: Icon(
                                          FluentIcons.check_mark,
                                          size: 12,
                                        ),
                                      )
                                    else
                                      const SizedBox(width: 16),
                                    Text(status.label),
                                  ],
                                ),
                                if (status.description != null) ...[
                                  const SizedBox(height: 2),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 16),
                                    child: Text(
                                      status.description!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            leading: Icon(
                              status.icon,
                              color: status.color,
                              size: 14,
                            ),
                            onPressed: () async {
                              await ref
                                  .read(imStatusProvider.notifier)
                                  .setStatus(status);
                              // Close flyout after selection if desired, or let it stay
                            },
                          );
                        }).toList(),
                      ),
                      MenuFlyoutItem(
                        text: const Text('Mis preferencias'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const UserPreferencesDialog(),
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(4),
                image: _cachedAvatarBytes != null
                    ? DecorationImage(
                        image: MemoryImage(_cachedAvatarBytes!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: _cachedAvatarBytes == null
                  ? Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            Positioned(
              bottom: -2,
              right: -2,
              child: Consumer(
                builder: (context, ref, _) {
                  final currentImStatus = ref.watch(imStatusProvider);
                  return Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: currentImStatus.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: FluentTheme.of(context).scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
