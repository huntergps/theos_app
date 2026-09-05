import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show userManager, UserManagerBusiness;

import '../../core/database/repositories/base_repository.dart';
import '../../core/database/repositories/repository_providers.dart';
import '../../core/navigation/app_router.dart';
import '../../core/managers/manager_providers.dart'
    show resetModelManagersSession;
import '../../core/services/auth_event_service.dart';
import '../../core/services/app_initializer.dart';
import '../../core/session/session_cleanup_sequence.dart';

import 'package:odoo_sdk/odoo_sdk.dart' show logger;

import '../../core/services/platform/server_connectivity_service.dart';
import '../../features/authentication/services/server_service.dart';
import '../../features/sync/services/connectivity_sync_orchestrator.dart';
import '../../features/products/providers/product_providers.dart';
import '../../features/sales/screens/fast_sale/fast_sale_providers.dart';
import '../../features/sales/providers/order_cache_provider.dart';
import '../providers/im_status_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/server_info_provider.dart';
import '../providers/user_provider.dart';
import '../../features/sales/providers/sale_order_form_notifier.dart';
import '../../features/sync/providers/sync_provider.dart';
import '../../core/database/providers.dart';
import 'dialogs/copyable_info_bar.dart';

/// Guards the app against expired/revoked authentication.
///
/// Listens to [AuthEventService] for session expired events and performs
/// the same logout cleanup as the MainScreen logout action, then
/// redirects to the login screen.
class AuthGuard extends ConsumerStatefulWidget {
  final Widget child;

  const AuthGuard({super.key, required this.child});

  @override
  ConsumerState<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends ConsumerState<AuthGuard> {
  StreamSubscription<AuthEvent>? _subscription;
  bool _isHandlingExpiry = false;

  @override
  void initState() {
    super.initState();
    final authEventService = ref.read(authEventServiceProvider);
    _subscription = authEventService.events.listen(_handleAuthEvent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _handleAuthEvent(AuthEvent event) async {
    if (event != AuthEvent.sessionExpired) return;
    if (!mounted) return;
    if (_isHandlingExpiry) return;

    // Skip if already on login or splash
    // GoRouter may not be in context when the app is still initializing
    final GoRouter router;
    try {
      router = GoRouter.of(context);
    } catch (_) {
      // GoRouter not yet available in widget tree — skip
      return;
    }
    final currentLocation = router.routerDelegate.currentConfiguration.uri.path;
    if (currentLocation == '/login' || currentLocation == '/splash') {
      return;
    }
    _isHandlingExpiry = true;
    try {
      logger.w('[AuthGuard] Session expired detected, performing logout...');

      final offlineSync = ref.read(offlineSyncServiceProvider);
      final serverService = ref.read(serverServiceProvider.notifier);
      final currentServer = serverService.currentSession;
      final currentUserId = ref.read(userProvider)?.id;
      await runBestEffortSessionCleanup(
        [
          SessionCleanupStep('connectivity sync cancellation', () {
            ref.invalidate(connectivitySyncOrchestratorProvider);
          }),
          SessionCleanupStep(
            'foreground sync cancellation',
            ref.read(syncProvider.notifier).cancelAndWait,
          ),
          if (offlineSync != null)
            SessionCleanupStep('offline sync shutdown', offlineSync.shutdown),
          SessionCleanupStep('provider invalidation', () {
            ref.invalidate(serverHealthServiceProvider);
            ref.invalidate(serverInfoProvider);
            ref.invalidate(notificationCounterProvider);
            ref.invalidate(offlineSyncServiceProvider);
            ref.invalidate(catalogServiceProvider);
            ref.invalidate(fastSaleProvider);
            ref.invalidate(orderCacheProvider);
            ref.invalidate(imStatusProvider);
            ref.invalidate(syncProvider);
            ref.invalidate(currentSessionProvider);
            ref.invalidate(saleOrderFormProvider);
          }),
          // This marker belongs to the scoped DB and must be cleared before it.
          SessionCleanupStep(
            'current user marker',
            userManager.clearCurrentUser,
          ),
          SessionCleanupStep('model manager scope', resetModelManagersSession),
          SessionCleanupStep('repository session handles', () {
            ref.read(odooClientProvider.notifier).set(null);
            ref.read(databaseHelperProvider.notifier).set(null);
          }),
          SessionCleanupStep('session info cache', SessionInfoCache.clearCache),
          if (currentServer != null && currentUserId != null)
            SessionCleanupStep(
              'revoked offline credential',
              () => serverService.removeStoredCredential(
                serverUrl: currentServer.url,
                database: currentServer.database,
                userId: currentUserId,
              ),
            ),
          SessionCleanupStep('secure credentials', serverService.clearSession),
          SessionCleanupStep(
            'session database',
            AppInitializer.deactivateSessionScope,
          ),
        ],
        onError: (step, error, stackTrace) => logger.e(
          '[AuthGuard]',
          'Expired-session cleanup failed at $step',
          error,
          stackTrace,
        ),
      );

      ref.read(userProvider.notifier).clearUser();
      AppRouter.session.value = const RouteSessionSnapshot();

      if (!mounted) return;

      CopyableInfoBar.showError(
        context,
        title: 'Sesión expirada',
        message: 'Tu clave API ha expirado o fue revocada. Inicia sesión nuevamente.',
      );
      context.go('/login');
    } catch (error, stackTrace) {
      logger.e(
        '[AuthGuard]',
        'Unexpected expired-session handling failure',
        error,
        stackTrace,
      );
    } finally {
      _isHandlingExpiry = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
